extends Button

func _pressed() -> void:
	if Autoload.k_option_use_naive:
		get_tree().change_scene_to_file("res://scenes/naive_open_world.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/open_world.tscn")
