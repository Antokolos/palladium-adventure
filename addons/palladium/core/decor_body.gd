extends StaticBody
class_name PLDDecorBody

const NEED_ANIM_STOP = false
const NEED_SOUND_STOP = false

export(NodePath) var anim_player_path : NodePath = NodePath("../AnimationPlayer")
export(Array, String) var anim_names = [ "" ]
export(Array, float) var anim_speeds = [ 1.0 ]
export(Array, NodePath) var audio_player_paths = [
	NodePath("AudioStreamPlayer3D")
]

onready var anim_player : AnimationPlayer = (
	get_node(anim_player_path)
		if anim_player_path and has_node(anim_player_path)
		else null
)

var current_anim_idx = -1

func _ready() -> void:
	var camera = __PLDRT.game_state.get_cam()
	camera.connect("tactical_cursor_over", self, "_on_tactical_cursor_over")
	camera.connect("tactical_cursor_out", self, "_on_tactical_cursor_out")
	camera.connect("tactical_cursor_action", self, "_on_tactical_cursor_action")

func get_audio_player():
	if current_anim_idx < 0 or current_anim_idx >= audio_player_paths.size():
		return null
	var path = audio_player_paths[current_anim_idx]
	return get_node(path) if path and has_node(path) else null

func get_anim_name():
	if current_anim_idx < 0 or current_anim_idx >= anim_names.size():
		return ""
	return anim_names[current_anim_idx]

func get_anim_speed():
	if current_anim_idx < 0 or current_anim_idx >= anim_speeds.size():
		return 1.0
	return anim_speeds[current_anim_idx]

func is_this_body(collider) -> bool:
	return collider and collider.get_instance_id() == get_instance_id()

func is_animation_needed():
	return (
		anim_player
		and not get_anim_name().empty()
	)

func _on_tactical_cursor_over(collider) -> void:
	_on_tactical_cursor_action(collider)

func _on_tactical_cursor_out(collider) -> void:
	if is_this_body(collider):
		if NEED_ANIM_STOP and anim_player and anim_player.is_playing():
			anim_player.stop(true)
		var audio_player = get_audio_player()
		if NEED_SOUND_STOP and audio_player and audio_player.playing:
			audio_player.stop()

func _on_tactical_cursor_action(collider) -> void:
	current_anim_idx = randi() % anim_names.size()
	if is_this_body(collider):
		if is_animation_needed():
			anim_player.play(get_anim_name(), -1, get_anim_speed())
		var audio_player = get_audio_player()
		if audio_player:
			audio_player.play()
