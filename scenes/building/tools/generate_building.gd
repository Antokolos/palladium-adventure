extends SceneTree

# Generates res://building.tscn — the test level with a 5-storey building.
#
# Usage (from the project root):
#   godot --no-window --path . -s res://scenes/building/tools/generate_building.gd
#
# Layout of every floor (top view, X to the right, Z down):
#
#   +---------------------+---------------+---------------------+  Z = -7
#   |                     |               |                     |
#   |     left wing       D     lobby     D     right wing      |
#   |    (4 enemies)      |    [door]     |    (4 enemies)      |
#   |                     |   [shaft ]    |                     |
#   +---------------------+---------------+---------------------+  Z = +7
#  X = -26              X = -5          X = +5                X = +26
#
# Everything except the player and the enemies is built from engine primitives
# (CubeMesh + BoxShape). The navigation mesh is baked here, so the level does
# not need to bake it at runtime.
#
# The generated scene is meant to be identical to what the Godot editor writes
# when the scene is opened and saved, i.e. properties that have their default
# values are not stored. Two mechanisms are used for that:
#   1. Engine.editor_hint is enabled before anything is built, so that
#      PackedScene.pack() knows the default values of exported script
#      variables (outside the editor GDScript does not track them and every
#      exported variable gets written).
#   2. Some scripts cannot be fully analyzed in this mode (e.g. camera.gd and
#      hud.gd use PLDSettings constants in match patterns, which cannot be
#      resolved without the running __PLDRT singleton). For instanced scenes
#      the saved file is therefore post-processed: properties equal to the
#      values of a freshly instanced scene are removed.

const OUTPUT_PATH = "res://building.tscn"

const FLOORS = 5
const ROOM_H = 4.0                 # floor top -> ceiling top
const GAP_H = 4.0                  # empty space between a ceiling and the next floor slab
const SLAB_T = 0.2
const FLOOR_H = ROOM_H + GAP_H     # vertical distance between floors (elevator stops)
const WALL_H = ROOM_H - SLAB_T     # interior height of a room
const GAP_WALL_H = FLOOR_H - SLAB_T  # outer/shaft walls also close the gap up to the next slab
const WALL_T = 0.3

const HALF_X = 26.0
const HALF_Z = 7.0
const PARTITION_X = 5.0
const DOORWAY_HALF_W = 1.5
const DOORWAY_H = 2.6

# Elevator shaft (inner space), located at the back of the lobby
const SHAFT_HALF_X = 1.6
const SHAFT_Z0 = 3.0
const SHAFT_Z1 = HALF_Z - WALL_T
const SHAFT_FRONT_HALF_X = 2.2
const SHAFT_DOOR_HALF_W = 1.0
const SHAFT_DOOR_H = 2.6

# Enemies are placed deep enough in the wings so that they are farther than
# PLDEnemy.AGGRESSION_RANGE (12) from the elevator exit and from the lobby
# center; the player has to approach the doorway to be noticed.
const ENEMIES_PER_WING = [
	Vector3(14.0, 0.0, -3.5),
	Vector3(16.5, 0.0, 3.5),
	Vector3(20.0, 0.0, -3.5),
	Vector3(23.0, 0.0, 3.5),
]
const PILLARS_PER_WING = [ Vector3(10.0, 0, 0), Vector3(18.5, 0, 0) ]

# Collision setup, the same as in other Palladium levels:
#   walls:   layer bits 0, 1;  mask bits 0, 1
#   floor:   layer bit 2;      mask bits 0-3, 10-13
#   ceiling: layer bits 0, 10 (Default + Ceiling Hint), so that it blocks
#            characters and visibility rays, but is not parsed into the navmesh
const LAYER_WALLS = 3          # bits 0, 1
const MASK_WALLS = 3           # bits 0, 1
const LAYER_FLOOR = 4          # bit 2
const MASK_FLOOR = 15375       # bits 0-3, 10-13
const LAYER_CEILING = 1025     # bits 0, 10
const MASK_CEILING = 15375
const NAVMESH_PARSE_MASK = 6   # bits 1 (walls) and 2 (floor) only
const LAYER_USE_TARGET = 128   # bit 7
const LAYER_PLAYER = 2048      # bit 11
const LAYER_ENEMY = 4096       # bit 12

