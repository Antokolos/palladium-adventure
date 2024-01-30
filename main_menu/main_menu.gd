extends PLDLevel

func do_init(is_loaded):
	__PLDRT.MEDIA.change_music_to(__PLDRT.MEDIA.MusicId.LOADING)
	__PLDRT.PREFS.set_achievement("MAIN_MENU")
	__PLDRT.PREFS.resend_achievements()
	__PLDRT.game_state.reset_variables()
	__PLDRT.story_node.reset_all() # If we have gone here via game_state.change_scene() we should reset stories state
