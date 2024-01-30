extends TextureRect

const GAME_URLS_FILE = "res://game_urls.json"
const APPIDS = [ 1040310, 531630, 815070, 594320, 490690, 392820 ]

onready var main_panel = get_node("VBoxContainer/HBoxContainer/PanelContainer")
onready var site_url_node = main_panel.get_node("VBoxContainer/HBoxAuthor/SiteUrl")
onready var tab_node = main_panel.get_node("VBoxContainer/GamesContent/HBoxContainerInfo/TabContainer")
onready var back_node = main_panel.get_node("VBoxContainer/HBoxControls/Back")
onready var open_game_page_button = main_panel.get_node("VBoxContainer/GameActions/ButtonOpen")

var game_urls = {}

func _ready():
	var game_urls_file = File.new()
	if (
		game_urls_file.file_exists(GAME_URLS_FILE)
		and game_urls_file.open(GAME_URLS_FILE, File.READ) == OK
	):
		game_urls = parse_json(game_urls_file.get_as_text())
		game_urls_file.close()
	__PLDRT.common_utils.show_mouse_cursor_if_needed(true)
	site_url_node.push_meta(0)
	site_url_node.append_bbcode("https://nlbproject.com")
	site_url_node.pop()
	for i in range(tab_node.get_tab_count()):
		tab_node.set_tab_title(i, tr(tab_node.get_tab_title(i)))
	select_tab(0)
	back_node.grab_focus()

func _on_Back_pressed():
	__PLDRT.game_state.change_scene("res://main_menu/main_menu.tscn")

func _on_SiteUrl_meta_clicked(meta):
	__PLDRT.common_utils.open_url("https://nlbproject.com")

func select_tab(tab_index):
	tab_node.set("current_tab", tab_index)
	open_game_page_button.visible = is_open_game_page_button_visible(str(tab_index))

func is_open_game_page_button_visible(key):
	return game_urls.has(key)

func _on_ABOUT_CAPTION_IKE_pressed():
	select_tab(0)

func _on_ABOUT_CAPTION_NONLINEAR_TQ_pressed():
	select_tab(1)

func _on_ABOUT_CAPTION_ADVFOUR_pressed():
	select_tab(2)

func _on_ABOUT_CAPTION_REDHOOD_pressed():
	select_tab(3)

func _on_ABOUT_CAPTION_BARBARIAN_pressed():
	select_tab(4)

func _on_ABOUT_CAPTION_WIQ_pressed():
	select_tab(5)

func _on_ButtonOpen_pressed():
	var game_index = tab_node.get("current_tab")
	var key = str(game_index)
	if not game_urls.has(key):
		return
	if game_urls[key].empty():
		__PLDRT.common_utils.open_store_page(APPIDS[game_index])
	else:
		__PLDRT.common_utils.open_url(game_urls[key])

func _input(event):
	if __PLDRT.common_utils.is_event_cancel_action(event):
		_on_Back_pressed()
