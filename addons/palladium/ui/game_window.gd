extends ViewportContainer
class_name PLDGameWindow

func _input(event):
	if do_input(event) > 1:
		get_tree().set_input_as_handled()

func do_input(event):
	if (
		__PLDRT.settings.disable_mouse_if_joy_connected
		and __PLDRT.common_utils.has_joypads()
		and event is InputEventMouseMotion
	):
		return 2
	if __PLDRT.common_utils.is_mouse_captured():
		var is_joy_motion = event is InputEventJoypadMotion
		if not is_joy_motion:
			return 0
		elif is_joy_motion and event.get_axis() == JOY_AXIS_6: # Joypad Left Trigger Analog Axis
			return 2
		elif is_joy_motion and event.get_axis() == JOY_AXIS_7: # Joypad Right Trigger Analog Axis
			return 2
		else:
			return 0
	var hud = __PLDRT.game_state.get_hud()
	if (
		hud
		and not event is InputEventMouseButton
		and (event.is_action_pressed("action") or event.is_action_pressed("ui_accept"))
	):
		if (
			(
				not hud.is_paused()
				and not __PLDRT.game_state.is_tactical_view()
			)
			or hud.is_tablet_visible()
			or hud.is_quit_dialog_visible()
		):
			hud.get_mouse_cursor().click_the_left_mouse_button()
	return 1
