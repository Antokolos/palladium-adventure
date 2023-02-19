extends Camera
class_name PLDCamera

signal tactical_cursor_action(collider)
signal tactical_cursor_over(collider)
signal tactical_cursor_out(collider)

const TACTICAL_CAMERA_ROT_EPS = deg2rad(0.5)
const TACTICAL_CAMERA_ROT_MIN_RAD = deg2rad(20)
const TACTICAL_CAMERA_ROT_MAX_RAD = deg2rad(75)
const TACTICAL_CAMERA_DISTANCE_EPS = 0.15
const TACTICAL_CAMERA_DISTANCE_MIN = 3
const TACTICAL_CAMERA_DISTANCE_MAX = 180
const TACTICAL_CAMERA_DISTANCE_PLAYER_SW = 19.9
const TACTICAL_CAMERA_PROJECTION_LENGTH = 9999
const TACTICAL_MOVEMENT_THRESHOLD = 10
const TACTICAL_MOVEMENT_SPEED = 0.3
const TACTICAL_ZOOM_SPEED = 4
const TACTICAL_CAMERA_BACKTRACE_INDENT = 0.05

# The factor to use for asymptotical translation lerping.
# If 0, the camera will stop moving. If 1, the camera will move instantly.
export(float) var translate_speed = 0.95

# The factor to use for asymptotical rotation lerping.
# If 0, the camera will stop rotating. If 1, the camera will rotate instantly.
export(float) var rotate_speed = 0.95

# The factor to use for asymptotical FOV lerping.
# If 0, the camera will stop changing its FOV. If 1, the camera will change its FOV instantly.
# Note: Only works if the target node is a Camera3D.
export(float) var fov_speed = 0.95

# The factor to use for asymptotical Z near/far plane distance lerping.
# If 0, the camera will stop changing its Z near/far plane distance. If 1, the camera will do so instantly.
# Note: Only works if the target node is a Camera3D.
export(float) var near_far_speed = 0.95

# The node to target.
# Can optionally be a Camera3D to support smooth FOV and Z near/far plane distance changes.
export(NodePath) var target_path

onready var strict_following = true

onready var flashlight = get_node("Flashlight") if has_node("Flashlight") else null
onready var flashlight_spot = flashlight.get_node("Flashlight") if flashlight else null
onready var cutscene_flashlight = get_node("CutsceneFlashlight") if has_node("CutsceneFlashlight") else null
onready var use_point = get_use_point()

onready var env_norm = preload("res://addons/palladium/env_norm.tres")
onready var env_opt = preload("res://addons/palladium/env_opt.tres")
onready var env_good = preload("res://addons/palladium/env_good.tres")
onready var env_high = preload("res://addons/palladium/env_high.tres")

onready var backtrace_ray = get_node("BacktraceRay") if has_node("BacktraceRay") else null
onready var projection_ray = get_node("ProjectionRay") if has_node("ProjectionRay") else null
onready var culling_rays = get_node("culling_rays") if has_node("culling_rays") else null
onready var shader_cache = get_node("viewpoint/shader_cache") if has_node("viewpoint/shader_cache") else null
onready var item_preview = get_node("viewpoint/item_preview") if has_node("viewpoint/item_preview") else null
onready var item_use = get_node("viewpoint/item_use") if has_node("viewpoint/item_use") else null

onready var separated_viewport = get_node("separated_viewport") if has_node("separated_viewport") else null

var input_movement_vector = Vector2(0, 0)
var tactical_view_rotation = false
var tactical_view_action = false
var tactical_view_double_click = false
var tactical_player_character = null
var tactical_cursor_collider = null
var tactical_camera_distance = (TACTICAL_CAMERA_DISTANCE_MIN + TACTICAL_CAMERA_DISTANCE_MAX) / 2
var tactical_zoom_speed = 0
var angle_rad_x = 0
var angle_x_reset = false
var angle_rad_y = 0
var angle_y_reset = false
var character_to_switch_to = null setget set_character_to_switch_to, get_character_to_switch_to
func set_character_to_switch_to(character):
	character_to_switch_to = character
func get_character_to_switch_to():
	return character_to_switch_to

