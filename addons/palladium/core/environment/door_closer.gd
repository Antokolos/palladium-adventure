extends PLDStaticUsable
class_name PLDDoorCloser

export(NodePath) var door_path = null
export(NodePath) var lock_path = null

onready var door = get_node(door_path) if door_path and has_node(door_path) else null
onready var lock = get_node(lock_path) if lock_path and has_node(lock_path) else null

func get_usage_code(player_node):
	return "ACTION_CLOSE" if not lock or lock.was_opened() else ""

func use(player_node, camera_node):
	if .use(player_node, camera_node):
		if door:
			door.close()