const FLOOR_COLORS = [
	Color(0.78, 0.70, 0.58),
	Color(0.62, 0.74, 0.62),
	Color(0.60, 0.68, 0.82),
	Color(0.80, 0.64, 0.64),
	Color(0.74, 0.66, 0.82),
]

var scene_root : Control
var mesh_cache = {}
var shape_cache = {}
var mat_floor : SpatialMaterial
var mat_shaft : SpatialMaterial
var mat_cabin : SpatialMaterial
var mat_door : SpatialMaterial
var mat_button : SpatialMaterial
var mat_pillar : SpatialMaterial
var mat_walls = []
var font : Font

func _init():
	Engine.editor_hint = true

func _initialize():
	var err = generate()
	if err != OK:
		printerr("Building generation failed: %d" % err)
	quit()

func generate():
	mat_floor = make_material(Color(0.45, 0.45, 0.47))
	mat_shaft = make_material(Color(0.30, 0.30, 0.33))
	mat_cabin = make_material(Color(0.72, 0.74, 0.78), 0.6, 0.35)
	mat_door = make_material(Color(0.42, 0.50, 0.62), 0.7, 0.3)
	mat_button = make_material(Color(0.95, 0.75, 0.15))
	mat_button.emission_enabled = true
	mat_button.emission = Color(0.6, 0.4, 0.0)
	mat_pillar = make_material(Color(0.55, 0.52, 0.50))
	for c in FLOOR_COLORS:
		mat_walls.append(make_material(c))
	font = load("res://addons/palladium/styles/menu_font.tres")

	scene_root = Control.new()
	scene_root.name = "HUD"
	scene_root.anchor_right = 1.0
	scene_root.anchor_bottom = 1.0
	scene_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene_root.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vc = ViewportContainer.new()
	vc.name = "ViewportContainer"
	vc.anchor_right = 1.0
	vc.anchor_bottom = 1.0
	vc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vc.stretch = true
	vc.set_script(load("res://addons/palladium/ui/game_window.gd"))
	add(scene_root, vc)

	var viewport = load("res://addons/palladium/ui/viewport.tscn").instance(PackedScene.GEN_EDIT_STATE_INSTANCE)
	viewport.size = Vector2(1920, 1080)
	# ViewportContainer with stretch switches it to UPDATE_ALWAYS anyway, and the
	# editor writes this value on save, so it is set here to avoid diffs
	viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	add(vc, viewport)

	var level = Navigation.new()
	level.name = "Building"
	level.set_script(load("res://building.gd"))
	level.is_inside = true
	level.is_bright = true
	level.cam_path = NodePath("camera")
	add(viewport, level)

	add_environment(level)

	# Static geometry is built in a separate subtree that is added to the
	# SceneTree temporarily: NavigationMeshGenerator needs global transforms.
	var nmi = build_static_geometry()
	get_root().add_child(nmi)
	NavigationMeshGenerator.bake(nmi.navmesh, nmi)
	get_root().remove_child(nmi)
	var polys = nmi.navmesh.get_polygon_count()
	print("Navigation mesh baked: %d polygons" % polys)
	if polys == 0:
		return ERR_BUG
	add(level, nmi)

	add_lights(level)
	add_elevator(level)
	add_enemies(level)
	add_player_and_camera(level)

	var hud = load("res://addons/palladium/ui/hud.tscn").instance(PackedScene.GEN_EDIT_STATE_INSTANCE)
	add(scene_root, hud)

	var packed = PackedScene.new()
	var err = packed.pack(scene_root)
	if err != OK:
		return err
	err = ResourceSaver.save(OUTPUT_PATH, packed)
	scene_root.free()
	if err != OK:
		return err
	err = strip_instance_defaults(OUTPUT_PATH)
	if err == OK:
		print("Saved %s" % OUTPUT_PATH)
	return err

### Removing default values of instanced scenes ###

var instance_defaults_cache = {}

func get_instance_defaults(scene_path):
	if instance_defaults_cache.has(scene_path):
		return instance_defaults_cache[scene_path]
	var result = {}
	var inst = load(scene_path).instance()
	for p in inst.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE:
			result[p.name] = var2str(inst.get(p.name))
	inst.free()
	instance_defaults_cache[scene_path] = result
	return result

