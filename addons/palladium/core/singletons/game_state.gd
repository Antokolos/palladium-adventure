extends Node
class_name PLDGameState

signal game_saved()
signal game_loaded()
signal shader_cache_processed()
signal player_registered(player)
signal rest_state_changed(player, previous_state, new_state)
signal teleported_to(player, origin, basis)
signal player_surge(player, enabled)
signal player_underwater(player, enabled)
signal player_poisoned(player, enabled, intoxication_rate)
signal item_taken(item_id, count_total, count_taken, item_path)
signal item_removed(item_id, count_total, count_removed)
signal item_used(player_node, target, item_id, item_count)
signal health_changed(name_hint, health_current, health_max)
signal oxygen_changed(name_hint, oxygen_current, oxygen_max)
signal action_points_changed(name_hint, action_points_current, action_points_max)
signal flashlight_state_changed(camera, flashlight_on)

enum DoorState {
	DEFAULT = 0,
	OPENED = 1,
	CLOSED = 2
}

enum LightState {
	DEFAULT = 0,
	ON = 1,
	OFF = 2
}

enum ContainerState {
	DEFAULT = 0,
	OPENED = 1,
	CLOSED = 2
}

enum TakableState {
	DEFAULT = 0,
	PRESENT = 1,
	ABSENT = 2
}

enum ActivatableState {
	DEFAULT = 0,
	ACTIVATED = 1,
	DEACTIVATED = 2,
	PAUSED = 3,
	ACTIVATED_FOREVER = 4,
	DEACTIVATED_FOREVER = 5,
	PAUSED_FOREVER = 6
}

enum TimeOfDay {
	MORNING = 0,
	DAY = 1,
	EVENING = 2,
	NIGHT = 3
}

const SPEED_SCALE_INFINITY = 1000.0
const SKY_ROTATION_DEGREES_DEFAULT = Vector3(0, 160, 0)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_BLACK = Color(0, 0, 0, 0)
const DOORS_DEFAULT = {}
const LIGHTS_DEFAULT = {}
const CONTAINERS_DEFAULT = {}
const TAKABLES_DEFAULT = {}
const LOOTABLES_DEFAULT = {}
const ACTIVATABLES_DEFAULT = {}
const MULTISTATES_DEFAULT = {}
const MESSAGES_DEFAULT = {
	"MESSAGE_CHANGE_SETTINGS" : true,
	"MESSAGE_CONTROLS_MOVE" : true,
	"MESSAGE_CONTROLS_ITEMS" : true,
	"MESSAGE_CONTROLS_ITEMS_KEYS" : true,
	"MESSAGE_CONTROLS_INVENTORY" : true,
	"MESSAGE_CONTROLS_EXAMINE" : true,
	"MESSAGE_CONTROLS_FLASHLIGHT" : true,
	"MESSAGE_CONTROLS_CROUCH" : true,
	"MESSAGE_CONTROLS_JUMP" : true,
	"MESSAGE_CONTROLS_SWIM_UP" : true,
	"MESSAGE_CONTROLS_DIALOGUE_1" : true,
	"MESSAGE_CONTROLS_DIALOGUE_2" : true,
	"MESSAGE_CONTROLS_TOGGLE_ITEM_1" : true,
	"MESSAGE_CONTROLS_TOGGLE_ITEM_2" : true
}
const CHARACTER_STATS_DEFAULT = {
	"health_current" : PLDDB.PLAYER_HEALTH_CURRENT_DEFAULT,
	"health_max" : PLDDB.PLAYER_HEALTH_MAX_DEFAULT,
	"oxygen_current" : PLDDB.PLAYER_OXYGEN_CURRENT_DEFAULT,
	"oxygen_max" : PLDDB.PLAYER_OXYGEN_MAX_DEFAULT,
	"action_points_current" : PLDDB.PLAYER_ACTION_POINTS_CURRENT_DEFAULT,
	"action_points_max" : PLDDB.PLAYER_ACTION_POINTS_MAX_DEFAULT
}

var characters_cache = {}
var characters_transition_data = {}
var scenes_data = {}
var saving_disabled = false
var slot_to_load_from = -1
var scene_path = PLDDB.SCENE_PATH_DEFAULT
var is_transition = false
var is_level_ready = false setget set_level_ready, is_level_ready
var player_name_hint = ""
var party_stats = {}
var player_paths = {}
var room_enabler_paths = {}
var usable_paths = {}
var activatable_paths = {}
var conversation_area_paths = {}
var story_vars = PLDDB.STORY_VARS_DEFAULT.duplicate(true)
var inventory = PLDDB.INVENTORY_DEFAULT.duplicate(true)
var quick_items = PLDDB.QUICK_ITEMS_DEFAULT.duplicate(true)
var doors = DOORS_DEFAULT.duplicate(true)
var lights = LIGHTS_DEFAULT.duplicate(true)
var containers = CONTAINERS_DEFAULT.duplicate(true)
var takables = TAKABLES_DEFAULT.duplicate(true)
var lootables = LOOTABLES_DEFAULT.duplicate(true)
var activatables = ACTIVATABLES_DEFAULT.duplicate(true)
var multistates = MULTISTATES_DEFAULT.duplicate(true)
var messages = MESSAGES_DEFAULT.duplicate(true)

var sky_outside
var sky_inside
var sky_rotation_degrees = SKY_ROTATION_DEGREES_DEFAULT
var time_of_day = TimeOfDay.MORNING

var _pldrt = null

func init(pldrt):
	_pldrt = pldrt
	return self

static func process_activatables(source):
	var result = {}
	for sk in source.keys():
		result[sk] = lookup_activatable_state_from_int(source[sk])
	return result

static func lookup_activatable_state_from_int(state : int):
	for activatable_state in ActivatableState:
		if state == ActivatableState[activatable_state]:
			return ActivatableState[activatable_state]
	return ActivatableState.DEFAULT

