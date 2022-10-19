extends PLDStaticUsable
class_name PLDDoorToggler

export(NodePath) var door_path = null
export(NodePath) var lock_path = null
export(NodePath) var anim_player_path = null
export(String) var anim_open = "open"
export(String) var anim_close = "close"

onready var door = get_node(door_path) if door_path and has_node(door_path) else null
onready var lock = get_node(lock_path) if lock_path and has_node(lock_path) else null
onready var anim_player = get_node(anim_player_path) if anim_player_path and has_node(anim_player_path) else null

func get_code():
	return "ACTION_CLOSE" if door.is_opened() else "ACTION_OPEN"

func get_usage_code(player_node):
	return get_code() if not lock or lock.was_opened() else ""

func use(player_node, camera_node):
	if .use(player_node, camera_node):
		if not door:
			return
		if door.is_opened():
			if anim_player:
				anim_player.play(anim_close)
			door.close()
		else:
			if anim_player:
				anim_player.play(anim_open)
			door.open()
