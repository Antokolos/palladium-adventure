extends Spatial
class_name PLDCharacterNodes

const RAY_ROT_MIN_DEG = -88
const RAY_ROT_MAX_DEG = 88
const FRIENDLY_FIRE_ENABLED = false
const OXYGEN_DECREASE_RATE = 5
const DEBUG_RAYS = false

onready var character = get_parent()

onready var oxygen_timer = $OxygenTimer
onready var poison_timer = $PoisonTimer
onready var stun_timer = $StunTimer
onready var attack_timer = $AttackTimer
onready var rest_timer = $RestTimer

onready var melee_attack_area = $MeleeAttackArea
onready var melee_damage_area = $MeleeDamageArea
onready var ranged_damage_raycast = $RangedDamageRayCast
onready var standing_raycast = $StandingRayCast
onready var under_feet_raycast = $UnderFeetRayCast
onready var rays_to_characters = $RaysToCharacters

onready var visibility_notifier = $VisibilityNotifier
onready var sound_player_walking = $SoundWalking
onready var sound_player_falling_to_floor = $SoundFallingToFloor
onready var sound_player_angry = $SoundAngry
onready var sound_player_pain = $SoundPain
onready var sound_player_attack = $SoundAttack
onready var sound_player_miss = $SoundMiss

var walk_sound_ids = [ __PLDRT.CHARS.SoundId.SOUND_WALK_NONE ]
var visible_to_player = true

func _ready():
	__PLDRT.game_state.connect("player_underwater", self, "_on_player_underwater")
	__PLDRT.game_state.connect("player_poisoned", self, "_on_player_poisoned")
	var model = character.get_model()
	if model:
		model.connect("cutscene_finished", self, "_on_cutscene_finished")
	else:
		push_warning("Model not set")
	melee_attack_area.monitoring = character.has_melee_attack()
	melee_damage_area.monitoring = character.has_melee_attack()
	ranged_damage_raycast.enabled = character.has_ranged_attack()
	ranged_damage_raycast.add_exception(character)
	standing_raycast.add_exception(character)
	under_feet_raycast.add_exception(character)
	if __PLDRT.game_state.is_tactical_view():
		var m = AudioStreamPlayer3D.ATTENUATION_DISABLED
		sound_player_walking.set_attenuation_model(m)
		sound_player_falling_to_floor.set_attenuation_model(m)
		sound_player_angry.set_attenuation_model(m)
		sound_player_pain.set_attenuation_model(m)
		sound_player_attack.set_attenuation_model(m)
		sound_player_miss.set_attenuation_model(m)

func replace_model(model):
	var existing_model = character.get_model()
	if (
		existing_model
		and existing_model.is_connected("cutscene_finished", self, "_on_cutscene_finished")
	):
		existing_model.disconnect("cutscene_finished", self, "_on_cutscene_finished")
	model.connect("cutscene_finished", self, "_on_cutscene_finished")
	return existing_model

func _on_player_underwater(player, enable):
	if player and not player.equals(character):
		return
	if enable and oxygen_timer.is_stopped():
		oxygen_timer.start()
	elif not enable:
		if not oxygen_timer.is_stopped():
			oxygen_timer.stop()
		var oxygen_max = __PLDRT.game_state.party_stats[character.get_name_hint()]["oxygen_max"]
		__PLDRT.game_state.set_oxygen(character, oxygen_max, oxygen_max)

func _on_player_poisoned(player, enable, intoxication_rate):
	if player and not player.equals(character):
		return
	if enable and poison_timer.is_stopped():
		poison_timer.start()
	elif not enable and not poison_timer.is_stopped():
		poison_timer.stop()

func get_rays_to_characters():
	return rays_to_characters

func get_rays_to_characters_pos():
	return get_rays_to_characters().get_global_transform().origin

func need_ray_to_character(another_character):
	return (
		character.is_activated()
		and another_character.is_activated()
	)

func get_ray_to_character_name(another_character):
	return "ray_" + another_character.get_name_hint()

func get_ray_to_character(another_character):
	if not another_character:
		return null
	var ray_name = get_ray_to_character_name(another_character)
	return rays_to_characters.get_node(ray_name) \
			if rays_to_characters.has_node(ray_name) \
			else null