func _ready():
	change_quality(__PLDRT.settings.quality)
	__PLDRT.settings.connect("quality_changed", self, "change_quality")
	__PLDRT.game_state.connect("game_loaded", self, "_on_game_loaded")
	if item_preview:
		item_preview.connect("preview_opened", self, "_on_preview_opened")
		item_preview.connect("preview_closed", self, "_on_preview_closed")
	strict_following = __PLDRT.settings.get_camera_view() != PLDDB.CAMERA_VIEW_THIRD_PERSON_FOLLOW

func get_use_point():
	return get_node("Gun_Fire_Points/use_point") if has_node("Gun_Fire_Points/use_point") else null

func rebuild_exceptions(player_node):
	var upt = get_use_point()
	if upt:
		upt.rebuild_exceptions(player_node)

func enable_use(enable):
	if use_point:
		use_point.enable(enable)

func show_cutscene_flashlight(enable):
	cutscene_flashlight.visible = enable
	if enable:
		flashlight.hide()
	elif flashlight and __PLDRT.game_state.is_flashlight_on():
		flashlight.show()

func get_use_distance():
	return use_point.get_use_distance() if use_point else 0

# Settings applied in the following way will be loaded after game restart
# see https://github.com/godotengine/godot/issues/30087
#func apply_advanced_settings(force_vertex_shading):
#	var config = ConfigFile.new()
#	config.set_value("rendering", "quality/shading/force_vertex_shading", force_vertex_shading)
#	config.save("user://settings.ini")

func change_quality(quality):
	match quality:
		PLDSettings.QUALITY_NORM:
			self.environment = env_norm
			if separated_viewport:
				separated_viewport.set_camera_environment(env_norm)
			#get_tree().call_group("lightmaps", "enable", false)
			#__PLDRT.game_state.get_viewport().shadow_atlas_size = 2048
			get_tree().call_group("fire_sources", "set_quality_normal")
			get_tree().call_group("light_sources", "set_quality_normal")
			get_tree().call_group("grass", "set_quality_normal")
			get_tree().call_group("moving", "shadow_casting_enable", false)
			get_tree().call_group("trees", "wind_effect_enable", false)
			if flashlight_spot:
				flashlight_spot.set("shadow_enabled", false)
			ProjectSettings.set_setting("rendering/quality/shadows/filter_mode", 0)
		PLDSettings.QUALITY_OPT:
			self.environment = env_opt
			if separated_viewport:
				separated_viewport.set_camera_environment(env_opt)
			#get_tree().call_group("lightmaps", "enable", true)
			#__PLDRT.game_state.get_viewport().shadow_atlas_size = 2048
			get_tree().call_group("fire_sources", "set_quality_optimal")
			get_tree().call_group("light_sources", "set_quality_optimal")
			get_tree().call_group("grass", "set_quality_optimal")
			get_tree().call_group("moving", "shadow_casting_enable", false)
			get_tree().call_group("trees", "wind_effect_enable", false)
			if flashlight_spot:
				flashlight_spot.set("shadow_enabled", false)
			ProjectSettings.set_setting("rendering/quality/shadows/filter_mode", 0)
		PLDSettings.QUALITY_GOOD:
			self.environment = env_good
			if separated_viewport:
				separated_viewport.set_camera_environment(env_good)
			#get_tree().call_group("lightmaps", "enable", false)
			#__PLDRT.game_state.get_viewport().shadow_atlas_size = 4096
			get_tree().call_group("fire_sources", "set_quality_good")
			get_tree().call_group("light_sources", "set_quality_good")
			get_tree().call_group("grass", "set_quality_good")
			get_tree().call_group("moving", "shadow_casting_enable", false)
			get_tree().call_group("trees", "wind_effect_enable", true)
			if flashlight_spot:
				flashlight_spot.set("shadow_enabled", false)
			ProjectSettings.set_setting("rendering/quality/shadows/filter_mode", 1)
		PLDSettings.QUALITY_HIGH:
			self.environment = env_high
			if separated_viewport:
				separated_viewport.set_camera_environment(env_high)
			#get_tree().call_group("lightmaps", "enable", false)
			#__PLDRT.game_state.get_viewport().shadow_atlas_size = 8192
			get_tree().call_group("fire_sources", "set_quality_high")
			get_tree().call_group("light_sources", "set_quality_high")
			get_tree().call_group("grass", "set_quality_high")
			get_tree().call_group("moving", "shadow_casting_enable", true)
			get_tree().call_group("trees", "wind_effect_enable", true)
			if flashlight_spot:
				flashlight_spot.set("shadow_enabled", true)
			ProjectSettings.set_setting("rendering/quality/shadows/filter_mode", 2)
	set_inside(__PLDRT.game_state.is_inside(), __PLDRT.game_state.is_bright())
	if shader_cache:
		shader_cache.refresh()

