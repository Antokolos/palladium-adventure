extends Navigation
class_name PLDLevel

export var is_bright = false
export var is_inside = true
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
	__PLDRT.settings.set_reverb(is_inside)
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

func is_need_show_path():
	return is_need_show_path

func get_cam():
	return get_node(cam_path) if cam_path and has_node(cam_path) else null

func can_create_waypoint(character, origin):
	if not character:
		return false
	return true

func create_waypoint(character, origin, basis = Basis()):
	if not can_create_waypoint(character, origin):
		return null
	var pos3d = Position3D.new()
	if has_node("patrol_area"):
		get_node("patrol_area").add_child(pos3d)
	else:
		add_child(pos3d)
	pos3d.global_transform = Transform(basis, origin)
	return pos3d
