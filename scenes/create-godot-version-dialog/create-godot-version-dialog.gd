extends ColorRect
@onready var _godotVersionLineEdit = $NewProjectDialog/MarginContainer/VBoxContainer/HBoxContainer/GodotVersionLineEdit
@onready var _godotPathLineEdit = $NewProjectDialog/MarginContainer/VBoxContainer/ProjectPathHBoxContainer2/GodotPathLineEdit
@onready var _selectGodotExeFileDialog = $SelectGodotExeFileDialog
@onready var _useFileVersionCheckBox = $NewProjectDialog/MarginContainer/VBoxContainer/UseFileVersionCheckBox
var _godotVersionId = ""

func SetGodotVersionId(value):
	_godotVersionId = value

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
	var id = _godotVersionId
	if id == "":
		id = Common.GetId()
		
	# Save the config file.
	var err = config.save("user://" + App.GetGodotVersionItemFolder() +"/" + id + ".cfg")

	if err != OK:
		OS.alert("An error occurred while saving the config file.")
		return
	
	Signals.emit_signal("GodotVersionsChanged")
	queue_free()

func GetGodotFileVersion(path):	
	path = path.replace("\\", "/")
	var pathParts = path.split("/")
	var version = pathParts[pathParts.size() - 1]
	version = version.to_lower().trim_prefix("godot_v")
	var index = version.find("-")
	if index >= 0:
		version = version.left(index)
		_godotVersionLineEdit.text = "v" + version

func SanityCheckPath(path):
	var isGoodLookingGodotBinary = true
	path = path.replace("\\", "/")
	var pathParts = path.to_lower().split("/")
	var fileName = pathParts[pathParts.size() - 1]
	var index = fileName.find("godot_v")
	if index < 0:
		isGoodLookingGodotBinary = false
	
	index = fileName.find("-stable")
	if index == -1:
		isGoodLookingGodotBinary = false
	
	return isGoodLookingGodotBinary

func _on_file_dialog_file_selected(path):
	_godotPathLineEdit.text = path

	var isRecognizedFileName = SanityCheckPath(path)	
	
	if !isRecognizedFileName:
		_useFileVersionCheckBox.button_pressed = false
		_useFileVersionCheckBox.disabled = true
		
		$ConfirmationDialog.show()
		return false
	
	_useFileVersionCheckBox.disabled = false
	if isRecognizedFileName && _useFileVersionCheckBox.button_pressed:
		GetGodotFileVersion(path)
	
func _on_select_godot_exe_file_dialog_canceled():
	queue_free()

func _on_save_button_pressed():
	SaveGodotConfiguration()

func _on_cancel_button_pressed():
	queue_free()

func _on_use_file_version_check_box_pressed():
	if _useFileVersionCheckBox.button_pressed:
		var isRecognizedFileName = SanityCheckPath(_godotPathLineEdit.text)
		if !isRecognizedFileName:
			return
			
		GetGodotFileVersion(_godotPathLineEdit.text)

func _on_select_godot_path_button_pressed():
	_selectGodotExeFileDialog.show()