# Because item_ids are saved as ints but should be enums
static func sanitize_items(inv):
	var result = {}
	for k in inv:
		var items = inv[k]
		result[k] = []
		for item in items:
			result[k].append({ "item_id" : PLDDB.lookup_takable_from_int(item.item_id) if item.item_id else null, "count" : int(item.count) })
	return result

func _ready():
	reset_all()

func reset_all():
	cleanup_paths()
	reset_variables()
	clear_caches()

func is_level_ready():
	return is_level_ready

func set_level_ready(level_ready):
	is_level_ready = level_ready
	if level_ready:
		clear_caches()
	else:
		get_tree().paused = true # To prevent possible NPEs

func clear_caches():
	characters_cache.clear()

func cleanup_paths():
	player_paths.clear()
	room_enabler_paths.clear()
	usable_paths.clear()
	activatable_paths.clear()
	conversation_area_paths.clear()

func reset_variables():
	sky_outside = PanoramaSky.new()
	sky_outside.panorama = load("res://addons/palladium/assets/cape_hill_4k.hdr")
	sky_outside.radiance_size = Sky.RADIANCE_SIZE_32
	sky_inside = PanoramaSky.new()
	sky_inside.panorama = load("res://addons/palladium/assets/ui/undersky5.png")
	sky_inside.radiance_size = Sky.RADIANCE_SIZE_32
	sky_rotation_degrees = SKY_ROTATION_DEGREES_DEFAULT
	time_of_day = TimeOfDay.MORNING
	scene_path = PLDDB.SCENE_PATH_DEFAULT
	scenes_data = {}
	player_name_hint = ""
	party_stats[PLDChars.PLAYER_NAME_HINT] = CHARACTER_STATS_DEFAULT.duplicate(true)
	story_vars = PLDDB.STORY_VARS_DEFAULT.duplicate(true)
	inventory = PLDDB.INVENTORY_DEFAULT.duplicate(true)
	quick_items = PLDDB.QUICK_ITEMS_DEFAULT.duplicate(true)
	doors = DOORS_DEFAULT.duplicate(true)
	lights = LIGHTS_DEFAULT.duplicate(true)
	containers = CONTAINERS_DEFAULT.duplicate(true)
	takables = TAKABLES_DEFAULT.duplicate(true)
	lootables = LOOTABLES_DEFAULT.duplicate(true)
	activatables = ACTIVATABLES_DEFAULT.duplicate(true)
	multistates = MULTISTATES_DEFAULT.duplicate(true)
	messages = MESSAGES_DEFAULT.duplicate(true)

func get_game_window_parent():
	return get_node("/root/HUD") if has_node("/root/HUD") else null

func connect_video_cutscene_finished(target : Object, method : String, binds : Array = [], flags : int = 0):
	var gwp = get_game_window_parent()
	if gwp and gwp.has_node("video_cutscene"):
		return gwp.get_node("video_cutscene").connect("video_cutscene_finished", target, method, binds, flags)
	return FAILED

func is_video_cutscene():
	var gwp = get_game_window_parent()
	if gwp and gwp.has_node("video_cutscene"):
		return gwp.get_node("video_cutscene").is_playing()

func play_video_cutscene(video_file_name):
	var gwp = get_game_window_parent()
	if gwp and gwp.has_node("video_cutscene"):
		gwp.get_node("video_cutscene").play(video_file_name)

func get_hud():
	var gwp = get_game_window_parent()
	return gwp.get_node("hud") if gwp and gwp.has_node("hud") else null

func get_active_item():
	var hud = _pldrt.game_state.get_hud()
	return hud.get_active_item() if hud else null

func get_viewport():
	return (
		get_node("/root/HUD/ViewportContainer/Viewport")
			if has_node("/root/HUD/ViewportContainer/Viewport")
			else get_root_viewport()
	)

func get_root_viewport():
	return get_node("/root")

func get_player():
	return get_node(player_paths[player_name_hint]) if has_character(player_name_hint) else null

func get_companion(name_hint = null):
	if not name_hint:
		var companions = get_companions()
		return companions[0] if companions.size() > 0 else null
	return get_character(name_hint)

func get_name_hints():
	var name_hints = []
	for name_hint in player_paths.keys():
		name_hints.append(name_hint)
	return name_hints

func get_companions():
	var result = []
	for character in get_characters():
		var name_hint = character.get_name_hint()
		if character.is_in_party() and name_hint != player_name_hint:
			var companion_node = get_character(name_hint)
			if companion_node:
				result.append(companion_node)
	return result

func has_character(name_hint):
	return name_hint and player_paths.has(name_hint) and has_node(player_paths[name_hint])

func get_character(name_hint):
	if characters_cache.has(name_hint):
		return characters_cache[name_hint]
	var ch = get_node(player_paths[name_hint]) if has_character(name_hint) else null
	if ch:
		characters_cache[name_hint] = ch
	return ch

func get_characters():
	var result = []
	for name_hint in get_name_hints():
		var character_node = get_character(name_hint)
		if character_node:
			result.append(character_node)
	return result

func get_room_enabler_path(room_id):
	if not room_id \
		or room_id == PLDDB.RoomIds.NONE \
		or not room_enabler_paths.has(room_id):
		return null
	return room_enabler_paths[room_id]

func get_room_enabler(room_id):
	var room_path = get_room_enabler_path(room_id)
	if not room_path or not has_node(room_path):
		return null
	return get_node(room_path)

func get_usable_path(usable_id):
	if not usable_id \
		or usable_id == PLDDB.UsableIds.NONE \
		or not usable_paths.has(usable_id):
		return null
	return usable_paths[usable_id]

func get_usable(usable_id):
	var usable_path = get_usable_path(usable_id)
	if not usable_path or not has_node(usable_path):
		return null
	return get_node(usable_path)

