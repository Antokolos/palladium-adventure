extends Spatial
class_name PLDShaderCache

const ENABLE_BAKED_LIGHT_USAGE_FOR_ALL = true
const SHADER_CACHE_HIDING_ENABLED = true
const EXTRA_CULL_MARGIN_INCREMENT = 0 # TODO: Can break baked lights?
const STEP = 0.005
const HALFROW = 20
# Character skeletons used to stay under the camera after the warm-up (scaled
# down and moved to the center), being skinned and drawn in every frame.
# Compiled shader variants belong to the shaders and do not need it.
const KEEP_CHARACTER_SKELETONS = false
# Shader variants depend on the viewport and the camera that render an object:
# USE_SHADOW is enabled only in viewports with a shadow atlas, the camera's
# environment enables multiple render targets (SSAO, SSR, DOF) and the radiance
# map (sky). Secondary viewports (mirrors, item previews...) have no shadow atlas
# and their cameras use the World's environment, so the objects rendered there
# need other variants than in the main viewport. Therefore the warm-up assets
# are rendered once more by a camera in a small secondary viewport like that.
const SECONDARY_PASS_SIZE = Vector2(64, 36)
# Both passes are rendered in small offscreen viewports, and the warm-up assets
# are on a render layer that is not in the main camera's cull mask, so the
# player does not see them, no matter how long the passes last.
# The first pass reproduces the main viewport (a shadow atlas, the main
# camera's environment), the second one the secondary viewports.
# The layer must not be used by anything that the main camera should see.
export(int, 0, 19) var asset_layer = 19
# Any non-zero shadow atlas enables the same shader variants (USE_SHADOW)
const MAIN_PASS_SHADOW_ATLAS_SIZE = 256

# How long the warm-up assets are shown in each pass (the main viewport and the
# secondary one). A shader variant is compiled when an object using it is
# drawn, but with asynchronous compilation (shader_compilation_mode 1 or 2)
# Godot starts at most max_simultaneous_compiles compilations at a time, at most
# two per frame; a variant that did not get a slot is started only when the
# object is drawn again. With assets shown for one frame most variants were
# not even started and were compiled later, during the game.
# Number of frames of each pass; 0 means automatic: 2 frames for synchronous
# compilation, and for asynchronous compilation enough frames to start the
# compilation of every asset's variants
export(int, 0, 1000) var pass_frames = 0
# Asynchronous compilation only: minimum duration of each pass in seconds,
# so that started compilations can finish and free their slots
export(float, 0, 10) var pass_min_duration_async = 1.0
# Asynchronous compilation only: maximum duration of each pass in seconds,
# the pass ends then even if pass_frames are not shown yet
export(float, 0, 30) var pass_max_duration_async = 5.0
# Variants started per asset in a pass, used for automatic pass_frames
# (the color pass, the depth prepass, the shadow pass...)
const VARIANTS_PER_ASSET_ESTIMATE = 2
const PASS_FRAMES_SYNC = 2
const PASS_FRAMES_MARGIN = 2

# Prints a report about the shaders used by the level's materials after each
# warm-up (see print_shader_report()). Every unique shader means a separate
# ubershader, compiled synchronously when it appears, and separate variants,
# so materials that differ only in a couple of settings are worth unifying.
export var shader_report_enabled = false

var stage = 0
var pass_frames_done = 0
var pass_frames_needed = 0
var pass_start_msec = 0
var secondary_viewport = null
var rids = {}
var skeleton_paths = {}
var character_skeleton_paths = {}

func _ready():
	__PLDRT.settings.connect("shader_cache_enabled_changed", self, "refresh")
	#refresh() -- will be called on settings ready

func get_cacheable_items(scn):
	var result = []
	if scn is MeshInstance:
		result.append({"mesh" : scn, "particles": null, "particles_cpu": null})
	elif scn is Particles:
		result.append({"mesh" : null, "particles": scn, "particles_cpu": null})
	elif scn is CPUParticles:
		result.append({"mesh" : null, "particles": null, "particles_cpu": scn})
	elif scn is GeometryInstance:
		# CSG shapes, MultiMeshInstance, Sprite3D, Label3D etc.: only materials are warmed up
		result.append({"mesh" : null, "particles": null, "particles_cpu": null, "geometry": scn})

	for ch in scn.get_children():
		var items = get_cacheable_items(ch)
		for item in items:
			result.append(item)
	return result

