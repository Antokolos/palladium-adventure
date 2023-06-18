extends PLDPathfinder
class_name PLDCharacter

signal party_joined(character)
signal party_left(character)
signal player_changed(player_new, player_prev)
signal visibility_to_player_changed(player_node, previous_state, new_state)
signal patrolling_changed(player_node, previous_state, new_state)
signal aggressive_changed(player_node, previous_state, new_state)
signal morale_changed(player_node, previous_value, new_value)
signal crouching_changed(player_node, previous_state, new_state)
signal sprinting_changed(player_node, previous_state, new_state)
signal floor_collision_changed(player_node, previous_state, new_state)
signal attack_started(player_node, target, attack_anim_idx)
signal attack_stopped(player_node, target, attack_anim_idx)
signal attack_finished(player_node, target, previous_target, attack_anim_idx)
signal stun_started(player_node, weapon)
signal stun_finished(player_node, prematurely)
signal take_damage(player_node, fatal, hit_direction_node, hit_dir_vec)
signal teleport_tween_started(player_node, origin)

const TELEPORT_TWEEN_DURATION_S = 5
const TELEPORT_TWEEN_ELEVATION_MAX = 3
const BITMASK_WATERWAYS : int = 4 # Bit 2, value 4
const SNAP_LENGTH = 0.2
const GRAVITY_FALLING = 10.2
const GRAVITY_DEFAULT = 0.3  # Very small, to prevent sliding from slopes
const GRAVITY_UNDERWATER = 0.2
const MAX_SPEED = 3
const MAX_SPRINT_SPEED = 10
const JUMP_SPEED = 4.5
const DIVE_SPEED = 0.2
const BOB_UP_SPEED = 1.5
const ACCEL= 1.5
const DEACCEL= 16
const SPRINT_ACCEL = 4.5
const MIN_MOVEMENT = 0.01
const SPRINTING_DISTANCE_THRESHOLD = 10
const INJURY_RATE = 20

const PUSH_STRENGTH = 10
const PUSH_BACK_STRENGTH = 30
const NONCHAR_PUSH_STRENGTH = 2

const YROT_LADDER_MIN_DEG = -33
const YROT_LADDER_MAX_DEG = 33
const MAX_SLOPE_ANGLE_RAD = deg2rad(70)
const AXIS_VALUE_THRESHOLD = 0.15

const USE_RAYS_ONLY_FOR_PARTY_MEMBERS = true
const USE_AVOIDANCE = false
const COLLISION_LAYER_DEFAULT = 0
const COLLISION_LAYER_WALLS = 1
const COLLISION_LAYER_FLOOR = 2
const COLLISION_LAYER_INTERACTIVE = 3
const COLLISION_LAYER_PLAYER = 11
const COLLISION_LAYER_ENEMY = 12
const COLLISION_LAYER_OBSTACLES = 13
const BACKTRACE_RATIO = 0.9
const FIRST_PERSON_CAMERA_PATH = "Rotation_Helper/FirstPersonCamera"
const THIRD_PERSON_CAMERA_PATH = "Rotation_HelperX/Rotation_HelperY/ThirdPersonCamera"
const TRANSLATOR_NODE_PATH = "Rotation_Helper/FirstPersonCamera/TranslatorNode"

export(bool) var has_ranged_attack : bool = false
export(bool) var has_melee_attack : bool = false
export(float) var attack_speed : float = 0.7
export(bool) var can_hide : bool = true
export(bool) var can_read : bool = false
export(bool) var auto_sit_down : bool = false

onready var character_nodes = $character_nodes
onready var animation_player = $AnimationPlayer
onready var first_person_camera = get_node(FIRST_PERSON_CAMERA_PATH) if has_node(FIRST_PERSON_CAMERA_PATH) else null
onready var third_person_camera = get_node(THIRD_PERSON_CAMERA_PATH) if has_node(THIRD_PERSON_CAMERA_PATH) else null
onready var third_person_collision_pos = third_person_camera.get_node("CameraCollisionPos") if third_person_camera and third_person_camera.has_node("CameraCollisionPos") else null
onready var backtrace_ray = third_person_camera.get_node("BacktraceRay") if third_person_camera and third_person_camera.has_node("BacktraceRay") else null
onready var translator_node = get_node(TRANSLATOR_NODE_PATH) if has_node(TRANSLATOR_NODE_PATH) else null
onready var selection_mark = get_node("selection_mark") if has_node("selection_mark") else null
onready var teleport_tween = get_node("TeleportTween") if has_node("TeleportTween") else null

var vel = Vector3()

var is_transporting = false setget set_transporting, is_transporting
var is_hidden = false
var hideout_path : String = ""
var too_late_to_unhide = false setget set_too_late_to_unhide, is_too_late_to_unhide
var is_patrolling = false setget set_patrolling
var is_aggressive = false setget set_aggressive
var is_crouching = false
var is_sprinting = false
var is_underwater = false  # is_underwater flag is not stored in the save file
var is_air_pocket = false  # is_air_pocket flag is not stored in the save file
var is_on_ladder = false setget set_on_ladder, is_on_ladder
var ladder_rotation_deg = 0 setget set_ladder_rotation_deg, get_ladder_rotation_deg
var ladder_ymin = 0 setget set_ladder_ymin, get_ladder_ymin
var ladder_ymax = 0 setget set_ladder_ymax, get_ladder_ymax
var is_poisoned = false
# player_type is like a class in RPG: Warrior, Cleric, Thief, Mage etc
# it can be used to determine player traits based on its class
# corresponding integer constants can be placed in PLDDB
var player_type : int = 0 setget set_player_type, get_player_type
var intoxication : int = 0
var relationship : int = 0
var morale : int = 0 setget set_morale
var stuns_count : int = 0
var has_floor_collision = true
var force_physics = false
var force_no_physics = false
var force_visibility = false
var last_attack_target = null
var last_attack_anim_idx = -1
var model_to_restore = null