# Removes "key = value" lines from [node ... instance=...] sections, when the
# value equals the one of a freshly instanced scene. Sections that override the
# script are left as is: their defaults come from the new script, and these are
# already handled by pack() thanks to Engine.editor_hint.
func strip_instance_defaults(path):
	var f = File.new()
	var err = f.open(path, File.READ)
	if err != OK:
		return err
	var lines = f.get_as_text().split("\n")
	f.close()

	var re_ext = RegEx.new()
	re_ext.compile("^\\[ext_resource path=\"([^\"]+)\" type=\"PackedScene\" id=(\\d+)\\]")
	var re_inst = RegEx.new()
	re_inst.compile("^\\[node .* instance=ExtResource\\( (\\d+) \\)\\]")
	var scenes = {}
	for line in lines:
		var m = re_ext.search(line)
		if m:
			scenes[m.get_string(2)] = m.get_string(1)

	var out = PoolStringArray()
	var section = []
	var defaults = null
	var removed = 0
	for i in range(lines.size() + 1):
		var line = lines[i] if i < lines.size() else "["
		if line.begins_with("["):
			# Flush the previous section
			var overrides_script = false
			for l in section:
				if l.begins_with("script = "):
					overrides_script = true
			for l in section:
				if defaults != null and not overrides_script:
					var eq = l.find(" = ")
					if eq > 0:
						var key = l.substr(0, eq)
						var val = l.substr(eq + 3)
						if defaults.has(key) and defaults[key] == val:
							removed += 1
							continue
				out.append(l)
			section = []
			defaults = null
			if i == lines.size():
				break
			var mi = re_inst.search(line)
			if mi and scenes.has(mi.get_string(1)):
				defaults = get_instance_defaults(scenes[mi.get_string(1)])
			out.append(line)
		else:
			section.append(line)

	err = f.open(path, File.WRITE)
	if err != OK:
		return err
	f.store_string(out.join("\n"))
	f.close()
	print("Removed %d default values of instanced scenes" % removed)
	return OK

### Helpers ###

func make_material(color, metallic = 0.0, roughness = 0.9):
	var m = SpatialMaterial.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

func add(parent, node):
	parent.add_child(node)
	set_owner_recursive(node)
	return node

# Instanced scenes keep their own internals, so only the instance scene_root gets the owner.
func set_owner_recursive(node):
	node.owner = scene_root if node != scene_root else null
	if node.filename != "":
		return
	for ch in node.get_children():
		set_owner_recursive(ch)

func key_of(size : Vector3):
	return "%.3f_%.3f_%.3f" % [size.x, size.y, size.z]

func get_mesh(size : Vector3):
	var k = key_of(size)
	if not mesh_cache.has(k):
		var m = CubeMesh.new()
		m.size = size
		mesh_cache[k] = m
	return mesh_cache[k]

func get_shape(size : Vector3):
	var k = key_of(size)
	if not shape_cache.has(k):
		var s = BoxShape.new()
		s.extents = size * 0.5
		shape_cache[k] = s
	return shape_cache[k]

# Creates a mesh + collision box. Coordinates are given as min/max corners.
func make_box(node_name, from : Vector3, to : Vector3, material, layer, body_type = "static"):
	var size = (to - from).abs()
	var center = (from + to) * 0.5
	var body
	match body_type:
		"static":
			body = StaticBody.new()
		"none":
			body = Spatial.new()
	body.name = node_name
	body.translation = center
	if body is CollisionObject:
		body.collision_layer = layer
		body.collision_mask = mask_for_layer(layer)
		var cs = CollisionShape.new()
		cs.name = "CollisionShape"
		cs.shape = get_shape(size)
		body.add_child(cs)
	var mi = MeshInstance.new()
	mi.name = "MeshInstance"
	mi.mesh = get_mesh(size)
	mi.material_override = material
	body.add_child(mi)
	return body

func mask_for_layer(layer):
	match layer:
		LAYER_WALLS:
			return MASK_WALLS
		LAYER_FLOOR:
			return MASK_FLOOR
		LAYER_CEILING:
			return MASK_CEILING
	return 0

