extends Control

onready var dimmer = get_node("Dimmer")
onready var tablet = get_node("tablet")

onready var mouse_cursor = get_node("mouse_cursor")
onready var label_joy_hint = get_node("LabelJoyHint")
onready var image_adjust = get_node("ImageAdjust")

func _ready():
	__PLDRT.common_utils.show_mouse_cursor_if_needed_in_game(self)
	__PLDRT.settings.connect("image_adjust_changed", self, "_on_image_adjust_changed")
	_on_image_adjust_changed(__PLDRT.settings.use_image_adjust, __PLDRT.settings.brightness, __PLDRT.settings.contrast, __PLDRT.settings.saturation)
	label_joy_hint.text = tr("MAIN_MENU_JOY_HINT") % __PLDRT.common_utils.get_input_control("ui_accept", false)
	label_joy_hint.visible = __PLDRT.common_utils.has_joypads()
	Input.connect("joy_connection_changed", self, "_on_joy_connection_changed")

func _on_joy_connection_changed(device_id, is_connected):
	label_joy_hint.visible = __PLDRT.common_utils.has_joypads()

func is_menu_hud():
	return true

func is_tablet_visible():
	return tablet.visible

func is_quit_dialog_visible():
	return get_node("quit_dialog").visible

func get_mouse_cursor():
	return mouse_cursor

func pause_game(enable, with_dimmer = true):
	dimmer.visible = with_dimmer and enable
	# Menu HUD does not use _PLDRT.DB.USE_PAUSE setting
	get_tree().paused = enable

func is_paused():
	return get_tree().paused

func show_tablet(is_show, activation_mode = PLDTablet.ActivationMode.DESKTOP):
	if is_show:
		__PLDRT.common_utils.show_mouse_cursor_if_needed(true)
		pause_game(true)
		tablet.activate(activation_mode)
	else:
		__PLDRT.common_utils.show_mouse_cursor_if_needed(true, true)
		tablet.visible = false
		pause_game(false)
		__PLDRT.settings.save_settings()
		__PLDRT.settings.save_input()
		var ui = get_node("/root/UI") if has_node("/root/UI") else null # 'nlbutils' module is used
		if ui:
			ui.fullscreen = __PLDRT.settings.fullscreen
			ui.save_settings()

func show_difficulty_dialog():
	get_node("difficulty_dialog").popup_centered_ratio(0.5)

func set_game_name_font(
	name_font_path : String,
	name_size : int = 100,
	name_extra_spacing_bottom : int = -22,
	subname_size : int = 50,
	subname_extra_spacing_char : int = 26,
	outline_size : int = 5,
	outline_color : Color = Color.black
):
	var gn = get_node("VBoxContainer/LabelGameName")
	var fgn = DynamicFont.new()
	fgn.font_data = load(name_font_path)
	fgn.size = name_size
	fgn.extra_spacing_bottom = name_extra_spacing_bottom
	fgn.outline_size = outline_size
	fgn.outline_color = outline_color
	gn.set("custom_fonts/font", fgn)
	var gsn = get_node("VBoxContainer/LabelGameSubname")
	var fgsn = DynamicFont.new()
	fgsn.font_data = load(name_font_path)
	fgsn.size = subname_size
	fgsn.extra_spacing_char = subname_extra_spacing_char
	fgsn.outline_size = outline_size
	fgsn.outline_color = outline_color
	gsn.set("custom_fonts/font", fgsn)

func update_hud():
	pass

func _on_image_adjust_changed(enabled, brightness, contrast, saturation):
	image_adjust.visible = enabled
	image_adjust.material.set_shader_param("brightness", brightness)
	image_adjust.material.set_shader_param("contrast", contrast)
	image_adjust.material.set_shader_param("saturation", saturation)

func _unhandled_input(event):
	if not is_paused() and event.is_action_pressed("ui_tablet_toggle") and not __PLDRT.game_state.is_video_cutscene():
		get_tree().set_input_as_handled()
		show_tablet(true, PLDTablet.ActivationMode.DESKTOP)
