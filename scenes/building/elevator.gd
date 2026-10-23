extends Spatial

# Simple elevator for the test building.
#
# Expected node structure:
#   elevator (this script)
#     cabin (KinematicBody)          -- moves vertically, has floor/walls collisions
#       passengers (Area)            -- everybody inside is carried together with the cabin
#     doors (Spatial)
#       floor_N (Spatial)            -- one per floor, N = 0..floors_count-1
#         left (StaticBody)          -- sliding door halves
#         right (StaticBody)
#     Tween
#
# Passengers are moved explicitly together with the cabin instead of relying on
# move_and_slide() floor velocity, because Palladium characters do not call
# move_and_slide() while standing still.

enum State { IDLE, CLOSING, MOVING, OPENING }

export(int) var floors_count = 5
export(float) var floor_height = 4.0
export(float) var speed = 2.0
export(float) var door_time = 0.6
export(float) var door_slide = 1.0
export(int) var initial_floor = 0

onready var cabin = $cabin
onready var passengers_area = $cabin/passengers
onready var doors_root = $doors
onready var tween = $Tween

var state = State.IDLE
var current_floor = 0
var target_floor = 0
var queue = []
var doors_closed_x = {}

func _ready():
	tween.connect("tween_all_completed", self, "_on_tween_all_completed")
	current_floor = clamp_floor(initial_floor)
	target_floor = current_floor
	cabin.translation.y = get_floor_y(current_floor)
	for i in range(floors_count):
		var door_node = get_door_node(i)
		if not door_node:
			continue
		doors_closed_x[i] = [ door_node.get_node("left").translation.x, door_node.get_node("right").translation.x ]
		set_doors_opened_immediately(i, i == current_floor)
	set_physics_process(false)

func clamp_floor(floor_idx):
	return int(clamp(floor_idx, 0, floors_count - 1))

func get_floor_y(floor_idx):
	return floor_idx * floor_height

func get_door_node(floor_idx):
	var path = "floor_%d" % floor_idx
	return doors_root.get_node(path) if doors_root.has_node(path) else null

func get_current_floor():
	return current_floor

func is_moving():
	return state != State.IDLE

### Public API ###

func request_floor(floor_idx):
	floor_idx = clamp_floor(floor_idx)
	if state == State.IDLE and floor_idx == current_floor:
		return
	if state != State.IDLE and floor_idx == target_floor:
		return
	if not queue.has(floor_idx):
		queue.append(floor_idx)
	if state == State.IDLE:
		start_next_trip()

### Internals ###

func start_next_trip():
	while not queue.empty():
		var next_floor = queue.pop_front()
		if next_floor != current_floor:
			target_floor = next_floor
			state = State.CLOSING
			animate_doors(current_floor, false)
			return
	state = State.IDLE

func set_doors_opened_immediately(floor_idx, opened):
	var door_node = get_door_node(floor_idx)
	if not door_node:
		return
	var closed_x = doors_closed_x[floor_idx]
	door_node.get_node("left").translation.x = closed_x[0] - (door_slide if opened else 0.0)
	door_node.get_node("right").translation.x = closed_x[1] + (door_slide if opened else 0.0)

func animate_doors(floor_idx, opened):
	var door_node = get_door_node(floor_idx)
	if not door_node:
		call_deferred("_on_tween_all_completed")
		return
	var closed_x = doors_closed_x[floor_idx]
	var left = door_node.get_node("left")
	var right = door_node.get_node("right")
	var left_x = closed_x[0] - (door_slide if opened else 0.0)
	var right_x = closed_x[1] + (door_slide if opened else 0.0)
	tween.interpolate_property(
		left, "translation:x", left.translation.x, left_x,
		door_time, Tween.TRANS_SINE, Tween.EASE_IN_OUT
	)
	tween.interpolate_property(
		right, "translation:x", right.translation.x, right_x,
		door_time, Tween.TRANS_SINE, Tween.EASE_IN_OUT
	)
	tween.start()

func _on_tween_all_completed():
	match state:
		State.CLOSING:
			state = State.MOVING
			set_physics_process(true)
		State.OPENING:
			state = State.IDLE
			start_next_trip()

func move_cabin(dy):
	if dy == 0.0:
		return
	var offset = Vector3(0, dy, 0)
	for body in passengers_area.get_overlapping_bodies():
		if body is KinematicBody and body.get_instance_id() != cabin.get_instance_id():
			body.global_translate(offset)
	cabin.global_translate(offset)

func _physics_process(delta):
	if state != State.MOVING:
		set_physics_process(false)
		return
	var target_y = get_floor_y(target_floor)
	var diff = target_y - cabin.translation.y
	var step = speed * delta
	move_cabin(clamp(diff, -step, step))
	if abs(target_y - cabin.translation.y) < 0.001:
		move_cabin(target_y - cabin.translation.y)
		current_floor = target_floor
		state = State.OPENING
		set_physics_process(false)
		animate_doors(current_floor, true)
