extends ImmediateGeometry
class_name PLDLineDrawer3D

const LINES_REROUTE_THRESHOLD = 0.9
const ALPHA_COEF = 0.96

enum LineType { LINES, STRIP }

export(LineType) var line_type = LineType.STRIP
export(float) var width = 0.2
export(float) var gap = 0.0

class Line:
	var start : Vector3
	var end : Vector3
	func _init(start, end):
		self.start = start
		self.end = end

class Lines:
	var lines = []
	var prev_lines = []
	var alpha = 1.0

var lines_map = {}

func lm(name_hint : String):
	if not lines_map.has(name_hint):
		lines_map[name_hint] = Lines.new()
	return lines_map[name_hint]

func remove_character(name_hint):
	if lines_map.has(name_hint):
		lines_map.erase(name_hint)

func reset_alpha(name_hint):
	lm(name_hint).alpha = 1.0

func clear_lines(name_hint : String):
	lm(name_hint).prev_lines.clear()
	lm(name_hint).prev_lines.append_array(lines_map[name_hint].lines)
	lm(name_hint).lines.clear()

func add_line(name_hint : String, start : Vector3, end : Vector3):
	var line = Line.new(start, end)
	lm(name_hint).lines.push_back(line)

func filter_first_prev_lines(name_hint : String):
	var l = lm(name_hint)
	while (
		not l.lines.empty()
		and not l.prev_lines.empty()
		and (l.lines[0].end - l.prev_lines[0].end).length() > LINES_REROUTE_THRESHOLD
	):
		l.prev_lines.pop_front()
	return l.lines.size() != l.prev_lines.size()

func lines_rerouted_at_index(name_hint : String, line : Line, i : int):
	var l = lm(name_hint)
	return (
		l.prev_lines.empty()
		or (line.end - l.prev_lines[i].end).length() > LINES_REROUTE_THRESHOLD
	)

func draw_lines(name_hint : String):
	if not lines_map.has(name_hint):
		return
	clear()
	var different_size = filter_first_prev_lines(name_hint)
	lm(name_hint).alpha *= ALPHA_COEF
	material_override.albedo_color.a = lm(name_hint).alpha
	begin(Mesh.PRIMITIVE_LINES)
	for i in range(0, lm(name_hint).lines.size()):
		var line = lm(name_hint).lines[i]
		if (different_size or lines_rerouted_at_index(name_hint, line, i)):
			lm(name_hint).alpha = 1.0
			material_override.albedo_color.a = 1.0
		add_vertex(line.start)
		add_vertex(line.end)
	end()

func draw_strip(name_hint : String):
	if not lines_map.has(name_hint):
		return
	clear()
	var different_size = filter_first_prev_lines(name_hint)
	lm(name_hint).alpha *= ALPHA_COEF
	material_override.albedo_color.a = lm(name_hint).alpha
	begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, null)
	for i in range(0, lm(name_hint).lines.size()):
		var line = lm(name_hint).lines[i]
		if (different_size or lines_rerouted_at_index(name_hint, line, i)):
			lm(name_hint).alpha = 1.0
			material_override.albedo_color.a = 1.0
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

func find_most_important_name_hint():
	var max_alpha = 0.0
	var name_hint = null
	for nh in lines_map:
		if ALPHA_COEF * lm(nh).alpha > max_alpha:
			max_alpha = lm(nh).alpha
			name_hint = nh
	return name_hint

func draw_most_important_line():
	var name_hint = find_most_important_name_hint()
	if name_hint:
		draw_lines(name_hint)

func draw_most_important_strip():
	var name_hint = find_most_important_name_hint()
	if name_hint:
		draw_strip(name_hint)

func _process(delta):
	match line_type:
		LineType.LINES:
			draw_most_important_line()
		LineType.STRIP:
			draw_most_important_strip()
