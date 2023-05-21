extends ColorRect
@onready var _godotVersionNameLineEdit = $NewProjectDialog/MarginContainer/VBoxContainer/HBoxContainer/GodotNameLineEdit
@onready var _godotPathLineEdit = $NewProjectDialog/MarginContainer/VBoxContainer/ProjectPathHBoxContainer2/GodotPathLineEdit
@onready var _selectGodotExeFileDialog = $SelectGodotExeFileDialog

var _godotVersionName = ""
var _godotPath = ""

func SetGodotPath(value):
	_godotPath = value

func SetGodotVersionName(value):
	_godotVersionName = value

func GetGodotPath():
	return _godotPath

func GetGodotVersionName():
	return _godotVersionName

func SaveGodotConfiguration():
	if _godotVersionNameLineEdit.text == "":
		OS.alert("Invalid godot version name")
		return
	
	if !FileAccess.file_exists(_godotPathLineEdit.text):
		OS.alert("Could not find file at given path! Expecting godot binary")
	
	_godotPath = _godotPathLineEdit.text
	_godotVersionName = _godotVersionNameLineEdit.text

	CreateNewGodotVersionSettingsFile()
	
func CreateNewGodotVersionSettingsFile():
	var config = ConfigFile.new()

	config.set_value("GodotVersionSettings", "godot_version", _godotVersionName)
	config.set_value("GodotVersionSettings", "godot_path", _godotPath)
	
	DirAccess.make_dir_recursive_absolute("user://godot-version-items")
	
	# Save the config file.
	var err = config.save("user://godot-version-items/" + Common.GetId() + ".cfg")

	if err != OK:
		OS.alert("An error occurred while saving the config file.")
		return
	
	Signals.emit_signal("NewGodotVersionAdded")
	queue_free()
	
func _on_select_project_folder_button_pressed():
	_selectGodotExeFileDialog.show()

func _on_file_dialog_file_selected(path):
	_godotPathLineEdit.text = path

func _on_select_godot_exe_file_dialog_canceled():
	queue_free()

func _on_save_button_pressed():
	SaveGodotConfiguration()
