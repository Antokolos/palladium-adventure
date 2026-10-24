extends SceneTree

# Measures the cost of enemies on the test building level (res://building.tscn).
# The player is placed in the lobby of the given floor, where no enemy can see
# him, and the average/max physics step time is printed.
#
# Usage (from the project root):
#   godot --no-window --path . -s res://test/performance/enemies_benchmark.gd
# Environment variables:
#   BENCH_FLOOR=<0..4>      floor index, 2 by default
#   BENCH_NO_ENEMIES=1      disable all enemies (to measure the fixed overhead)

const SCENE_PATH = "res://building.tscn"
const FLOOR_HEIGHT = 8.0
const WARMUP_S = 3.0
const MEASURE_FRAMES = 600

var t = 0.0
var stage = 0
var frames = 0
var acc_phys = 0.0
var acc_proc = 0.0
var max_phys = 0.0
var active_acc = 0
var no_enemies = OS.get_environment("BENCH_NO_ENEMIES") == "1"

func _initialize():
	change_scene(SCENE_PATH)

func _idle(delta):
	t += delta
	if no_enemies and stage > 0:
		for e in get_nodes_in_group("enemies"):
			e.set_process(false)
			e.set_physics_process(false)
	match stage:
		0:
			if t > 1.0:
				var floor_env = OS.get_environment("BENCH_FLOOR")
				var floor_idx = int(floor_env) if floor_env != "" else 2
				var level = current_scene.get_node("ViewportContainer/Viewport/Building")
				var player = level.get_node("player")
				player.global_transform.origin = Vector3(0, floor_idx * FLOOR_HEIGHT + 0.05, -3.5)
				stage = 1
				t = 0.0
		1:
			if t > WARMUP_S:
				stage = 2
		2:
			measure()

func measure():
	var p = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	acc_phys += p
	max_phys = max(max_phys, p)
	acc_proc += Performance.get_monitor(Performance.TIME_PROCESS)
	var active = 0
	for e in get_nodes_in_group("enemies"):
		if e.is_physics_processing():
			active += 1
	active_acc += active
	frames += 1
	if frames < MEASURE_FRAMES:
		return
	var aggressive = 0
	for e in get_nodes_in_group("enemies"):
		if e.is_aggressive():
			aggressive += 1
	print("BENCH physics_avg_ms=%.3f physics_max_ms=%.3f process_avg_ms=%.3f active_enemies_avg=%.1f aggressive=%d" % [
		acc_phys / frames * 1000.0,
		max_phys * 1000.0,
		acc_proc / frames * 1000.0,
		float(active_acc) / frames,
		aggressive
	])
	stage = 3
	quit()