# Same as make_box, but adds shapes and meshes directly into an existing body
func add_box_to_body(body, part_name, from : Vector3, to : Vector3, material):
	var size = (to - from).abs()
	var center = (from + to) * 0.5
	var cs = CollisionShape.new()
	cs.name = part_name + "_shape"
	cs.shape = get_shape(size)
	cs.translation = center
	body.add_child(cs)
	var mi = MeshInstance.new()
	mi.name = part_name + "_mesh"
	mi.mesh = get_mesh(size)
	mi.material_override = material
	mi.translation = center
	body.add_child(mi)

func make_label(text, pixel_size, pos : Vector3, yaw_deg):
	var l = Label3D.new()
	l.name = "Label_" + text
	l.text = text
	l.font = font
	l.pixel_size = pixel_size
	l.modulate = Color(0.1, 0.1, 0.1)
	l.outline_modulate = Color(1, 1, 1, 0.8)
	l.transform = Transform(Basis(Vector3.UP, deg2rad(yaw_deg)), pos)
	return l

### Environment and lights ###

func add_environment(level):
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.11)
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 0.35
	var we = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add(level, we)

func add_lights(level):
	var lights = Spatial.new()
	lights.name = "lights"
	add(level, lights)
	for f in range(FLOORS):
		var y = f * FLOOR_H + WALL_H - 0.6
		for p in [ Vector3(0, y, -2.0), Vector3(-15.5, y, 0), Vector3(15.5, y, 0) ]:
			var l = OmniLight.new()
			l.name = "light_%d_%s" % [f, "lobby" if p.x == 0 else ("left" if p.x < 0 else "right")]
			l.translation = p
			l.omni_range = 13.0 if p.x != 0 else 8.0
			l.light_energy = 1.0
			l.shadow_enabled = false
			lights.add_child(l)
	set_owner_recursive(lights)

### Static geometry ###

func build_static_geometry():
	var nm = NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = NAVMESH_PARSE_MASK
	nm.agent_radius = 0.4
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.3
	nm.sample_partition_type = NavigationMesh.SAMPLE_PARTITION_MONOTONE

	var nmi = NavigationMeshInstance.new()
	nmi.name = "PLDNavigationMeshInstance"
	nmi.navmesh = nm
	nmi.set_script(load("res://addons/palladium/core/environment/navigation_mesh_instance.gd"))

	for f in range(FLOORS):
		var floor_node = Spatial.new()
		floor_node.name = "floor_%d" % (f + 1)
		floor_node.translation = Vector3(0, f * FLOOR_H, 0)
		nmi.add_child(floor_node)
		build_floor(floor_node, f)
	# Bottom of the elevator pit
	nmi.add_child(make_box(
		"shaft_pit",
		Vector3(-SHAFT_FRONT_HALF_X, -0.8, SHAFT_Z0),
		Vector3(SHAFT_FRONT_HALF_X, -0.6, HALF_Z),
		mat_shaft, LAYER_FLOOR
	))
	return nmi

