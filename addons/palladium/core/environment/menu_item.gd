extends Spatial
class_name PLDMenuItem

enum MenuType {
	CUSTOM = 0,
	CREDITS = 1,
	EXIT = 2,
	LOAD_GAME = 3,
	NEW_GAME = 4,
	OUR_GAMES = 5,
	SETTINGS = 6
}

export var text_path = "Text023"
export var sfx_player_over_path = "../../SFXOver"
export var emission_enabled = true
export var emission_energy = 0.05
export var activation_lang_id = PLDSettings.LANGUAGE_EN
export var menu_type = MenuType.CUSTOM
onready var menu_item_normal = SpatialMaterial.new()
onready var menu_item_highlight = SpatialMaterial.new()
onready var text_node = get_node(text_path)
onready var sfx_player_over = get_node(sfx_player_over_path)
onready var static_body = get_node("StaticBody")
onready var collision_shape = static_body.get_node("CollisionShape")

var is_mouse_over = false

func _ready():
	var text_mesh = get_node(text_path).mesh
	text_mesh.text = get_mesh_text()
	var aabb = text_mesh.get_aabb()
	static_body.translation.y = aabb.size.y / 2
	collision_shape.shape.extents.x = aabb.size.x / 2
	collision_shape.shape.extents.y = aabb.size.y / 2
	collision_shape.shape.extents.z = aabb.size.z / 2
	menu_item_normal.set("albedo_color", Color("#FFFFFF"))
	menu_item_normal.set("metallic", 0.9)
	menu_item_normal.set("roughness", 0.1)
	menu_item_normal.set("emission_enabled", emission_enabled)
	if emission_enabled:
		menu_item_normal.set("emission", Color("#FFFFFF"))
		menu_item_normal.set("emission_energy", emission_energy)
	menu_item_highlight.set("albedo_color", Color("#EC6418"))
	menu_item_highlight.set("metallic", 0.1)
	menu_item_highlight.set("roughness", 0.9)
	menu_item_highlight.set("emission_enabled", true)
	menu_item_highlight.set("emission", Color("EC6418"))
	text_node.set_surface_material(0, menu_item_normal)
	__PLDRT.settings.connect("language_changed", self, "_on_language_changed")
	static_body.connect("input_event", self, "_on_StaticBody_input_event")
	static_body.connect("mouse_entered", self, "_on_StaticBody_mouse_entered")
	static_body.connect("mouse_exited", self, "_on_StaticBody_mouse_exited")
	is_mouse_over = false

func _on_language_changed(lang_id):
	var active = lang_id == activation_lang_id
	visible = active
	get_node("StaticBody/CollisionShape").disabled = not active

func get_mesh_text():
	match menu_type:
		MenuType.CREDITS:
			match activation_lang_id:
				PLDSettings.LANGUAGE_RU:
					return "АВТОРЫ"
				_:
					return "CREDITS"
		MenuType.EXIT:
			match activation_lang_id:
				PLDSettings.LANGUAGE_RU:
					return "ВЫХОД"
				_:
					return "EXIT"
		MenuType.LOAD_GAME:
			match activation_lang_id:
				PLDSettings.LANGUAGE_RU:
					return "ЗАГРУЗКА"
				_:
					return "LOAD GAME"
		MenuType.NEW_GAME:
			match activation_lang_id:
				PLDSettings.LANGUAGE_RU:
					return "НОВАЯ ИГРА"
				_:
					return "NEW GAME"
		MenuType.OUR_GAMES:
			match activation_lang_id:
				PLDSettings.LANGUAGE_RU:
					return "НАШИ ИГРЫ"
				_:
					return "OUR GAMES"
		MenuType.SETTINGS:
			match activation_lang_id:
				PLDSettings.LANGUAGE_RU:
					return "НАСТРОЙКИ"
				_:
					return "SETTINGS"
		_:
			return "???"

func click():
	match menu_type:
		MenuType.CREDITS:
			__PLDRT.game_state.get_hud().show_tablet(true, PLDTablet.ActivationMode.CREDITS)
		MenuType.EXIT:
			get_tree().notify_group("quit_dialog", MainLoop.NOTIFICATION_WM_QUIT_REQUEST)
		MenuType.LOAD_GAME:
			__PLDRT.game_state.get_hud().show_tablet(true, PLDTablet.ActivationMode.LOAD)
		MenuType.NEW_GAME:
			__PLDRT.game_state.get_hud().show_difficulty_dialog()
		MenuType.OUR_GAMES:
			__PLDRT.game_state.change_scene("res://our_games.tscn")
		MenuType.SETTINGS:
			__PLDRT.game_state.get_hud().show_tablet(true, PLDTablet.ActivationMode.SETTINGS)
		_:
			pass

func mouse_over():
	text_node.set_surface_material(0, menu_item_highlight)
	sfx_player_over.play()
	is_mouse_over = true

func mouse_out():
	text_node.set_surface_material(0, menu_item_normal)
	is_mouse_over = false

func _on_StaticBody_input_event(camera, event, click_position, click_normal, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		click()

func _on_StaticBody_mouse_entered():
	mouse_over()

func _on_StaticBody_mouse_exited():
	mouse_out()
