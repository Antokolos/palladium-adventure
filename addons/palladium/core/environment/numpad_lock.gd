extends Spatial

const TEXT_SUCCESS = "OK"
const TEXT_ERROR = "ERROR"
const COLOR_GREEN = Color(0, 1, 0)
const COLOR_RED = Color(1, 0, 0)
const COLOR_BLACK = Color(0, 0, 0)

export(NodePath) var door_path = null
export(NodePath) var numpad_path = NodePath("Model/numpad")

var code_correct = [1, 2, 3, 4]
var code_current = []
var was_opened = false

onready var label = $Label3D
onready var door = get_node(door_path) if door_path and has_node(door_path) else null
onready var numpad = get_node(numpad_path) if numpad_path and has_node(numpad_path) else null

func _ready():
	code_clear()
	was_opened = not door.is_untouched()
	door.connect("door_state_changing", self, "_on_door_state_changing")

func set_code_correct(code : int):
	code_clear()
	var c = code
	code_correct.clear()
	while true:
		var cr = c % 10
		code_correct.push_front(cr)
		if c < 10:
			return
		c = c / 10

func was_opened():
	return was_opened

func is_opened():
	return door.is_opened() if door else false

func code_success():
	code_clear()
	was_opened = true
	label.text = TEXT_SUCCESS
	label.modulate = COLOR_GREEN

func code_error():
	code_clear()
	label.text = TEXT_ERROR
	label.modulate = COLOR_RED

func code_clear():
	code_current.clear()
	label.text = ""

func check_code():
	if code_correct.size() != code_current.size():
		return false
	for i in range(0, code_correct.size()):
		if code_correct[i] != code_current[i]:
			return false
	return true

func button_press(button_code):
	if door.is_opened():
		return
	if button_code == PLDNumpadButton.CODE_AC:
		code_clear()
	elif button_code == PLDNumpadButton.CODE_ENTER:
		code_success() if check_code() else code_error()
	else:
		if code_current.size() >= code_correct.size():
			return
		if code_current.empty():
			label.text = ""
		code_current.push_back(button_code)
		label.modulate = COLOR_BLACK
		label.text += str(button_code)
	if numpad:
		numpad.play_animation(button_code)

func _on_door_state_changing(door_id, opened):
	code_clear()