func build_floor(fnode, f):
	var mw = mat_walls[f]
	var t = WALL_T
	var h = WALL_H
	var is_top = f == FLOORS - 1
	# Outer and shaft walls go up to the next floor slab, closing the gap
	var oh = h if is_top else GAP_WALL_H
	var sx = SHAFT_HALF_X + t  # outer half width of the shaft side walls

	# Floor slab with a hole for the elevator shaft
	fnode.add_child(make_box("slab_left", Vector3(-HALF_X, -SLAB_T, -HALF_Z), Vector3(-sx, 0, HALF_Z), mat_floor, LAYER_FLOOR))
	fnode.add_child(make_box("slab_right", Vector3(sx, -SLAB_T, -HALF_Z), Vector3(HALF_X, 0, HALF_Z), mat_floor, LAYER_FLOOR))
	fnode.add_child(make_box("slab_middle", Vector3(-sx, -SLAB_T, -HALF_Z), Vector3(sx, 0, SHAFT_Z0), mat_floor, LAYER_FLOOR))

	# Ceiling (the top one also covers the shaft and serves as the roof)
	if is_top:
		fnode.add_child(make_box("ceiling", Vector3(-HALF_X, h, -HALF_Z), Vector3(HALF_X, h + SLAB_T, HALF_Z), mat_floor, LAYER_CEILING))
	else:
		fnode.add_child(make_box("ceiling_left", Vector3(-HALF_X, h, -HALF_Z), Vector3(-sx, h + SLAB_T, HALF_Z), mat_floor, LAYER_CEILING))
		fnode.add_child(make_box("ceiling_right", Vector3(sx, h, -HALF_Z), Vector3(HALF_X, h + SLAB_T, HALF_Z), mat_floor, LAYER_CEILING))
		fnode.add_child(make_box("ceiling_middle", Vector3(-sx, h, -HALF_Z), Vector3(sx, h + SLAB_T, SHAFT_Z0), mat_floor, LAYER_CEILING))

	# Outer walls
	fnode.add_child(make_box("wall_front", Vector3(-HALF_X, 0, -HALF_Z), Vector3(HALF_X, oh, -HALF_Z + t), mw, LAYER_WALLS))
	fnode.add_child(make_box("wall_back", Vector3(-HALF_X, 0, HALF_Z - t), Vector3(HALF_X, oh, HALF_Z), mw, LAYER_WALLS))
	fnode.add_child(make_box("wall_left", Vector3(-HALF_X, 0, -HALF_Z + t), Vector3(-HALF_X + t, oh, HALF_Z - t), mw, LAYER_WALLS))
	fnode.add_child(make_box("wall_right", Vector3(HALF_X - t, 0, -HALF_Z + t), Vector3(HALF_X, oh, HALF_Z - t), mw, LAYER_WALLS))

	# Partitions between the lobby and the wings, with doorways
	for side in [ -1, 1 ]:
		var x0 = side * PARTITION_X - t * 0.5
		var x1 = side * PARTITION_X + t * 0.5
		var sname = "left" if side < 0 else "right"
		fnode.add_child(make_box("partition_%s_front" % sname, Vector3(x0, 0, -HALF_Z + t), Vector3(x1, h, -DOORWAY_HALF_W), mw, LAYER_WALLS))
		fnode.add_child(make_box("partition_%s_back" % sname, Vector3(x0, 0, DOORWAY_HALF_W), Vector3(x1, h, HALF_Z - t), mw, LAYER_WALLS))
		fnode.add_child(make_box("partition_%s_lintel" % sname, Vector3(x0, DOORWAY_H, -DOORWAY_HALF_W), Vector3(x1, h, DOORWAY_HALF_W), mw, LAYER_WALLS))
		# Pillars in the wings (cover for the player)
		for p in PILLARS_PER_WING:
			var px = side * p.x
			fnode.add_child(make_box(
				"pillar_%s_%d" % [sname, int(p.x)],
				Vector3(px - 0.35, 0, p.z - 0.35), Vector3(px + 0.35, h, p.z + 0.35),
				mat_pillar, LAYER_WALLS
			))

	# Elevator shaft walls (side walls also cover the slab gap below)
	fnode.add_child(make_box("shaft_left", Vector3(-sx, -SLAB_T, SHAFT_Z0), Vector3(-SHAFT_HALF_X, oh, SHAFT_Z1), mat_shaft, LAYER_WALLS))
	fnode.add_child(make_box("shaft_right", Vector3(SHAFT_HALF_X, -SLAB_T, SHAFT_Z0), Vector3(sx, oh, SHAFT_Z1), mat_shaft, LAYER_WALLS))
	if not is_top:
		# Front wall of the shaft in the gap between floors
		fnode.add_child(make_box("shaft_front_gap", Vector3(-sx, h + SLAB_T, SHAFT_Z0 - t), Vector3(sx, oh, SHAFT_Z0), mat_shaft, LAYER_WALLS))
	var fz0 = SHAFT_Z0 - t
	fnode.add_child(make_box("shaft_front_left", Vector3(-SHAFT_FRONT_HALF_X, 0, fz0), Vector3(-SHAFT_DOOR_HALF_W, h, SHAFT_Z0), mat_shaft, LAYER_WALLS))
	fnode.add_child(make_box("shaft_front_right", Vector3(SHAFT_DOOR_HALF_W, 0, fz0), Vector3(SHAFT_FRONT_HALF_X, h, SHAFT_Z0), mat_shaft, LAYER_WALLS))
	fnode.add_child(make_box("shaft_front_lintel", Vector3(-SHAFT_DOOR_HALF_W, SHAFT_DOOR_H, fz0), Vector3(SHAFT_DOOR_HALF_W, h, SHAFT_Z0), mat_shaft, LAYER_WALLS))

	# Floor number above the elevator door
	fnode.add_child(make_label(str(f + 1), 0.02, Vector3(0, SHAFT_DOOR_H + 0.55, fz0 - 0.02), 180))

