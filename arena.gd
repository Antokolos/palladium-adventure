extends PLDLevel

const HTerrainData = preload("res://addons/zylann.hterrain/hterrain_data.gd")

onready var _terrain = get_node("arena_scene/PLDNavigationMeshInstance/HTerrain")

var _resolution : int = 0
var _heights : PoolRealArray = []
var show_grid = false

func _ready():
	if not show_grid:
		return
	var data : HTerrainData = _terrain.get_data()
	_resolution = data.get_resolution()
	_heights = data.get_all_heights()
	for x in range(0, 1000, 20):
		for z in range(0, 1000, 20):
			var h = get_height_at(x, z)
			var mi = MeshInstance.new()
			mi.mesh = SphereMesh.new()
			add_child(mi)
			mi.global_transform.origin = Vector3(x, h, z)

func get_height_at(x : int, z : int):
	var idx = x + z * _resolution
	if idx >= _heights.size():
		return -9999
	return _heights[idx]
