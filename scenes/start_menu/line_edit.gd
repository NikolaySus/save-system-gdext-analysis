extends LineEdit

func _ready():
	connect("text_changed", _on_text_submitted)

func _on_text_submitted(new_text: String):
	Autoload.k_finish_tick = int(new_text)
	print(new_text)