func _on_game_loaded():
	show_flashlight(__PLDRT.game_state.is_flashlight_on())

func set_inside(inside, bright):
	environment.set_background(Environment.BG_COLOR_SKY if inside else Environment.BG_SKY)
	environment.set_bg_color(Color(1, 1, 1) if bright else Color(0, 0, 0))
	environment.set("background_sky", __PLDRT.game_state.sky_inside if inside else __PLDRT.game_state.sky_outside)
	environment.set("background_energy", 0.3 if bright else (0.04 if inside else 0.3))
	environment.set("background_sky_rotation_degrees", __PLDRT.game_state.sky_rotation_degrees)
	environment.set("ambient_light_energy", 0.3 if bright else (0.04 if inside else 0.3))

func set_target_path(path : NodePath):
	target_path = path

func change_culling():
	if culling_rays:
		self.far = culling_rays.get_max_distance(self.get_global_transform().origin)

func activate_item_use(item):
	# TODO: eliminate use cases when item_use is null
	if item_use and item_use.activate_item(item):
		separated_viewport.visible = true

func clear_item_use():
	# TODO: eliminate use cases when item_use is null
	if item_use:
		item_use.clear_item()
		separated_viewport.visible = false

func activate_transporting():
	if __PLDRT.settings.get_camera_view() != PLDDB.CAMERA_VIEW_FIRST_PERSON:
		return
	separated_viewport.visible = true

func deactivate_transporting():
	if __PLDRT.settings.get_camera_view() != PLDDB.CAMERA_VIEW_FIRST_PERSON:
		return
	if not item_use or not item_use.get_item_in_use():
		separated_viewport.visible = false

func walk_initiate(player_node):
	if item_use:
		item_use.walk_initiate(player_node, self)

func walk_stop(player_node):
	if item_use:
		item_use.walk_stop(player_node, self)

func process_rotation(player_node):
	if item_use:
		item_use.process_rotation(player_node, self)

func show_flashlight(is_show):
	if flashlight:
		if is_show:
			flashlight.show()
		else:
			flashlight.hide()

func _on_preview_opened(item):
	clear_item_use()
	show_cutscene_flashlight(true)
	separated_viewport.visible = true
	separated_viewport.show_dimmer(true)

func _on_preview_closed(item):
	show_cutscene_flashlight(false)
	separated_viewport.show_dimmer(false)
	if not item_use or not item_use.get_item_in_use():
		separated_viewport.visible = false

func estimate_position(point, normal = null, up = Vector3.UP):
	var v = global_transform.origin - point
	var nva = normal.angle_to(v) if normal else 0
	var uva = up.angle_to(v)
	var vdn = (v.dot(normal) < 0) if normal else false
	var vdu = (v.dot(up) < 0)
	if not (
			(
				normal
				and (
					vdn
					or nva < TACTICAL_CAMERA_ROT_MIN_RAD
					or nva > TACTICAL_CAMERA_ROT_MAX_RAD
				)
			)
			or (
				vdu
				or uva < TACTICAL_CAMERA_ROT_MIN_RAD
				or uva > TACTICAL_CAMERA_ROT_MAX_RAD
			)
	):
		return {
			"acceptable" : true,
			"diff" : 0,
			"emergency" : false
		}
	if vdn or vdu:
		return {
			"acceptable" : false,
			"diff" : 0,
			"emergency" : true
		}
	var diff = 0
	if normal:
		if nva < TACTICAL_CAMERA_ROT_MIN_RAD:
			diff = TACTICAL_CAMERA_ROT_MIN_RAD + TACTICAL_CAMERA_ROT_EPS - nva
			diff = -diff
		elif nva > TACTICAL_CAMERA_ROT_MAX_RAD:
			diff = nva - TACTICAL_CAMERA_ROT_MAX_RAD + TACTICAL_CAMERA_ROT_EPS
	if diff == 0:
		if uva < TACTICAL_CAMERA_ROT_MIN_RAD:
			diff = TACTICAL_CAMERA_ROT_MIN_RAD + TACTICAL_CAMERA_ROT_EPS - uva
			diff = -diff
		elif uva > TACTICAL_CAMERA_ROT_MAX_RAD:
			diff = uva - TACTICAL_CAMERA_ROT_MAX_RAD + TACTICAL_CAMERA_ROT_EPS
	return {
		"acceptable" : false,
		"diff" : diff,
		"emergency" : (diff == 0)
	}

