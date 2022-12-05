extends ImmediateGeometry
class_name LineDrawer3D

var points = []

func clear_points():
	points.clear()

func add_line(p1 : Vector3, p2 : Vector3):
	points.push_back(p1)
	points.push_back(p2)

func _process(delta):
	._process(delta)
	clear()
	begin(Mesh.PrimitiveType.Lines)
	for i in range(0, points.size()):
		add_vertex(points[i])
	end()
