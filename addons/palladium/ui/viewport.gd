extends Viewport

const MIN_SIZE = Vector2(1, 1)

var active = true
var last_size = MIN_SIZE

func _ready():
	var vp = __PLDRT.game_state.get_root_viewport()
	vp.connect("size_changed", self, "_root_viewport_size_changed")
	__PLDRT.settings.connect("resolution_changed", self, "_on_resolution_changed")
	_on_resolution_changed(__PLDRT.settings.resolution)

func activate(enable):
	if active and not enable:
		self.size = MIN_SIZE
		self.set_size_override(true, MIN_SIZE)
		self.render_target_clear_mode = CLEAR_MODE_NEVER
		self.render_target_update_mode = UPDATE_DISABLED
		active = enable
	elif not active and enable:
		self.render_target_clear_mode = CLEAR_MODE_NEVER
		self.render_target_update_mode = UPDATE_ALWAYS
		reset_size()
		active = enable

func _root_viewport_size_changed():
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