func rotate_around(point, axis, angle, normal = null, up = Vector3.UP):
	# Get transform
	var trans = global_transform # if global else transform
	# Rotate its basis
	var rotated_basis = trans.basis.rotated(axis, angle)
	# Rotate its origin
	var rotated_origin = point + (trans.origin - point).rotated(axis, angle)
	# Set the result back (set to transform if not global)
	global_transform = Transform(rotated_basis, rotated_origin)
	return estimate_position(point, normal)

func emergency(origin, point, normal):
	var l = TACTICAL_CAMERA_DISTANCE_MIN + TACTICAL_CAMERA_DISTANCE_EPS
	var v = origin - point
	var ucn = v.cross(normal).rotated(normal, -PI/2)
	var alpha = TACTICAL_CAMERA_ROT_MIN_RAD + TACTICAL_CAMERA_ROT_EPS
	var position = (
		point + l * (normal * cos(alpha) + ucn.normalized() * sin(alpha))
			if ucn.length() > 0
			else origin
	)
	look_at_from_position(position, point, Vector3.UP)

func process_tactical_camera_movement(zoom):
	var result = PLDTacticalCameraMovement.new()
	var roty = global_rotation.y
	var x = -sin(roty) * input_movement_vector.y
	var y = -cos(roty) * input_movement_vector.y
	global_translate(Vector3(x, 0, y) * TACTICAL_MOVEMENT_SPEED)
	translate_object_local(Vector3(input_movement_vector.x, 0, 0) * TACTICAL_MOVEMENT_SPEED)
	var point = use_point.get_collision_point()
	if point:
		result.with_point(point)
		tactical_camera_distance = clamp(
			tactical_camera_distance,
			TACTICAL_CAMERA_DISTANCE_MIN,
			TACTICAL_CAMERA_DISTANCE_MAX
		)
		var diff = Vector3.ZERO
		var origin = global_transform.origin
		var pvl = (origin - point).length()
		if pvl < tactical_camera_distance:
			diff = (tactical_camera_distance - pvl) * (origin - point).normalized()
		if pvl > tactical_camera_distance:
			diff = (pvl - tactical_camera_distance) * (point - origin).normalized()
		global_translate(diff)
		var z = (
			zoom
				if zoom < 0
				else (
					min(zoom, pvl - TACTICAL_CAMERA_DISTANCE_MIN)
						if pvl > TACTICAL_CAMERA_DISTANCE_MIN
						else 0
				)
		)
		translate_object_local(Vector3(0, 0, -z) * TACTICAL_MOVEMENT_SPEED)
		origin = global_transform.origin
		pvl = (origin - point).length()
		if pvl < TACTICAL_CAMERA_DISTANCE_MIN:
			diff = (TACTICAL_CAMERA_DISTANCE_MIN - pvl) * (origin - point).normalized()
		if pvl > TACTICAL_CAMERA_DISTANCE_MAX:
			diff = (pvl - TACTICAL_CAMERA_DISTANCE_MAX) * (point - origin).normalized()
		global_translate(diff * TACTICAL_MOVEMENT_SPEED)
		var normal = use_point.get_collision_normal()
		var axis = Vector3(cos(global_rotation.y), 0, -sin(global_rotation.y))
		var epx = rotate_around(point, axis, -angle_rad_x, normal)
		if not epx.acceptable:
			if epx.emergency:
				emergency(origin, point, normal)
			else:
				rotate_around(point, axis, -epx.diff, normal)
		var epy = rotate_around(point, Vector3.UP, angle_rad_y, normal)
		if not epy.acceptable:
			if epy.emergency:
				emergency(origin, point, normal)
			else:
				rotate_around(point, Vector3.UP, -epy.diff, normal)
		origin = global_transform.origin
		var v = origin - point
		var backtrace_origin = point + v * TACTICAL_CAMERA_BACKTRACE_INDENT
		backtrace_ray.set_global_transform(Transform(
			global_transform.basis,
			backtrace_origin
		))
		backtrace_ray.cast_to = backtrace_ray.to_local(origin)
		backtrace_ray.force_raycast_update()
		if backtrace_ray.is_colliding():
			return result.create_error(
				backtrace_ray.get_collision_normal() * TACTICAL_MOVEMENT_SPEED
			)
		else:
			var ep = estimate_position(point, normal)
			if not ep.acceptable:
				if ep.emergency:
					emergency(origin, point, normal)
				else:
					look_at_from_position(origin, point, Vector3.UP)
	else:
		translate_object_local(Vector3(0, 0, -zoom) * TACTICAL_MOVEMENT_SPEED)
		rotate_object_local(Vector3(1, 0, 0), -angle_rad_x)
		global_rotate(Vector3.UP, angle_rad_y)
	return result.create_ok()

