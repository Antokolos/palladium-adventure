extends PLDStaticUsable

# Elevator button: sends the elevator to target_floor.
# Used both inside the cabin and as a call button on each floor.

export(NodePath) var elevator_path = NodePath("../../..")
export(int) var target_floor = 0

onready var elevator = get_node(elevator_path) if elevator_path and has_node(elevator_path) else null

func use(player_node, camera_node):
	if not .use(player_node, camera_node):
		return false
	if elevator:
		elevator.request_floor(target_floor)
	return true
