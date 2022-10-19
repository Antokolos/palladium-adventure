extends Spatial

export(bool) var enabled : bool = true
export(int) var enemies_count_max : int = 10
export(String) var enemy_name_template : String = "enemy_%d"
export(String) var enemy_model_path : String = ""
export(NodePath) var navigation_path : NodePath = NodePath("..")

onready var spawn_timer = $SpawnTimer
var enemies_count_cur = 0

func _ready():
	if enabled:
		spawn_timer.start()

func _on_SpawnTimer_timeout():
	enemies_count_cur = enemies_count_cur + 1
	var enemy = load("res://addons/palladium/core/enemy.tscn").instance()
	enemy.name_hint = enemy_name_template % enemies_count_cur
	enemy.navigation_path = navigation_path
	enemy.has_melee_attack = true
	enemy.max_hits = 1
	enemy.use_distance = 8.8
	enemy.global_transform = global_transform
	var enemy_model = load(enemy_model_path).instance()
	var model_holder = Spatial.new()
	model_holder.set_name("Model")
	model_holder.add_child(enemy_model)
	enemy.add_child(model_holder)
	get_parent().add_child(enemy)
	enemy.set_relationship(-1)
	enemy.activate()
	if enemies_count_cur >= enemies_count_max:
		spawn_timer.stop()