func is_tactical_player_character(character : PLDCharacter):
	if not tactical_player_character:
		return false
	return tactical_player_character.equals(character)

func process_tactical_player_sprinting():
	tactical_player_character.set_sprinting(tactical_view_double_click)

func try_to_attack(character):
	if (
		tactical_player_character
		and ((
				tactical_player_character is PLDPlayer
				and character is PLDEnemy
			) or (
				tactical_player_character is PLDEnemy
				and character is PLDPlayer
			)
		)
	):
		var current_target = tactical_player_character.get_target_node()
		if (
			not current_target
			or not character.equals(current_target)
		):
			tactical_player_character.set_target_node(character)
			process_tactical_player_sprinting()
			return true
	return false

func select_tactical_player(character):
	if tactical_player_character:
		tactical_player_character.enable_selection_mark(false)
		tactical_player_character.set_sprinting(false)
	tactical_player_character = character
	tactical_player_character.enable_selection_mark(true)

func process_tactical_view_cursor(needs_action):
	var point = (
		projection_ray.get_collision_point()
			if projection_ray.is_colliding()
			else null
	)
	var collider = (
		projection_ray.get_collider()
			if point
			else null
	)
	projection_ray.cast_to = Vector3.ZERO
	if point:
		if collider:
			if (
				needs_action
				and collider is PLDCharacter
				and not collider.equals(tactical_player_character)
			):
				if try_to_attack(collider):
					return
				if __PLDRT.game_state.tactical_selection_enabled():
					select_tactical_player(collider)
				return
			elif (
				needs_action
				or not tactical_cursor_collider
				or tactical_cursor_collider.get_instance_id() != collider.get_instance_id()
			):
				if needs_action:
					emit_signal("tactical_cursor_action", collider)
				else:
					emit_signal("tactical_cursor_over", collider)
					emit_signal("tactical_cursor_out", tactical_cursor_collider)
				tactical_cursor_collider = collider
		if not needs_action or not tactical_player_character:
			return
		if not tactical_player_character.is_activated():
			tactical_player_character.activate()
		var level = __PLDRT.game_state.get_level()
		var pos3d = level.create_waypoint(tactical_player_character, point)
		if pos3d:
			tactical_player_character.set_target_node(pos3d)
			process_tactical_player_sprinting()

func process_tactical_player_attack():
	var possible_attack_target = (
		tactical_player_character.get_possible_attack_target(false)
	)
	if (
		possible_attack_target
		and possible_attack_target.equals(tactical_player_character.get_target_node())
	):
		if possible_attack_target.is_dead():
			tactical_player_character.clear_target_node()
		else:
			tactical_player_character.attack_start(possible_attack_target)

func switch_to_character(character):
	var cht = character.get_cam_holder().get_global_transform()
	var v = cht.origin - character.get_global_transform().origin
	var vn = v.normalized()
	set_global_transform(Transform(
		cht.basis,
		cht.origin + (TACTICAL_CAMERA_DISTANCE_PLAYER_SW - v.length()) * vn
	))
	tactical_camera_distance = TACTICAL_CAMERA_DISTANCE_PLAYER_SW

func switch_to_party_member(idx : int) -> void:
	var i = 0
	for ch in __PLDRT.game_state.get_characters():
		if not ch.is_in_party():
			continue
		if i == idx:
			switch_to_character(ch)
			return
		i += 1

