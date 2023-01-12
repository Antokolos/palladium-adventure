tool
extends Node
class_name PLDDB

### COMMON PART ###
const HEALING_RATE = 1
const INTOXICATION_RATE_DEFAULT = 1
const INTOXICATION_RATE_STRONG = 5
const SCENE_PATH_DEFAULT = ""
const SCENE_DATA_DEFAULT = { "loads_count" : 0, "transitions_count" : 0 }
const PLAYER_HEALTH_CURRENT_DEFAULT = 100
const PLAYER_HEALTH_MAX_DEFAULT = 100
const SUFFOCATION_DAMAGE_RATE = 10
const BUBBLES_RATE = 20
const PLAYER_OXYGEN_CURRENT_DEFAULT = 100
const PLAYER_OXYGEN_MAX_DEFAULT = 100

const CAMERA_VIEW_FIRST_PERSON = 0
const CAMERA_VIEW_THIRD_PERSON_STRICT = 1
const CAMERA_VIEW_THIRD_PERSON_FOLLOW = 2

var _pldrt = null

func _init(pldrt):
	_pldrt = pldrt

static func lookup_activatable_from_int(activatable_id : int):
	for id in ActivatableIds:
		if activatable_id == ActivatableIds[id]:
			return ActivatableIds[id]
	return ActivatableIds.NONE

static func lookup_takable_from_int(item_id : int):
	for takable_id in TakableIds:
		if item_id == TakableIds[takable_id]:
			return TakableIds[takable_id]
	return TakableIds.NONE

static func get_item_data(takable_id):
	if not takable_id or takable_id == TakableIds.NONE or not ITEMS.has(takable_id):
		return null
	return ITEMS[takable_id]

static func get_item_name(takable_id):
	var item_data = get_item_data(takable_id)
	return item_data.item_nam if item_data else null

static func get_items_name(takable_id):
	var item_data = get_item_data(takable_id)
	return item_data.item_nam + "s" if item_data else null

static func is_item_stackable(takable_id):
	var item_data = get_item_data(takable_id)
	return item_data.stackable if item_data else false

static func get_pedestal_applicable_items():
	return PEDESTAL_APPLICABLE_ITEMS

static func is_weapon_stun(takable_id):
	if not takable_id or takable_id == TakableIds.NONE:
		return false
	return WEAPONS_STUN.has(takable_id)

static func is_weapon_ranged(takable_id):
	if not takable_id or takable_id == TakableIds.NONE:
		return false
	return WEAPONS_RANGED.has(takable_id)

static func get_weapon_stun_data(takable_id):
	return WEAPONS_STUN[takable_id] if is_weapon_stun(takable_id) else null

static func get_weapon_ranged_data(takable_id):
	return WEAPONS_RANGED[takable_id] if is_weapon_ranged(takable_id) else null

func can_execute_custom_action(item, action = "item_preview_action_1", event = null):
	var item_data = get_item_data(item.item_id)
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

### CODE THAT MUST BE INCLUDED IN THE GAME-SPECIFIC PART ###

#const CAMERA_VIEW_TYPE_DEFAULT = CAMERA_VIEW_FIRST_PERSON

#const STORY_VARS_DEFAULT = {
#	"flashlight_on" : false
#}

#enum LightIds {
#	NONE = 0
#}

#enum RiddleIds {
#	NONE = 0
#}

#enum PedestalIds {
#	NONE = 0
#}

#enum ContainerIds {
#	NONE = 0
#}

#enum RoomIds {
#	NONE = 0
#}

#enum DoorIds {
#	NONE = 0
#}

#enum ButtonActivatorIds {
#	NONE = 0
#}

#enum UsableIds {
#	NONE = 0
#}

#enum ActivatableIds {
#	NONE = 0
#}

#enum ConversationAreaIds {
#	NONE = 0
#}

#enum TakableIds {
#	NONE = 0
#}

#const PEDESTAL_APPLICABLE_ITEMS = [
#	TakableIds.XXX
#]

#enum UseTargetIds {
#	NONE = 0
#}

#const INVENTORY_DEFAULT = []
#const QUICK_ITEMS_DEFAULT = []

#const ITEMS = {
#	TakableIds.NONE : { "item_nam" : "item_none", "item_image" : "none.png", "model_path" : "res://assets/none.escn", "model_use_path" : null, "stackable" : false, "can_give" : false, "custom_actions" : [] },
#}

#const WEAPONS_STUN = {
#	TakableIds.MEDUSA_HEAD : { "stun_duration" : 5, "sound_id" : PLDDBMedia.SoundId.SNAKE_HISS }
#}

#func execute_give_item_action(player, target):
#	if not player or not target:
#		return false
#	var hud = _pldrt.game_state.get_hud()
#	var item = hud.get_active_item()
#	if not item:
#		return false
#	match item.item_id:
#		_:
#			return false
#	hud.inventory.visible = false
#	item.used(player, target)
#	item.remove()
#	return true

#func item_constraints_satisfied(item, action = "item_preview_action_1"):
#	match action:
#		"item_preview_action_1":
#			match item.item_id:
#				TakableIds.SOME_ID:
#					return some_constraint()
#		"item_preview_action_2":
#			pass
#		"item_preview_action_3":
#			pass
#		"item_preview_action_4":
#			pass
#	return true

#func execute_custom_action(item, action = "item_preview_action_1"):
#	match action:
#		"item_preview_action_1":
#			match item.item_id:
#				_:
#					pass
#		"item_preview_action_2":
#			pass
#		"item_preview_action_3":
#			pass
#		"item_preview_action_4":
#			pass

### GAME-SPECIFIC PART ###

const CAMERA_VIEW_TYPE_DEFAULT = CAMERA_VIEW_THIRD_PERSON_STRICT