func _ready():
	__PLDRT.game_state.connect("player_underwater", self, "_on_player_underwater")
	__PLDRT.game_state.connect("player_poisoned", self, "_on_player_poisoned")
	__PLDRT.game_state.connect("player_registered", self, "_on_player_registered")
	__PLDRT.game_state.register_player(self)

func get_gravity():
	return (
		GRAVITY_UNDERWATER
		if is_underwater
		else (
			GRAVITY_DEFAULT
			if has_floor_collision()
			else GRAVITY_FALLING
		)
	)

func set_sound_walk(mode):
	character_nodes.set_sound_walk(mode)

func set_sound_angry(mode):
	character_nodes.set_sound_angry(mode)

func set_sound_pain(mode):
	character_nodes.set_sound_pain(mode)

func set_sound_attack(mode):
	character_nodes.set_sound_attack(mode)

func set_sound_miss(mode):
	character_nodes.set_sound_miss(mode)

func has_ranged_attack():
	return has_ranged_attack

func has_melee_attack():
	return has_melee_attack

func can_hide():
	return can_hide

func can_read():
	return can_read

func get_possible_attack_target(update_collisions):
	return character_nodes.get_possible_attack_target(update_collisions)

func handle_attack():
	var possible_target = get_possible_attack_target(false)
	if not possible_target:
		stop_attack()
		return
	var aggression_target = get_aggression_target()
	if not aggression_target:
		stop_attack()
		return
	if possible_target.get_instance_id() != aggression_target.get_instance_id():
		stop_attack()
		return
	attack_start(possible_target)

func attack_start(possible_attack_target, attack_anim_idx = -1, with_anim = true, immediately = false):
	if character_nodes.is_attacking():
		return
	set_sprinting(false)
	last_attack_target = possible_attack_target
	set_point_of_interest(possible_attack_target)
	last_attack_anim_idx = attack_anim_idx
	var model = get_model()
	if model:
		if with_anim and not model.is_attacking():
			last_attack_anim_idx = model.attack(attack_anim_idx)
	else:
		push_warning("Model not set")
	character_nodes.attack_start(immediately)
	emit_signal("attack_started", self, possible_attack_target, last_attack_anim_idx)

func stop_attack():
	if not is_attacking():
		return
	stop_cutscene()
	character_nodes.stop_attack()
	emit_signal("attack_stopped", self, last_attack_target, last_attack_anim_idx)
	clear_point_of_interest()
	clear_last_attack_data()

func clear_last_attack_data():
	last_attack_target = null
	last_attack_anim_idx = -1

func get_last_attack_data():
	return {
		"target" : last_attack_target,
		"anim_idx" : last_attack_anim_idx,
		"injury_rate" : get_attack_injury_rate(),
		"poison_rate" : get_attack_poison_rate()
	}

func get_attack_speed():
	return attack_speed

func get_attack_injury_rate():
	return INJURY_RATE

func get_attack_poison_rate():
	return 0

func is_attacking():
	var model = get_model()
	if not model:
		push_warning("Model not set")
	return character_nodes.is_attacking() or (model and model.is_attacking())

func hit(injury_rate, poison_rate = 0, hit_direction_node = null, hit_dir_vec = Z_DIR):
	if not is_activated():
		return
	if poison_rate > 0:
		__PLDRT.game_state.set_poisoned(self, true, poison_rate)
	character_nodes.play_pain_sound()

func miss(hit_direction_node = null, hit_dir_vec = Z_DIR):
	pass

func take_damage(fatal, hit_direction_node = null, hit_dir_vec = Z_DIR):
	if not is_activated() or is_dying():
		return
	emit_signal("take_damage", self, fatal, hit_direction_node, hit_dir_vec)
	stop_cutscene()
	var model = get_model()
	if model:
		model.take_damage(fatal)
	else:
		push_warning("Model not set")
	push_back(get_push_vec(hit_direction_node, hit_dir_vec))

func kill_on_load():
	var model = get_model()
	if model:
		model.kill_on_load()
	else:
		push_warning("Model not set")

func kill():
	if is_player_controlled():
		__PLDRT.game_state.game_over()
		return
	var model = get_model()
	if model:
		model.kill()
	else:
		push_warning("Model not set")

func need_to_set_look_transition():
	return (
		__PLDRT.conversation_manager.meeting_is_in_progress(
			name_hint,
			PLDChars.PLAYER_NAME_HINT
		) \
		or __PLDRT.conversation_manager.meeting_is_finished(
			name_hint,
			PLDChars.PLAYER_NAME_HINT
		)
	)

func set_look_transition_if_needed():
	if not need_to_set_look_transition():
		return
	var model = get_model()
	if not model:
		push_warning("Model not set")
		return
	model.set_look_transition(
		PLDCharacterModel.LOOK_TRANSITION_SQUATTING
			if is_crouching
			else PLDCharacterModel.LOOK_TRANSITION_STANDING
	)

