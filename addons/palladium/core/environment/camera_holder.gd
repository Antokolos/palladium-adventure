extends Position3D
class_name PLDCameraHolder

const GLOBAL_ROTATE = true
const ANGLE_LIMIT_RAD = PI / 1.1
const EPS = 0.02

onready var global_axis = to_global(Vector3(0, 0, 1)) - to_global(Vector3(0, 0, 0))

var angle_rad_x = 0
var angle_x_reset = true
var angle_rad_y = 0
var angle_y_reset = true
var holder_transform = null

func get_hidden_player():
	if not __PLDRT.cutscene_manager.is_cutscene():
		return null
	return get_parent().get_hidden_player()

func prepare():
	reset_transform()
	get_parent().get_node("SpotLight").visible = true

func deconstruct():
	get_parent().get_node("SpotLight").visible = false

func reset_transform():
	if holder_transform:
		global_transform = holder_transform
		holder_transform = null

func _unhandled_input(event):
	if not get_hidden_player():
		return
	
	if event is InputEventMouseMotion:
		angle_rad_x = deg2rad(event.relative.y * __PLDRT.settings.get_sensitivity() * __PLDRT.settings.get_yaxis_coeff())
		angle_rad_y = deg2rad(event.relative.x * __PLDRT.settings.get_sensitivity() * -1)
		angle_x_reset = true
		angle_y_reset = true

func _process(delta):
	if not __PLDRT.game_state.is_level_ready():
		return
	
	if not get_hidden_player():
		return
	
	if abs(angle_rad_x) > EPS or abs(angle_rad_y) > EPS:
		if not holder_transform:
			holder_transform = global_transform
		var t = global_transform
		if GLOBAL_ROTATE:
			global_rotate(Vector3.UP, angle_rad_y)
		else:
			rotate_object_local(Vector3.UP, angle_rad_y)
		rotate_object_local(Vector3(1, 0, 0), -angle_rad_x)
		var a = global_axis.angle_to(to_global(Vector3(0, 0, 1)) - to_global(Vector3(0, 0, 0)))
		if a > ANGLE_LIMIT_RAD:
			global_transform = t
	if angle_x_reset:
		angle_rad_x = 0
		angle_x_reset = false
	if angle_y_reset:
		angle_rad_y = 0
		angle_y_reset = false
