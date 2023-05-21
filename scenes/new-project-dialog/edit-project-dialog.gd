extends ColorRect

@onready var _projectNameLineEdit = $VBoxContainer/HBoxContainer/ProjectNameLineEdit
@onready var _godotVersionOptionButton = $VBoxContainer/GodotVersionHBoxContainer/GodotVersionOptionButton
@onready var _projectPathLineEdit = $VBoxContainer/ProjectPathHBoxContainer2/ProjectPathLineEdit
@onready var _fileDialog = $FileDialog
func _ready():
	color = Game.GetDefaultBackgroundColor()
	LoadGodotVersion()

func ConfigureForSelectedProject(id):
	if id == null:
		return
	
	LoadProjectById(id)

func LoadProjectById(id):
	var config = ConfigFile.new()
	var err = config.load("user://" + Game.GetProjectItemFolder() + "/" + id + ".cfg")
	if err == OK:
		_projectNameLineEdit.text = config.get_value("ProjectSettings", "project_name", "")
		_godotVersionOptionButton.text = config.get_value("ProjectSettings", "godot_version", "")
		_projectPathLineEdit = config.get_value("ProjectSettings", "project_path", "")
			
func LoadGodotVersion():
	var allResourceFiles = Files.GetFilesFromPath("user://godot-version-items")
	for resourceFile in allResourceFiles:
		if !resourceFile.ends_with(".cfg"):
			continue

		var fileName = resourceFile.trim_suffix(".cfg")
			
		var config = ConfigFile.new()
		var err = config.load("user://godot-version-items//" + fileName + ".cfg")
		if err == OK:
			var godotVersion = config.get_value("GodotVersionSettings", "godot_version", "???")
			_godotVersionOptionButton.add_item(godotVersion)
			
func CreateNewProject():
	var newProjectName = _projectNameLineEdit.text.trim_prefix(" ").trim_suffix(" ")
	if newProjectName == "":
		OS.alert("Invalid project name. Cancel to close.")
		return
	
	var id = Common.GetId()
	CreateNewSettingsFile(id)
	Signals.emit_signal("NewProjectCreated", id)
	queue_free()

func CreateNewSettingsFile(id):
	var config = ConfigFile.new()

	config.set_value("ProjectSettings", "project_name", _projectNameLineEdit.text)
	config.set_value("ProjectSettings", "godot_version", _godotVersionOptionButton.text)
	config.set_value("ProjectSettings", "project_path", _projectPathLineEdit.text)

	# Save the config file.
	var err = config.save("user://" + Game.GetProjectItemFolder() + "/" + id + ".cfg")

	if err != OK:
		OS.alert("An error occurred while saving the config file.")
		
func _on_cancel_button_pressed():
	queue_free()

func _on_save_button_pressed():
	CreateNewProject()

func _on_file_dialog_dir_selected(dir):
	_projectPathLineEdit.text = dir


func _on_select_project_folder_button_pressed():
	_fileDialog.show()
