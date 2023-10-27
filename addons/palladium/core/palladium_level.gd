extends Navigation
class_name PLDLevel

signal give_item_action_executed(player, target, item)
signal custom_action_executed(item, custom_action)
signal healing_item_used(item_id, last_item)

# Constants for player_type field in PLDCharacter
# More such constants can be added in extending classes
const PLAYER_TYPE_UNKNOWN = -1

export var is_bright = false
export var is_inside = true
export var is_reverb = false
export var is_loadable = true
export var is_need_show_path = true
export var player_path = "player"
export var player_female_path = "player_female"
export var player_bandit_path = "player_bandit"
export(NodePath) var cam_path

onready var player = get_node(player_path) if has_node(player_path) else null
onready var player_female = get_node(player_female_path) if has_node(player_female_path) else null
onready var player_bandit = get_node(player_bandit_path) if has_node(player_bandit_path) else null

func _ready():
	__PLDRT.settings.set_reverb(is_reverb)
	if not is_loadable:
		__PLDRT.game_state.restore_states()
		do_init(false)
		__PLDRT.game_state.set_level_ready(true)
		return
	var is_loaded = __PLDRT.game_state.finish_load()
	do_init(is_loaded)
	if not is_loaded:
		__PLDRT.game_state.autosave_create()
	__PLDRT.game_state.set_level_ready(true)

func do_init(is_loaded):
	# Override in children instead of _ready()
	pass

func is_bright():
	return is_bright

func is_inside():
	return is_inside

func is_reverb():
	return is_reverb

func is_need_show_path():
	return is_need_show_path

func get_cam():
	return get_node(cam_path) if cam_path and has_node(cam_path) else null

func can_create_waypoint(character, origin):
	if not character:
		return false
	return true

func create_waypoint(character, origin, basis = Basis(), force : bool = false):
	if not force and not can_create_waypoint(character, origin):
		return null
	var pos3d = Position3D.new()
	if has_node("patrol_area"):
		get_node("patrol_area").add_child(pos3d)
	else:
		add_child(pos3d)
	pos3d.global_transform = Transform(basis, origin)
	return pos3d

func execute_give_item_action(player, target):
	if not player or not target:
		return false
	var hud = __PLDRT.game_state.get_hud()
	var item = hud.get_active_item()
	if not item or not item.can_be_given():
		return false
	emit_signal("give_item_action_executed", player, target, item)
	hud.inventory.visible = false
	item.used(player, target)
	return true

func use_healing_item(item):
	var name_hint = PLDChars.PLAYER_NAME_HINT
	var ps = __PLDRT.game_state.party_stats[name_hint]
	var health_current = ps["health_current"]
	var health_max = ps["health_max"]
	if health_current >= health_max:
		__PLDRT.game_state.get_hud().queue_popup_message("MESSAGE_FULL_HEALTH")
		return false
	var sound_id = PLDDBMedia.SoundId.MAN_DRINKS
	__PLDRT.MEDIA.play_sound(sound_id)
	var player = __PLDRT.game_state.get_player()
	var heal_amount = health_max / 2
	__PLDRT.game_state.set_health(player, health_current + heal_amount, health_max)
	__PLDRT.game_state.set_poisoned(player, false, 0)
	var last_item = (item.get_item_count() == 1)
	item.remove()
	# healing_item_used signal can be used, for example, to return empty flask to inventory
	emit_signal("healing_item_used", item.item_id, last_item)
	return true

func is_current_player(character):
	var name_hint = character.get_name_hint()
	return is_current_player_name(name_hint)

func is_current_player_name(name_hint):
	# Override this method to be able to filter out network players
	# actions for which should not be performed by the player on this machine
	return true

func do_actions_if_self_character_is(player_type):
	# Override this method to make additional changes depending on self player type
	pass

func get_player_type_by_portrait(portrait_file_name):
	return PLAYER_TYPE_UNKNOWN

func set_player_traits(player_name_hint, player_type):
	var character = __PLDRT.game_state.get_character(player_name_hint)
	character.set_player_type(player_type)
	# Override this method to make additional changes depending on player type

func can_execute_custom_action(item, action = PLDDB.ITEM_PREVIEW_ACTION_1, event = null):
	var item_data = PLDDB.get_item_data(item.item_id)
	if not item_data.has("custom_actions"):
		return false
	var custom_actions = item_data.custom_actions
	if not custom_actions:
		return false
	if custom_actions.find(action) < 0:
		return false
	if event and not event.is_action_pressed(action):
		return false
	return item_constraints_satisfied(item, action)

func item_constraints_satisfied(item, action = PLDDB.ITEM_PREVIEW_ACTION_1):
	match action:
		PLDDB.ITEM_PREVIEW_ACTION_1:
#			match item.item_id:
#				PLDDB.TakableIds.CELL_PHONE:
#					return __PLDRT.conversation_manager.conversation_is_not_finished("Chat")
			pass
		PLDDB.ITEM_PREVIEW_ACTION_2:
			pass
		PLDDB.ITEM_PREVIEW_ACTION_3:
			pass
		PLDDB.ITEM_PREVIEW_ACTION_4:
			pass
	return true

func get_custom_action_params_for(custom_action, item_id):
	match custom_action:
		PLDDB.ITEM_PREVIEW_ACTION_1:
			match item_id:
				PLDDB.TakableIds.RAT:
					return {
						"has_action" : true,
						"need_remove" : true
					}
	return {
		"has_action" : false,
		"need_remove" : false
	}

func do_custom_action_for(custom_action, item_id, is_ai_action = false):
	match custom_action:
		PLDDB.ITEM_PREVIEW_ACTION_1:
			match item_id:
#				PLDDB.TakableIds.CELL_PHONE:
#					__PLDRT.game_state.get_hud().show_tablet(true, PLDTablet.ActivationMode.CHAT)
#					return true
#				PLDDB.TakableIds.FLASK_HEALING, PLDDB.TakableIds.AMBROSIA_CUP:
#					__PLDRT.geme_state.get_level().use_healing_item(item)
#					return true
#				PLDDB.TakableIds.AIR_TANK:
#					__PLDRT.game_state.set_oxygen(
#						__PLDRT.game_state.get_player(),
#						__PLDRT.game_state.player_oxygen_max,
#						__PLDRT.game_state.player_oxygen_max
#					)
#					__PLDRT.MEDIA.play_sound(PLDDBMedia.SoundId.MAN_BREATHE_IN_TANK)
#					return true
				PLDDB.TakableIds.RAT:
					var rat = PLDRatSource.create_rat(90)
					var pl = __PLDRT.game_state.get_player().get_model()
					var pl_origin = pl.get_global_transform().origin
					var shift = pl.to_global(pl.get_transform().basis.xform(Vector3(0, 0, 1))) - pl_origin
					shift.y = 0
					shift = shift.normalized()
					var cross = shift.cross(Vector3(0, 1, 0))
					var basis = Basis(shift, Vector3(0, 1, 0), cross)
					var origin = pl_origin - shift * 2
					rat.set_global_transform(Transform(basis, origin))
					rat.rotate_y(deg2rad(180))
					__PLDRT.game_state.get_level().add_child(rat)
					return true
	return false

func execute_custom_action(item, action = PLDDB.ITEM_PREVIEW_ACTION_1):
	if not is_current_player(__PLDRT.game_state.get_player()):
		return
	if not item_constraints_satisfied(item, action):
		return
	var ap = get_custom_action_params_for(action, item.item_id)
	if ap.has_action:
		if ap.need_remove:
			item.remove()
		do_custom_action_for(action, item.item_id)
	emit_signal("custom_action_executed", item, action)