func get_activatable_path(activatable_id):
	if not activatable_id \
		or activatable_id == PLDDB.ActivatableIds.NONE \
		or not activatable_paths.has(activatable_id):
		return null
	return activatable_paths[activatable_id]

func get_activatable(activatable_id):
	var activatable_path = get_activatable_path(activatable_id)
	if not activatable_path or not has_node(activatable_path):
		return null
	return get_node(activatable_path)

func get_conversation_area_path(conversation_area_id):
	if not conversation_area_id \
		or conversation_area_id == PLDDB.ConversationAreaIds.NONE \
		or not conversation_area_paths.has(conversation_area_id):
		return null
	return conversation_area_paths[conversation_area_id]

func get_conversation_area(conversation_area_id):
	var conversation_area_path = get_conversation_area_path(conversation_area_id)
	if not conversation_area_path or not has_node(conversation_area_path):
		return null
	return get_node(conversation_area_path)

func get_level():
	var viewport = get_viewport()
	return viewport.get_child(0) if viewport.get_child_count() > 0 else null

func get_cam():
	return get_level().get_cam()

func get_door(door_full_path):
	var level = get_level()
	if not level or not level.has_node("doors"):
		return null
	var doors = level.get_node("doors")
	return doors.get_node(door_full_path) if doors.has_node(door_full_path) else null

func is_inside():
	var level = get_level()
	return level.is_inside() if level else true

func is_bright():
	var level = get_level()
	return level.is_bright() if level else false

func change_sky_panorama(
	inside,
	panorama,
	sky_rotation_degrees = SKY_ROTATION_DEGREES_DEFAULT,
	time_of_day = TimeOfDay.MORNING
):
	var panorama_prev
	if inside:
		panorama_prev = sky_inside.panorama
		sky_inside.panorama = panorama
	else:
		panorama_prev = sky_outside.panorama
		sky_outside.panorama = panorama
	self.sky_rotation_degrees = sky_rotation_degrees
	self.time_of_day = time_of_day
	return panorama_prev

func is_flashlight_on():
	return _pldrt.game_state.story_vars.flashlight_on

func change_flashlight_state(camera, flashlight_on):
	_pldrt.game_state.story_vars.flashlight_on = flashlight_on
	emit_signal("flashlight_state_changed", camera, flashlight_on)

func is_tactical_view():
	return _pldrt.game_state.story_vars.tactical_view_on

func change_tactical_view(tactical_view_val):
	_pldrt.game_state.story_vars.tactical_view_on = tactical_view_val

func tactical_selection_enabled():
	return _pldrt.game_state.story_vars.tactical_selection_on

func set_tactical_selection(enabled):
	_pldrt.game_state.story_vars.tactical_selection_on = enabled

func set_surge(player, enable):
	emit_signal("player_surge", player, enable)

func set_underwater(player, enable):
	emit_signal("player_underwater", player, enable)

func set_poisoned(player, enable, intoxication_rate):
	emit_signal("player_poisoned", player, enable, intoxication_rate)

func get_custom_actions(item):
	var item_record = get_registered_item_data(item.item_id)
	return item_record.custom_actions.duplicate() if item_record else []

func shader_cache_processed():
	emit_signal("shader_cache_processed")

func handle_conversation(player, target, initiator):
	if _pldrt.conversation_manager.arrange_meeting(player, target, initiator):
		return
	if _pldrt.DB.execute_give_item_action(player, target):
		return
	if not target.is_in_party():
		return
	_pldrt.conversation_manager.start_conversation(player, "Conversation", target)

func get_current_scene_data():
	var scene_path = get_tree().current_scene.filename
	return scenes_data[scene_path] if scenes_data.has(scene_path) else PLDDB.SCENE_DATA_DEFAULT.duplicate(true)

func current_scene_was_loaded_before():
	return get_current_scene_data().loads_count > 1

func change_scene(scene_path, is_transition = false, fade_out = false):
	for character in get_characters():
		if character.is_stunned():
			character.stun_stop()
	characters_transition_data = get_characters_data() if is_transition else {}
	if not scenes_data.has(scene_path):
		scenes_data[scene_path] = PLDDB.SCENE_DATA_DEFAULT.duplicate(true)
	scenes_data[scene_path].loads_count += 1
	if is_transition:
		scenes_data[scene_path].transitions_count += 1
	self.scene_path = scene_path
	self.is_transition = is_transition
	_pldrt.conversation_manager.stop_conversation(get_player())
	_pldrt.cutscene_manager.clear_cutscene_node()
	set_level_ready(false)
	var gwp = get_game_window_parent() if fade_out else null
	if gwp:
		change_modulation(gwp, COLOR_WHITE, COLOR_BLACK)
	else:
		get_tree().change_scene("res://addons/palladium/ui/scene_loader.tscn")

func change_modulation(node, color_start, color_end):
	var tween = $ModulationTween
	tween.interpolate_property(
		node,
		"modulate",
		color_start,
		color_end,
		1.5,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT
	)
	tween.start()

func on_party_joined(character):
	var name_hint = character.get_name_hint()
	if not party_stats.has(name_hint):
		party_stats[name_hint] = CHARACTER_STATS_DEFAULT.duplicate(true)
	emit_stats_signals(name_hint)

func on_party_left(character):
	emit_stats_signals_for_everyone()

func on_rest_state_changed(character, previous_state, new_state):
	emit_signal("rest_state_changed", character, previous_state, new_state)

func on_teleported_to(character, origin, basis):
	emit_signal("teleported_to", character, origin, basis)
	
func _on_ModulationTween_tween_completed(object, key):
	var gwp = get_game_window_parent()
	if not gwp:
		return
	if object.get_instance_id() == gwp.get_instance_id() \
		and key == ":modulate" \
		and object.get("modulate") == COLOR_BLACK:
		get_tree().change_scene("res://addons/palladium/ui/scene_loader.tscn")