func enable_collisions_and_interaction(enable, all_shapes = false):
#	if has_node("UpperBody_CollisionShape"):
#		$UpperBody_CollisionShape.disabled = not enable
#	$Body_CollisionShape.disabled = not enable
# Also we should toggle all additional collision shapes
	for ch in get_children():
		if ch is CollisionShape:
			ch.disabled = not enable
	character_nodes.enable_areas_and_raycasts(enable)
	# Feet collision is always enabled to prevent falling through floor, unless all_shapes is true
	$Feet_CollisionShape.disabled = all_shapes and not enable
	if is_transportable():
		# Transport collisions are enabled when all others are disabled
		$Transport_CollisionShape1.disabled = enable
		$Transport_CollisionShape2.disabled = enable
	set_collision_mask_bit(COLLISION_LAYER_DEFAULT, enable)
	set_collision_mask_bit(COLLISION_LAYER_WALLS, enable)
#		set_collision_mask_bit(COLLISION_LAYER_FLOOR, enable) -- always has floor collision
	set_collision_mask_bit(COLLISION_LAYER_INTERACTIVE, enable)
	set_collision_mask_bit(COLLISION_LAYER_PLAYER, enable)
	set_collision_mask_bit(COLLISION_LAYER_ENEMY, enable)
	set_collision_mask_bit(COLLISION_LAYER_OBSTACLES, enable)
	set_collision_layer_bit(COLLISION_LAYER_INTERACTIVE, not enable)

func enable_selection_mark(enable):
	if selection_mark:
		selection_mark.visible = enable

func enable_waterways_navigation(enable):
	var navigation_agent = get_node("NavigationAgent") if has_node("NavigationAgent") else null
	if navigation_agent:
		var nl = navigation_agent.get_navigation_layers()
		navigation_agent.set_navigation_layers(
			nl | BITMASK_WATERWAYS if enable else nl & ~BITMASK_WATERWAYS
		)

func waterway_enter(changed_model = null):
	character_nodes.set_sound_walk(__PLDRT.CHARS.SoundId.SOUND_WALK_SWIM, false)
	if changed_model:
		model_to_restore = replace_model(changed_model)
		model_to_restore.visible = false

func waterway_exit(and_disable_navigation : bool):
	if model_to_restore:
		model_to_restore.visible = true
		var em = replace_model(model_to_restore)
		if em:
			em.queue_free()
		model_to_restore = null
	character_nodes.restore_sound_walk_from(__PLDRT.CHARS.SoundId.SOUND_WALK_SWIM)
	if and_disable_navigation:
		enable_waterways_navigation(false)

### Use target ###

func use(player_node, camera_node):
	if not is_activated():
		if is_transportable():
			var was_transporting = is_transporting
			is_transporting = not is_transporting
			var player = __PLDRT.game_state.get_player()
			var cam = __PLDRT.game_state.get_cam()
			var m = get_model()
			if not m:
				push_warning("Model not set")
			if not was_transporting and is_transporting:
				if cam:
					cam.activate_transporting()
				if m:
					m.set_meshes_portal_mode(m, CullInstance.PORTAL_MODE_GLOBAL, true)
			elif was_transporting and not is_transporting:
				if m:
					m.set_meshes_portal_mode(m, CullInstance.PORTAL_MODE_ROAMING, false)
				if cam:
					cam.deactivate_transporting()
				set_scale(Vector3(1.0, 1.0, 1.0))
				rotation_degrees.z = 0
				var ufy = character_nodes.get_under_feet_y()
				if ufy:
					global_translation.y = ufy
				elif player:
					global_translation.y = player.global_translation.y
			return true
		return false
	var hud = __PLDRT.game_state.get_hud()
	if hud and hud.get_active_item():
		var item = hud.get_active_item()
		if not item_is_weapon(item):
			return false
		hud.inventory.visible = false
		item.used(player_node, self)
		character_nodes.use_weapon(item)
		return true
	return false

func item_is_weapon(item):
	if not item:
		return false
	return item.is_weapon()

func can_be_given(item):
	if not item:
		return false
	return item.can_be_given()

func get_usage_code(player_node):
	if not is_activated():
		if is_transportable():
			return "ACTION_TRANSPORT" if not is_transporting else "ACTION_DROP"
		return .get_usage_code(player_node)
	var hud = __PLDRT.game_state.get_hud()
	if hud and hud.get_active_item():
		var item = hud.get_active_item()
		if item_is_weapon(item):
			return "ACTION_ATTACK"
		if can_be_given(item) and __PLDRT.conversation_manager.meeting_is_finished(player_node.get_name_hint(), get_name_hint()):
			return "ACTION_GIVE"
	return .get_usage_code(player_node)

### Getting character's parts ###

func get_translator_node():
	return translator_node

func get_cam_holder_path():
	return get_cam_holder().get_path()

func get_cam_holder():
	return (
		first_person_camera
			if __PLDRT.settings.get_camera_view() == PLDDB.CAMERA_VIEW_FIRST_PERSON
			else third_person_collision_pos
	)

func replace_model(model):
	character_nodes.replace_model(model)
	return .replace_model(model)

### States ###

func become_player():
	if not is_activated():
		activate()
	if not is_in_party():
		join_party()
	var model = get_model()
	if model:
		model.set_simple_mode(
			__PLDRT.settings.get_camera_view() == PLDDB.CAMERA_VIEW_FIRST_PERSON
		)
	else:
		push_warning("Model not set")
	var player = __PLDRT.game_state.get_player()
	var cam = __PLDRT.game_state.get_cam()
	deactivate()
	if not player or is_player():
		if cam:
			cam.set_target_path(get_cam_holder_path())
			cam.rebuild_exceptions(self)
	else:
		player.deactivate()
		if cam:
			cam.set_target_path(get_cam_holder_path())
			cam.rebuild_exceptions(self)
		if __PLDRT.cutscene_manager.is_cutscene():
			__PLDRT.cutscene_manager.stop_cutscene(self)
		var player_model = player.get_model()
		if player_model:
			player_model.set_simple_mode(false)
		else:
			push_warning("Model not set")
		player.activate()
	__PLDRT.game_state.set_player_name_hint(get_name_hint())
	__PLDRT.game_state.set_poisoned(self, is_poisoned(), get_intoxication())
	activate()
	emit_signal("player_changed", self, player)