func perform_player_switching():
	if character_to_switch_to:
		switch_to_character(character_to_switch_to)
		character_to_switch_to = null
		return true
	if Input.is_action_just_pressed("switch_to_player_1"):
		switch_to_party_member(0)
		return true
	elif Input.is_action_just_pressed("switch_to_player_2"):
		switch_to_party_member(1)
		return true
	elif Input.is_action_just_pressed("switch_to_player_3"):
		switch_to_party_member(2)
		return true
	elif Input.is_action_just_pressed("switch_to_player_4"):
		switch_to_party_member(3)
		return true
	return false

func _process(delta):
	if not __PLDRT.game_state.is_level_ready():
		return
	
	# ----------------------------------
	# Turning the flashlight on/off
	if flashlight \
		and not cutscene_flashlight.visible \
		and Input.is_action_just_pressed("flashlight"):
		if flashlight.is_visible_in_tree():
			$AudioStreamFlashlightOff.play()
			flashlight.hide()
			__PLDRT.game_state.change_flashlight_state(self, false)
		else:
			$AudioStreamFlashlightOn.play()
			flashlight.show()
			__PLDRT.game_state.change_flashlight_state(self, true)
	# ----------------------------------
	
	if use_point:
		var player = __PLDRT.game_state.get_player()
		__PLDRT.game_state.get_hud().main_hud.get_node("HBoxHints/ActionHintLabel").text = use_point.highlight(player)
	change_culling()
	
	if __PLDRT.game_state.is_tactical_view():
		if perform_player_switching():
			return
		if backtrace_ray and not backtrace_ray.enabled:
			backtrace_ray.enabled = true
		if projection_ray and not projection_ray.enabled:
			projection_ray.enabled = true
		if Input.is_action_just_pressed("tactical_view_zoom_in"):
			tactical_zoom_speed = TACTICAL_ZOOM_SPEED
		elif Input.is_action_just_released("tactical_view_zoom_in"):
			tactical_zoom_speed = 0
		elif Input.is_action_just_pressed("tactical_view_zoom_out"):
			tactical_zoom_speed = -TACTICAL_ZOOM_SPEED
		elif Input.is_action_just_released("tactical_view_zoom_out"):
			tactical_zoom_speed = 0
		var prev_transform = global_transform
		var m = process_tactical_camera_movement(tactical_zoom_speed)
		if not m.get_result():
			global_transform = prev_transform # revert anything
			var push_back_vector = m.get_push_back_vector()
			if push_back_vector:
				global_translate(push_back_vector)
		if m.get_point():
			var v = global_transform.origin - m.get_point()
			tactical_camera_distance = v.length()
		process_tactical_view_cursor(tactical_view_action)
		if tactical_view_action:
			tactical_view_action = false
		elif tactical_player_character:
			process_tactical_player_attack()
		if angle_x_reset:
			angle_rad_x = 0
			angle_x_reset = false
		if angle_y_reset:
			angle_rad_y = 0
			angle_y_reset = false
		return
	else:
		if backtrace_ray and backtrace_ray.enabled:
			backtrace_ray.enabled = false
		if projection_ray and projection_ray.enabled:
			projection_ray.enabled = false

	if not has_node(target_path):
		return
	var target_node = get_node(target_path)
	var target_xform = target_node.get_global_transform()
	if strict_following:
		set_global_transform(target_xform)
	else:
		# TODO: Fix delta calculation so it behaves correctly if the speed is set to 1.0.
		var translate_factor = translate_speed * delta * 10
		var rotate_factor = rotate_speed * delta * 10
		# Interpolate the origin and basis separately so we can have different translation and rotation
		# interpolation speeds.
		var local_transform_only_origin = Transform(Basis(), get_global_transform().origin)
		var local_transform_only_basis = Transform(get_global_transform().basis, Vector3())
		local_transform_only_origin = local_transform_only_origin.interpolate_with(target_xform, translate_factor)
		local_transform_only_basis = local_transform_only_basis.interpolate_with(target_xform, rotate_factor)
		set_global_transform(Transform(local_transform_only_basis.basis, local_transform_only_origin.origin))
	if target_node is Camera:
		var camera = target_node as Camera
		# The target node can be a Camera3D, which allows interpolating additional properties.
		# In this case, make sure the "Current" property is enabled on the InterpolatedCamera3D
		# and disabled on the Camera3D.
		if camera.projection == projection:
			# Interpolate the near and far clip plane distances.
			var near_far_factor = near_far_speed * delta * 10
			var fov_factor = fov_speed * delta * 10
			var new_near = lerp(near, camera.near, near_far_factor) as float
			var new_far = lerp(far, camera.far, near_far_factor) as float

			# Interpolate size or field of view.
			if camera.projection == Camera.PROJECTION_ORTHOGONAL:
				var new_size := lerp(size, camera.size, fov_factor) as float
				set_orthogonal(new_size, new_near, new_far)
			else:
				var new_fov := lerp(fov, camera.fov, fov_factor) as float
				set_perspective(new_fov, new_near, new_far)