func initiate_load(slot):
	var f = File.new()
	var error = f.open("user://saves/slot_%d/state.json" % slot, File.READ)

	if (error):
		print("no state to load.")
		return

	var d = parse_json( f.get_as_text() )
	if (typeof(d) != TYPE_DICTIONARY) or (typeof(d.story_vars) != TYPE_DICTIONARY):
		return

	if ("scene_path" in d):
		reset_variables()
		_pldrt.story_node.reload_all_saves(slot)
		slot_to_load_from = slot
		scenes_data = d.scenes_data if ("scenes_data" in d) else {}
		change_scene(d.scene_path)

func is_loading():
	return slot_to_load_from >= 0

func is_transition():
	return is_transition

func finish_load():
	var is_loading = is_loading()
	if is_loading:
		clear_caches()
		load_state(slot_to_load_from)
		slot_to_load_from = -1
	else:
		restore_states()
	get_tree().call_group("hud", "update_hud")
	return is_loading

func is_item_registered(item_id):
	return PLDDB.ITEMS.has(item_id)

func get_registered_item_data(item_id):
	return PLDDB.ITEMS[item_id] if is_item_registered(item_id) else null

func has_item(item_id):
	return get_item_count(item_id) > 0

func get_player_with_item(item_id):
	for name_hint in quick_items:
		var player_quick_items = quick_items[name_hint]
		for item in player_quick_items:
			if item_id == item.item_id:
				return get_character(name_hint)
	for name_hint in inventory:
		var player_inventory = inventory[name_hint]
		for item in player_inventory:
			if item_id == item.item_id:
				return get_character(name_hint)
	return null

func remove_item_from_player(item_owner, item_id):
	if not item_owner:
		return
	var name_hint = item_owner.get_name_hint()
	if quick_items.has(name_hint):
		var item_owner_quick_items = quick_items[name_hint]
		for i in range(0, item_owner_quick_items.size()):
			if item_id == item_owner_quick_items[i].item_id:
				item_owner_quick_items.remove(i)
				return
	if inventory.has(name_hint):
		var item_owner_inventory = inventory[name_hint]
		for i in range(0, item_owner_inventory.size()):
			if item_id == item_owner_inventory[i].item_id:
				item_owner_inventory.remove(i)
				return

func get_inventory():
	if not inventory.has(player_name_hint):
		inventory[player_name_hint] = []
	return inventory[player_name_hint]

func get_quick_items():
	if not quick_items.has(player_name_hint):
		quick_items[player_name_hint] = []
	return quick_items[player_name_hint]

func get_item_count(item_id):
	if not item_id or item_id == PLDDB.TakableIds.NONE:
		return 0
	for quick_item in get_quick_items():
		if item_id == quick_item.item_id:
			return quick_item.count
	for item in get_inventory():
		if item_id == item.item_id:
			return item.count
	return 0

func get_quick_items_count():
	var result = 0
	for quick_item in get_quick_items():
		if quick_item.item_id and quick_item.item_id != PLDDB.TakableIds.NONE:
			result = result + 1
	return result

func take(item_id, count = 1, item_path = null):
	if not is_item_registered(item_id):
		push_error("Unknown item_id: " + str(item_id))
		return
	var is_stackable = PLDDB.is_item_stackable(item_id)
	if count > 1 and not is_stackable:
		push_warning("Trying to take %d items with id = %d, which is not stackable" % [count, item_id])
		return
	for item in get_inventory():
		if item_id == item.item_id:
			if not is_stackable:
				push_warning("Trying to stack item with id = %d, which is not stackable" % item_id)
				return
			item.count = item.count + count
			emit_signal("item_taken", item_id, item.count, count, item_path)
			return
	var maxpos = 0
	var quick_item_candidate = null
	for quick_item in get_quick_items():
		if (
			(
				not quick_item.item_id
				or quick_item.item_id == PLDDB.TakableIds.NONE
			)
			and not quick_item_candidate
		):
			quick_item_candidate = quick_item
		if item_id == quick_item.item_id:
			if not is_stackable:
				push_warning("Trying to stack item with id = %d, which is not stackable" % item_id)
				return
			quick_item.count = quick_item.count + count
			emit_signal("item_taken", item_id, quick_item.count, count, item_path)
			return
		maxpos = maxpos + 1
	if quick_item_candidate:
		quick_item_candidate.item_id = item_id
		quick_item_candidate.count = count
		emit_signal("item_taken", item_id, quick_item_candidate.count, count, item_path)
		return
	elif maxpos < PLDHUD.MAX_QUICK_ITEMS:
		get_quick_items().append({ "item_id" : item_id, "count" : count })
		emit_signal("item_taken", item_id, count, count, item_path)
		return
	get_inventory().append({ "item_id" : item_id, "count" : count })
	emit_signal("item_taken", item_id, count, count, item_path)
	get_hud().queue_popup_message("MESSAGE_CONTROLS_INVENTORY", [_pldrt.common_utils.get_input_control("inventory_toggle", false)])

func remove(item_id, count = 1):
	var idx = 0
	for item in get_inventory():
		if item_id == item.item_id:
			item.count = item.count - count
			if item.count <= 0:
				item.count = 0
				get_inventory().remove(idx)
			emit_signal("item_removed", item_id, item.count, count)
			return item.count
		idx = idx + 1
	for quick_item in get_quick_items():
		if item_id == quick_item.item_id:
			quick_item.count = quick_item.count - count
			if quick_item.count <= 0:
				quick_item.count = 0
				quick_item.item_id = null
			emit_signal("item_removed", item_id, quick_item.count, count)
			return quick_item.count
	return 0

func remove_all(item_id):
	var cnt = get_item_count(item_id)
	return remove(item_id, cnt) if cnt > 0 else 0

