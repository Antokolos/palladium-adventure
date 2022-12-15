extends PLDStaticUsable
class_name PLDLadder

const DISTANCE_INFINITY = 99999.0

const STATE_VACANT = 0
const STATE_OCCUPIED = 1

onready var positions_in_holder = get_node("positions_in")
onready var positions_out_holder = get_node("positions_out")

var positions_in = []
var positions_out = []
var state = STATE_VACANT
var ymin = DISTANCE_INFINITY
var ymax = -DISTANCE_INFINITY

func init_positions():
	if positions_in.empty():
		ymin = DISTANCE_INFINITY
		ymax = -DISTANCE_INFINITY
		for pos in positions_in_holder.get_children():
			positions_in.append(pos)
			var posy = pos.get_global_transform().origin.y
			if posy > ymax:
				ymax = posy
			if posy < ymin:
				ymin = posy
	if positions_out.empty():
		for pos in positions_out_holder.get_children():
			positions_out.append(pos)

func find_closest_pos(player, positions_arr):
	if not player:
		return null
	var player_origin = player.get_global_transform().origin
	var closest_distance = DISTANCE_INFINITY
	var closest_pos = null
	for pos in positions_arr:
		var pos_origin = pos.get_global_transform().origin
		var pl = (pos_origin - player_origin).length()
		if pl < closest_distance:
			closest_distance = pl
			closest_pos = pos
	return closest_pos

func use(player_node, camera_node):
	if not .use(player_node, camera_node):
		return false
	var player = __PLDRT.game_state.get_player()
	if not player:
		return false
	init_positions()
	if state == STATE_VACANT:
		if positions_in.empty():
			return false
		__PLDRT.game_state.set_multistate_state(get_path(), STATE_OCCUPIED)
		var pos = find_closest_pos(player, positions_in)
		player.teleport(pos)
		player.set_on_ladder(true)
		player.set_ladder_rotation_deg(pos.rotation_degrees.y)
		player.set_ladder_ymax(ymax)
		player.set_ladder_ymin(ymin)
		state = STATE_OCCUPIED
	elif state == STATE_OCCUPIED:
		if positions_out.empty():
			return false
		__PLDRT.game_state.set_multistate_state(get_path(), STATE_VACANT)
		var pos = find_closest_pos(player, positions_out)
		player.teleport(pos)
		player.set_on_ladder(false)
		player.set_ladder_rotation_deg(0)
		player.set_ladder_ymax(ymax)
		player.set_ladder_ymin(ymin)
		state = STATE_VACANT
	return true

func restore_state():
	state = __PLDRT.game_state.get_multistate_state(get_path())
	positions_in.clear()
	positions_out.clear()
	ymin = DISTANCE_INFINITY
	ymax = -DISTANCE_INFINITY
	if state == STATE_VACANT:
		pass
	elif state == STATE_OCCUPIED:
		pass
