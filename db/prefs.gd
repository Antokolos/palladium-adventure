extends Reference
class_name PLDPrefs

### COMMON PART ###
const MODIFICATION_ID_DEFAULT = "DEFAULT"
const CLEAR_ON_SERVER_IF_NOT_IN_PREFS = false

var achievements = {}

var _pldrt = null

func _init(pldrt):
	_pldrt = pldrt
	load_prefs()

func clear_all_achievements():
	achievements.clear()
	for achievement_id in ACHIEVEMENTS_DATA.keys():
		if CLEAR_ON_SERVER_IF_NOT_IN_PREFS:
			_pldrt.common_utils.clear_achievement(achievement_id, false)
		achievements[achievement_id] = {}
	if CLEAR_ON_SERVER_IF_NOT_IN_PREFS:
		_pldrt.common_utils.store_stats()

func has_achievement_on_server(achievement_id):
	var ach = _pldrt.common_utils.has_achievement(achievement_id)
	return ach and ach.ret and ach.achieved

func get_achievement_progress(achievement_id):
	if not achievements.has(achievement_id):
		push_warning("Cannot get progress for achievement %s: key not found")
		return 0
	var l = achievements[achievement_id].size()
	if l <= 0:
		return 0
	# Default modification ID has priority over another modification IDs
	# If you want to have stat that is dependent on different modifications count
	# (e.g. GREEK_LANGUAGE_LOVER in Palladium), then
	# you should NOT use default modification ID
	var r = (
		achievements[achievement_id][MODIFICATION_ID_DEFAULT]
			if achievements[achievement_id].has(MODIFICATION_ID_DEFAULT)
			else l
	)
	if ACHIEVEMENTS_DATA[achievement_id].has("stat_id"):
		var stat_id = ACHIEVEMENTS_DATA[achievement_id]["stat_id"]
		var stat_max = STATS_DATA[stat_id]["stat_max"]
		if r > stat_max:
			return stat_max
	return r

func set_achievement(achievement_id, modification_id = MODIFICATION_ID_DEFAULT):
	if not achievements.has(achievement_id):
		push_warning("Cannot set achievement %s: key not found" % achievement_id)
		return false
	if not achievements[achievement_id].has(modification_id):
		achievements[achievement_id][modification_id] = 1
	else:
		achievements[achievement_id][modification_id] += 1
	store_achievement(achievement_id)
	if PERFECT_GAME_ACHIEVEMENT_ID:
		for aid in ACHIEVEMENTS_DATA.keys():
			var m = 1
			if ACHIEVEMENTS_DATA[aid].has("stat_id"):
				var stat_id = ACHIEVEMENTS_DATA[aid]["stat_id"]
				m = STATS_DATA[stat_id]["stat_max"]
			var l = get_achievement_progress(aid)
			if PERFECT_GAME_ACHIEVEMENT_ID.casecmp_to(aid) != 0 and l < m:
				achievements[PERFECT_GAME_ACHIEVEMENT_ID].clear()
				_pldrt.common_utils.clear_achievement(PERFECT_GAME_ACHIEVEMENT_ID)
				save_prefs()
				return false
		achievements[PERFECT_GAME_ACHIEVEMENT_ID][MODIFICATION_ID_DEFAULT] = 1
		_pldrt.common_utils.set_achievement(PERFECT_GAME_ACHIEVEMENT_ID)
	save_prefs()
	return true

func store_achievement(achievement_id, show_progress = true):
	if not achievements.has(achievement_id):
		push_warning("Cannot store achievement %s: key not found" % achievement_id)
		return
	if not ACHIEVEMENTS_DATA[achievement_id].has("stat_id"):
		_pldrt.common_utils.set_achievement(achievement_id)
	else:
		var stat_id = ACHIEVEMENTS_DATA[achievement_id]["stat_id"]
		var stat_max = STATS_DATA[stat_id]["stat_max"]
		var l = get_achievement_progress(achievement_id)
		if show_progress:
			_pldrt.common_utils.set_achievement_progress(achievement_id, l, stat_max)
		_pldrt.common_utils.set_stat_int(stat_id, l)
		if l >= stat_max:
			_pldrt.common_utils.set_achievement(achievement_id)

func get_achievement(achievement_id, modification_id = null):
	if not achievements.has(achievement_id):
		push_warning("Cannot get achievement %s: achievement key not found" % achievement_id)
		return 0
	if not modification_id:
		return get_achievement_progress(achievement_id)
	if not achievements[achievement_id].has(modification_id):
		return 0
	return achievements[achievement_id][modification_id]

func resend_achievements():
	for achievement_id in achievements.keys():
		var has_locally = (get_achievement_progress(achievement_id) > 0)
		var has_on_server = has_achievement_on_server(achievement_id)
		if has_locally and not has_on_server:
			store_achievement(achievement_id, false)
		elif has_on_server and not has_locally:
			if CLEAR_ON_SERVER_IF_NOT_IN_PREFS:
				_pldrt.common_utils.clear_achievement(achievement_id, false)
			elif not ACHIEVEMENTS_DATA[achievement_id].has("stat_id"):
				set_achievement(achievement_id)
	_pldrt.common_utils.store_stats()

func load_prefs():
	var f = File.new()
	var error = f.open("user://saves/prefs.json", File.READ)

	if (error):
		print("no prefs to load.")
		clear_all_achievements()
		return

	var d = parse_json( f.get_as_text() )
	if (typeof(d)!=TYPE_DICTIONARY):
		return

	if ("achievements" in d):
		achievements = d.achievements
	else:
		clear_all_achievements()

func save_prefs():
	var f = File.new()
	var error = f.open("user://saves/prefs.json", File.WRITE)
	assert( not error )
	
	var d = {
		"achievements" : achievements
	}
	f.store_line( to_json(d) )

### GAME-SPECIFIC PART ###

const STATS_DATA = {
	"STAT_WINNER" : {"stat_min" : 0, "stat_max" : 3}
}

const ACHIEVEMENTS_DATA = {
	"MAIN_MENU" : {},
	"PERFECT_GAME" : {},
	"WINNER" : {
		"stat_id" : "STAT_WINNER"
	}
}

const PERFECT_GAME_ACHIEVEMENT_ID = "PERFECT_GAME"
