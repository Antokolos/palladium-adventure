extends GodotCredits

onready var text_review_label = get_node("VBoxContainer/ColorRectUpper/VBoxUpper/HBoxUpper/Label")
onready var button_review = get_node("VBoxContainer/PanelContainer/VBoxLower/HBoxLower/ButtonReview")

func _ready():
	__PLDRT.common_utils.show_mouse_cursor_if_needed(true)
	button_review.grab_focus()
	text_review_label.text = get_text_review_label_text()

func get_text_review_label_text():
	match TranslationServer.get_locale():
		"ru":
			return "Спасибо за игру!\nБудем очень благодарны за ваше мнение об игре: что понравилось,\nчто не понравилось, что вы изменили бы в игре, какие эмоции вы испытали во время игры.\nС уважением, команда NLB project."
		_:
			return "Thanks for playing!\nWe would appreciate some feedback about our game: what did you like and what didn't;\nwhat would you change in the game, what emotions did you have while playing?\nYours faithfully, NLB project team"

func do_on_finish():
	pass

func _on_ButtonQuit_pressed():
	eos_utils.exit_game()

func _on_ButtonMainMenu_pressed():
	__PLDRT.game_state.change_scene("res://main_menu/main_menu.tscn")

func _on_ButtonReview_pressed():
	__PLDRT.common_utils.open_store_page(1137270)
