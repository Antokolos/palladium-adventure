extends Spatial

export(NodePath) var leaves_node_path = null
export(bool) var use_coloring = false
export(int) var surface_index = 0
export(float) var sway_speed = 0.9
export(float) var sway_strength = 0.03
export(float) var sway_phase_len = 8.0
export(Texture) var texture_albedo = null
export(Texture) var texture_metallic = null
export(Texture) var texture_roughness = null
export(Texture) var texture_normal = null
export(Texture) var texture_transmission = null

onready var tree_1_material = load("res://addons/palladium/shaders/tree_1_shader.tres")

func _ready():
	tree_1_material.set("shader_param/texture_albedo", texture_albedo)
	tree_1_material.set("shader_param/texture_metallic", texture_metallic)
	tree_1_material.set("shader_param/texture_roughness", texture_roughness)
	tree_1_material.set("shader_param/texture_normal", texture_normal)
	tree_1_material.set("shader_param/texture_transmission", texture_transmission)
	tree_1_material.set("shader_param/use_coloring", use_coloring)
	tree_1_material.set("shader_param/sway_speed", sway_speed)
	tree_1_material.set("shader_param/sway_strength", sway_strength)
	tree_1_material.set("shader_param/sway_phase_len", sway_phase_len)

func wind_effect_enable(enable):
	var mesh = get_node(leaves_node_path) if leaves_node_path and has_node(leaves_node_path) else null
	if mesh:
		mesh.set_surface_material(surface_index, tree_1_material if enable else null)