func join_party(and_clear_target_node = true):
	.join_party(and_clear_target_node)
	set_sprinting(false)
	emit_signal("party_joined", self)

func leave_party(new_target_node = null, and_teleport_to_target = false):
	.leave_party(new_target_node, and_teleport_to_target)
	emit_signal("party_left", self)

func is_underwater():
	return is_underwater

func need_breathe_in():
	var oxygen_current = __PLDRT.game_state.party_stats[name_hint]["oxygen_current"]
	var oxygen_max = __PLDRT.game_state.party_stats[name_hint]["oxygen_max"]
	return oxygen_current < oxygen_max * 0.9

func breathe_in():
	var sound_id
	__PLDRT.MEDIA.play_sound(PLDDBMedia.SoundId.SPLASH_IN)
	if __PLDRT.game_state.player_name_is(__PLDRT.CHARS.FEMALE_NAME_HINT):
		sound_id = PLDDBMedia.SoundId.WOMAN_BREATHE_IN_1 if randf() > 0.5 else PLDDBMedia.SoundId.WOMAN_BREATHE_IN_2
	else:
		sound_id = PLDDBMedia.SoundId.MAN_BREATHE_IN_1 if randf() > 0.5 else PLDDBMedia.SoundId.MAN_BREATHE_IN_2
	__PLDRT.MEDIA.play_sound(sound_id)

func set_underwater(enable, and_emit_signal = true):
	if is_underwater \
		and not enable \
		and need_breathe_in():
		breathe_in()
	is_underwater = enable
	if and_emit_signal and is_player():
		__PLDRT.game_state.set_underwater(self, enable)
	if not enable:
		is_air_pocket = false
	elif __PLDRT.conversation_manager.conversation_is_in_progress():
		__PLDRT.conversation_manager.stop_conversation(__PLDRT.game_state.get_player())
	vel.y = -DIVE_SPEED if enable or vel.y <= 0.0 else BOB_UP_SPEED
	character_nodes.set_underwater(enable)

func _on_player_underwater(player, enable):
	if player and not equals(player):
		return
	set_underwater(enable, false)

func is_air_pocket():
	return is_air_pocket

func set_air_pocket(enable):
	is_air_pocket = enable

func is_on_ladder():
	return is_on_ladder

func set_on_ladder(enable):
	is_on_ladder = enable

func get_ladder_rotation_deg():
	return ladder_rotation_deg

func set_ladder_rotation_deg(angle_deg):
	ladder_rotation_deg = angle_deg

func get_ladder_ymin():
	return ladder_ymin

func set_ladder_ymin(ymin):
	ladder_ymin = ymin

func get_ladder_ymax():
	return ladder_ymax

func set_ladder_ymax(ymax):
	ladder_ymax = ymax

func is_poisoned():
	return is_poisoned

func set_poisoned(enable):
	is_poisoned = enable

func get_player_type() -> int:
	return player_type

func set_player_type(type : int):
	player_type = type

func get_intoxication() -> int:
	return intoxication

func set_intoxication(intoxication : int):
	self.intoxication = intoxication

func _on_player_poisoned(player, enable, intoxication_rate):
	if player and not equals(player):
		return
	set_poisoned(enable)
	set_intoxication(intoxication_rate)

func _on_player_registered(player):
	if not player:
		push_error("Player not set")
		return
	player.connect("aggressive_changed", self, "_on_aggressive_changed")
	player.connect("morale_changed", self, "_on_morale_changed")
	var model = player.get_model()
	if model:
		model.connect("character_dead", self, "_on_character_dead")
		model.connect("character_dying", self, "_on_character_dying")
	else:
		push_warning("Model not set")

func _on_aggressive_changed(player_node, previous_state, new_state):
	if new_state:
		return
	if equals(player_node) and get_point_of_interest():
		clear_point_of_interest()
	else:
		clear_poi_if_it_is(player_node)

func _on_morale_changed(player_node, previous_value, new_value):
	pass

func _on_character_dead(player):
	if equals(player):
		stop_attack()
		enable_collisions_and_interaction(false)
	clear_poi_if_it_is(player)
	._on_character_dead(player)

func _on_character_dying(player):
	invoke_physics_pass()
	._on_character_dying(player)

func activate():
	.activate()
	navigation_agent.avoidance_enabled = USE_AVOIDANCE and is_in_party()
	var model = get_model()
	if model:
		model.activate()
	else:
		push_warning("Model not set")
	# enable_rays_to_characters(true) -- rays will be enabled in do_process() if needed

func deactivate():
	.deactivate()
	navigation_agent.avoidance_enabled = false
	disable_rays_to_characters()

func is_visible_to_player():
	return character_nodes.is_visible_to_player() or is_player_controlled()

func is_transporting():
	return is_transporting

func set_transporting(transporting):
	is_transporting = transporting

func is_hidden():
	return is_hidden

