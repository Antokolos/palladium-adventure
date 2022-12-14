extends Node
class_name PLDTacticalCameraMovement

var camera_movement = {}

func create_ok():
	return with_result(true).with_push_back_vector(Vector3.ZERO)

func create_error(push_back_vector : Vector3 = Vector3.ZERO):
	return with_result(false).with_push_back_vector(push_back_vector)

func get_data(key : String):
	return camera_movement[key] if camera_movement.has(key) else null

func with_result(result : bool):
	camera_movement["result"] = result
	return self

func get_result():
	return get_data("result")

func with_point(point : Vector3):
	camera_movement["point"] = point
	return self

func get_point():
	return get_data("point")

func with_push_back_vector(push_back_vector : Vector3):
	camera_movement["push_back_vector"] = push_back_vector
	return self

func get_push_back_vector():
	return get_data("push_back_vector")
