extends ColorRect

func _ready():
	color = Game.GetDefaultBackgroundColor()

func OpenGodotVersionManager():
	var godotVersionManager = load("res://scenes/godot-version-manager/godot-version-manager.tscn").instantiate()
	add_child(godotVersionManager)

func _on_open_godot_version_manager_button_pressed():
	OpenGodotVersionManager()

func _on_close_button_pressed():
	queue_free()