func get_scale_from_aabb(aabb):
	var size = aabb.size
	if size.x == 0:
		size.x = 0.001
	if size.y == 0:
		size.y = 0.001
	if size.z == 0:
		size.z = 0.001
	return Vector3(STEP / (2 * size.x), STEP / (2 * size.y), STEP / (2 * size.z))

func make_skeleton(pos, skeleton):
	skeleton.set_transform(Transform())
	skeleton.translate(Vector3(pos.x, pos.y, 0))
	var aabb = AABB(Vector3(0, 0, 0), Vector3(STEP, STEP, STEP))
	for skeleton_child in skeleton.get_children():
		if skeleton_child is VisualInstance:
			aabb = aabb.merge(skeleton_child.get_aabb())
		if skeleton_child is PLDBoneAttachment:
			skeleton_child.queue_free()
	skeleton.set_scale(get_scale_from_aabb(aabb))
	# All animations of the skeleton's AnimationPlayers used to be played here.
	# Skinning shader variants do not depend on the pose, and playing animations
	# that the game itself never plays printed errors (e.g. "slerp: The start
	# quaternion must be normalized" for animations with non-normalized rotation
	# keys) during the whole warm-up.
	disable_animations(skeleton)
	return skeleton

# Copies must not play animations: neither autoplay nor ones that were playing
# in the original node when it was duplicated
func disable_animations(node):
	for ch in node.get_children():
		if ch is AnimationPlayer:
			ch.autoplay = ""
			ch.stop()
			ch.playback_active = false
		elif ch is AnimationTree:
			ch.active = false
		disable_animations(ch)

func make_base_asset(pos, resource):
	var asset = MeshInstance.new()
	asset.set_portal_mode(CullInstance.PORTAL_MODE_GLOBAL)
	asset.include_in_bound = false
	asset.set_transform(Transform())
	asset.translate(Vector3(pos.x, pos.y, 0))
	var mname = resource.get_name() if resource else "" 
	if not mname.empty():
		asset.set_name(mname)
	return asset

func make_asset(pos, material):
	var asset = make_base_asset(pos, material)
	asset.mesh = SphereMesh.new()
	asset.mesh.radius = STEP / 4.0
	asset.mesh.height = STEP / 2.0
	asset.mesh.set_material(material)
	return asset

func make_mesh(pos, mesh, surface_materials = []):
	var asset = make_base_asset(pos, mesh)
	asset.mesh = mesh
	var aabb = AABB(Vector3(0, 0, 0), Vector3(STEP, STEP, STEP))
	aabb = aabb.merge(asset.get_aabb())
	asset.set_scale(get_scale_from_aabb(aabb))
	for i in range(surface_materials.size()):
		asset.set_surface_material(i, surface_materials[i])
	return asset

func make_particles(pos, particles):
	particles.set_transform(Transform())
	particles.set_portal_mode(CullInstance.PORTAL_MODE_GLOBAL)
	particles.include_in_bound = false
	particles.translate(Vector3(pos.x, pos.y, 0))
	var aabb = AABB(Vector3(0, 0, 0), Vector3(STEP, STEP, STEP))
	aabb = aabb.merge(particles.get_aabb())
	particles.set_scale(get_scale_from_aabb(aabb))
	particles.emitting = true
	disable_animations(particles)
	return particles

# Adds a warm-up sphere for the material, if it was not added yet
func add_material(pos, mat):
	if not mat:
		return pos
	var rid = mat.get_rid().get_id()
	if rids.has(rid):
		return pos
	rids[rid] = make_asset(pos, mat)
	self.add_child(rids[rid])
	return next_pos(pos)

# The same skeleton (model) is warmed up once, no matter how many characters use it
func get_skeleton_key(sk):
	var owner_node = sk.owner
	if owner_node and owner_node.filename != "":
		return owner_node.filename + ":" + str(owner_node.get_path_to(sk))
	if sk.filename != "":
		return sk.filename
	return str(sk.get_path()) if sk.is_inside_tree() else str(sk.get_instance_id())