func item_used(player_node, target, item_id, item_count):
	emit_signal("item_used", player_node, target, item_id, item_count)

func set_quick_item(pos, item_id):
	if pos >= PLDHUD.MAX_QUICK_ITEMS:
		return
	for i in range(get_quick_items().size(), pos + 1):
		get_quick_items().append({ "item_id" : null, "count" : 0 })
	var existing_quick_item = get_quick_items()[pos]
	for quick_item in get_quick_items():
		if item_id == quick_item.item_id:
			var new_item = { "item_id" : item_id, "count" : quick_item.count }
			quick_item.item_id = existing_quick_item.item_id
			quick_item.count = existing_quick_item.count
			get_quick_items()[pos] = new_item
			return
	var idx = 0
	for item in get_inventory():
		if item_id == item.item_id:
			var new_item = { "item_id" : item_id, "count" : item.count }
			if existing_quick_item.item_id:
				item.item_id = existing_quick_item.item_id
				item.count = existing_quick_item.count
			else:
				get_inventory().remove(idx)
			get_quick_items()[pos] = new_item
			return
		idx = idx + 1

func get_player_name_hint():
	return player_name_hint

func set_player_name_hint(name_hint):
	player_name_hint = name_hint

func player_name_is(name_hint):
	return player_name_hint == name_hint

func damage_party(injury_rate):
	for character in get_characters():
		if character.is_in_party():
			var health_current = party_stats[character.get_name_hint()]["health_current"]
			var health_max = party_stats[character.get_name_hint()]["health_max"]
			set_health(character, health_current - injury_rate, health_max)

func kill_party(and_finish_the_game = true):
	for character in get_characters():
		if character.is_in_party():
			character.kill()
	if and_finish_the_game:
		game_over()

func set_health(character, health_current, health_max):
	if health_current <= 0:
		character.kill()
		return
	var name_hint = character.get_name_hint()
	var hc = health_current if health_current < health_max else health_max
	party_stats[name_hint]["health_current"] = hc
	party_stats[name_hint]["health_max"] = health_max
	emit_signal("health_changed", name_hint, hc, health_max)

func game_over():
	change_scene("res://addons/palladium/ui/game_over.tscn", false, true)

func set_oxygen(character, oxygen_current, oxygen_max):
	var name_hint = character.get_name_hint()
	if oxygen_current < 0:
		var health_new = party_stats[name_hint]["health_current"] - PLDDB.SUFFOCATION_DAMAGE_RATE
		if (
			health_new > 0
			and health_new % PLDDB.BUBBLES_RATE == 0
			and health_new < (party_stats[name_hint]["health_max"] / 2)
		):
			_pldrt.MEDIA.play_random_sound([ PLDDBMedia.SoundId.BUBBLES_1, PLDDBMedia.SoundId.BUBBLES_2, PLDDBMedia.SoundId.BUBBLES_3 ])
		set_health(character, health_new, party_stats[name_hint]["health_max"])
		return
	var oc = oxygen_current if oxygen_current < oxygen_max else oxygen_max
	party_stats[name_hint]["oxygen_current"] = oc
	party_stats[name_hint]["oxygen_max"] = oxygen_max
	emit_signal("oxygen_changed", name_hint, oc, oxygen_max)

func set_action_points(character, action_points_current, action_points_max):
	var name_hint = character.get_name_hint()
	set_action_points_for_name(name_hint, action_points_current, action_points_max)

func set_action_points_for_name(name_hint, action_points_current, action_points_max):
	var apc = action_points_current if action_points_current < action_points_max else action_points_max
	party_stats[name_hint]["action_points_current"] = apc
	party_stats[name_hint]["action_points_max"] = action_points_max
	emit_signal("action_points_changed", name_hint, apc, action_points_max)

func get_door_state(door_path):
	var id = scene_path + ":" + door_path
	if not doors.has(id):
		return DoorState.DEFAULT
	return DoorState.OPENED if doors[id] else DoorState.CLOSED

func set_door_state(door_path, opened):
	doors[scene_path + ":" + door_path] = opened

func get_light_state(light_path):
	var id = scene_path + ":" + light_path
	if not lights.has(id):
		return LightState.DEFAULT
	return LightState.ON if lights[id] else LightState.OFF

func set_light_state(light_path, active):
	lights[scene_path + ":" + light_path] = active

func get_container_state(container_path):
	var id = scene_path + ":" + container_path
	if not containers.has(id):
		return ContainerState.DEFAULT
	return ContainerState.OPENED if containers[id] else ContainerState.CLOSED

func set_container_state(container_path, opened):
	containers[scene_path + ":" + container_path] = opened

func get_takable_state(takable_path):
	if not takable_path:
		return null
	var id = scene_path + ":" + takable_path
	if not takables.has(id):
		return TakableState.DEFAULT
	return TakableState.ABSENT if takables[id] else TakableState.PRESENT

func set_takable_state(takable_path, absent):
	takables[scene_path + ":" + takable_path] = absent

func get_lootable_count(lootable_path):
	if not lootable_path:
		return null
	var id = scene_path + ":" + lootable_path
	return lootables[id] if lootables.has(id) else 0

func set_lootable_count(lootable_path, count):
	lootables[scene_path + ":" + lootable_path] = count

func get_activatable_state_by_id(activatable_id):
	var path = get_activatable_path(activatable_id)
	return get_activatable_state(path)

func get_activatable_state(activatable_path):
	if not activatable_path:
		return null
	var id = scene_path + ":" + activatable_path
	if not activatables.has(id):
		return ActivatableState.DEFAULT
	return activatables[id]

func set_activatable_state(activatable_path, state):
	activatables[scene_path + ":" + activatable_path] = state

func _is_room_enabled(room_id):
	var room_enabler = get_room_enabler(room_id)
	return room_enabler and room_enabler.is_room_enabled()

