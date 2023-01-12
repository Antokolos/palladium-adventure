extends Spatial

signal preview_opened(item)
signal preview_closed(item)

const MAX_SIZE = Vector3(0.5, 0.5, 0.5)
const AXIS_VALUE_THRESHOLD = 0.15
const KEY_LOOK_SPEED_FACTOR = 30
const ZOOM_MIN = Vector3(0.40001, 0.40001, 0.40001)
const ZOOM_MAX = Vector3(2.0, 2.0, 2.0)
const ZOOM_SPEED = Vector3(0.2, 0.2, 0.2)
onready var item_holder_node = get_node("item_holder")

var inst
var item
var angle_rad_x = 0
var angle_rad_y = 0
var base_scale = Vector3(1.0, 1.0, 1.0)
var zoom = Vector3(1.0, 1.0, 1.0)
var des_zoom = zoom
var just_opened = true

func _ready():
	var hud = __PLDRT.game_state.get_hud()
	connect("preview_opened", hud, "_on_preview_opened")
	connect("preview_closed", hud, "_on_preview_closed")

func vmin(vec):
	var m = min(vec.x, vec.y)
	return min(m, vec.z)

func coord_div(vec1, vec2):
	return Vector3(vec1.x / vec2.x, vec1.y / vec2.y, vec1.z / vec2.z)

func toggle_meshes(root, enable):
	for m in root.get_children():
		if m is MeshInstance:
			m.set_layer_mask_bit(5, enable)
		else:
			toggle_meshes(m, enable)

func is_opened():
	return item_holder_node.get_child_count() > 0

func open_preview(item):
	if not item:
		return
	self.item = item
	self.inst = item.get_model_instance()
	for ch in item_holder_node.get_children():
		ch.queue_free()
	__PLDRT.common_utils.shadow_casting_enable(inst, false)
	toggle_meshes(inst, true)
	item_holder_node.add_child(inst)
	var aabb = item.get_aabb(inst)
	var vmcd = vmin(coord_div(MAX_SIZE, aabb.size))
	base_scale = Vector3(vmcd, vmcd, vmcd)
	inst.scale_object_local(base_scale)
	zoom = Vector3(1.0, 1.0, 1.0)
	des_zoom = zoom
	__PLDRT.common_utils.enter_hidden_mouse_mode()
	__PLDRT.game_state.get_hud().get_mouse_cursor().warp_mouse_in_center()
	just_opened = true
	emit_signal("preview_opened", item)

func process_input():
	if Input.is_action_just_pressed("item_preview_toggle"):
		if just_opened:
			just_opened = false
		else:
			close_preview()
	elif Input.is_action_just_pressed("ui_tablet_toggle"):
		close_preview()
	elif Input.is_action_just_pressed("item_preview_zoom_in"):
		if des_zoom < ZOOM_MAX:
			des_zoom += ZOOM_SPEED
	elif Input.is_action_just_pressed("item_preview_zoom_out"):
		if des_zoom > ZOOM_MIN:
			des_zoom -= ZOOM_SPEED
	elif (
		Input.is_action_just_pressed("item_preview_action_1")
		and __PLDRT.DB.can_execute_custom_action(item, "item_preview_action_1")
	):
		close_preview()
		__PLDRT.DB.execute_custom_action(item, "item_preview_action_1")
	elif (
		Input.is_action_just_pressed("item_preview_action_2")
		and __PLDRT.DB.can_execute_custom_action(item, "item_preview_action_2")
	):
		close_preview()
		__PLDRT.DB.execute_custom_action(item, "item_preview_action_2")
	elif (
		Input.is_action_just_pressed("item_preview_action_3")
		and __PLDRT.DB.can_execute_custom_action(item, "item_preview_action_3")
	):
		close_preview()
		__PLDRT.DB.execute_custom_action(item, "item_preview_action_3")
	elif (
		Input.is_action_just_pressed("item_preview_action_4")
		and __PLDRT.DB.can_execute_custom_action(item, "item_preview_action_4")
	):
		close_preview()
		__PLDRT.DB.execute_custom_action(item, "item_preview_action_4")
	else:
		var mouse_relative = __PLDRT.game_state.get_hud().get_mouse_cursor().get_mouse_relative_and_warp_in_center()
		if mouse_relative.length_squared() > 0:
			item_holder_node.rotate_x(deg2rad(mouse_relative.y * __PLDRT.settings.get_sensitivity() * __PLDRT.settings.get_yaxis_coeff()))
			item_holder_node.rotate_y(deg2rad(mouse_relative.x * __PLDRT.settings.get_sensitivity()))
			angle_rad_x = 0
			angle_rad_y = 0
		else:
			if Input.is_action_just_pressed("cam_up"):
				angle_rad_x = deg2rad(KEY_LOOK_SPEED_FACTOR * __PLDRT.settings.get_sensitivity() * -1 * __PLDRT.settings.get_yaxis_coeff())
			elif Input.is_action_just_pressed("cam_down"):
				angle_rad_x = deg2rad(KEY_LOOK_SPEED_FACTOR * __PLDRT.settings.get_sensitivity() * __PLDRT.settings.get_yaxis_coeff())
			elif Input.is_action_just_released("cam_up") or Input.is_action_just_released("cam_down"):
				angle_rad_x = 0
			else:
				var v = Input.get_joy_axis(0, JOY_AXIS_3)  # Joypad Right Stick Vertical Axis
				var nonzero = v > AXIS_VALUE_THRESHOLD or v < -AXIS_VALUE_THRESHOLD
				angle_rad_x = deg2rad(KEY_LOOK_SPEED_FACTOR * __PLDRT.settings.get_sensitivity() * v * __PLDRT.settings.get_yaxis_coeff()) if nonzero else 0
			
			if Input.is_action_just_pressed("cam_left"):
				angle_rad_y = deg2rad(KEY_LOOK_SPEED_FACTOR * __PLDRT.settings.get_sensitivity() * -1)
			elif Input.is_action_just_pressed("cam_right"):
				angle_rad_y = deg2rad(KEY_LOOK_SPEED_FACTOR * __PLDRT.settings.get_sensitivity())
			elif Input.is_action_just_released("cam_left") or Input.is_action_just_released("cam_right"):
				angle_rad_y = 0
			else:
				var v = Input.get_joy_axis(0, JOY_AXIS_2)  # Joypad Right Stick Horizontal Axis
				var nonzero = v > AXIS_VALUE_THRESHOLD or v < -AXIS_VALUE_THRESHOLD
				angle_rad_y = deg2rad(KEY_LOOK_SPEED_FACTOR * __PLDRT.settings.get_sensitivity() * v) if nonzero else 0

func _process(delta):
	if not __PLDRT.game_state.is_level_ready():
		return
	if item_holder_node.get_child_count() == 0 or __PLDRT.game_state.is_video_cutscene():
		return
	process_input()
	item_holder_node.rotate_x(angle_rad_x)
	item_holder_node.rotate_y(angle_rad_y)
	if (
		zoom.x != des_zoom.x
		or zoom.y != des_zoom.y
		or zoom.z != des_zoom.z
	):
		zoom = lerp(zoom, des_zoom, 0.2)
		inst.set_scale(base_scale * zoom)

func close_preview():
	for ch in item_holder_node.get_children():
		toggle_meshes(ch, false)
		ch.queue_free()
	__PLDRT.common_utils.exit_hidden_mouse_mode()
	emit_signal("preview_closed", item)