func set_hidden(enable, hideout_path_str : String = ""):
	if is_hidden and not enable:
		enable_collisions_and_interaction(true)
		is_hidden = false
		hideout_path = hideout_path_str
	elif not is_hidden and enable:
		is_hidden = true
		hideout_path = hideout_path_str
		enable_collisions_and_interaction(false)
	else:
		return
	visible = not enable
	var is_player = is_player()
	if is_player:
		var companions = __PLDRT.game_state.get_companions()
		for companion in companions:
			companion.set_hidden(enable, hideout_path_str)

func get_hideout_path():
	return hideout_path

func has_hideout():
	return hideout_path and not hideout_path.empty() and has_node(hideout_path)

func get_hideout():
	return get_node(hideout_path) if has_hideout() else null

func set_too_late_to_unhide(is_too_late):
	too_late_to_unhide = is_too_late

func is_too_late_to_unhide():
	return too_late_to_unhide

func is_patrolling():
	return is_patrolling

func set_patrolling(enable):
	var is_patrolling_prev = is_patrolling
	is_patrolling = enable
	if is_patrolling_prev != is_patrolling:
		emit_signal("patrolling_changed", self, is_patrolling_prev, is_patrolling)
	if enable:
		set_aggressive(false)

func is_aggressive():
	return is_aggressive

func set_aggressive(enable):
	var is_aggressive_prev = is_aggressive
	is_aggressive = enable
	if is_aggressive_prev != is_aggressive:
		if is_aggressive:
			character_nodes.play_angry_sound()
		emit_signal("aggressive_changed", self, is_aggressive_prev, is_aggressive)
	if enable:
		set_patrolling(false)

func get_nearest_character(party_members_only = false):
	var characters = __PLDRT.game_state.get_characters()
	var tgt = null
	var dist_squared_min
	var origin = get_global_transform().origin
	for ch in characters:
		if equals(ch):
			continue
		if not ch.is_activated():
			continue
		if ch.is_dying():
			continue
		if party_members_only and not ch.is_in_party():
			continue
		var dist_squared_cur = origin.distance_squared_to(ch.get_global_transform().origin)
		if not tgt:
			tgt = ch
			dist_squared_min = dist_squared_cur
			continue
		if dist_squared_cur < dist_squared_min:
			dist_squared_min = dist_squared_cur
			tgt = ch
	return tgt

func get_aggression_target():
	return get_nearest_character(true)

func set_target_node(node, update_navpath = true, force_no_sprinting = false):
	var result = .set_target_node(node, update_navpath)
	if not result:
		return false
	if not node or is_player_controlled():
		return result
	if force_no_sprinting:
		set_sprinting(false)
		return result
	if not is_in_party() and get_morale() >= 0:
		set_sprinting(false)
		return result
	var cp = get_global_transform().origin
	var tp = node.get_global_transform().origin
	var d = cp.distance_to(tp)
	set_sprinting(d > SPRINTING_DISTANCE_THRESHOLD)
	if d <= ALIGNMENT_RANGE:
		emit_signal("arrived_to", [ node ])
	return result

func sit_down_change_collisions():
	if animation_player.is_playing():
		return false
	animation_player.play("crouch")
	return true

func sit_down():
	if not sit_down_change_collisions():
		return
	var model = get_model()
	if model:
		model.sit_down()
	else:
		push_warning("Model not set")
	var is_player = is_player()
	if is_player:
		var companions = __PLDRT.game_state.get_companions()
		for companion in companions:
			companion.sit_down()
	if is_sprinting:
		emit_signal("sprinting_changed", self, false, is_sprinting)
	is_sprinting = false
	is_crouching = true
	emit_signal("crouching_changed", self, false, true)

func stand_up_change_collisions():
	if character_nodes.is_low_ceiling():
		# I.e. if the player is crouching and something is above the head, do not allow to stand up.
		return false
	if animation_player.is_playing():
		return false
	animation_player.play_backwards("crouch")
	return true

func stand_up():
	if not stand_up_change_collisions():
		return
	var model = get_model()
	if model:
		model.stand_up()
	else:
		push_warning("Model not set")
	var is_player = is_player()
	if is_player:
		var companions = __PLDRT.game_state.get_companions()
		for companion in companions:
			companion.stand_up()
	is_crouching = false
	emit_signal("crouching_changed", self, true, false)

func is_crouching():
	return is_crouching

func toggle_crouch():
	stand_up() if is_crouching else sit_down()

func set_crouching(enable):
	if enable and not is_crouching:
		sit_down()
	elif not enable and is_crouching:
		stand_up()

func get_possible_attacker():
	return null

func can_run():
	return true

func is_sprinting():
	return is_sprinting

func set_sprinting(enable):
	if enable and not can_run():
		return
	if is_sprinting != enable:
		emit_signal("sprinting_changed", self, enable, is_sprinting)
	is_sprinting = enable
	var is_player = is_player()
	if is_player:
		var companions = __PLDRT.game_state.get_companions()
		for companion in companions:
			companion.set_sprinting(enable)

func get_relationship() -> int:
	return relationship

func set_relationship(relationship : int):
	self.relationship = relationship

func get_morale() -> int:
	return morale

func set_morale(morale_new : int):
	var morale_prev = morale
	morale = morale_new
	if morale_prev != morale:
		emit_signal("morale_changed", self, morale_prev, morale)

func is_stunned():
	return character_nodes.is_stunned()

func is_transportable():
	return has_node("Transport_CollisionShape1") or has_node("Transport_CollisionShape2")

func stun_stop():
	return character_nodes.stun_stop(true)

func get_stuns_count() -> int:
	return stuns_count

func set_stuns_count(stuns_count : int):
	self.stuns_count = stuns_count

