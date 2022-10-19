extends RoomManager

export var use_rooms : bool = true

func _ready():
	if use_rooms:
		rooms_clear()
		rooms_convert()
