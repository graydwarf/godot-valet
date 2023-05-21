extends ColorRect

@onready var _godotVersionItemContainer = $VBoxContainer/HBoxContainer/MarginContainer/ScrollContainer/GodotVersionItemContainer
var _selectedGodotVersionItem

func _ready():
	InitSignals()
	color = Game.GetDefaultBackgroundColor()
	LoadGodotVersionItems()
	
func InitSignals():
	Signals.connect("GodotVersionItemClicked", GodotVersionItemClicked)
	Signals.connect("NewGodotVersionAdded", NewGodotVersionAdded)

func GodotVersionItemClicked(godotVersionItem):
	_selectedGodotVersionItem = godotVersionItem
	
func ClearVersionItems():
	for child in _godotVersionItemContainer.get_children():
		child.queue_free()
		
func NewGodotVersionAdded():
	ClearVersionItems()
	LoadGodotVersionItems()

func EditSelectedGodotVersion():
	if !is_instance_valid(_selectedGodotVersionItem):
		return
		
	var editGodotVersionDialog = load("res://scenes/create-godot-version-dialog/create-godot-version-dialog.tscn").instantiate()
	add_child(editGodotVersionDialog)
	editGodotVersionDialog.SetId(_selectedGodotVersionItem.GetId())
	editGodotVersionDialog.SetGodotVersion(_selectedGodotVersionItem.GetGodotVersion())
	editGodotVersionDialog.SetGodotPath(_selectedGodotVersionItem.GetGodotPath())
	
func LoadGodotVersionItems():
	var allResourceFiles = Files.GetFilesFromPath("user://" + Game.GetGodotVersionItemFolder())
	for resourceFile in allResourceFiles:
		if !resourceFile.ends_with(".cfg"):
			continue

		var fileName = resourceFile.trim_suffix(".cfg")
		
		var godotVersionItem = load("res://scenes/godot-version-item/godot-version-item.tscn").instantiate()
		_godotVersionItemContainer.add_child(godotVersionItem)
		
		var config = ConfigFile.new()
		var err = config.load("user://" + Game.GetGodotVersionItemFolder() + "/" + fileName + ".cfg")
		if err == OK:
			godotVersionItem.SetGodotVersion(config.get_value("GodotVersionSettings", "godot_version", ""))
			godotVersionItem.SetGodotPath(config.get_value("GodotVersionSettings", "godot_path", ""))
			godotVersionItem.SetId(fileName)
		
func OpenNewGodotVersionDialog():
	var newGodotVersionDialog = load("res://scenes/create-godot-version-dialog/create-godot-version-dialog.tscn").instantiate()
	add_child(newGodotVersionDialog)
	
func _on_new_project_button_pressed():
	OpenNewGodotVersionDialog()

func _on_close_button_pressed():
	queue_free()

func _on_edit_button_pressed():
	EditSelectedGodotVersion()
