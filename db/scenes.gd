extends Node
class_name PLDScenes

const DATA = {
	"res://addons/palladium/ui/game_over.tscn" : { "splash" : null, "progress" : false },
	"res://main_menu.tscn" : { "splash" : preload("res://addons/palladium/assets/images/splash/knossos.jpg"), "progress" : true },
	"res://our_games.tscn" : { "splash" : preload("res://addons/palladium/assets/images/splash/knossos.jpg"), "progress" : true },
	"res://arena.tscn" : { "splash" : preload("res://addons/palladium/assets/images/splash/knossos.jpg"), "progress" : true },
}

var _pldrt = null

func _init(pldrt):
	_pldrt = pldrt
