extends Node

func set_msaa(msaa):
	__PLDRT.game_state.get_root_viewport().set_msaa(msaa)

func get_mouse_position():
	return __PLDRT.game_state.get_root_viewport().get_mouse_position()

func get_visible_rect():
	return __PLDRT.game_state.get_root_viewport().get_visible_rect()

func warp_mouse(position : Vector2):
	return __PLDRT.game_state.get_root_viewport().warp_mouse(position)
