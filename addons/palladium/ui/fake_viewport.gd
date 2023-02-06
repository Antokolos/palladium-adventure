extends Node

func set_msaa(msaa):
	get_node("/root").set_msaa(msaa)

func get_mouse_position():
	return get_node("/root").get_mouse_position()

func get_visible_rect():
	return get_node("/root").get_visible_rect()

func warp_mouse(position : Vector2):
	return get_node("/root").warp_mouse(position)
