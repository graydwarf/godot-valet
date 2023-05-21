extends Control
@onready var _godotVersionItemContainer = $HBoxContainer/MarginContainer/ScrollContainer/VBoxContainer
func _ready():
	InitSignals()
	LoadGodotVersionItems()
	
func InitSignals():
	Signals.connect("NewGodotVersionAdded", NewGodotVersionAdded)

func NewGodotVersionAdded():
	LoadGodotVersionItems()

func LoadGodotVersionItems():
	var allResourceFiles = Files.GetFilesFromPath("user://godot-version-items")
	for resourceFile in allResourceFiles:
		if !resourceFile.ends_with(".cfg"):
			continue

		var fielName = resourceFile.trim_suffix(".cfg")
		
		var godotVersionItem = load("res://scenes/scenes/godot-version-item/godot-version-item.tscn").instantiate()
		_godotVersionItemContainer.add_child(godotVersionItem)
		
		var config = ConfigFile.new()
		var err = config.load("user://godot-version-items//" + fielName + ".cfg")
		if err == OK:
			godotVersionItem.SetGodotVersion(config.get_value("GodotVersionSettings", "godot_version", ""))
			godotVersionItem.SetGodotPath(config.get_value("GodotVersionSettings", "godot_path", ""))
		
func OpenNewGodotVersionDialog():
	var newGodotVersionDialog = load("res://scenes/scenes/new-godot-version-dialog/new-godot-version-dialog.tscn").instantiate()
	add_child(newGodotVersionDialog)
	
func _on_new_project_button_pressed():
	OpenNewGodotVersionDialog()