func inc_stuns_count():
	stuns_count = stuns_count + 1

### Player/target following ###

func reset_movement():
	.reset_movement()
	vel.x = 0
	vel.y = 0
	vel.z = 0
	set_sprinting(false)

func reset_rotation():
	.reset_rotation()
	get_model_holder().set_rotation_degrees(Vector3(0, 0, 0))

func process_rotation(need_to_update_collisions):
	if angle_rad_y == 0 or is_dying():
		return { "rotate_y" : false }
	self.rotate_y(angle_rad_y)
	if is_on_ladder:
		var rot = self.rotation_degrees
		rot.y = clamp(rot.y, ladder_rotation_deg + YROT_LADDER_MIN_DEG, ladder_rotation_deg + YROT_LADDER_MAX_DEG)
		self.rotation_degrees = rot
	if angle_y_reset:
		angle_rad_y = 0
		angle_y_reset = false
	return { "rotate_y" : true }

func invoke_physics_pass():
	set_has_floor_collision(false)
	var v = Vector3()
	v.y = -get_gravity()
	move_and_slide(
		v,
		Vector3.UP,
		true,
		4,
		MAX_SLOPE_ANGLE_RAD,
		is_in_party()
	)

func get_snap():
	if character_nodes.has_floor_collision():
		return -character_nodes.get_floor_normal() * SNAP_LENGTH
	else:
		return Vector3.ZERO

func is_need_to_use_physics(characters):
	if force_physics:
		return true
	if force_no_physics:
		return false
	if is_on_ladder:
		return false
	if is_teleport_tween_active():
		return false
	if is_player_controlled() or not character_nodes.has_floor_collision():
		return true
	if has_path():
		return false
	if not has_floor_collision():
		return true
	if not is_visible_to_player():
		return false
	for character in characters:
		if equals(character):
			continue
		if get_distance_to_character(character) < POINT_BLANK_RANGE:
			return true
	return false

func has_horz_movement(v):
	return (
		v.x >= MIN_MOVEMENT \
			or v.x <= -MIN_MOVEMENT \
			or v.z <= -MIN_MOVEMENT \
			or v.z >= MIN_MOVEMENT
	)

func has_vert_movement(v, fc):
	return (
		v.y >= MIN_MOVEMENT
		or (is_on_ladder and v.y <= -MIN_MOVEMENT)
		or (not is_air_pocket and not is_on_ladder and not fc)
	)

func has_movement(v, fc):
	return has_horz_movement(v) or has_vert_movement(v, fc)

func move_without_physics(hvel, fc, delta):
	if has_movement(hvel, fc):
		global_translate(hvel * delta)
	return hvel

func get_max_speed():
	return MAX_SPEED

func get_max_sprint_speed():
	return MAX_SPRINT_SPEED

func get_collider_collision_layer_bit(collider, bit : int):
	if collider is CollisionObject:
		return collider.get_collision_layer_bit(bit)
	if "collision_layer" in collider:
		var cl = collider.collision_layer
		var b = 1 << bit
		return cl & b != 0
	return false

func process_movement(delta, dir, characters):
	var target = Vector3.ZERO if is_movement_disabled() else dir
	var is_need_to_use_physics = is_need_to_use_physics(characters)
	if is_need_to_use_physics:
		target.y = 0
	target = target.normalized()

	if is_on_ladder:
		var current_transform = get_global_transform()
		var ynew = current_transform.origin.y + target.y
		if ynew < ladder_ymin or ynew > ladder_ymax:
			vel.y = 0
			target.y = 0
		else:
			vel.y += target.y
	elif is_air_pocket:
		vel.y = 0
		target.y = 0
	else:
		vel.y -= delta * get_gravity()

	if is_sprinting:
		target *= get_max_sprint_speed()
	else:
		target *= get_max_speed()

	var hvel = vel
	hvel.y = 0 if is_need_to_use_physics else target.y
	
	var accel
	if dir.dot(hvel) > 0:
		if is_sprinting:
			accel = SPRINT_ACCEL
		else:
			accel = ACCEL
	else:
		accel = DEACCEL

	hvel = hvel.linear_interpolate(target, accel * delta)
	vel.x = hvel.x
	vel.z = hvel.z
	
	if is_need_to_use_physics:
		if force_physics or has_movement(vel, has_floor_collision()):
			if is_player_controlled():
				vel = move_and_slide_with_snap(
					vel,
					get_snap(),
					Vector3.UP,
					true,
					4,
					MAX_SLOPE_ANGLE_RAD,
					is_in_party()
				)
			else:
				if navigation_agent.avoidance_enabled:
					navigation_agent.set_velocity(vel)
				else:
					vel = do_movement(vel, characters, delta)
	else:
		var fc = has_floor_collision()
		if has_movement(hvel, fc):
			if navigation_agent.avoidance_enabled:
				navigation_agent.set_velocity(hvel)
			else:
				vel = do_movement(hvel, characters, delta)
		return { "vel" : hvel, "collides_floor" : fc }
	
	var sc = get_slide_count()
	var character_collisions = []
	var nonchar_collision = null
	var collides_floor = false
	for i in range(0, sc):
		var collision = get_slide_collision(i)
		var has_char_collision = false
		for character in characters:
			if collision.collider_id == character.get_instance_id():
				has_char_collision = true
				character_collisions.append(collision)
				break
		var is_floor_collision = (
			get_collider_collision_layer_bit(collision.collider, 2)
			and collision.normal
			and collision.normal.y > 0
		)
		collides_floor = collides_floor or is_floor_collision
		if (
			not has_char_collision
			and not is_floor_collision
		):
			nonchar_collision = collision
	for collision in character_collisions:
		var character = collision.collider
		if (
			not character.is_movement_disabled()
			and not character.is_player_controlled()
		):
			pass
			#character.vel = get_push_vec(-collision.normal) * PUSH_STRENGTH
			#character.vel.y = 0
			#if not is_player_controlled():
			#	vel = vel - character.vel
			#character.invoke_physics_pass()
	
	return { "vel" : vel, "collides_floor" : collides_floor }

