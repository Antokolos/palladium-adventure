extends PLDUsable
class_name PLDTakable

signal use_takable(player_node, takable, parent, was_taken)

export(PLDDB.TakableIds) var takable_id = PLDDB.TakableIds.NONE
export var count = 1
# If exclusive == true, then this item should not be present at the same time as the another items on the same pedestal or in the same container
export var exclusive = true
export(int) var max_count = 0

onready var initially_present = visible
# If volatile_path is true then the item path should not be saved in game_state.
# For example, any takables that can be dynamically created, e.g. rats
var volatile_path = false setget set_volatile_path, is_volatile_path

func _ready():
	__PLDRT.game_state.connect("item_taken", self, "_on_item_taken")
	__PLDRT.game_state.connect("item_removed", self, "_on_item_removed")

func set_volatile_path(vp):
	volatile_path = vp

func is_volatile_path():
	return volatile_path

func connect_signals(target):
	connect("use_takable", target, "use_takable")

func use(player_node, camera_node):
	if max_count > 0 and __PLDRT.game_state.get_item_count(takable_id) > max_count:
		__PLDRT.game_state.get_hud().queue_popup_message("MESSAGE_TOO_MANY_ITEMS", [ tr(PLDDB.get_items_name(takable_id)) ])
		return false
	var was_taken = is_present()
	__PLDRT.game_state.take(takable_id, count, get_path())
	emit_signal("use_takable", player_node, self, get_parent(), was_taken)
	return was_taken

func get_usage_code(player_node):
	return "ACTION_TAKE" if is_present() else ""

func _on_item_taken(item_id, count_total, count_taken, item_path):
	if has_id(item_id) and item_path == get_path():
		make_absent()

func _on_item_removed(item_id, count_total, count_removed):
	# TODO: make present??? Likely it is handled in containers...
	if has_id(item_id) and has_node("SoundPut"):
		$SoundPut.play()

func has_id(tid):
	return takable_id == tid

func is_exclusive():
	return exclusive

func is_existent():
	return is_present()

func is_present():
	if is_volatile_path():
		return visible
	var ts = __PLDRT.game_state.get_takable_state(get_path())
	return (ts == PLDGameState.TakableState.DEFAULT and initially_present) or (ts == PLDGameState.TakableState.PRESENT)

func make_present():
	make_present_without_state_change()
	if not is_volatile_path():
		__PLDRT.game_state.set_takable_state(get_path(), false)

func make_absent():
	make_absent_without_state_change()
	if not is_volatile_path():
		__PLDRT.game_state.set_takable_state(get_path(), true)

func restore_state():
	if is_volatile_path():
		return
	var state = __PLDRT.game_state.get_takable_state(get_path())
	if state == PLDGameState.TakableState.DEFAULT:
		if initially_present:
			make_present()
		else:
			make_absent()
		return
	if state == PLDGameState.TakableState.PRESENT:
		make_present()
	else:
		make_absent()

func can_do_integrate_forces(state):
	return .can_do_integrate_forces(state) and is_present()