func _player_is_in_room(room_id):
	var room_enabler = get_room_enabler(room_id)
	return room_enabler and room_enabler.player_is_in_room()

func _is_found(activatable_id : int):
	var id = PLDDB.lookup_activatable_from_int(activatable_id)
	if id == PLDDB.ActivatableIds.NONE:
		return false
	if not get_activatable_path(activatable_id):
		return false
	return true

func _is_untouched(activatable_id : int):
	var id = PLDDB.lookup_activatable_from_int(activatable_id)
	if id == PLDDB.ActivatableIds.NONE:
		return false
	return get_activatable_state_by_id(id) == ActivatableState.DEFAULT

func _is_activated(activatable_id : int):
	var id = PLDDB.lookup_activatable_from_int(activatable_id)
	if id == PLDDB.ActivatableIds.NONE:
		return false
	match get_activatable_state_by_id(id):
		ActivatableState.ACTIVATED, ActivatableState.ACTIVATED_FOREVER:
			return true
		_:
			return false

func _is_deactivated(activatable_id : int):
	var id = PLDDB.lookup_activatable_from_int(activatable_id)
	if id == PLDDB.ActivatableIds.NONE:
		return false
	match get_activatable_state_by_id(id):
		ActivatableState.DEACTIVATED, ActivatableState.DEACTIVATED_FOREVER:
			return true
		_:
			return false

func _is_paused(activatable_id : int):
	var id = PLDDB.lookup_activatable_from_int(activatable_id)
	if id == PLDDB.ActivatableIds.NONE:
		return false
	match get_activatable_state_by_id(id):
		ActivatableState.PAUSED, ActivatableState.PAUSED_FOREVER:
			return true
		_:
			return false

func _is_final_destination(activatable_id : int):
	var id = PLDDB.lookup_activatable_from_int(activatable_id)
	if id == PLDDB.ActivatableIds.NONE:
		return false
	match get_activatable_state_by_id(id):
		ActivatableState.ACTIVATED_FOREVER, ActivatableState.DEACTIVATED_FOREVER, ActivatableState.PAUSED_FOREVER:
			return true
		_:
			return false

func _is_actual(activatable_id : int):
	return _is_found(activatable_id) \
		and not _is_untouched(activatable_id) \
		and not _is_final_destination(activatable_id)

func get_multistate_state(multistate_path):
	var id = scene_path + ":" + multistate_path
	return int(multistates[id]) if multistates.has(id) else 0

func set_multistate_state(multistate_path, state : int):
	multistates[scene_path + ":" + multistate_path] = int(state)

func get_message_state(message_key):
	return messages[message_key] if messages.has(message_key) else true

func set_message_state(message_key, state):
	# You can set state only for messages that are registered from the very start of the game
	if messages.has(message_key):
		messages[message_key] = state

func is_saving_disabled():
	return saving_disabled

func set_saving_disabled(saving_disabled):
	self.saving_disabled = saving_disabled

func is_in_party(name_hint):
	var character = get_character(name_hint)
	return character and character.is_in_party()

func join_party(name_hint, and_clear_target_node = true):
	var character = get_character(name_hint)
	if not character:
		push_error("Cannot join character '%s' to party, because this character was not found" % name_hint)
		return
	character.join_party(and_clear_target_node)

func leave_party(name_hint, new_target_node = null, and_teleport_to_target = false):
	var character = get_character(name_hint)
	if not character:
		push_error("Cannot leave character '%s' from party, because this character was not found" % name_hint)
		return
	character.leave_party(new_target_node, and_teleport_to_target)

func register_player(player):
	var name_hint = player.get_name_hint()
	var hud = get_hud()
	player_paths[name_hint] = player.get_path()
	player.connect("crouching_changed", hud, "on_crouching_changed")
	player.connect("player_changed", hud, "on_player_changed")
	player.connect("party_joined", self, "on_party_joined")
	player.connect("party_left", self, "on_party_left")
	player.connect("rest_state_changed", self, "on_rest_state_changed")
	player.connect("teleported_to", self, "on_teleported_to")
	player.set_look_transition_if_needed()
	if characters_transition_data.has(name_hint):
		set_character_data(characters_transition_data[name_hint], player)
	emit_signal("player_registered", player)

func register_room_enabler(room_enabler):
	var room_id = room_enabler.get_room_id()
	if not room_id or room_id == PLDDB.RoomIds.NONE:
		return
	room_enabler_paths[room_id] = room_enabler.get_path()

func register_usable(usable):
	var usable_id = usable.get_usable_id()
	if not usable_id or usable_id == PLDDB.UsableIds.NONE:
		return
	usable_paths[usable_id] = usable.get_path()

func register_activatable(activatable):
	var activatable_id = activatable.get_activatable_id()
	if not activatable_id or activatable_id == PLDDB.ActivatableIds.NONE:
		return
	activatable_paths[activatable_id] = activatable.get_path()

func register_conversation_area(conversation_area):
	var conversation_area_id = conversation_area.get_conversation_area_id()
	if not conversation_area_id or conversation_area_id == PLDDB.ConversationAreaIds.NONE:
		return
	conversation_area_paths[conversation_area_id] = conversation_area.get_path()

func save_slot_exists(slot):
	var f = File.new()
	return f.file_exists("user://saves/slot_%d/state.json" % slot)

func set_characters_data(characters_data):
	var movement_datas = []
	for name_hint in characters_data.keys():
		var character = get_character(name_hint)
		if not character:
			continue
		var dd = characters_data[name_hint]
		movement_datas.append({
			"character" : character,
			"movement_data" : set_character_data(dd, character)
		})
		if name_hint == player_name_hint:
			character.become_player()
	return movement_datas