func convert_mouse_event(event : InputEventMouse):
	var mouseEvent = event.duplicate()
	var viewport_size = __PLDRT.game_state.get_viewport().size
	var root_viewport_size = get_node("/root").size
	mouseEvent.position.x = (viewport_size.x / root_viewport_size.x) * event.global_position.x
	mouseEvent.position.y = (viewport_size.y / root_viewport_size.y) * event.global_position.y
	return mouseEvent

func _input(event):
	if get_tree().paused \
		or __PLDRT.conversation_manager.conversation_is_in_progress():
		return
	var player = __PLDRT.game_state.get_player()
	if player and player.is_hidden():
		return
	for dlg in get_tree().get_nodes_in_group("game_dialogs"):
		if dlg.is_visible():
			return
	if __PLDRT.game_state.is_tactical_view():
		if event is InputEventMouse:
			var pln = project_local_ray_normal(convert_mouse_event(event).position)
			projection_ray.cast_to = TACTICAL_CAMERA_PROJECTION_LENGTH * pln
		if (
			event is InputEventMouseButton
			and event.pressed
			and event.button_index == BUTTON_LEFT
		):
			tactical_view_double_click = event.doubleclick
			if use_point:
				tactical_view_action = true
		
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
		
		if event.is_action_pressed("tactical_view_rotation"):
			tactical_view_rotation = true
		elif event.is_action_released("tactical_view_rotation"):
			tactical_view_rotation = false
		if event is InputEventMouseMotion:
			if tactical_view_rotation:
				angle_rad_x = deg2rad(event.relative.y * __PLDRT.settings.get_sensitivity() * __PLDRT.settings.get_yaxis_coeff())
				angle_rad_y = deg2rad(event.relative.x * __PLDRT.settings.get_sensitivity() * -1)
				angle_x_reset = true
				angle_y_reset = true
			elif (
				not (
					Input.is_action_pressed("movement_forward")
					or Input.is_action_pressed("movement_backward")
					or Input.is_action_pressed("movement_left")
					or Input.is_action_pressed("movement_right")
				)
			):
				input_movement_vector.x = 0
				input_movement_vector.y = 0
				var viewport = __PLDRT.game_state.get_viewport()
				var pos = viewport.get_mouse_position()
				if pos.x < TACTICAL_MOVEMENT_THRESHOLD:
					input_movement_vector.x = -1
				if pos.y < TACTICAL_MOVEMENT_THRESHOLD:
					input_movement_vector.y = 1
				if pos.x > viewport.size.x - TACTICAL_MOVEMENT_THRESHOLD:
					input_movement_vector.x = 1
				if pos.y > viewport.size.y - TACTICAL_MOVEMENT_THRESHOLD:
					input_movement_vector.y = -1
		
		if (
			tactical_player_character
			and (
				event.is_action_pressed("crouch")
				or event.is_action_released("crouch")
			)
		):
			tactical_player_character.toggle_crouch()
	
	if (
		item_preview
		and not tactical_view_rotation
		and event.is_action_pressed("item_preview_toggle")
	):
		if item_preview.is_opened():
			return
		var hud = __PLDRT.game_state.get_hud()
		if not hud:
			return
		if hud.is_in_conversation():
			return 
		var item = hud.get_active_item()
		if not item:
			return
		item_preview.open_preview(item)
	elif (
		use_point
		and not tactical_view_action
		and item_use and event.is_action_pressed("action")
	):
		use_point.action(player, self)
		item_use.action(player, self)
		get_tree().set_input_as_handled()
