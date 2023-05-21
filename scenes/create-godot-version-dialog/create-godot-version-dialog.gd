extends ColorRect
@onready var _godotVersionLineEdit = $NewProjectDialog/MarginContainer/VBoxContainer/HBoxContainer/GodotVersionLineEdit
@onready var _godotPathLineEdit = $NewProjectDialog/MarginContainer/VBoxContainer/ProjectPathHBoxContainer2/GodotPathLineEdit
@onready var _selectGodotExeFileDialog = $SelectGodotExeFileDialog

var _id = ""

func SetId(value):
	_id = value

func SetGodotVersion(value):
	_godotVersionLineEdit.text = value
	
func SetGodotPath(value):
	_godotPathLineEdit.text = value

func SaveGodotConfiguration():
	if _godotVersionLineEdit.text == "":
		OS.alert("Invalid godot version name")
		return
	
	CreateNewGodotVersionSettingsFile()
	
func CreateNewGodotVersionSettingsFile():
	var config = ConfigFile.new()

	config.set_value("GodotVersionSettings", "godot_version", _godotVersionLineEdit.text)
	config.set_value("GodotVersionSettings", "godot_path", _godotPathLineEdit.text)
		
	# New or are we saving?
	var id = _id
	if _id == "":
		id = Common.GetId()
		
	# Save the config file.
	var err = config.save("user://" + Game.GetGodotVersionItemFolder() +"/" + id + ".cfg")

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

func _on_cancel_button_pressed():
	queue_free()
