extends HBoxContainer

func _process(_delta) -> void:
	self.visible = (Autoload.k_finish_tick > 0)
