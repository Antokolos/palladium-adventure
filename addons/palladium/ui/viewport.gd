extends Viewport

const MIN_SIZE = Vector2(1, 1)

var active = true
var last_size = MIN_SIZE

func _ready():
	var vp = __PLDRT.game_state.get_root_viewport()
	vp.connect("size_changed", self, "_root_viewport_size_changed")
	__PLDRT.settings.connect("resolution_changed", self, "_on_resolution_changed")
	__PLDRT.game_state.connect("shader_cache_processed", self, "_on_shader_cache_processed")
	_on_resolution_changed(__PLDRT.settings.resolution)

func activate(enable):
	if active and not enable:
		active = false
		self.size = MIN_SIZE
		self.set_size_override(true, MIN_SIZE)
	elif not active and enable:
		active = true
		_on_resolution_changed(__PLDRT.settings.resolution)

func _root_viewport_size_changed():
	_on_resolution_changed(__PLDRT.settings.resolution)

func _on_shader_cache_processed():
	_on_resolution_changed(__PLDRT.settings.resolution)

func _on_resolution_changed(ID):
	last_size = __PLDRT.settings.get_resolution_size(ID)
	if not active:
		return
	reset_size()

func reset_size():
	self.size = last_size
	self.set_size_override(true, last_size)
	var vp = __PLDRT.game_state.get_root_viewport()
	var screen_size = OS.get_screen_size()
	vp.size = screen_size
	vp.set_size_override(true, screen_size)