func make_multimesh(pos, mmi):
	var src = mmi.multimesh
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.color_format = src.color_format
	mm.custom_data_format = src.custom_data_format
	mm.mesh = src.mesh
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform())
	var asset = MultiMeshInstance.new()
	asset.set_portal_mode(CullInstance.PORTAL_MODE_GLOBAL)
	asset.include_in_bound = false
	asset.multimesh = mm
	asset.material_override = mmi.material_override
	asset.set_transform(Transform())
	asset.translate(Vector3(pos.x, pos.y, 0))
	var aabb = AABB(Vector3(0, 0, 0), Vector3(STEP, STEP, STEP))
	aabb = aabb.merge(src.mesh.get_aabb())
	asset.set_scale(get_scale_from_aabb(aabb))
	return asset

# Adds an instanced copy of the MultiMeshInstance (one instance), once per mesh and material_override
func add_multimesh(pos, mmi):
	var key = "mm:%d:%d" % [
		mmi.multimesh.mesh.get_rid().get_id(),
		mmi.material_override.get_rid().get_id() if mmi.material_override else 0
	]
	if rids.has(key):
		return pos
	rids[key] = make_multimesh(pos, mmi)
	self.add_child(rids[key])
	return next_pos(pos)

# Settings that the built-in materials of Sprite3D, AnimatedSprite3D and Label3D depend on
const BUILTIN_MATERIAL_PROPERTIES = [
	"billboard", "transparent", "shaded", "double_sided", "no_depth_test",
	"fixed_size", "alpha_cut", "render_priority"
]

# Adds a copy of a node with a built-in material, once per combination of the settings
func add_geometry_copy(pos, geometry):
	var values = [ geometry.get_class() ]
	for property in BUILTIN_MATERIAL_PROPERTIES:
		values.append(geometry.get(property))
	var key = "builtin:" + str(values)
	if rids.has(key):
		return pos
	var asset = geometry.duplicate(0)  # without scripts, signals and groups
	for ch in asset.get_children():
		asset.remove_child(ch)
		ch.free()
	if asset is GeometryInstance:
		asset.set_portal_mode(CullInstance.PORTAL_MODE_GLOBAL)
		asset.include_in_bound = false
	asset.set_transform(Transform())
	asset.translate(Vector3(pos.x, pos.y, 0))
	asset.set_scale(Vector3(STEP, STEP, STEP))
	rids[key] = asset
	self.add_child(asset)
	return next_pos(pos)

func next_pos(pos):
	pos.x = pos.x + STEP
	if pos.x > STEP * HALFROW:
		pos.x = -STEP * HALFROW
		pos.y = pos.y + STEP
	return pos

