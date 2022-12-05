extends ImmediateGeometry
class_name LineDrawer3D

enum LineType { LINES, STRIP }

export(LineType) var line_type = LineType.STRIP

var points = []
var width = 0.2
var gap = 0.2
#var color = Color(0, 1, 0, 1)

func clear_points():
	points.clear()

func add_line(p1 : Vector3, p2 : Vector3):
	points.push_back(p1)
	points.push_back(p2)

func draw_lines():
	clear()
	begin(Mesh.PRIMITIVE_LINES)
	for i in range(0, points.size()):
		add_vertex(points[i])
	end()

func draw_strip():
	clear()
	begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, null)

	for i in range(1, points.size(), 2):
		var v = points[i] - points[i - 1]
		var cv = Vector3.UP.cross(v).normalized() * width
		
		set_normal(Vector3(0, 1, 0))
		set_uv(Vector2(0, 1))
		add_vertex(points[i - 1] + gap * v - cv)

		set_normal(Vector3(0, 1, 0))
		set_uv(Vector2(1, 1))
		add_vertex(points[i - 1] + gap * v + cv)

		set_normal(Vector3(0, 1, 0))
		set_uv(Vector2(0, 0))
		add_vertex(points[i] - gap * v - cv)

		set_normal(Vector3(0, 1, 0))
		set_uv(Vector2(1, 0))
		add_vertex(points[i] - gap * v + cv)
		
	end()

func _process(delta):
	match line_type:
		LineType.LINES:
			draw_lines()
		LineType.STRIP:
			draw_strip()
