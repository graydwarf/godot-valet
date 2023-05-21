extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func OpenGodotVersionManager():
	var godotVersionManager = load("res://scenes/scenes/godot-version-manager/godot-version-manager.tscn").instantiate()
	add_child(godotVersionManager)

func _on_open_godot_version_manager_button_pressed():
	OpenGodotVersionManager()
