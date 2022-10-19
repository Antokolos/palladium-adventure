extends StaticBody
class_name PLDStaticUsable

signal use_usable(player_node, usable)

const USE_DISTANCE_COMMON = 2.6

export(float) var use_distance = USE_DISTANCE_COMMON
export(PLDDB.UsableIds) var usable_id = PLDDB.UsableIds.NONE
export(bool) var remove_on_hard_difficulty = false

func _ready():
	if Engine.editor_hint:
		return
	__PLDRT.game_state.register_usable(self)
	if remove_on_hard_difficulty and __PLDRT.settings.is_difficulty_hard():
		make_absent_without_state_change()
	__PLDRT.settings.connect("difficulty_changed", self, "_on_difficulty_changed")

func is_existent():
	# It can be made invisible via make_absent_without_state_change(), but in global sense it always "exists"
	# This behaviour can (and probably should) be redefined in child classes (for example, takable is not existent when it was taken)
	return true

func enable_collisions(enable):
	for ch in get_children():
		if ch is CollisionShape:
			ch.disabled = not enable

func make_present_without_state_change():
	visible = true
	enable_collisions(true)

func make_absent_without_state_change():
	visible = false
	enable_collisions(false)

func _on_difficulty_changed(ID):
	match ID:
		PLDSettings.DIFFICULTY_NORMAL:
			if is_existent():
				make_present_without_state_change()
		PLDSettings.DIFFICULTY_HARD:
			if remove_on_hard_difficulty:
				make_absent_without_state_change()

func get_usable_id():
	return usable_id

func get_use_distance():
	return use_distance

func connect_signals(target):
	connect("use_usable", target, "use_usable")

func get_usage_code(player_node):
	return "ACTION_USE"

func can_be_used_by(player_node):
	var uc = get_usage_code(player_node)
	return uc and not uc.empty()

func use(player_node, camera_node):
	if not can_be_used_by(player_node):
		return false
	emit_signal("use_usable", player_node, self)
	return true

func add_highlight(player_node):
	var uc = get_usage_code(player_node)
	if not uc or uc.empty():
		return ""
	return __PLDRT.common_utils.get_action_input_control() + tr(uc)

func remove_highlight(player_node):
	pass
