extends ImmediateGeometry
class_name LineDrawer3D

const LINES_REROUTE_THRESHOLD = 0.7
const ALPHA_COEF = 0.96

enum LineType { LINES, STRIP }

export(LineType) var line_type = LineType.STRIP

var lines = []
var prev_lines = []
var width = 0.2
var gap = 0.0
var alpha = 1.0

class Line:
	var start : Vector3
	var end : Vector3
	func _init(start, end):
		self.start = start
		self.end = end

func reset_alpha():
	alpha = 1.0

func clear_lines():
	prev_lines.clear()
	prev_lines.append_array(lines)
	lines.clear()

func add_line(start : Vector3, end : Vector3):
	var line = Line.new(start, end)
	lines.push_back(line)

func draw_lines():
	clear()
	while (
		not lines.empty()
		and not prev_lines.empty()
		and (lines[0].end - prev_lines[0].end).length() > LINES_REROUTE_THRESHOLD
	):
		prev_lines.pop_front()
	var different_size = lines.size() != prev_lines.size()
	alpha *= ALPHA_COEF
	material_override.albedo_color.a = alpha
	begin(Mesh.PRIMITIVE_LINES)
	for i in range(0, lines.size()):
		var line = lines[i]
		if (
			different_size
			or prev_lines.empty()
			or (line.end - prev_lines[i].end).length() > LINES_REROUTE_THRESHOLD
		):
			alpha = 1.0
		add_vertex(line.start)
		add_vertex(line.end)
	end()

func draw_strip():
	clear()
	while (
		not lines.empty()
		and not prev_lines.empty()
		and (lines[0].end - prev_lines[0].end).length() > LINES_REROUTE_THRESHOLD
	):
		prev_lines.pop_front()
	var different_size = lines.size() != prev_lines.size()
	alpha *= ALPHA_COEF
	material_override.albedo_color.a = alpha
	begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, null)
	for i in range(0, lines.size()):
		var line = lines[i]
		if (
			different_size
			or prev_lines.empty()
			or (line.end - prev_lines[i].end).length() > LINES_REROUTE_THRESHOLD
		):
			alpha = 1.0
		var v = line.end - line.start
		var cv = Vector3.UP.cross(v).normalized() * width

		set_normal(Vector3(0, 1, 0))
		set_uv(Vector2(0, 0))
		add_vertex(line.start + gap * v + cv)

		set_normal(Vector3(0, 1, 0))
		set_uv(Vector2(1, 0))
		add_vertex(line.end - gap * v + cv)

		set_normal(Vector3(0, 1, 0))
		set_uv(Vector2(0, 1))
		add_vertex(line.start + gap * v - cv)

		set_normal(Vector3(0, 1, 0))
		set_uv(Vector2(1, 1))
		add_vertex(line.end - gap * v - cv)
		
	end()

func _process(delta):
	match line_type:
		LineType.LINES:
			draw_lines()
		LineType.STRIP:
			draw_strip()
