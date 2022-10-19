extends PLDPlayerModel
class_name VasyaModel

func _ready():
	set_loop("male_rest")
	set_loop("male_walks")
	set_loop("male_runs")
	set_loop("male_crouches")
	set_loop("male_reat_squated")
	set_loop("male_death_1_frame")
	set_loop("b_idle")
	set_loop("b1")
	set_loop("b2")
	set_loop("b3")
	set_loop("b4")
	set_loop("b5")
	set_loop("b6")
	set_loop("b7")
	set_loop("b8")
	set_loop("b9")
	set_loop("b10")
	set_loop("b11")
	set_loop("b12")
	set_loop("b13")
	set_loop("b14")
	set_loop("b15")
	set_loop("b16")
	set_loop("b17")

func _on_SpeechTimer_timeout():
	return ._on_SpeechTimer_timeout()

func _on_RestTimer_timeout():
	return ._on_RestTimer_timeout()
