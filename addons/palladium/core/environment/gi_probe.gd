extends GIProbe

export var enabled : bool = true
export var persistent : bool = false
export var activator_add = 0.0
export(NodePath) var navigation_path = null
export(NodePath) var navigation_safe_path = null

onready var navigation = get_node(navigation_path) if navigation_path and get_node(navigation_path) else null
onready var navigation_safe = get_node(navigation_safe_path) if navigation_safe_path and get_node(navigation_safe_path) else null

func _ready():
	#__PLDRT.settings.connect("quality_changed", self, "change_quality")
	rebuild(__PLDRT.settings.quality)

func rebuild(quality):
	if enabled:
		visible = false
		data = null
		match quality:
			PLDSettings.QUALITY_NORM:
				subdiv = GIProbe.SUBDIV_64
			PLDSettings.QUALITY_OPT:
				subdiv = GIProbe.SUBDIV_128
			PLDSettings.QUALITY_GOOD:
				subdiv = GIProbe.SUBDIV_256
			PLDSettings.QUALITY_HIGH:
				subdiv = GIProbe.SUBDIV_512
			_:
				subdiv = GIProbe.SUBDIV_128
		call_deferred("bake")
		visible = true
	else:
		data = null
		visible = false

func change_quality(quality):
	rebuild(quality)

func enable(enabled):
	if visible and not enabled:
		if navigation:
			navigation.enabled = false
		if navigation_safe:
			navigation_safe.enabled = false
		print_debug("GIProbe %s was disabled" % get_path())
	elif not visible and enabled:
		if navigation:
			navigation.enabled = true
		if navigation_safe:
			navigation_safe.enabled = true
		print_debug("GIProbe %s was enabled" % get_path())
	visible = enabled

func player_is_in_room(camera_global_origin = null):
	var origin = camera_global_origin
	if not origin:
		var camera = __PLDRT.game_state.get_cam()
		if not camera:
			return false
		origin = camera.get_global_transform().origin
	var aabb = get_aabb()
	var lo = to_local(origin)
	return lo.y > aabb.position.y - activator_add and lo.y < aabb.end.y + activator_add

func _physics_process(delta):
	if persistent or not __PLDRT.game_state.is_level_ready():
		return
	var camera = __PLDRT.game_state.get_cam()
	if not camera:
		enable(false)
		return
	var origin = camera.get_global_transform().origin
	enable(player_is_in_room(origin))
