extends PLDCharacter
class_name PLDPlayer

const YROT_THRESHOLD_RAD = 0.02
const THIRD_PERSON_YROT_MIN_DEG = -33
const THIRD_PERSON_YROT_MAX_DEG = 33
const CAMERA_ROT_MIN_DEG = -88
const CAMERA_ROT_MAX_DEG = 88
const CAMERA_ROT_LADDER_MIN_DEG = -33
const CAMERA_ROT_LADDER_MAX_DEG = 33
const MODEL_ROT_MIN_DEG = -88
const MODEL_ROT_MAX_DEG = 0
const MODEL_ROT_LADDER_MIN_DEG = -33
const MODEL_ROT_LADDER_MAX_DEG = 0
const SHAPE_ROT_MIN_DEG = -90 - 88
const SHAPE_ROT_MAX_DEG = -90 + 88
const SHAPE_ROT_LADDER_MIN_DEG = -90 - 33
const SHAPE_ROT_LADDER_MAX_DEG = -90 + 33
const SHAPE_ROT_MIN_DISABLED_DEG = -90 - 20
const SHAPE_ROT_MAX_DISABLED_DEG = -90 + 20
const YROT_HELPER_PATH = "Rotation_HelperX/Rotation_HelperY"

export var initial_player = true

onready var yrot_helper = get_node(YROT_HELPER_PATH) if has_node(YROT_HELPER_PATH) else null
onready var upper_body_shape = $UpperBody_CollisionShape
onready var rotation_helper = $Rotation_Helper
onready var rotation_helper_tp = $Rotation_HelperX

var input_movement_vector = Vector3()
var angle_rad_x = 0
var angle_x_reset = false
var is_in_jump = false

func _ready():
	if is_player() or (
			initial_player \
			and not __PLDRT.game_state.is_loading() \
			and not __PLDRT.game_state.is_transition()
		):
			become_player()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.connect("attack_started", self, "_on_enemy_attack_started")
		enemy.connect("attack_stopped", self, "_on_enemy_attack_stopped")
		enemy.connect("attack_finished", self, "_on_enemy_attack_finished")
	#activate() -- restored from save

func get_rotation_helper():
	return (
		rotation_helper
			if __PLDRT.settings.get_camera_view() == PLDDB.CAMERA_VIEW_FIRST_PERSON
			else rotation_helper_tp
	)

func hit(injury_rate, poison_rate = 0, hit_direction_node = null, hit_dir_vec = Z_DIR):
	.hit(injury_rate, poison_rate, hit_direction_node, hit_dir_vec)
	var health_new = __PLDRT.game_state.party_stats[name_hint]["health_current"] - injury_rate
	if health_new > 0:
		take_damage(false, hit_direction_node, hit_dir_vec)
	else:
		take_damage(true, hit_direction_node, hit_dir_vec)
	__PLDRT.game_state.set_health(self, health_new, __PLDRT.game_state.party_stats[name_hint]["health_max"])

func reset_movement():
	.reset_movement()
	input_movement_vector.x = 0
	input_movement_vector.y = 0

func reset_rotation():
	.reset_rotation()
	angle_rad_x = 0
	var rotation_helper = get_rotation_helper()
	character_nodes.reset_rotation()
	if rotation_helper:
		rotation_helper.set_rotation_degrees(Vector3(0, 0, 0))
	if upper_body_shape:
		upper_body_shape.set_rotation_degrees(Vector3(-90, 0, 0))
		upper_body_shape.disabled = true
	if yrot_helper:
		yrot_helper.set_rotation_degrees(Vector3(0, 0, 0))

func enable_collisions_and_interaction(enable, all_shapes = false):
	.enable_collisions_and_interaction(enable, all_shapes)
	set_collision_layer_bit(COLLISION_LAYER_PLAYER, enable)

### Use target ###

func use(player_node, camera_node):
	var u = .use(player_node, camera_node)
	if not u:
		__PLDRT.game_state.handle_conversation(player_node, self, player_node)
	return true