const STORY_VARS_DEFAULT = {
	"flashlight_on" : false,
	"tactical_view_on" : true
}

enum LightIds {
	NONE = 0
}

enum RiddleIds {
	NONE = 0
}

enum PedestalIds {
	NONE = 0
}

enum ContainerIds {
	NONE = 0
}

enum RoomIds {
	NONE = 0
}

enum DoorIds {
	NONE = 0
}

enum ButtonActivatorIds {
	NONE = 0
}

enum UsableIds {
	NONE = 0
}

enum ActivatableIds {
	NONE = 0
}

enum ConversationAreaIds {
	NONE = 0
}

enum TakableIds {
	NONE = 0,
	RAT = 10,
	TORCH = 20,
	RIFLE = 30
}

const PEDESTAL_APPLICABLE_ITEMS = [
]

enum UseTargetIds {
	NONE = 0
}

const INVENTORY_DEFAULT = []
const QUICK_ITEMS_DEFAULT = [
	{ "item_id" : TakableIds.RIFLE, "count" : 1 }
]

const ITEMS = {
	TakableIds.RAT : { "item_nam" : "rat", "item_image" : "rat.png", "model_path" : "res://scenes/rat_grey.tscn", "model_use_path" : null, "stackable" : true, "can_give" : false, "custom_actions" : ["item_preview_action_1"] },
	TakableIds.TORCH : { "item_nam" : "torch", "item_image" : "torch.png", "model_path" : "res://assets/torch.dae", "model_use_path" : null, "stackable" : false, "can_give" : false, "custom_actions" : ["item_preview_action_1"] },
	TakableIds.RIFLE : { "item_nam" : "rifle", "item_image" : "rifle.png", "model_path" : "res://scenes/air_rifle_rigid.tscn", "model_use_path" : null, "stackable" : false, "can_give" : false, "custom_actions" : ["item_preview_action_1"] },
}

const WEAPONS_STUN = {
	#TakableIds.RIFLE : { "stun_duration" : 20, "sound_id" : PLDDBMedia.SoundId.RAT_SQUEAK }
}

const WEAPONS_RANGED = {
	TakableIds.RIFLE : { "injury_rate" : 10, "poison_rate" : 0, "sound_id" : PLDDBMedia.SoundId.RAT_SQUEAK }
}

func execute_give_item_action(player, target):
	if not player or not target:
		return false
	var hud = _pldrt.game_state.get_hud()
	var item = hud.get_active_item()
	if not item:
		return false
	match item.item_id:
#		TakableIds.BUN:
#			_pldrt.conversation_manager.start_conversation(player, "Bun", target)
#			item.remove()
		_:
			return false
	hud.inventory.visible = false
	item.used(player, target)
	return true

func item_constraints_satisfied(item, action = "item_preview_action_1"):
	match action:
		"item_preview_action_1":
#			match item.item_id:
#				TakableIds.CELL_PHONE:
#					return _pldrt.conversation_manager.conversation_is_not_finished("Chat")
			pass
		"item_preview_action_2":
			pass
		"item_preview_action_3":
			pass
		"item_preview_action_4":
			pass
	return true

func execute_custom_action(item, action = "item_preview_action_1"):
	match action:
		"item_preview_action_1":
			match item.item_id:
#				TakableIds.CELL_PHONE:
#					_pldrt.game_state.get_hud().show_tablet(true, PLDTablet.ActivationMode.CHAT)
				TakableIds.RAT:
					item.remove()
					var rat = PLDRatSource.create_rat(90)
					var pl = _pldrt.game_state.get_player().get_model()
					var pl_origin = pl.get_global_transform().origin
					var shift = pl.to_global(pl.get_transform().basis.xform(Vector3(0, 0, 1))) - pl_origin
					shift.y = 0
					shift = shift.normalized()
					var cross = shift.cross(Vector3(0, 1, 0))
					var basis = Basis(shift, Vector3(0, 1, 0), cross)
					var origin = pl_origin - shift * 2
					rat.set_global_transform(Transform(basis, origin))
					rat.rotate_y(deg2rad(180))
					_pldrt.game_state.get_level().add_child(rat)
#				TakableIds.FLASK_HEALING, TakableIds.AMBROSIA_CUP:
#					use_healing_item(item)
#				TakableIds.AIR_TANK:
#					_pldrt.game_state.set_oxygen(_pldrt.game_state.get_player(), _pldrt.game_state.player_oxygen_max, _pldrt.game_state.player_oxygen_max)
#					_pldrt.MEDIA.play_sound(PLDDBMedia.SoundId.MAN_BREATHE_IN_TANK)

func use_healing_item(item):
	var name_hint = __PLDRT.CHARS.PLAYER_NAME_HINT
	var ps = __PLDRT.game_state.party_stats[name_hint]
	var health_current = ps["health_current"]
	var health_max = ps["health_max"]
	if health_current >= health_max:
		_pldrt.game_state.get_hud().queue_popup_message("MESSAGE_FULL_HEALTH")
		return false
	var sound_id = PLDDBMedia.SoundId.MAN_DRINKS
	_pldrt.MEDIA.play_sound(sound_id)
	var player = _pldrt.game_state.get_player()
	var heal_amount = health_max / 2
	_pldrt.game_state.set_health(player, health_current + heal_amount, health_max)
	_pldrt.game_state.set_poisoned(player, false, 0)
	var last_item = (item.get_item_count() == 1)
	item.remove()
	if last_item:
#		_pldrt.game_state.take(
#			TakableIds.HEBE_CUP
#				if item.item_id == TakableIds.AMBROSIA_CUP
#				else TakableIds.FLASK_EMPTY
#		)
		pass
	return true
