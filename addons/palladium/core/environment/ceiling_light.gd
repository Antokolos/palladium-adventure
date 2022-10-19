extends Light

var shadow = true
var flicker = true
var max_light = 1.0

func _ready():
	randomize()

func toggle():
	visible = not visible

func enable(enable):
	visible = enable

func enable_shadow_if_needed(enable):
	set_shadow(shadow and enable)

func decrease_light():
	max_light = 0.5
	light_energy = max_light

func restore_light():
	max_light = 1.0
	light_energy = max_light

func set_quality_normal():
	shadow = false
	set_shadow(shadow)
	flicker = false

func set_quality_optimal():
	shadow = true
	set_shadow(shadow)
	flicker = false

func set_quality_good():
	shadow = true
	set_shadow(shadow)
	flicker = true

func set_quality_high():
	shadow = true
	set_shadow(shadow)
	flicker = true

func _process(delta):
	if not __PLDRT.game_state.is_level_ready():
		return
	if flicker:
		light_energy = rand_range(0.92 * max_light, max_light)