func get_usage_code(player_node):
	var uc = .get_usage_code(player_node)
	if not uc.empty():
		return uc
	if __PLDRT.game_state.is_tactical_view():
		return ""
	if not is_in_party() \
		and __PLDRT.conversation_manager.meeting_is_finished(get_name_hint(), player_node.get_name_hint()):
		return ""
	return "ACTION_TALK"

### States ###

func set_simple_mode(enable):
	var model = get_model()
	if model:
		model.set_simple_mode(enable)
	else:
		push_warning("Model not set")

func remove_item_from_hand():
	var model = get_model()
	if model:
		model.remove_item_from_hand()
	else:
		push_warning("Model not set")

func get_camera_rot_min_deg():
	return CAMERA_ROT_LADDER_MIN_DEG if is_on_ladder() else CAMERA_ROT_MIN_DEG

func get_camera_rot_max_deg():
	return CAMERA_ROT_LADDER_MAX_DEG if is_on_ladder() else CAMERA_ROT_MAX_DEG

func get_model_rot_min_deg():
	return MODEL_ROT_LADDER_MIN_DEG if is_on_ladder() else MODEL_ROT_MIN_DEG

func get_model_rot_max_deg():
	return MODEL_ROT_LADDER_MAX_DEG if is_on_ladder() else MODEL_ROT_MAX_DEG

func get_shape_rot_min_deg():
	return SHAPE_ROT_LADDER_MIN_DEG if is_on_ladder() else SHAPE_ROT_MIN_DEG

func get_shape_rot_max_deg():
	return SHAPE_ROT_LADDER_MAX_DEG if is_on_ladder() else SHAPE_ROT_MAX_DEG

func process_rotation(need_to_update_collisions):
	if yrot_helper:
		var yrot = yrot_helper.rotation_degrees
		if angle_rad_y < -YROT_THRESHOLD_RAD and yrot.y < THIRD_PERSON_YROT_MAX_DEG:
			yrot.y += 1
		elif angle_rad_y > YROT_THRESHOLD_RAD and yrot.y > THIRD_PERSON_YROT_MIN_DEG:
			yrot.y -= 1
		yrot_helper.rotation_degrees = yrot
	var result = .process_rotation(need_to_update_collisions)
	if angle_rad_x == 0:
		return { "rotate_x" : false, "rotate_y" : result.rotate_y }
	if need_to_update_collisions:
		move_and_collide(Vector3.ZERO)
	var rotation_helper = get_rotation_helper()
	rotation_helper.rotate_x(angle_rad_x)
	character_nodes.process_rotation(angle_rad_x)
	var translator_node = get_translator_node()
	if translator_node:
		translator_node.global_rotation.z = 0
	upper_body_shape.rotate_x(angle_rad_x)
	var camera_rot = rotation_helper.rotation_degrees
	var model_rot = Vector3(camera_rot.x, camera_rot.y, camera_rot.z)
	var shape_rot = upper_body_shape.rotation_degrees
	camera_rot.x = clamp(camera_rot.x, get_camera_rot_min_deg(), get_camera_rot_max_deg())
	rotation_helper.rotation_degrees = camera_rot
	model_rot.x = clamp(model_rot.x, get_model_rot_min_deg(), get_model_rot_max_deg())
	if __PLDRT.settings.get_camera_view() == PLDDB.CAMERA_VIEW_FIRST_PERSON:
		get_model_holder().rotation_degrees = model_rot
	shape_rot.x = clamp(shape_rot.x, get_shape_rot_min_deg(), get_shape_rot_max_deg())
	upper_body_shape.rotation_degrees = shape_rot
	upper_body_shape.disabled = shape_rot.x >= SHAPE_ROT_MIN_DISABLED_DEG and shape_rot.x <= SHAPE_ROT_MAX_DISABLED_DEG
	if angle_x_reset:
		angle_rad_x = 0
		angle_x_reset = false
	return { "rotate_x" : true, "rotate_y" : result.rotate_y }

func get_snap():
	return Vector3.ZERO if is_in_jump else .get_snap()

func get_gravity():
	return (
		GRAVITY_FALLING
			if is_in_jump and not is_underwater()
			else .get_gravity()
	)