func set_character_data(dd, character):
	var movement_data = null
	var character_coords = {
		"basis" : character.get_global_transform().basis,
		"origin" : character.get_global_transform().origin
	}
	
	if dd["positions"].has(scene_path):
		var ddd = dd["positions"][scene_path]
		if ("basis" in ddd and (typeof(ddd.basis) == TYPE_ARRAY)):
			var bx = Vector3(ddd.basis[0][0], ddd.basis[0][1], ddd.basis[0][2])
			var by = Vector3(ddd.basis[1][0], ddd.basis[1][1], ddd.basis[1][2])
			var bz = Vector3(ddd.basis[2][0], ddd.basis[2][1], ddd.basis[2][2])
			character_coords.basis = Basis(bx, by, bz)
		
		if ("origin" in ddd and (typeof(ddd.origin) == TYPE_ARRAY)):
			character_coords.origin = Vector3(ddd.origin[0], ddd.origin[1], ddd.origin[2])
		
		if ("target_path" in ddd and ddd.target_path and has_node(ddd.target_path)):
			var target_node = get_node(ddd.target_path)
			character.set_target_node(target_node, false)
			movement_data = (
				PLDMovementData.new() \
				.clear_dir() \
				.with_rest_state(true) \
				.with_signal("arrived_to", [target_node])
			)
	
	character.set_global_transform(Transform(character_coords.basis, character_coords.origin))
	
	if ("activated" in dd):
		if dd.activated:
			character.activate()
		else:
			character.deactivate()
	
	if ("pathfinding_enabled" in dd):
		character.set_pathfinding_enabled(dd.pathfinding_enabled)
	
	if ("in_party" in dd):
		character.set_in_party(dd.in_party)
	
	if ("is_crouching" in dd):
		if dd.is_crouching and not character.is_crouching():
			character.sit_down()
		elif not dd.is_crouching and character.is_crouching():
			character.stand_up()
	
	if ("is_on_ladder" in dd):
		character.set_on_ladder(dd.is_on_ladder)
	
	if ("ladder_rotation_deg" in dd):
		character.set_ladder_rotation_deg(dd.ladder_rotation_deg)
	
	if ("ladder_ymin" in dd):
		character.set_ladder_ymin(dd.ladder_ymin)
	
	if ("ladder_ymax" in dd):
		character.set_ladder_ymax(dd.ladder_ymax)
	
	if ("is_poisoned" in dd and "intoxication" in dd):
		character.intoxication = int(dd.intoxication)
		set_poisoned(character, dd.is_poisoned, character.intoxication)
	
	if ("relationship" in dd):
		character.relationship = int(dd.relationship)
	
	if ("morale" in dd):
		character.morale = int(dd.morale)
	
	if ("stuns_count" in dd):
		character.stuns_count = int(dd.stuns_count)
	
	if ("is_transporting" in dd):
		character.set_transporting(dd.is_transporting)
	
	if ("is_hidden" in dd):
		var hideout_path = (
			dd.hideout_path if "hideout_path" in dd and dd.hideout_path else ""
		)
		character.set_hidden(dd.is_hidden, hideout_path)
	
	if ("is_sprinting" in dd):
		character.set_sprinting(dd.is_sprinting)
	
	if ("force_physics" in dd):
		character.set_force_physics(dd.force_physics)
	
	if ("force_no_physics" in dd):
		character.set_force_no_physics(dd.force_no_physics)
	
	if ("force_visibility" in dd):
		character.set_force_visibility(dd.force_visibility)
	
	if ("is_patrolling" in dd):
		character.set_patrolling(dd.is_patrolling)
	
	if ("is_aggressive" in dd):
		character.set_aggressive(dd.is_aggressive)
	
	if ("dead" in dd) and dd.dead:
		# Should be the last or at least after character.set_hidden(),
		# because character.set_hidden() modifies the same collisions
		character.kill_on_load()
	
	character.set_look_transition_if_needed()
	return movement_data

func restore_states():
	# Should restore state of all activatables before other restorable_state nodes
	get_tree().call_group("activatables", "restore_state")
	get_tree().call_group("lootables", "restore_state")
	get_tree().call_group("restorable_state", "restore_state")

func emit_stats_signals(name_hint):
	var ps = party_stats[name_hint]
	ps["health_current"] = int(ps["health_current"])
	ps["health_max"] = int(ps["health_max"])
	emit_signal("health_changed", name_hint, ps["health_current"], ps["health_max"])
	ps["oxygen_current"] = int(ps["oxygen_current"])
	ps["oxygen_max"] = int(ps["oxygen_max"])
	emit_signal("oxygen_changed", name_hint, ps["oxygen_current"], ps["oxygen_max"])
	ps["action_points_current"] = int(ps["action_points_current"])
	ps["action_points_max"] = int(ps["action_points_max"])
	emit_signal("action_points_changed", name_hint, ps["action_points_current"], ps["action_points_max"])

func emit_stats_signals_for_everyone():
	for name_hint in party_stats:
		emit_stats_signals(name_hint)

