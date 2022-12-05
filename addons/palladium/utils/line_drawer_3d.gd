extends ImmediateGeometry
class_name LineDrawer3D

enum LineType { LINES, STRIP }

export(LineType) var line_type = LineType.STRIP

var lines = []
var width = 0.2
var gap = 0.2

class Line:
	var start : Vector3
	var end : Vector3
	func _init(start, end):
		self.start = start
		self.end = end

func clear_lines():
	lines.clear()

func add_line(start : Vector3, end : Vector3):
	var line = Line.new(start, end)
	lines.push_back(line)

func draw_lines():
	clear()
	begin(Mesh.PRIMITIVE_LINES)
	for line in lines:
		add_vertex(line.start)
		add_vertex(line.end)
	end()

func draw_strip():
	clear()
	begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, null)
	for line in lines:
		var v = line.end - line.start
		var cv = Vector3.UP.cross(v).normalized() * width

		set_normal(Vector3(0, 1, 0))
		set_uv(Vector2(0, 1))
		add_vertex(line.start + gap * v + cv)

		set_normal(Vector3(0, 1, 0))
		set_uv(Vector2(1, 1))
		add_vertex(line.end - gap * v + cv)

		set_normal(Vector3(0, 1, 0))
		set_uv(Vector2(0, 0))
		add_vertex(line.start + gap * v - cv)

		set_normal(Vector3(0, 1, 0))
		set_uv(Vector2(1, 0))
		add_vertex(line.end - gap * v - cv)
		
	end()

func _process(delta):
	match line_type:
		LineType.LINES:
			draw_lines()
		LineType.STRIP:
			draw_strip()