func _on_character_dead(player):
	._on_character_dead(player)
	if player.is_player_controlled():
		__PLDRT.game_state.game_over()

func _on_enemy_attack_started(player_node, target, attack_anim_idx):
	if is_player_controlled() or not is_in_party():
		return
	#set_point_of_interest(player_node) -- should be already set

func _on_enemy_attack_stopped(player_node, target, attack_anim_idx):
	if is_player_controlled() or not is_in_party():
		return
	#clear_poi_if_it_is(player_node) -- better not to do it to minimize rotations

func _on_enemy_attack_finished(player_node, target, previous_target, attack_anim_idx):
	if is_player_controlled() or not is_in_party():
		return
	#clear_poi_if_it_is(player_node) -- better not to do it to minimize rotations

func is_joypad_look(event):
	if not event is InputEventJoypadMotion:
		return false
	var a = event.get_axis()
	return a == JOY_AXIS_2 or a == JOY_AXIS_3

func _input(event):
	if __PLDRT.game_state.is_tactical_view() or not is_player() or not is_activated():
		return
	var hud = __PLDRT.game_state.get_hud()
	if __PLDRT.conversation_manager.conversation_is_in_progress():
		if __PLDRT.story_node.can_choose():
			if event.is_action_pressed("dialogue_option_1"):
				__PLDRT.conversation_manager.story_choose(self, 0)
			elif event.is_action_pressed("dialogue_option_2"):
				__PLDRT.conversation_manager.story_choose(self, 1)
			elif event.is_action_pressed("dialogue_option_3"):
				__PLDRT.conversation_manager.story_choose(self, 2)
			elif event.is_action_pressed("dialogue_option_4"):
				__PLDRT.conversation_manager.story_choose(self, 3)
		elif event.is_action_pressed("dialogue_next"):
			__PLDRT.conversation_manager.proceed_story_immediately(self)
	if is_in_party() and not __PLDRT.cutscene_manager.is_cutscene():
		var on_ladder = is_on_ladder()
		if on_ladder:
			input_movement_vector.x = 0
			input_movement_vector.y = 0
			if event.is_action_pressed("movement_forward") \
				and input_movement_vector.y == 0:
				input_movement_vector.z = 1
			elif event.is_action_released("movement_forward") \
				and input_movement_vector.z == 1:
				input_movement_vector.z = 0
			elif event.is_action_pressed("movement_backward") \
				and input_movement_vector.z == 0:
				input_movement_vector.z = -1
			elif event.is_action_released("movement_backward") \
				and input_movement_vector.z == -1:
				input_movement_vector.z = 0
		else:
			input_movement_vector.z = 0
		
		if (
			__PLDRT.common_utils.is_mouse_captured()
			and event is InputEventMouseMotion
		):
			angle_rad_x = deg2rad(event.relative.y * __PLDRT.settings.get_sensitivity() * __PLDRT.settings.get_yaxis_coeff())
			change_angle_rad_y_to(
				deg2rad(event.relative.x * __PLDRT.settings.get_sensitivity() * -1)
			)
			angle_x_reset = true
			angle_y_reset = true
			__PLDRT.game_state.get_cam().process_rotation(self)
		elif is_joypad_look(event):
			var v = event.get_axis_value()
			var nonzero = v > AXIS_VALUE_THRESHOLD or v < -AXIS_VALUE_THRESHOLD
			if event.get_axis() == JOY_AXIS_2:  # Joypad Right Stick Horizontal Axis
				change_angle_rad_y_to(
					deg2rad(KEY_LOOK_SPEED_FACTOR * __PLDRT.settings.get_sensitivity() * -v)
						if nonzero
						else 0
				)
			if event.get_axis() == JOY_AXIS_3:  # Joypad Right Stick Vertical Axis
				angle_rad_x = deg2rad(KEY_LOOK_SPEED_FACTOR * __PLDRT.settings.get_sensitivity() * v * __PLDRT.settings.get_yaxis_coeff()) if nonzero else 0
		elif not on_ladder:
			if event.is_action_pressed("movement_forward") \
				and input_movement_vector.y == 0:
				input_movement_vector.y = 1
			elif event.is_action_released("movement_forward") \
				and input_movement_vector.y == 1:
				input_movement_vector.y = 0
			elif event.is_action_pressed("movement_backward") \
				and input_movement_vector.y == 0:
				input_movement_vector.y = -1
			elif event.is_action_released("movement_backward") \
				and input_movement_vector.y == -1:
				input_movement_vector.y = 0
			
			if event.is_action_pressed("movement_left") \
				and input_movement_vector.x == 0:
				input_movement_vector.x = -1
			elif event.is_action_released("movement_left") \
				and input_movement_vector.x == -1:
				input_movement_vector.x = 0
			elif event.is_action_pressed("movement_right") \
				and input_movement_vector.x == 0:
				input_movement_vector.x = 1
			elif event.is_action_released("movement_right") \
				and input_movement_vector.x == 1:
				input_movement_vector.x = 0
			
			if event.is_action_pressed("cam_up"):
				angle_rad_x = deg2rad(KEY_LOOK_SPEED_FACTOR * __PLDRT.settings.get_sensitivity() * -1 * __PLDRT.settings.get_yaxis_coeff())
			elif event.is_action_pressed("cam_down"):
				angle_rad_x = deg2rad(KEY_LOOK_SPEED_FACTOR * __PLDRT.settings.get_sensitivity() * __PLDRT.settings.get_yaxis_coeff())
			elif event.is_action_released("cam_up") or event.is_action_released("cam_down"):
				angle_rad_x = 0
			
			if event.is_action_pressed("cam_left"):
				change_angle_rad_y_to(
					deg2rad(KEY_LOOK_SPEED_FACTOR * __PLDRT.settings.get_sensitivity())
				)
			elif event.is_action_pressed("cam_right"):
				change_angle_rad_y_to(
					deg2rad(KEY_LOOK_SPEED_FACTOR * __PLDRT.settings.get_sensitivity() * -1)
				)
			elif event.is_action_released("cam_left") or event.is_action_released("cam_right"):
				change_angle_rad_y_to(0)
			
			if event.is_action_pressed("crouch"):
				toggle_crouch()
				set_sprinting(false)
			elif can_jump() and event.is_action_pressed("movement_jump"):
				vel.y = JUMP_SPEED
				is_in_jump = true
			elif not is_crouching():
				if event.is_action_pressed("movement_sprint"):
					set_sprinting(true)
				elif event.is_action_released("movement_sprint"):
					set_sprinting(false)

