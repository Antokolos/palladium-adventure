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

var stage = 0
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
	for ch in skeleton.get_children():
		if ch is AnimationPlayer:
			var anim_list = ch.get_animation_list()
			for anim in anim_list:
				ch.play(anim)
	return skeleton

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
	return str(sk.get_path())

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
			pos = add_material(pos, geometry.material_override)
			if geometry is MultiMeshInstance and geometry.multimesh and geometry.multimesh.mesh:
				var mm = geometry.multimesh.mesh
				for j in range(mm.get_surface_count()):
					pos = add_material(pos, mm.surface_get_material(j))
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
			free_assets()
			get_tree().call_group("room_enablers", "set_active", false)
		2:
			stage = stage + 1
			var pos = Vector2(-STEP * HALFROW, 0)
			pos = add_material_meshes(pos, __PLDRT.game_state.get_viewport())
		3:
			stage = stage + 1
			# Show all items for one frame
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

func refresh():
	stage = 1
