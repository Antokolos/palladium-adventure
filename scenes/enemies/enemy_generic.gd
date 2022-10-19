extends PLDEnemy
class_name EnemyGeneric

const MAX_DIST = 37
const MAX_VERT_DIST = 9

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
		if abs(origin.y - player_origin.y) > MAX_VERT_DIST:
			return
		origin.y = 0
		player_origin.y = 0
		var dist = origin.distance_to(player_origin)
		if dist <= MAX_DIST:
			set_physics_process(true)
			if not is_activated() and not is_dead():
				activate()

func do_process(delta, is_player):
	var origin = get_global_transform().origin
	var player = __PLDRT.game_state.get_player()
	if player:
		var player_origin = player.get_global_transform().origin
		if abs(origin.y - player_origin.y) > MAX_VERT_DIST:
			if is_physics_processing():
				set_physics_process(false)
			return .do_process(delta, is_player)
		origin.y = 0
		player_origin.y = 0
		var dist = origin.distance_to(player_origin)
		if dist > MAX_DIST and is_physics_processing():
			set_physics_process(false)
	return .do_process(delta, is_player)
