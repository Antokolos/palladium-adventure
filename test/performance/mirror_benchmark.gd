extends SceneTree

# Measures the rendering cost of a mirror (addons/palladium/core/environment/mirror.tscn).
# A 3x2 m mirror is placed on the wall of the first floor lobby of the test
# building (res://building.tscn), enemies are hidden. Needs a real renderer,
# i.e. it does not work with the headless/server builds.
#
# Usage (from the project root):
#   godot --path . -s res://test/performance/mirror_benchmark.gd
# Environment variables:
#   MB_MODE=mirror     the player looks at the mirror (default)
#   MB_MODE=none       same view, no mirror
#   MB_MODE=away       the player turned away from the mirror, but stays in its activation area
#   MB_MODE=away_none  same view, no mirror
#   MB_MODE=far        the player is on another floor (mirror is not active)
#   MB_SHOT=<name>     save screenshots /tmp/<name>_view.png and /tmp/<name>_mirror.png instead of measuring

const SCENE_PATH = "res://building.tscn"
const MIRROR_PATH = "res://addons/palladium/core/environment/mirror.tscn"
const WARMUP_S = 3.0
const MEASURE_FRAMES = 300

var mode = OS.get_environment("MB_MODE") if OS.get_environment("MB_MODE") != "" else "mirror"
var shot = OS.get_environment("MB_SHOT")
var t = 0.0
var stage = 0
var frames = 0
var acc_ms = 0.0
var acc_draw = 0
var acc_obj = 0
var acc_vert = 0
var last_us = 0
var mirror = null

func _initialize():
	OS.vsync_enabled = false
	Engine.target_fps = 0
	change_scene(SCENE_PATH)

func _idle(delta):
	t += delta
	match stage:
		0:
			if t > 1.0:
				setup()
				stage = 1
				t = 0.0
		1:
			if t > WARMUP_S:
				if shot != "":
					save_screenshots()
					quit()
					return
				stage = 2
				last_us = OS.get_ticks_usec()
		2:
			measure()

func setup():
	var level = current_scene.get_node("ViewportContainer/Viewport/Building")
	for e in get_nodes_in_group("enemies"):
		e.visible = false
		e.set_process(false)
		e.set_physics_process(false)
	var player = level.get_node("player")
	match mode:
		"away", "away_none":
			player.global_transform = Transform(Basis(), Vector3(0, 0.05, -2.0))
		"far":
			player.global_transform = Transform(Basis(), Vector3(15.0, 8.05, 0))
		_:
			player.global_transform = Transform(Basis(Vector3.UP, PI), Vector3(0, 0.05, -2.0))
	if not mode.ends_with("none"):
		mirror = load(MIRROR_PATH).instance()
		mirror.transform = Transform(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 1.6, -6.68))
		level.add_child(mirror)

func save_screenshots():
	var img = current_scene.get_node("ViewportContainer/Viewport").get_texture().get_data()
	img.flip_y()
	img.save_png("/tmp/%s_view.png" % shot)
	if mirror:
		var mi = mirror.get_node("Viewport").get_texture().get_data()
		mi.flip_y()
		mi.save_png("/tmp/%s_mirror.png" % shot)

func measure():
	var now = OS.get_ticks_usec()
	acc_ms += (now - last_us) / 1000.0
	last_us = now
	frames += 1
	acc_draw += Performance.get_monitor(Performance.RENDER_DRAW_CALLS_IN_FRAME)
	acc_obj += Performance.get_monitor(Performance.RENDER_OBJECTS_IN_FRAME)
	acc_vert += Performance.get_monitor(Performance.RENDER_VERTICES_IN_FRAME)
	if frames < MEASURE_FRAMES:
		return
	var vs = mirror.get_node("Viewport").size if mirror else Vector2()
	print("MBENCH mode=%s frame_avg_ms=%.2f draw_calls=%d objects=%d vertices=%d mirror_viewport=%dx%d" % [
		mode, acc_ms / frames, acc_draw / frames, acc_obj / frames, acc_vert / frames, vs.x, vs.y
	])
	stage = 3
	quit()
