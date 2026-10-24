extends PLDEnemy
class_name PLDEnemyGeneric

const MAX_DIST = 37
const MAX_VERT_DIST = 9

export(bool) var use_distance_limits = true
# Enemy is processed only when the player is closer than max_dist horizontally
# and than max_vert_dist vertically. For multi-storey levels max_vert_dist
# should be less than the distance between floors, otherwise enemies on the
# neighbouring floors are processed too.
export(float) var max_dist = MAX_DIST
export(float) var max_vert_dist = MAX_VERT_DIST

func _ready():
	enemy_init()

func enemy_init():
	set_relationship(-1)
	deactivate()

func _process(delta):
	if is_physics_processing():
		return
	var origin = get_global_transform().origin
	var player = __PLDRT.game_state.get_player()
	if player:
		var player_origin = player.get_global_transform().origin
		if abs(origin.y - player_origin.y) > max_vert_dist:
			return
		origin.y = 0
		player_origin.y = 0
		var dist = origin.distance_to(player_origin)
		if dist <= max_dist:
			set_physics_process(true)
			if not is_activated() and not is_dead():
				activate()

func do_process(delta, is_player):
	if not use_distance_limits:
		return .do_process(delta, is_player)
	var origin = get_global_transform().origin
	var player = __PLDRT.game_state.get_player()
	if player:
		var player_origin = player.get_global_transform().origin
		if abs(origin.y - player_origin.y) > max_vert_dist:
			if is_physics_processing():
				set_physics_process(false)
			return .do_process(delta, is_player)
		origin.y = 0
		player_origin.y = 0
		var dist = origin.distance_to(player_origin)
		if dist > max_dist and is_physics_processing():
			set_physics_process(false)
	return .do_process(delta, is_player)