func get_movement_data(is_player):
	var cam = __PLDRT.game_state.get_cam()
	if not __PLDRT.game_state.is_tactical_view() \
		and is_player \
		and is_in_party() \
		and not is_movement_disabled() \
		and not __PLDRT.cutscene_manager.is_cutscene():
			var data = PLDMovementData.new()
			var cam_xform = cam.get_global_transform()
			if input_movement_vector.length_squared() > EPS:
				var dir_input = Vector3()
				var n = input_movement_vector.normalized()
				if is_on_ladder():
					dir_input += Vector3.UP * n.z
				else:
					dir_input += -cam_xform.basis.z.normalized() * n.y
					dir_input += cam_xform.basis.x.normalized() * n.x
				cam.walk_initiate(self)
				data.with_dir(dir_input).with_rest_state(false)
			else:
				data.with_rest_state(true)
			if cam_xform.origin.y < max_lower_limit_y:
				data.with_signal("out_of_bounds", [])
			return data
	else:
		if is_player and not __PLDRT.cutscene_manager.is_cutscene():
			cam.walk_stop(self)
		return .get_movement_data(is_player)

func _physics_process(delta):
	if not __PLDRT.game_state.is_level_ready():
		character_nodes.stop_all()
		return
	var is_player = is_player()
	var d = do_process(delta, is_player)
	if is_player and d.is_rotating:
		__PLDRT.game_state.get_cam().process_rotation(self)
	if has_floor_collision() and is_in_jump:
		is_in_jump = false
		character_nodes.play_sound_falling_to_floor()
