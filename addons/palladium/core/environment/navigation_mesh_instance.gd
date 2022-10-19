extends NavigationMeshInstance
class_name PLDNavigationMeshInstance

var needs_bake = false
var baking_now = false

func _ready():
	connect("bake_finished", self, "_on_bake_finished")

func _on_bake_finished():
	if needs_bake:
		needs_bake = false
		baking_now = true
		bake_navigation_mesh()
	else:
		baking_now = false

func try_bake_navigation_mesh():
	if baking_now:
		needs_bake = true
	else:
		baking_now = true
		bake_navigation_mesh()