func add_ray_to_character(another_character):
	var need_ray = need_ray_to_character(another_character)
	var ray_name = get_ray_to_character_name(another_character)
	if rays_to_characters.has_node(ray_name):
		rays_to_characters.get_node(ray_name).queue_free()
		if DEBUG_RAYS:
			print_debug(ray_name + " deleted in add for " + character.get_name_hint())
		return null
	if not need_ray:
		return null
	if DEBUG_RAYS:
		print_debug(ray_name + " created in add for " + character.get_name_hint())
	var r = RayCast.new()
	r.set_name(ray_name)
	r.enabled = need_ray
	r.set_collision_mask_bit(0, false) # Default layer is NOT a collision
	r.set_collision_mask_bit(1, true) # Collides with walls
	r.set_collision_mask_bit(2, true) # Collides with floor
	r.set_collision_mask_bit(3, false) # Interactives is NOT a collision
	r.set_collision_mask_bit(4, true) # Collides with doors
	r.set_collision_mask_bit(10, true) # Collides with ceiling
	r.set_collision_mask_bit(11, false) # Party is NOT a collision
	r.set_collision_mask_bit(12, false) # Enemies is NOT a collision
	r.set_collision_mask_bit(13, false) # Obstacles is NOT a collision
	rays_to_characters.add_child(r)
	update_ray_to_character(another_character, r)
	return r

func update_ray_to_character(another_character, ray = null):
	var r = ray if ray else get_ray_to_character(another_character)
	var need_ray = need_ray_to_character(another_character)
	if r:
		r.enabled = r.enabled and need_ray
		if r.enabled:
			r.cast_to = r.to_local(another_character.get_rays_to_characters_pos())
		else:
			if DEBUG_RAYS:
				print_debug(r.get_name() + " deleted in update for " + character.get_name_hint())
			r.queue_free()
			r = null
	return r

func delete_ray_to_character(another_character):
	var r = get_ray_to_character(another_character)
	if r:
		r.enabled = false
		if DEBUG_RAYS:
			print_debug(r.get_name() + " deleted for " + character.get_name_hint())
		r.queue_free()
		return true
	return false

func has_obstacles_between(another_character):
	if not another_character or another_character.equals(character):
		return false
	var r = get_ray_to_character(another_character)
	if not r or not r.enabled:
		return false
	return r.is_colliding()

func disable_rays_to_characters():
	for ray in rays_to_characters.get_children():
		ray.enabled = false

func play_walking_sound(is_sprinting):
	if sound_player_walking.stream and not sound_player_walking.is_playing():
		sound_player_walking.play()
	var new_pitch_scale = 2 if is_sprinting else 1
	if new_pitch_scale != sound_player_walking.pitch_scale:
		sound_player_walking.pitch_scale = new_pitch_scale

func stop_walking_sound():
	sound_player_walking.stop()

func play_sound_falling_to_floor():
	sound_player_falling_to_floor.play()

func set_sound_walk(mode, replace_existing = true):
	var stream = __PLDRT.CHARS.SOUND[mode] if mode != __PLDRT.CHARS.SoundId.SOUND_WALK_NONE and __PLDRT.CHARS.SOUND.has(mode) else null
	if (
		walk_sound_ids[0] == mode
		and stream and sound_player_walking.stream
		and __PLDRT.common_utils.is_same_resource(stream, sound_player_walking.stream)
	):
		return
	if replace_existing:
		walk_sound_ids[0] = mode
	else:
		walk_sound_ids.push_front(mode)
	sound_player_walking.stop()
	sound_player_walking.set_unit_db(0)
	if not __PLDRT.common_utils.set_stream_loop(stream, true):
		sound_player_walking.stream = null
		return
	sound_player_walking.stream = stream

func restore_sound_walk_from(mode):
	if walk_sound_ids.size() > 1 and walk_sound_ids[0] == mode:
		walk_sound_ids.pop_front()
		set_sound_walk(walk_sound_ids[0])

func set_sound_angry(mode):
	sound_player_angry.stop()
	sound_player_angry.set_unit_db(6)
	var stream = __PLDRT.SOUND[mode] if __PLDRT.CHARS.SOUND.has(mode) else null
	if not __PLDRT.common_utils.set_stream_loop(stream, false):
		sound_player_angry.stream = null
		return
	sound_player_angry.stream = stream

func set_sound_pain(mode):
	sound_player_pain.stop()
	sound_player_pain.set_unit_db(6)
	var stream = __PLDRT.CHARS.SOUND[mode] if __PLDRT.CHARS.SOUND.has(mode) else null
	if not __PLDRT.common_utils.set_stream_loop(stream, false):
		sound_player_pain.stream = null
		return
	sound_player_pain.stream = stream

func set_sound_attack(mode):
	sound_player_attack.stop()
	sound_player_attack.set_unit_db(0)
	var stream = __PLDRT.CHARS.SOUND[mode] if __PLDRT.CHARS.SOUND.has(mode) else null
	if not __PLDRT.common_utils.set_stream_loop(stream, false):
		sound_player_attack.stream = null
		return
	sound_player_attack.stream = stream