### Elevator ###

func add_elevator(level):
	var el = Spatial.new()
	el.name = "elevator"
	el.set_script(load("res://scenes/building/elevator.gd"))
	el.floors_count = FLOORS
	el.floor_height = FLOOR_H
	el.initial_floor = 0
	el.speed = 3.0
	var cabin_z = (SHAFT_Z0 + SHAFT_Z1) * 0.5 - 0.025
	el.translation = Vector3(0, 0, cabin_z)

	# Cabin: one KinematicBody with floor, walls and ceiling
	var cabin = KinematicBody.new()
	cabin.name = "cabin"
	cabin.collision_layer = LAYER_WALLS | LAYER_FLOOR
	cabin.collision_mask = MASK_WALLS | MASK_FLOOR
	el.add_child(cabin)
	var hx = SHAFT_HALF_X - 0.05
	var z0 = SHAFT_Z0 - cabin_z            # cabin front edge, flush with the landing
	var z1 = SHAFT_Z1 - 0.05 - cabin_z
	var ch = 3.0
	add_box_to_body(cabin, "floor", Vector3(-hx, -SLAB_T, z0), Vector3(hx, 0, z1), mat_cabin)
	add_box_to_body(cabin, "back", Vector3(-hx, 0, z1 - 0.1), Vector3(hx, ch, z1), mat_cabin)
	add_box_to_body(cabin, "left", Vector3(-hx, 0, z0), Vector3(-hx + 0.1, ch, z1 - 0.1), mat_cabin)
	add_box_to_body(cabin, "right", Vector3(hx - 0.1, 0, z0), Vector3(hx, ch, z1 - 0.1), mat_cabin)
	add_box_to_body(cabin, "ceiling", Vector3(-hx, ch, z0), Vector3(hx, ch + 0.1, z1), mat_cabin)

	var cabin_light = OmniLight.new()
	cabin_light.name = "light"
	cabin_light.translation = Vector3(0, ch - 0.3, 0)
	cabin_light.omni_range = 4.0
	cabin_light.light_energy = 0.8
	cabin.add_child(cabin_light)

	var passengers = Area.new()
	passengers.name = "passengers"
	passengers.collision_layer = 0
	passengers.collision_mask = LAYER_PLAYER | LAYER_ENEMY
	passengers.monitorable = false
	passengers.input_ray_pickable = false
	var pcs = CollisionShape.new()
	pcs.name = "CollisionShape"
	var psize = Vector3(hx * 2 - 0.3, 2.6, (z1 - z0) - 0.3)
	pcs.shape = get_shape(psize)
	pcs.translation = Vector3(0, 1.4, (z0 + z1) * 0.5)
	passengers.add_child(pcs)
	cabin.add_child(passengers)

	# Floor buttons on the right wall of the cabin, facing inside
	var buttons = Spatial.new()
	buttons.name = "buttons"
	cabin.add_child(buttons)
	for f in range(FLOORS):
		var b = make_button("button_%d" % (f + 1), f, Vector3(0.05, 0.16, 0.16))
		b.translation = Vector3(hx - 0.125, 0.9 + 0.22 * f, z0 + 0.6)
		b.add_child(make_label(str(f + 1), 0.006, Vector3(-0.03, 0, 0), -90))
		buttons.add_child(b)

	# Landing doors and call buttons
	var doors = Spatial.new()
	doors.name = "doors"
	el.add_child(doors)
	var dz = SHAFT_Z0 - WALL_T * 0.5 - cabin_z
	for f in range(FLOORS):
		var fd = Spatial.new()
		fd.name = "floor_%d" % f
		fd.translation = Vector3(0, f * FLOOR_H, 0)
		doors.add_child(fd)
		var w = SHAFT_DOOR_HALF_W
		var left = make_box("left", Vector3(-w, 0, dz - 0.05), Vector3(0, SHAFT_DOOR_H, dz + 0.05), mat_door, LAYER_WALLS)
		var right = make_box("right", Vector3(0, 0, dz - 0.05), Vector3(w, SHAFT_DOOR_H, dz + 0.05), mat_door, LAYER_WALLS)
		fd.add_child(left)
		fd.add_child(right)
		var cb = make_button("call_button", f, Vector3(0.16, 0.16, 0.05))
		cb.translation = Vector3(SHAFT_DOOR_HALF_W + 0.45, 1.2, SHAFT_Z0 - WALL_T - 0.025 - cabin_z)
		fd.add_child(cb)

	var tw = Tween.new()
	tw.name = "Tween"
	el.add_child(tw)

	add(level, el)

