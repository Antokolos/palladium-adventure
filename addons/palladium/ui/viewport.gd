extends Viewport

func _ready():
	var vp = __PLDRT.game_state.get_root_viewport()
	vp.connect("size_changed", self, "_root_viewport_size_changed")
	__PLDRT.settings.connect("resolution_changed", self, "_on_resolution_changed")
	_on_resolution_changed(__PLDRT.settings.resolution)
	
func _root_viewport_size_changed():
	_on_resolution_changed(__PLDRT.settings.resolution)

func _on_resolution_changed(ID):
	var size = __PLDRT.settings.get_resolution_size(ID)
	self.size = size
	self.set_size_override(true, size)
	var vp = __PLDRT.game_state.get_root_viewport()
	var screen_size = OS.get_screen_size()
	vp.size = screen_size
	vp.set_size_override(true, screen_size)