func set_sound_miss(mode):
	sound_player_miss.stop()
	sound_player_miss.set_unit_db(0)
	var stream = __PLDRT.CHARS.SOUND[mode] if __PLDRT.CHARS.SOUND.has(mode) else null
	if not __PLDRT.common_utils.set_stream_loop(stream, false):
		sound_player_miss.stream = null
		return
	sound_player_miss.stream = stream

func set_underwater(enable):
	if enable:
		set_sound_walk(__PLDRT.CHARS.SoundId.SOUND_WALK_SWIM, false)
		__PLDRT.MEDIA.change_music_to(PLDDBMedia.MusicId.UNDERWATER, false)
		__PLDRT.settings.set_reverb(false)
	else:
		restore_sound_walk_from(__PLDRT.CHARS.SoundId.SOUND_WALK_SWIM)
		__PLDRT.MEDIA.restore_music_from(PLDDBMedia.MusicId.UNDERWATER)
		__PLDRT.settings.set_reverb(__PLDRT.game_state.get_level().is_reverb())

func use_weapon(item):
	if not item:
		return
	if PLDDB.is_weapon_stun(item.item_id):
		var weapon_data = PLDDB.get_weapon_stun_data(item.item_id)
		if weapon_data.stun_duration > 0:
			__PLDRT.MEDIA.play_sound(weapon_data.sound_id)
			stun_start(item, weapon_data.stun_duration)
		else:
			__PLDRT.game_state.get_hud().queue_popup_message("MESSAGE_NOTHING_HAPPENS")
	elif PLDDB.is_weapon_ranged(item.item_id):
		var p = __PLDRT.game_state.get_player()
		var cam = __PLDRT.game_state.get_cam()
		var weapon_data = PLDDB.get_weapon_ranged_data(item.item_id)
		character.hit(weapon_data.injury_rate, weapon_data.poison_rate, cam)

func stun_start(item, stun_duration):
	character.inc_stuns_count()
	__PLDRT.common_utils.set_pause_scene(character, true)
	character.emit_signal("stun_started", character, item)
	character.clear_target_node()
	stun_timer.start(stun_duration)

func is_stunned():
	return not stun_timer.is_stopped()

func stun_stop(prematurely):
	var was_stunned = not stun_timer.is_stopped()
	if was_stunned:
		stun_timer.stop()
	if prematurely and not was_stunned:
		# It looks like that the stun has been already stopped by timer
		return was_stunned
	__PLDRT.common_utils.set_pause_scene(character, false)
	character.emit_signal("stun_finished", character, prematurely)
	return was_stunned

func has_floor_collision():
	return under_feet_raycast.is_colliding()

func get_under_feet_y():
	if under_feet_raycast.is_colliding():
		var p = under_feet_raycast.get_collision_point()
		return p.y
	else:
		return null

func process_rotation(angle_rad_x):
	ranged_damage_raycast.rotate_x(angle_rad_x)
	var ray_rot = ranged_damage_raycast.rotation_degrees
	ray_rot.x = clamp(ray_rot.x, RAY_ROT_MIN_DEG, RAY_ROT_MAX_DEG)
	ranged_damage_raycast.rotation_degrees = ray_rot

func reset_rotation():
	ranged_damage_raycast.set_rotation_degrees(Vector3(0, 0, 0))

func get_damage_point():
	if not ranged_damage_raycast.enabled or not ranged_damage_raycast.is_colliding():
		var t = get_global_transform()
		var rt = ranged_damage_raycast.get_transform()
		return t.xform(rt.xform(ranged_damage_raycast.cast_to))
	return ranged_damage_raycast.get_collision_point()

func get_possible_attack_target(update_collisions):
	if not character.is_activated():
		return null
	if character.has_melee_attack():
		for body in melee_attack_area.get_overlapping_bodies():
			if character.equals(body):
				continue
			if body.is_in_group("party") or body.is_in_group("enemies"):
				return body
	if character.has_ranged_attack():
		if update_collisions:
			ranged_damage_raycast.force_raycast_update()
		if ranged_damage_raycast.is_colliding():
			var body = ranged_damage_raycast.get_collider()
			if body.is_in_group("party") or body.is_in_group("enemies"):
				return body
	return null

func get_possible_damage_target(update_collisions):
	if not character.is_activated():
		return null
	if character.has_melee_attack():
		for body in melee_damage_area.get_overlapping_bodies():
			if character.equals(body):
				continue
			if body.is_in_group("party") or body.is_in_group("enemies"):
				return body
	if character.has_ranged_attack():
		if update_collisions:
			ranged_damage_raycast.force_raycast_update()
		if ranged_damage_raycast.is_colliding():
			var body = ranged_damage_raycast.get_collider()
			if body.is_in_group("party") or body.is_in_group("enemies"):
				return body
	return null

func is_attacking():
	return not attack_timer.is_stopped()