func add_material_meshes(pos, scn):
	var caching_enabled = caching_enabled()
	var items = get_cacheable_items(scn)
	pos.x = pos.x + STEP / 2.0
	pos.y = pos.y + STEP / 2.0
	for item in items:
		var mesh = item["mesh"]
		var particles = item["particles"]
		var particles_cpu = item["particles_cpu"]
		if mesh and ENABLE_BAKED_LIGHT_USAGE_FOR_ALL:
			mesh.use_in_baked_light = true
		if mesh and EXTRA_CULL_MARGIN_INCREMENT > 0:
			mesh.extra_cull_margin += EXTRA_CULL_MARGIN_INCREMENT
		if not caching_enabled:
			continue
		var geometry = item.get("geometry")
		if geometry:
			if geometry is MultiMeshInstance and geometry.multimesh and geometry.multimesh.mesh:
				# The materials of a MultiMesh are rendered with instancing
				# (USE_INSTANCING), a sphere would compile another variant
				pos = add_multimesh(pos, geometry)
			elif (geometry is SpriteBase3D or geometry is Label3D) and not geometry.material_override:
				# Their built-in materials are generated from their settings
				pos = add_geometry_copy(pos, geometry)
			else:
				pos = add_material(pos, geometry.material_override)
				# CSG primitives have their own material property
				var own_material = geometry.get("material")
				if own_material is Material:
					pos = add_material(pos, own_material)
			continue
		if mesh:
			# material_override replaces all surface materials, and it was not collected before
			pos = add_material(pos, mesh.material_override)
			# Adding materials from MeshInstance's surfaces, if any
			var sc = mesh.get_surface_material_count()
			var surface_materials = []
			for i in range(0, sc):
				var mat = mesh.get_surface_material(i)
				if mat:
					surface_materials.append(mat)
					pos = add_material(pos, mat)
			# Adding materials from MeshInstance's meshes' surfaces, if any
			var m = mesh.mesh
			if m and m is Mesh:
				var sc_mesh = m.get_surface_count()
				for j in range(0, sc_mesh):
					pos = add_material(pos, m.surface_get_material(j))
			
			var sk = mesh.get_node_or_null(mesh.get_skeleton_path())
			if sk is Skeleton:
				var sk_key = get_skeleton_key(sk)
				var target_dic = character_skeleton_paths if sk.get_parent() is PLDCharacterModel else skeleton_paths
				if not target_dic.has(sk_key):
					target_dic[sk_key] = make_skeleton(pos, sk.duplicate(Node.DUPLICATE_USE_INSTANCING))
					self.add_child(target_dic[sk_key])
					pos = next_pos(pos)
			
			if not m or not m is Mesh:
				continue
			var mesh_id = m.get_rid().get_id()
			if not rids.has(mesh_id):
				rids[mesh_id] = make_mesh(pos, m, surface_materials)
				self.add_child(rids[mesh_id])
				pos = next_pos(pos)
		elif particles:
			# Draw passes' materials are what is rendered; the process material
			# can be null, which crashed here before
			pos = add_material(pos, particles.material_override)
			for i in range(particles.draw_passes):
				var dp = particles.get_draw_pass_mesh(i)
				if dp:
					for j in range(dp.get_surface_count()):
						pos = add_material(pos, dp.surface_get_material(j))
			var pmat = particles.get_process_material()
			if pmat:
				var rid = pmat.get_rid().get_id()
				if not rids.has(rid):
					rids[rid] = make_particles(pos, particles.duplicate(Node.DUPLICATE_USE_INSTANCING))
					self.add_child(rids[rid])
					rids[rid].restart()
					pos = next_pos(pos)
		elif particles_cpu:
			# The material is often set as material_override, and the mesh or its
			# material can be null, which crashed here before
			pos = add_material(pos, particles_cpu.material_override)
			if particles_cpu.mesh:
				for j in range(particles_cpu.mesh.get_surface_count()):
					pos = add_material(pos, particles_cpu.mesh.surface_get_material(j))
	return pos

# Shader compilation mode: 0 - synchronous, 1 - asynchronous, 2 - asynchronous + cache.
# Previously "scm and scm < 2" returned false for 0, i.e. exactly for the mode
# with the compilation stalls.
### Scenes that are not on the level yet ###

func get_extra_scene_paths():
	var result = []
	var level = __PLDRT.game_state.get_level()
	if not level:
		return result
	var extra_scenes = level.get("shader_cache_extra_scenes")
	if extra_scenes:
		for scene in extra_scenes:
			if scene and scene.resource_path != "" and not result.has(scene.resource_path):
				result.append(scene.resource_path)
	if level.get("shader_cache_inventory_items"):
		for path in get_inventory_model_paths():
			if not result.has(path):
				result.append(path)
	return result

func get_inventory_model_paths():
	var result = []
	var item_lists = []
	for name_hint in __PLDRT.game_state.inventory.keys():
		item_lists.append(__PLDRT.game_state.inventory[name_hint])
	for name_hint in __PLDRT.game_state.quick_items.keys():
		item_lists.append(__PLDRT.game_state.quick_items[name_hint])
	for items in item_lists:
		for item in items:
			if not item or not item.has("item_id"):
				continue
			var item_data = PLDDB.get_item_data(item.item_id)
			if not item_data:
				continue
			for key in [ "model_path", "model_use_path" ]:
				var path = item_data.get(key)
				if path and not result.has(path):
					result.append(path)
	return result

