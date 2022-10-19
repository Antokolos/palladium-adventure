extends PLDUsable
class_name PLDNumpadButton

const CODE_AC = 10
const CODE_ENTER = 11

export(int) var button_code = 0

onready var numpad_lock = get_parent()

func get_usage_code(player_node):
	if numpad_lock.is_opened():
		return ""
	return "ACTION_PRESS"

func can_be_used_by(player_node):
	if numpad_lock.is_opened():
		return false
	return .can_be_used_by(player_node)

func use(player_node, camera_node):
	numpad_lock.button_press(button_code)
	return .use(player_node, camera_node)