func get_push_vec(direction_node, dir_vec = Z_DIR):
	if not direction_node:
		return Vector3.ZERO
	var dir_z = direction_node.get_global_transform().basis.xform(dir_vec)
	dir_z.y = 0
	return -dir_z.normalized() * PUSH_BACK_STRENGTH

func push_back(push_vec):
	vel = push_vec

func has_floor_collision():
	return has_floor_collision or is_on_floor()

func is_force_physics():
	return force_physics

func set_force_physics(force_physics):
	self.force_physics = force_physics

func is_force_no_physics():
	return force_no_physics

func set_force_no_physics(force_no_physics):
	self.force_no_physics = force_no_physics

func is_force_visibility():
	return force_visibility

func set_force_visibility(force_visibility):
	self.force_visibility = force_visibility

func can_jump():
	return has_floor_collision() or is_underwater()

func get_rays_to_characters_pos():
	return character_nodes.get_rays_to_characters_pos()

func add_ray_to_character(another_character):
	return character_nodes.add_ray_to_character(another_character)

func delete_ray_to_character(another_character):
	return character_nodes.delete_ray_to_character(another_character)

func update_ray_to_character(another_character, ray = null):
	return character_nodes.update_ray_to_character(another_character, ray)

func has_obstacles_between(another_character):
	return character_nodes.has_obstacles_between(another_character)

func disable_rays_to_characters():
	character_nodes.disable_rays_to_characters()

func set_has_floor_collision(fc):
	var fc_prev = has_floor_collision
	has_floor_collision = fc
	if fc_prev != fc:
		emit_signal(
			"floor_collision_changed",
			self,
			fc_prev,
			fc
		)
		if is_player():
			var characters = __PLDRT.game_state.get_characters()
			for character in characters:
				if equals(character):
					continue
				character.invoke_physics_pass()

func change_rest_state_to(rest_state_new):
	var was_changed = .change_rest_state_to(rest_state_new)
	if was_changed:
		# When the character started to move or stopped
		invoke_physics_pass()
	return was_changed

func update_rays_to_characters(characters):
	var player_is_crouching = false
	var poi = get_point_of_interest()
	if is_player_controlled():
		return { "poi" : poi, "player_is_crouching" : is_crouching() }
	for character in characters:
		if character.is_active_player():
			player_is_crouching = character.is_crouching()
		if equals(character):
			continue
		if (
			USE_RAYS_ONLY_FOR_PARTY_MEMBERS
			and (
				not is_in_party() and not character.is_in_party()
			)
		):
			delete_ray_to_character(character)
			continue
		var r = update_ray_to_character(character)
		if not r:
			r = add_ray_to_character(character)
		if not r or not r.enabled:
			if poi and clear_poi_if_it_is(character):
				poi = null
			continue
		var has_obstacles = has_obstacles_between(character)
		if poi and has_obstacles:
			if clear_poi_if_it_is(character):
				poi = null
		elif (
			not poi
			and not has_obstacles
			and is_in_party()
			and not is_player_controlled()
			and not character.is_dead()
			and character.is_aggressive()
		):
			set_point_of_interest(character)
			poi = character
	return { "poi" : poi, "player_is_crouching" : player_is_crouching }

func is_on_the_way_to_target():
	if is_teleport_tween_active():
		return true
	return .is_on_the_way_to_target()

func is_teleport_tween_active():
	return teleport_tween and teleport_tween.is_active()

func teleport_tween_translation(tween_point : Vector3):
	translation.x = tween_point.x
	var t = teleport_tween.tell()
	var w = 2 * t / TELEPORT_TWEEN_DURATION_S
	var a = 0
	if w <= 1.0:
		a = lerp(0.0, 1.0, w)
	elif w > 1.0:
		a = lerp(1.0, 0.0, w - 1.0)
	translation.y = tween_point.y + sqrt(abs(a)) * TELEPORT_TWEEN_ELEVATION_MAX
	translation.z = tween_point.z

func teleport_via_tween(origin, changed_model = null):
	if not teleport_tween or not origin:
		return
	var gt = get_global_transform()
	teleport_tween.interpolate_method(
		self,
		"teleport_tween_translation",
		gt.origin,
		origin,
		TELEPORT_TWEEN_DURATION_S,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT
	)
	var ra = gt.basis.z.signed_angle_to(origin - gt.origin, gt.basis.y)
	rotate_y(ra)
	enable_collisions_and_interaction(false, true)
	__PLDRT.game_state.set_saving_disabled(true)
	emit_signal("teleport_tween_started", self, origin)
	if changed_model:
		model_to_restore = replace_model(changed_model)
		model_to_restore.visible = false
	teleport_tween.start()

func _on_TeleportTween_tween_completed(object, key):
	if model_to_restore:
		model_to_restore.visible = true
		var em = replace_model(model_to_restore)
		if em:
			em.queue_free()
		model_to_restore = null
	enable_collisions_and_interaction(true, true)
	__PLDRT.game_state.set_saving_disabled(false)
	teleport_to_global_transform(global_transform)