# Extra scenes are instanced but not added to the tree (so that their scripts
# do not register characters, usables etc. in the game state); the warm-up
# assets made of them are independent copies, and the instances are freed.
func add_extra_scenes(pos):
	for path in get_extra_scene_paths():
		if not ResourceLoader.exists(path):
			push_warning("Shader cache: scene does not exist: " + path)
			continue
		var scene = load(path)
		if not scene is PackedScene:
			continue
		var inst = scene.instance()
		if not inst:
			continue
		pos = add_material_meshes(pos, inst)
		inst.free()
	return pos

func godot_shader_cache_is_off():
	var scm = ProjectSettings.get("rendering/gles3/shaders/shader_compilation_mode")
	return scm != null and int(scm) < 2

func caching_enabled():
	return __PLDRT.settings.shader_cache_enabled or godot_shader_cache_is_off()

func _process(delta):
	match stage:
		0:
			pass
		1:
			stage = stage + 1
			__PLDRT.game_state.get_hud().clear_popup_message()
			__PLDRT.game_state.get_hud().set_popup_message(tr("MESSAGE_PLEASE_WAIT"))
			stop_secondary_pass()
			free_assets()
			get_tree().call_group("room_enablers", "set_active", false)
		2:
			stage = stage + 1
			var pos = Vector2(-STEP * HALFROW, 0)
			pos = add_material_meshes(pos, __PLDRT.game_state.get_viewport())
			if caching_enabled():
				pos = add_extra_scenes(pos)
				set_assets_layer(self)
				if not start_secondary_pass(true):
					stage = stage + 2
			start_pass()
		3:
			# Showing all items in an offscreen viewport like the main one
			if caching_enabled() and not is_pass_finished():
				update_secondary_camera()
				return
			stage = stage + 1
			if caching_enabled() and start_secondary_pass(false):
				start_pass()
			else:
				stage = stage + 1
		4:
			# Showing all items once more in an offscreen viewport like the secondary ones
			if not is_pass_finished():
				update_secondary_camera()
				return
			stage = stage + 1
			stop_secondary_pass()
		_:
			if (
				SHADER_CACHE_HIDING_ENABLED
				and caching_enabled()
			):
				if KEEP_CHARACTER_SKELETONS:
					for character_sk_path in character_skeleton_paths.keys():
						var character_sk = character_skeleton_paths[character_sk_path]
						# Moving all character skeletons to center
						var scale = character_sk.get_scale()
						character_sk.set_transform(Transform())
						character_sk.set_scale(scale)
				# Warm-up assets are freed. They used to be only removed from the
				# tree (remove_child) and were never freed: about 600 orphan nodes
				# leaked on every refresh (level load, quality change) on the test level.
				free_assets(KEEP_CHARACTER_SKELETONS)
			__PLDRT.game_state.get_hud().clear_popup_message()
			__PLDRT.game_state.shader_cache_processed()
			get_tree().call_group("room_enablers", "set_active", true)
			stage = 0
			if shader_report_enabled:
				print_shader_report()

### Shader report ###

# Collects materials used in the node's subtree: material -> path of the first
# node that uses it. Built-in materials of Sprite3D/Label3D are not visible here.
func collect_materials(node, result):
	var mats = []
	if node is GeometryInstance:
		mats.append(node.material_override)
		var own_material = node.get("material")
		if own_material is Material:
			mats.append(own_material)
	if node is MeshInstance:
		for i in range(node.get_surface_material_count()):
			mats.append(node.get_surface_material(i))
		if node.mesh:
			for i in range(node.mesh.get_surface_count()):
				mats.append(node.mesh.surface_get_material(i))
	elif node is MultiMeshInstance and node.multimesh and node.multimesh.mesh:
		for i in range(node.multimesh.mesh.get_surface_count()):
			mats.append(node.multimesh.mesh.surface_get_material(i))
	elif node is Particles:
		for i in range(node.draw_passes):
			var dp = node.get_draw_pass_mesh(i)
			if dp:
				for j in range(dp.get_surface_count()):
					mats.append(dp.surface_get_material(j))
	elif node is CPUParticles and node.mesh:
		for i in range(node.mesh.get_surface_count()):
			mats.append(node.mesh.surface_get_material(i))
	for mat in mats:
		# next_pass materials are separate shaders too
		while mat:
			if not result.has(mat):
				result[mat] = str(node.get_path()) if node.is_inside_tree() else node.name
			mat = mat.next_pass if mat is Material else null
	if node == self:
		return
	for ch in node.get_children():
		collect_materials(ch, result)

