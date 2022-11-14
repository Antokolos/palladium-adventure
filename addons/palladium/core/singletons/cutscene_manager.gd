extends Node
class_name PLDCutsceneManager

signal camera_borrowed(player_node, cutscene_node, camera, conversation_name, target)
signal camera_restored(player_node, cutscene_node, camera, conversation_name, target)

var cutscene_node = null
var conversation_name = null
var target = null
var is_cutscene = false

var _pldrt = null

func init(pldrt):
	_pldrt = pldrt
	return self

func _ready():
	_pldrt.conversation_manager.connect("conversation_finished", self, "_on_conversation_finished")

func _on_conversation_finished(player, conversation_name, target, initiator, last_result):
	if not self.target and target:
		return
	if self.target and not target:
		return
	if self.conversation_name == conversation_name:
		if (not self.target and not target) or self.target.name_hint == target.name_hint:
			stop_cutscene(player)

func start_cutscene(player, cutscene_node, conversation_name = null, target = null):
	self.conversation_name = conversation_name
	self.target = target
	borrow_camera(player, cutscene_node)

func stop_cutscene(player):
	var conversation_name_prev = self.conversation_name
	var target_prev = self.target
	self.conversation_name = null
	self.target = null
	restore_camera(player, conversation_name_prev, target_prev)

func play_companion_cutscene(companions_map):
	for name_hint in companions_map.keys():
		if _pldrt.game_state.is_in_party(name_hint):
			var character = _pldrt.game_state.get_character(name_hint)
			character.play_cutscene(companions_map[name_hint])
			return

func borrow_camera(player, cutscene_node, is_hideout = false):
	if is_cutscene:
		return
	var camera = _pldrt.game_state.get_cam()
	is_cutscene = true
	_pldrt.game_state.get_hud().show_game_ui(false)
	if not is_hideout:
		camera.enable_use(false)
		camera.show_cutscene_flashlight(true)
	self.cutscene_node = cutscene_node
	if not cutscene_node:
		return
	player.reset_rotation()
	player.set_simple_mode(false)
	camera.set_target_path(cutscene_node.get_path())
	emit_signal("camera_borrowed", player, cutscene_node, camera, conversation_name, target)

func restore_camera(player, conversation_name_prev = null, target_prev = null):
	var camera = _pldrt.game_state.get_cam()
	if is_cutscene():
		player.reset_movement_and_rotation()
		player.set_simple_mode(_pldrt.settings.get_camera_view() == PLDDB.CAMERA_VIEW_FIRST_PERSON)
		camera.set_target_path(player.get_cam_holder_path())
		camera.show_cutscene_flashlight(false)
		camera.enable_use(true)
		emit_signal("camera_restored", player, cutscene_node, camera, conversation_name_prev, target_prev)
	else:
		camera.show_cutscene_flashlight(false)
		camera.enable_use(true)
	_pldrt.game_state.get_hud().show_game_ui(true)
	clear_cutscene_node()

# When borrowing camera in game, you should always use restore_camera()
# But sometimes it is needed to just clear cutscene node (for example, if your game is finished with a cutscene)
func clear_cutscene_node():
	cutscene_node = null
	target = null
	is_cutscene = false

func cutscene_node_is(node):
	if not node and not cutscene_node:
		return true
	if not node and cutscene_node:
		return false
	if node and not cutscene_node:
		return false
	return node.get_instance_id() == cutscene_node.get_instance_id()

func is_cutscene():
	return is_cutscene