func load_state(slot):
	var movement_datas = []
	
	var f = File.new()
	var error = f.open("user://saves/slot_%d/state.json" % slot, File.READ)
	
	if (error):
		print("no state to load.")
		return
	
	var t = f.get_as_text()
	f.close()
	
	var d = parse_json(t)
	if (typeof(d) != TYPE_DICTIONARY) or (typeof(d.story_vars) != TYPE_DICTIONARY):
		return
	
	scene_path = d.scene_path if ("scene_path" in d) else PLDDB.SCENE_PATH_DEFAULT
	
	player_name_hint = d.player_name_hint if ("player_name_hint" in d) else PLDChars.PLAYER_NAME_HINT
	party_stats = d.party_stats if ("party_stats" in d) else {
		PLDChars.PLAYER_NAME_HINT : CHARACTER_STATS_DEFAULT.duplicate(true)
	}
	for name_hint in party_stats:
		emit_stats_signals(name_hint)
	
	# player_paths should not be loaded, it must be recreated on level startup via register_player()
	# usable_paths should not be loaded, it must be recreated on level startup via register_usable()
	# activatable_paths should not be loaded, it must be recreated on level startup via register_activatable()
	
	story_vars = d.story_vars if ("story_vars" in d) else PLDDB.STORY_VARS_DEFAULT.duplicate(true)
	inventory = sanitize_items(d.inventory) if ("inventory" in d) else PLDDB.INVENTORY_DEFAULT.duplicate(true)
	quick_items = sanitize_items(d.quick_items) if ("quick_items" in d) else PLDDB.QUICK_ITEMS_DEFAULT.duplicate(true)
	doors = d.doors if ("doors" in d) else DOORS_DEFAULT.duplicate(true)
	lights = d.lights if ("lights" in d) else LIGHTS_DEFAULT.duplicate(true)
	containers = d.containers if ("containers" in d) else CONTAINERS_DEFAULT.duplicate(true)
	takables = d.takables if ("takables" in d) else TAKABLES_DEFAULT.duplicate(true)
	lootables = d.lootables if ("lootables" in d) else LOOTABLES_DEFAULT.duplicate(true)
	activatables = process_activatables(d.activatables) if ("activatables" in d) else ACTIVATABLES_DEFAULT.duplicate(true)
	multistates = d.multistates if ("multistates" in d) else MULTISTATES_DEFAULT.duplicate(true)
	messages = d.messages if ("messages" in d) else MESSAGES_DEFAULT.duplicate(true)
	
	restore_states()
	_pldrt.MEDIA.restore_music_from_save(d.music_ids if ("music_ids" in d) else null)
	
	if ("characters" in d and (typeof(d.characters) == TYPE_DICTIONARY)):
		movement_datas = set_characters_data(d.characters)
		characters_transition_data = d.characters
	for md in movement_datas:
		if md.character and md.movement_data:
			md.character.update_state(md.movement_data)
			md.movement_data.free()
	
	emit_signal("game_loaded")

func autosave_create():
	return save_state(0)

func autosave_restore():
	return initiate_load(0)

func get_characters_data():
	var characters = {}
	for character in get_characters():
		var name_hint = character.get_name_hint()
		characters[name_hint] = get_character_data(character)
	for name_hint in characters_transition_data.keys():
		if not characters.has(name_hint):
			characters[name_hint] = characters_transition_data[name_hint]
	return characters

func get_character_data(character):
	var p = character.is_in_party()
	
	var result = {
		"activated" : character.is_activated_flag(),
		"dead" : character.is_dead(),
		"pathfinding_enabled" : character.is_pathfinding_enabled(),
		"in_party" : p,
		"is_crouching" : character.is_crouching(),
		"is_on_ladder" : character.is_on_ladder(),
		"ladder_rotation_deg" : character.get_ladder_rotation_deg(),
		"ladder_ymin" : character.get_ladder_ymin(),
		"ladder_ymax" : character.get_ladder_ymax(),
		"is_poisoned" : character.is_poisoned(),
		"intoxication" : character.get_intoxication(),
		"relationship" : character.get_relationship(),
		"morale" : character.get_morale(),
		"stuns_count" : character.get_stuns_count(),
		"is_transporting" : character.is_transporting(),
		"is_hidden" : character.is_hidden(),
		"hideout_path" : character.get_hideout_path(),
		"is_sprinting" : character.is_sprinting(),
		"force_physics" : character.is_force_physics(),
		"force_no_physics" : character.is_force_no_physics(),
		"force_visibility" : character.is_force_visibility(),
		"is_patrolling" : character.is_patrolling(),
		"is_aggressive" : character.is_aggressive(),
		"positions" : { scene_path : {}}
	}
	
	var t = character.get_target_node()
	var b = t.get_global_transform().basis if t and not p else character.get_global_transform().basis
	var o = t.get_global_transform().origin if t and not p else character.get_global_transform().origin
	result["positions"][scene_path]["basis"] = [
		[b.x.x, b.x.y, b.x.z],
		[b.y.x, b.y.y, b.y.z],
		[b.z.x, b.z.y, b.z.z]
	]
	result["positions"][scene_path]["origin"] = [o.x, o.y, o.z]
	result["positions"][scene_path]["target_path"] = t.get_path() if t else null
	var name_hint = character.get_name_hint()
	if (
		not characters_transition_data.has(name_hint)
		or not characters_transition_data[name_hint].has("positions")
	):
		return result
	for pk in characters_transition_data[name_hint]["positions"].keys():
		if pk != scene_path:
			result["positions"][pk] = characters_transition_data[name_hint]["positions"][pk]
	return result

func save_state(slot):
	
	if saving_disabled:
		return
	
	var f = File.new()
	var error = f.open("user://saves/slot_%d/state.json" % slot, File.WRITE)
	assert( not error )
	
	_pldrt.story_node.save_all(slot)
	
	var characters = get_characters_data()
	
	# player_paths should not be saved, it must be recreated on level startup via register_player()
	# usable_paths should not be saved, it must be recreated on level startup via register_usable()
	# activatable_paths should not be loaded, it must be recreated on level startup via register_activatable()
	var d = {
		"scene_path" : scene_path,
		"scenes_data" : scenes_data,
		"player_name_hint" : player_name_hint,
		"party_stats" : party_stats,
		"characters" : characters,
		"story_vars" : story_vars,
		"inventory" : inventory,
		"quick_items" : quick_items,
		"doors" : doors,
		"lights" : lights,
		"containers" : containers,
		"takables" : takables,
		"lootables" : lootables,
		"activatables" : activatables,
		"multistates" : multistates,
		"messages" : messages,
		"music_ids" : _pldrt.MEDIA.music_ids
	}
	f.store_line( to_json(d) )
	emit_signal("game_saved")
