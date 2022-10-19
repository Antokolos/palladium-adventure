extends WindowDialog

onready var difficulty_normal_button = get_node("VBoxContainer/HBoxContainer/DifficultyNormalButton")

func _ready():
	get_close_button().connect("pressed", self, "_on_DifficultyNormalButton_pressed")

func _input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_tablet_toggle") or event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		_on_DifficultyNormalButton_pressed()

func _notification(what):
	match what:
		NOTIFICATION_POST_POPUP:
			__PLDRT.common_utils.show_mouse_cursor_if_needed(true)
			difficulty_normal_button.grab_focus()

func _on_DifficultyHardButton_pressed():
	visible = false
	__PLDRT.settings.set_difficulty(PLDSettings.DIFFICULTY_HARD)
	__PLDRT.game_state.get_hud().pause_game(false)
	__PLDRT.game_state.change_scene("res://intro_full.tscn")

func _on_DifficultyNormalButton_pressed():
	visible = false
	__PLDRT.settings.set_difficulty(PLDSettings.DIFFICULTY_NORMAL)
	__PLDRT.game_state.get_hud().pause_game(false)
	__PLDRT.game_state.change_scene("res://intro_full.tscn")

func _on_difficulty_dialog_about_to_show():
	__PLDRT.game_state.get_hud().pause_game(true)