func _on_NavigationAgent_velocity_computed(safe_velocity):
	var characters = __PLDRT.game_state.get_characters()
	vel = do_movement(safe_velocity, characters, 0.02)

func move_with_physics(v):
	if force_physics or has_movement(v, has_floor_collision()):
		return move_and_slide_with_snap(
			v,
			get_snap(),
			Vector3.UP,
			true,
			4,
			MAX_SLOPE_ANGLE_RAD,
			is_in_party()
		)
	else:
		return vel

func do_movement(safe_velocity, characters, delta):
	var is_need_to_use_physics = is_need_to_use_physics(characters)
	if is_need_to_use_physics:
		var v = Vector3(
			safe_velocity.x,
			0 if safe_velocity.y > 0 else safe_velocity.y,
			safe_velocity.z
		)
		return move_with_physics(v)
	else:
		return move_without_physics(safe_velocity, has_floor_collision(), delta)

func do_movement2(safe_velocity, characters, delta):
	var v = Vector3(
		safe_velocity.x,
		0 if safe_velocity.y > 0 else safe_velocity.y,
		safe_velocity.z
	)
	return move_with_physics(v)

func move_backtrace(target: Vector3):
	if not third_person_camera or not third_person_collision_pos:
		return
	var tpct = third_person_camera.get_global_transform()
	if backtrace_ray and backtrace_ray.enabled:
		backtrace_ray.set_global_transform(Transform(
			backtrace_ray.get_global_transform().basis,
			target
		))
		backtrace_ray.cast_to = backtrace_ray.to_local(tpct.origin)
		if backtrace_ray.is_colliding():
			var cp = backtrace_ray.get_collision_point()
			third_person_collision_pos.set_global_transform(Transform(
				third_person_collision_pos.get_global_transform().basis,
				cp * BACKTRACE_RATIO + target * (1 - BACKTRACE_RATIO)
			))
			return
	third_person_collision_pos.set_global_transform(tpct)

func do_process(delta, is_player):
	var cv = __PLDRT.settings.get_camera_view()
	var tv = __PLDRT.game_state.is_tactical_view()
	if (
		cv != PLDDB.CAMERA_VIEW_FIRST_PERSON
		and third_person_camera
		and (character_nodes or tv)
	):
		if backtrace_ray and not backtrace_ray.enabled:
			backtrace_ray.enabled = true
		var dp = (
			get_global_transform().origin
				if tv
				else character_nodes.get_damage_point()
		)
		third_person_camera.look_at(dp, Vector3.UP)
		move_backtrace(dp)
	elif backtrace_ray and backtrace_ray.enabled:
		backtrace_ray.enabled = false
	
	var has_floor_collision = has_floor_collision()
	var should_fall = (
		not is_air_pocket
		and not is_on_ladder
		and not character_nodes.has_floor_collision()
	)
	
	var model = get_model()
	if model:
		var animations_enabled = (
			force_visibility
			or should_fall
			or is_visible_to_player()
			or model.has_important_animations_now()
		)
		model.enable_animations(animations_enabled)
		if animations_enabled:
			model.do_advance(delta)
	
	var characters = __PLDRT.game_state.get_characters()
	var d = {
		"is_moving" : false,
		"is_rotating" : false,
		"cannot_move" : (
			is_transporting
			or not is_activated()
			or is_movement_disabled()
			or is_hidden()
			or is_dead()
		)
	}
	
	if d.cannot_move:
		reset_movement_and_rotation()
	else:
		var movement_data = get_movement_data(is_player)
		update_state(movement_data)
		var mpd = process_movement(delta, movement_data.get_dir(), characters)
		set_has_floor_collision(mpd.collides_floor and not should_fall)
		has_floor_collision = has_floor_collision() or not should_fall
		d.is_moving = has_movement(mpd.vel, has_floor_collision)
		model.rotate_head(movement_data.get_rotation_angle_to_target_deg())
	var rpd = process_rotation(
		not __PLDRT.game_state.is_tactical_view()
		and not d.is_moving
		and is_player
	)
	var urd = update_rays_to_characters(characters)
	if d.cannot_move:
		if is_transporting:
			var player = __PLDRT.game_state.get_player()
			if player:
				var translator_node = player.get_translator_node()
				var ty = translator_node.global_translation.y
				var t = translator_node.get_global_transform()
				set_global_transform(t)
				if player and player.global_translation.y > ty:
					global_translation.y = player.global_translation.y
		if is_transporting or not urd.poi:
			character_nodes.stop_walking_sound()
			return d
		model.rotate_head(0)
	d.is_rotating = rpd.rotate_y or (rpd.has("rotate_x") and rpd.rotate_x)
	if d.is_moving or rpd.rotate_y:
		if d.is_moving:
			is_air_pocket = false
		if has_floor_collision:
			character_nodes.play_walking_sound(is_sprinting)
		elif not character_nodes.has_floor_collision():
			character_nodes.stop_walking_sound()
	if has_floor_collision:
		if is_crouching \
			and not urd.player_is_crouching \
			and is_in_party() \
			and not character_nodes.is_low_ceiling():
			stand_up()
		elif auto_sit_down \
			and not is_crouching \
			and character_nodes.is_low_ceiling():
			sit_down()
	else:
		character_nodes.stop_rest_timer()
		if should_fall:
			model.fall()
	if not has_floor_collision:
		return d
	elif d.is_moving or rpd.rotate_y:
		character_nodes.stop_rest_timer()
		model.walk(is_crouching, is_sprinting)
	else:
		character_nodes.start_rest_timer()
	return d