func is_shader_relevant_property(name):
	if name.ends_with("_texture"):
		return true
	if name.begins_with("flags_") or name.ends_with("_enabled") or name.ends_with("_texture_channel"):
		return true
	if name.begins_with("params_") and not name in [
		"params_line_width", "params_point_size", "params_alpha_scissor_threshold", "params_grow_amount"
	]:
		return true
	return name in [
		"distance_fade_mode", "detail_blend_mode", "detail_uv_layer", "uv1_triplanar", "uv2_triplanar",
		"proximity_fade_enable", "albedo_texture_force_srgb", "vertex_color_use_as_albedo", "vertex_color_is_srgb"
	]

var default_spatial_material = null

# Settings of a SpatialMaterial that its generated shader depends on and that
# differ from the defaults ("name" for enabled flags, "name=value" otherwise,
# textures are shown as present)
func get_shader_settings(mat):
	if not default_spatial_material:
		default_spatial_material = SpatialMaterial.new()
	var result = []
	for p in mat.get_property_list():
		if not (p.usage & PROPERTY_USAGE_STORAGE) or not is_shader_relevant_property(p.name):
			continue
		var value = mat.get(p.name)
		if p.name.ends_with("_texture") and not p.name.ends_with("_texture_channel"):
			if value:
				result.append(p.name)
			continue
		if value == default_spatial_material.get(p.name):
			continue
		result.append(p.name if typeof(value) == TYPE_BOOL and value else "%s=%s" % [p.name, str(value)])
	return result

func describe_material(mat, user_path):
	var path = mat.resource_path
	if path != "" and path.find("::") < 0:
		return path
	return "built-in %s (%s), used by %s" % [mat.get_class(), mat.resource_name if mat.resource_name != "" else "unnamed", user_path]

func print_shader_report():
	var materials = {}
	collect_materials(__PLDRT.game_state.get_viewport(), materials)
	var groups = {}  # shader RID id -> { "materials": [...], "settings": [...], "type": ... }
	for mat in materials.keys():
		var shader_rid = VisualServer.material_get_shader(mat.get_rid())
		var key = shader_rid.get_id()
		if not groups.has(key):
			var settings = []
			var type = mat.get_class()
			if mat is SpatialMaterial:
				settings = get_shader_settings(mat)
			elif mat is ShaderMaterial and mat.shader:
				settings = [ "shader: " + (mat.shader.resource_path if mat.shader.resource_path != "" else "built-in") ]
			groups[key] = { "materials": [], "settings": settings, "type": type }
		groups[key].materials.append(describe_material(mat, materials[mat]))
	var keys = groups.keys()
	report_groups = groups
	keys.sort_custom(self, "_compare_groups_by_size")
	report_groups = {}
	var base = null
	for key in keys:
		if groups[key].type == "SpatialMaterial":
			base = groups[key]
			break
	print("Shader report: %d unique shaders for %d materials" % [groups.size(), materials.size()])
	var n = 0
	for key in keys:
		n += 1
		var g = groups[key]
		var line = "  #%d: %d material(s), %s" % [n, g.materials.size(), g.type]
		if g == base:
			line += ", the most common SpatialMaterial shader"
		elif base and g.type == "SpatialMaterial":
			var diff = []
			for s in g.settings:
				if not s in base.settings:
					diff.append("+" + s)
			for s in base.settings:
				if not s in g.settings:
					diff.append("-" + s)
			line += ", differs from the most common one by: " + PoolStringArray(diff).join(", ")
		print(line)
		if g.settings.size() > 0:
			print("      settings: " + PoolStringArray(g.settings).join(", "))
		for i in range(min(3, g.materials.size())):
			print("      " + g.materials[i])
		if g.materials.size() > 3:
			print("      ... and %d more" % (g.materials.size() - 3))

var report_groups = {}

func _compare_groups_by_size(a, b):
	return report_groups[a].materials.size() > report_groups[b].materials.size()

