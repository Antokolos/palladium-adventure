extends Spatial

const GLOBAL_UP = Vector3(0,1,0)

export var enabled : bool = true
export var width = 3.0
export var height = 2.0
export var quality = 0.6
export var cam_far = 22.0
export var activator_add = 2.2
export var activator_depth = 10.7

onready var mirror_plane = get_node('MirrorPlane')
onready var mirror_transform = get_node("MirrorTransform")
onready var viewport = get_node('Viewport')
onready var activation_shape = get_node('Area/CollisionShape')

# Compute reflection plane and its global transform  (origin in the middle, 
#  X and Y axis properly aligned with the viewport, -Z is the mirror's forward direction) 
onready var plane_origin = mirror_transform.global_transform.origin
onready var plane_normal = mirror_transform.global_transform.basis.z.normalized()
onready var reflection_plane = Plane(plane_normal, plane_origin.dot(plane_normal))
onready var reflection_transform = mirror_transform.global_transform

var active = false
var camera : Camera = null

func _ready():
	# The following line is not needed, see https://github.com/godotengine/godot/issues/23750#issuecomment-440708856
	#mirror_plane.material_override.albedo_texture = viewport.get_texture()
	mirror_plane.mesh = PlaneMesh.new()
	mirror_plane.mesh.size = Vector2(width, height)
	activation_shape.shape = BoxShape.new()
	activation_shape.translate_object_local(Vector3(0, activator_depth / 2.0, 0))
	activation_shape.shape.extents = Vector3(width / 2.0 + activator_add, activator_depth / 2.0, height / 2.0 + activator_add)
	# Add a mirror camera
	camera = Camera.new()
	viewport.add_child(camera)
	camera.keep_aspect = Camera.KEEP_WIDTH
	camera.current = true
	camera.cull_mask = 0
	camera.set_cull_mask_bit(0, true)
	camera.set_cull_mask_bit(1, true)
	camera.set_cull_mask_bit(2, true)
	camera.set_cull_mask_bit(5, true)
	camera.set_cull_mask_bit(10, true)
	camera.set_cull_mask_bit(11, true)
	camera.make_current()
	camera.far = cam_far
	get_tree().get_root().connect("size_changed", self, "_on_resolution_changed")
	deactivate()
	_on_resolution_changed()

func _on_resolution_changed():
	var screen_size = get_tree().get_root().size
	var pixels_size = screen_size.y * quality
	viewport.size.x = int(width * pixels_size)
	viewport.size.y = int(height * pixels_size)

func _process(delta):
	if not enabled or not __PLDRT.game_state.is_level_ready():
		return
	var player = __PLDRT.game_state.get_player()
	var eyes = player.get_cam_holder()
	var cam_pos = eyes.global_transform.origin
	frustum(cam_pos)

func frustum(cam_pos):
	# The projected point of main camera's position onto the reflection plane
	var proj_pos = reflection_plane.project(cam_pos)
	
	# Main camera position reflected over the mirror's plane
	var mirrored_pos = cam_pos + (proj_pos - cam_pos) * 2.0
	
	# Compute mirror camera transform
	# - origin at the mirrored position
	# - looking perpedicularly into the relfection plane (this way the near clip plane will be 
	#      parallel to the reflection plane) 
	var t = Transform(Basis(), mirrored_pos)
	t = t.looking_at(proj_pos, reflection_transform.basis.y.normalized())
	camera.set_global_transform(t)
	
	# Compute the tilting offset for the frustum (the X and Y coordinates of the mirrored camera position
	#	when expressed in the reflection plane coordinate system) 
	var offset = reflection_transform.xform_inv(cam_pos)
	offset = Vector2(offset.x, offset.y)
	
	# Set mirror camera frustum
	# - size 	-> mirror's width (camera is set to KEEP_WIDTH)
	# - offset 	-> previously computed tilting offset
	# - z_near 	-> distance between the mirror camera and the reflection plane (this ensures we won't
	#               be reflecting anything behind the mirror)
	# - z_far	-> large arbitrary value (render distance limit from the mirror camera position)
	camera.set_frustum(
		width,
		-offset,
		proj_pos.distance_to(cam_pos),
		cam_far
	)

func activate():
	active = true
	viewport.render_target_update_mode = Viewport.UPDATE_WHEN_VISIBLE

func deactivate():
	active = false
	viewport.render_target_update_mode = Viewport.UPDATE_ONCE

func _on_Area_body_entered(body):
	if active:
		return
	var player = __PLDRT.game_state.get_player()
	if body.get_instance_id() == player.get_instance_id():
		activate()

func _on_Area_body_exited(body):
	if not active or __PLDRT.game_state.is_loading():
		return
	var player = __PLDRT.game_state.get_player()
	if body.get_instance_id() == player.get_instance_id():
		deactivate()