func play_angry_sound():
	sound_player_angry.play()

func play_pain_sound():
	sound_player_pain.play()

func play_attack_sound():
	sound_player_attack.play()

func play_sound_miss():
	sound_player_miss.play()

func attack_start(immediately = false):
# TODO: Check it is OK
#	if not character.is_activated():
#		return
	if not is_attacking():
		if immediately:
			_on_AttackTimer_timeout()
		else:
			attack_timer.start(character.get_attack_speed())

func stop_attack():
	if is_attacking():
		attack_timer.stop()

func start_rest_timer():
	if rest_timer.is_stopped():
		rest_timer.start()

func stop_rest_timer():
	rest_timer.stop()

func stop_all():
	stop_rest_timer()
	stop_attack()
	stun_timer.stop()
	poison_timer.stop()
	oxygen_timer.stop()

func enable_areas_and_raycasts(enable):
	standing_raycast.enabled = enable
	under_feet_raycast.enabled = true # under_feet_raycast is always enabled
	ranged_damage_raycast.enabled = enable and character.has_ranged_attack()
	melee_attack_area.get_node("CollisionShape").disabled = not enable
	melee_damage_area.get_node("CollisionShape").disabled = not enable

func is_visible_to_player():
	return (
		visible_to_player
		and (
			__PLDRT.game_state.is_tactical_view()
			or not has_obstacles_between(__PLDRT.game_state.get_player())
		)
	)

func is_low_ceiling():
	# Make sure you've set proper collision layer bit for ceiling
	return standing_raycast.is_colliding()

func _on_HealTimer_timeout():
	if (
		not character.is_player()
		or not __PLDRT.game_state.is_level_ready()
		or not oxygen_timer.is_stopped()
		or not poison_timer.is_stopped()
	):
		return
	var name_hint = character.get_name_hint()
	var health_current = __PLDRT.game_state.party_stats[name_hint]["health_current"]
	var health_max = __PLDRT.game_state.party_stats[name_hint]["health_max"]
	__PLDRT.game_state.set_health(character, health_current + PLDDB.HEALING_RATE, health_max)

func _on_OxygenTimer_timeout():
	if oxygen_timer.is_stopped():
		return
	var oxygen_new = __PLDRT.game_state.party_stats[character.get_name_hint()]["oxygen_current"] - OXYGEN_DECREASE_RATE
	__PLDRT.game_state.set_oxygen(character, oxygen_new, __PLDRT.game_state.party_stats[character.get_name_hint()]["oxygen_max"])

func _on_PoisonTimer_timeout():
	if poison_timer.is_stopped():
		return
	__PLDRT.game_state.set_health(
		character,
		__PLDRT.game_state.party_stats[character.get_name_hint()]["health_current"] - character.get_intoxication(),
		__PLDRT.game_state.party_stats[character.get_name_hint()]["health_max"]
	)

func _on_StunTimer_timeout():
	stun_stop(false)

func _on_cutscene_finished(player, player_model, cutscene_id, was_active):
	if is_attacking() and player_model.is_attack_cutscene(cutscene_id):
		attack_timer.stop()
		if not was_active:
			_on_AttackTimer_timeout()

func _on_AttackTimer_timeout():
# TODO: Check it is OK
#	if not character.is_activated():
#		return
	var last_attack_data = character.get_last_attack_data()
	var last_attack_target = last_attack_data.target
	var attack_target = get_possible_damage_target(true)
	if attack_target:
		play_attack_sound()
		if attack_target.is_in_group("party"):
			if FRIENDLY_FIRE_ENABLED \
				or not character.is_in_group("party"):
				attack_target.hit(last_attack_data.injury_rate, last_attack_data.poison_rate)
		elif attack_target.is_in_group("enemies"):
			attack_target.hit(last_attack_data.injury_rate, last_attack_data.poison_rate)
		if last_attack_target and attack_target.get_instance_id() != last_attack_target.get_instance_id():
			last_attack_target.miss()
	else:
		play_sound_miss()
		if last_attack_target:
			last_attack_target.miss()
		#character.stop_cutscene()
	character.emit_signal("attack_finished", character, attack_target, last_attack_target, last_attack_data.anim_idx)
	character.clear_point_of_interest()
	character.clear_last_attack_data()

func _on_RestTimer_timeout():
	stop_walking_sound()
	var model = character.get_model()
	if model:
		model.look()
	else:
		push_warning("Model not set")

func _on_VisibilityNotifier_screen_entered():
	visible_to_player = true
	character.emit_signal("visibility_to_player_changed", character, false, true)
	if character.is_in_party():
		character.invoke_physics_pass()

func _on_VisibilityNotifier_screen_exited():
	visible_to_player = false
	character.emit_signal("visibility_to_player_changed", character, true, false)
