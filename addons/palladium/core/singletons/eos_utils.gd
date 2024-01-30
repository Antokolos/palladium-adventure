extends Node
class_name EOSUtils

# Will be always false in this stub
var use_eos = false
var is_quitting = false
var network_image_cache = {}

func configure_eos_and_start_game():
	use_eos = false
	start_game()

func has_user_id():
	return false

func start_game():
	__PLDRT.game_state.change_scene("res://main_menu/main_menu.tscn")

func is_quitting():
	return is_quitting

func exit_game():
	is_quitting = true
	get_tree().quit()

func set_achievement(achievement_name, and_store_stats):
	pass
	
func has_achievement(achievement_name):
	return false

func indicate_achievement_progress(achievement_name, progress_current, progress_max):
	pass

func ingest_stat(stat_name, stat_value):
	pass
