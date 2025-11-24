extends CharacterBody2D

@onready var camera = $Marker2D/Camera2D

var speed = 400  # speed in pixels/sec

func _physics_process(_delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()
