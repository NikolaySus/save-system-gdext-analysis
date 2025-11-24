extends OptionButton

var options = {
	"<NONE>": [],
	"RIGHT_DOWN": [KEY_RIGHT, KEY_DOWN],
	"DOWN": [KEY_DOWN],
	"LEFT_DOWN": [KEY_LEFT, KEY_DOWN],
	"LEFT": [KEY_LEFT],
	"LEFT_UP": [KEY_LEFT, KEY_UP],
	"UP": [KEY_UP],
	"RIGHT_UP": [KEY_RIGHT, KEY_UP],
	"RIGHT": [KEY_RIGHT],
}

var options_array = options.keys()

func _ready() -> void:
	var counter: int = 0
	for key in options_array:
		add_item(key, counter)
		counter += 1
	connect("item_selected", _item_selected)

func _item_selected(index: int):
	Autoload.k_option_str = options_array[index]
	Autoload.k_option = options[Autoload.k_option_str]
	print(Autoload.k_option_str)