func make_button(node_name, target_floor, size : Vector3):
	var b = StaticBody.new()
	b.name = node_name
	b.set_script(load("res://scenes/building/elevator_button.gd"))
	b.collision_layer = LAYER_USE_TARGET
	b.collision_mask = 0
	b.target_floor = target_floor
	b.elevator_path = NodePath("../../..")
	var cs = CollisionShape.new()
	cs.name = "CollisionShape"
	cs.shape = get_shape(size)
	b.add_child(cs)
	var mi = MeshInstance.new()
	mi.name = "MeshInstance"
	mi.mesh = get_mesh(size)
	mi.material_override = mat_button
	b.add_child(mi)
	return b

### Characters ###

func add_enemies(level):
	var enemy_scene = load("res://addons/palladium/core/enemy.tscn")
	var enemy_script = load("res://scenes/enemies/enemy_squig.gd")
	var squig_scene = load("res://scenes/enemies/squig.tscn")
	var enemies = Spatial.new()
	enemies.name = "enemies"
	add(level, enemies)
	for f in range(FLOORS):
		for side in [ -1, 1 ]:
			var sname = "l" if side < 0 else "r"
			var idx = 0
			for p in ENEMIES_PER_WING:
				idx += 1
				var e = enemy_scene.instance(PackedScene.GEN_EDIT_STATE_INSTANCE)
				e.set_script(enemy_script)
				var nh = "enemy_f%d_%s%d" % [f + 1, sname, idx]
				e.name = nh
				e.name_hint = nh
				e.show_path = false
				e.has_melee_attack = true
				e.can_hide = false
				e.max_hits = 1
				# Facing the lobby (the model looks along +Z)
				var basis = Basis(Vector3.UP, -side * PI * 0.5)
				e.transform = Transform(basis, Vector3(side * p.x, f * FLOOR_H, p.z))
				enemies.add_child(e)
				e.owner = scene_root
				var model = Spatial.new()
				model.name = "Model"
				e.add_child(model)
				model.owner = scene_root
				var squig = squig_scene.instance(PackedScene.GEN_EDIT_STATE_INSTANCE)
				model.add_child(squig)
				squig.owner = scene_root

func add_player_and_camera(level):
	var cam = load("res://addons/palladium/core/camera.tscn").instance(PackedScene.GEN_EDIT_STATE_INSTANCE)
	cam.name = "camera"
	cam.transform = Transform(Basis(Vector3.UP, PI), Vector3(0, 2.2, -8.0))
	add(level, cam)

	var player = load("res://addons/palladium/core/player.tscn").instance(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "player"
	player.has_ranged_attack = true
	# Standing in the lobby on the first floor, facing the elevator (+Z)
	player.transform = Transform(Basis(), Vector3(0, 0, -3.5))
	add(level, player)
	var model = Spatial.new()
	model.name = "Model"
	add(player, model)
	var vasya = load("res://vasya.tscn").instance(PackedScene.GEN_EDIT_STATE_INSTANCE)
	vasya.transform = Transform(Vector3(-4.37114e-08, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, -4.37114e-08), Vector3())
	add(model, vasya)
