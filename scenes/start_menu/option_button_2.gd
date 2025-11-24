extends OptionButton

func _ready() -> void:
	connect("item_selected", _item_selected)

func _item_selected(index: int):
	Autoload.k_option_use_naive = index
	print("Use naive set to: ", Autoload.k_option_use_naive)
