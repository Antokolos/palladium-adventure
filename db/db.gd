tool
extends Reference
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
const PLAYER_ACTION_POINTS_CURRENT_DEFAULT = 0
const PLAYER_ACTION_POINTS_MAX_DEFAULT = 6

const CAMERA_VIEW_FIRST_PERSON = 0
const CAMERA_VIEW_THIRD_PERSON_STRICT = 1
const CAMERA_VIEW_THIRD_PERSON_FOLLOW = 2

const ITEM_PREVIEW_ACTION_1 = "item_preview_action_1"
const ITEM_PREVIEW_ACTION_2 = "item_preview_action_2"
const ITEM_PREVIEW_ACTION_3 = "item_preview_action_3"
const ITEM_PREVIEW_ACTION_4 = "item_preview_action_4"

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

static func lookup_takable_from_name(item_nam : String):
	if not item_nam or item_nam.length() == 0:
		return TakableIds.NONE
	for takable_id in ITEMS:
		var item_data = ITEMS[takable_id]
		if item_nam.casecmp_to(item_data.item_nam) == 0:
			return takable_id
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

### CODE THAT MUST BE INCLUDED IN THE GAME-SPECIFIC PART ###

#const CAMERA_VIEW_TYPE_DEFAULT = CAMERA_VIEW_FIRST_PERSON
#const USE_HEALTH = true
#const USE_ACTION_POINTS = false
#const USE_CROSSHAIR = true
#const USE_INDICATORS = true
#const USE_CHAT = true
#const USE_LOAD = true
#const USE_SAVE = true

#const STORY_VARS_DEFAULT = {
#	"flashlight_on" : false,
#	"tactical_view_on" : false,
#	"tactical_selection_on" : false,
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

#const INVENTORY_DEFAULT = {}
#const QUICK_ITEMS_DEFAULT = {}

#const ITEMS = {
#	TakableIds.NONE : { "item_nam" : "item_none", "item_image" : "none.png", "model_path" : "res://assets/none.escn", "model_use_path" : null, "stackable" : false, "can_give" : false, "custom_actions" : [] },
#}

#const WEAPONS_STUN = {
#	TakableIds.MEDUSA_HEAD : { "stun_duration" : 5, "sound_id" : PLDDBMedia.SoundId.SNAKE_HISS }
#}

#const WEAPONS_RANGED = {
#	TakableIds.RIFLE : { "injury_rate" : 10, "poison_rate" : 0, "sound_id" : PLDDBMedia.SoundId.RAT_SQUEAK }
#}

### GAME-SPECIFIC PART ###

const CAMERA_VIEW_TYPE_DEFAULT = CAMERA_VIEW_THIRD_PERSON_STRICT
const USE_HEALTH = true
const USE_ACTION_POINTS = false
const USE_CROSSHAIR = true
const USE_INDICATORS = true
const USE_CHAT = false
const USE_LOAD = true
const USE_SAVE = true
const USE_PAUSE = false

const STORY_VARS_DEFAULT = {
	"flashlight_on" : false,
	"tactical_view_on" : false,
	"tactical_selection_on" : true
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

const INVENTORY_DEFAULT = {}
const QUICK_ITEMS_DEFAULT = {
	PLDChars.PLAYER_NAME_HINT : [
		{ "item_id" : TakableIds.RIFLE, "count" : 1 }
	]
}

const ITEMS = {
	TakableIds.RAT : { "item_nam" : "rat", "item_image" : "rat.png", "model_path" : "res://scenes/rat_grey.tscn", "model_use_path" : null, "stackable" : true, "can_give" : false, "custom_actions" : [ ITEM_PREVIEW_ACTION_1 ] },
	TakableIds.TORCH : { "item_nam" : "torch", "item_image" : "torch.png", "model_path" : "res://assets/torch.dae", "model_use_path" : null, "stackable" : false, "can_give" : false, "custom_actions" : [ ITEM_PREVIEW_ACTION_1 ] },
	TakableIds.RIFLE : { "item_nam" : "rifle", "item_image" : "rifle.png", "model_path" : "res://scenes/air_rifle_rigid.tscn", "model_use_path" : null, "stackable" : false, "can_give" : false, "custom_actions" : [ ITEM_PREVIEW_ACTION_1 ] },
}

const WEAPONS_STUN = {
	#TakableIds.RIFLE : { "stun_duration" : 20, "sound_id" : PLDDBMedia.SoundId.RAT_SQUEAK }
}

const WEAPONS_RANGED = {
	TakableIds.RIFLE : { "injury_rate" : 10, "poison_rate" : 0, "sound_id" : PLDDBMedia.SoundId.RAT_SQUEAK }
}
