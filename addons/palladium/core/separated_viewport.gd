extends ViewportContainer

onready var viewport = $Viewport
onready var camera = $Viewport/Camera
onready var dimmer = $dimmer

var active = false

func _ready():
	activate(false)

func activate(enable):
	visible = enable
	viewport.activate(enable)
	sync_transform()
	active = enable

func set_camera_environment(environment):
	camera.environment = environment

func show_dimmer(is_show):
	dimmer.visible = is_show

func sync_transform():
	camera.global_transform = get_parent().get_global_transform()

func _process(delta):
	if not active:
		return
	sync_transform()
