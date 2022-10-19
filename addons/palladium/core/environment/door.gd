extends Spatial
class_name PLDDoor

signal door_state_changing(door_id, opened)
signal door_state_changed(door_id, opened)

const ANIM_SPEED_SCALE = 0.725

export(PLDDB.DoorIds) var door_id = PLDDB.DoorIds.NONE
export var initially_opened = false
export var reverse = false
export(NodePath) var navigation_mesh_path = null
export(NodePath) var door_body_path = NodePath("closed_door")
export(NodePath) var anim_player_path = NodePath("AnimationPlayer")
export(String) var anim_name_open = "open"
export(NodePath) var collision_anim_player_path = null
export(String) var collision_anim_name_open = "open"
export var anim_speed_scale = ANIM_SPEED_SCALE
export(NodePath) var lock_sound_player_path = null

onready var anim_player = (
	get_node(anim_player_path)
		if anim_player_path and has_node(anim_player_path)
		else null
)
onready var collision_anim_player = (
	get_node(collision_anim_player_path)
		if collision_anim_player_path and has_node(collision_anim_player_path)
		else null
)
onready var navigation_mesh = (
	get_node(navigation_mesh_path)
		if navigation_mesh_path and has_node(navigation_mesh_path)
		else null
)
onready var door_body = get_node(door_body_path)
onready var lock_sound_player = (
	get_node(lock_sound_player_path)
		if lock_sound_player_path and has_node(lock_sound_player_path)
		else null
)

func _ready():
	if anim_player:
		anim_player.connect("animation_finished", self, "_on_animation_finished")
	if lock_sound_player:
		lock_sound_player.connect("finished", self, "_on_lock_sound_finished")

func _on_animation_finished(anim_name):
	var is_opened = is_opened()
	emit_signal("door_state_changed", door_id, is_opened)
	if navigation_mesh:
		navigation_mesh.try_bake_navigation_mesh()

func _on_lock_sound_finished():
	do_open(false)

func enable_collisions(body, enable):
	for collision in body.get_children():
		if collision is CollisionShape:
			collision.disabled = not enable

func do_open(is_restoring):
	emit_signal("door_state_changing", door_id, true)
	var sp = PLDGameState.SPEED_SCALE_INFINITY if is_restoring else anim_speed_scale
	if anim_player:
		anim_player.play(anim_name_open, -1, -sp if reverse else sp, reverse)
	if collision_anim_player:
		collision_anim_player.play(
			collision_anim_name_open,
			-1,
			-sp if reverse else sp,
			reverse
		)
	else:
		enable_collisions(door_body, false)
	if not is_restoring:
		__PLDRT.game_state.set_door_state(get_path(), true)
		if has_node("door_sound"):
			get_node("door_sound").play(false)

func open(is_restoring = false):
	if not is_restoring and is_opened():
		return false
	if lock_sound_player and not is_restoring:
		lock_sound_player.play()
	else:
		do_open(is_restoring)
	return true

func close(is_restoring = false):
	if not is_restoring and not is_opened():
		return false
	emit_signal("door_state_changing", door_id, false)
	var sp = PLDGameState.SPEED_SCALE_INFINITY if is_restoring else anim_speed_scale
	if anim_player:
		anim_player.play(anim_name_open, -1, sp if reverse else -sp, not reverse)
	if collision_anim_player:
		collision_anim_player.play(
			collision_anim_name_open,
			-1,
			sp if reverse else -sp,
			not reverse
		)
	else:
		enable_collisions(door_body, true)
	if not is_restoring:
		__PLDRT.game_state.set_door_state(get_path(), false)
		if has_node("door_sound"):
			get_node("door_sound").play(true)
	return true

func is_untouched():
	var state = __PLDRT.game_state.get_door_state(get_path())
	return state == PLDGameState.DoorState.DEFAULT

func is_opened():
	var state = __PLDRT.game_state.get_door_state(get_path())
	return (state == PLDGameState.DoorState.OPENED) or (state == PLDGameState.DoorState.DEFAULT and initially_opened)

func is_closed():
	return not is_opened()

func restore_state():
	if is_opened():
		open(true)
	else:
		close(true)
