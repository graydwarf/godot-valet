extends Window

@onready var close_button = %CloseButton

func _ready():
	close_button.pressed.connect(_on_close_button_pressed)

func _on_close_button_pressed():
	hide()
