tool
extends Area
class_name PLDWaterArea

export var water_width = 7.8
export var water_height = 7.8
export var water_depth = 7.8

onready var water_mesh = $WaterMesh
onready var collision_shape = $CollisionShape

func _ready():
	water_mesh.mesh.size.x = water_width
	water_mesh.mesh.size.y = water_height
	collision_shape.shape.extents.x = water_width / 2
	collision_shape.shape.extents.y = water_width / 2
	collision_shape.shape.extents.z = water_width / 2
	collision_shape.translation.y = -water_depth / 2

func _on_water_area_area_entered(area):
	if Engine.editor_hint:
		return
	if area.is_in_group("view_area"):
		__PLDRT.game_state.set_underwater(__PLDRT.game_state.get_player(), true)

func _on_water_area_area_exited(area):
	if Engine.editor_hint:
		return
	if area.is_in_group("view_area"):
		__PLDRT.game_state.set_underwater(__PLDRT.game_state.get_player(), false)