func free_assets(keep_character_skeletons = false):
	for rid in rids.keys():
		var a = rids[rid]
		if is_instance_valid(a):
			a.queue_free()
	rids.clear()
	for sk_path in skeleton_paths.keys():
		var sk = skeleton_paths[sk_path]
		if is_instance_valid(sk):
			sk.queue_free()
	skeleton_paths.clear()
	if keep_character_skeletons:
		return
	for character_sk_path in character_skeleton_paths.keys():
		var character_sk = character_skeleton_paths[character_sk_path]
		if is_instance_valid(character_sk):
			character_sk.queue_free()
	character_skeleton_paths.clear()

### Pass duration ###

func is_async_compilation():
	var scm = ProjectSettings.get("rendering/gles3/shaders/shader_compilation_mode")
	return scm != null and int(scm) >= 1

func get_assets_count():
	return rids.size() + skeleton_paths.size() + character_skeleton_paths.size()

func get_pass_frames():
	if pass_frames > 0:
		return pass_frames
	if not is_async_compilation():
		return PASS_FRAMES_SYNC
	var slots = ProjectSettings.get("rendering/gles3/shaders/max_simultaneous_compiles")
	slots = max(1, int(slots) if slots != null else 2)
	# At most two compilations are started per frame, and at most `slots` at a time
	var per_frame = min(2, slots)
	return int(ceil(float(get_assets_count() * VARIANTS_PER_ASSET_ESTIMATE) / per_frame)) + PASS_FRAMES_MARGIN

func start_pass():
	pass_frames_done = 0
	pass_frames_needed = get_pass_frames()
	pass_start_msec = OS.get_ticks_msec()

# Called once per frame while the pass is in progress
func is_pass_finished():
	pass_frames_done += 1
	if not is_async_compilation():
		return pass_frames_done > pass_frames_needed
	var elapsed = (OS.get_ticks_msec() - pass_start_msec) / 1000.0
	if elapsed >= pass_max_duration_async:
		return true
	return pass_frames_done > pass_frames_needed and elapsed >= pass_min_duration_async

### Passes in offscreen viewports ###

func get_camera():
	# shader_cache is a child of the camera's viewpoint
	var node = get_parent()
	while node and not node is Camera:
		node = node.get_parent()
	return node

# The warm-up assets are moved to asset_layer, so that only the offscreen
# cameras of the passes see them
func set_assets_layer(node):
	for ch in node.get_children():
		if ch is VisualInstance:
			ch.layers = 1 << asset_layer
		set_assets_layer(ch)

# like_main_viewport: with a shadow atlas and the main camera's environment,
# otherwise like secondary viewports (mirrors etc.): without a shadow atlas and
# with the World's environment. Only the warm-up assets are rendered.
func start_secondary_pass(like_main_viewport):
	var main_camera = get_camera()
	if not main_camera:
		return false
	if main_camera.get_cull_mask_bit(asset_layer):
		push_warning("Shader cache: asset_layer %d is visible to the main camera" % asset_layer)
	stop_secondary_pass()
	secondary_viewport = Viewport.new()
	secondary_viewport.name = "main_pass" if like_main_viewport else "secondary_pass"
	secondary_viewport.size = SECONDARY_PASS_SIZE
	secondary_viewport.shadow_atlas_size = MAIN_PASS_SHADOW_ATLAS_SIZE if like_main_viewport else 0
	secondary_viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	var camera = Camera.new()
	camera.cull_mask = 1 << asset_layer
	if like_main_viewport:
		camera.environment = main_camera.environment
	secondary_viewport.add_child(camera)
	add_child(secondary_viewport)
	camera.make_current()
	update_secondary_camera()
	return true

func update_secondary_camera():
	if not secondary_viewport:
		return
	var main_camera = get_camera()
	var camera = secondary_viewport.get_child(0)
	if not main_camera or not camera:
		return
	camera.fov = main_camera.fov
	camera.near = main_camera.near
	camera.far = main_camera.far
	camera.global_transform = main_camera.global_transform

func stop_secondary_pass():
	if secondary_viewport and is_instance_valid(secondary_viewport):
		secondary_viewport.queue_free()
	secondary_viewport = null

func refresh():
	stage = 1
