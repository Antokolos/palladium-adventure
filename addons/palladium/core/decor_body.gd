extends StaticBody
class_name PLDDecorBody

const NEED_ANIM_STOP = false
const NEED_SOUND_STOP = false

export(NodePath) var anim_player_path : NodePath = NodePath("../AnimationPlayer")
export(float) var anim_speed = 1.0
export(NodePath) var audio_player_path : NodePath = NodePath("AudioStreamPlayer3D")
export(String) var anim_name = ""

onready var anim_player : AnimationPlayer = (
	get_node(anim_player_path)
		if anim_player_path and has_node(anim_player_path)
		else null
)

onready var audio_player : AudioStreamPlayer3D = (
	get_node(audio_player_path)
		if audio_player_path and has_node(audio_player_path)
		else null
)

func _ready() -> void:
	var camera = __PLDRT.game_state.get_cam()
	camera.connect("tactical_cursor_over", self, "_on_tactical_cursor_over")
	camera.connect("tactical_cursor_out", self, "_on_tactical_cursor_out")
	camera.connect("tactical_cursor_action", self, "_on_tactical_cursor_action")

func is_this_body(collider) -> bool:
	return collider and collider.get_instance_id() == get_instance_id()

func is_animation_needed(collider):
	return (
		anim_player
		and not anim_name.empty()
		and is_this_body(collider)
	)

func _on_tactical_cursor_over(collider) -> void:
	_on_tactical_cursor_action(collider)

func _on_tactical_cursor_out(collider) -> void:
	if is_animation_needed(collider):
		if NEED_ANIM_STOP and anim_player.is_playing():
			anim_player.stop(true)
		if NEED_SOUND_STOP and audio_player.playing:
			audio_player.stop()

func _on_tactical_cursor_action(collider) -> void:
	if is_animation_needed(collider):
		if not anim_player.is_playing():
			anim_player.play(anim_name, -1, anim_speed)
		if not audio_player.playing:
			audio_player.play()
