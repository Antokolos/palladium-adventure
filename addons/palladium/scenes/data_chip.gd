extends PLDUseTarget

export(int) var chip_code = 1234

func use_action(player_node, item):
	__PLDRT.game_state.get_hud().queue_popup_message("MESSAGE_CHIP_CODE", [chip_code], false, 3)
	return true
