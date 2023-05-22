extends ColorRect
@onready var _projectNameLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/ProjectNameLabel
@onready var _godotVersionLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/GodotVersionLabel
@onready var _projectPathLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer/ProjectPathLabel
@onready var _projectVersionLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer3/ProjectVersionLabel

var _selected = false
var _projectId = ""
var _godotVersionId = null

# Release Management Vars
var _itchProjectName = ""
var _projectVersion = ""
var _windowsChecked = false
var _linuxChecked = false
var _webChecked = false
var _exportType = ""
var _packageType = ""
var _itchProfileName = ""
var _projectReleaseId = ""

func _ready():
	Signals.connect("ProjectItemSelected", ProjectItemSelected)

func SetGodotVersionId(value):
	_godotVersionId = value
	
func SetProjectVersion(value):
	_projectVersionLabel.text = value

func SetProjectReleaseId(value):
	_projectReleaseId = value
	
func SetProjectPath(value):
	_projectPathLabel.text = value
	
func SetProjectName(value):
	_projectNameLabel.text = value
	
func SetGodotVersion(value):
	_godotVersionLabel.text = value

func SetItchProjectName(value):
	_itchProjectName = value

func SetWindowsChecked(value):
	_windowsChecked = value

func SetLinuxChecked(value):
	_linuxChecked = value
	
func SetWebChecked(value):
	_webChecked = value

func SetExportType(value):
	_exportType = value
	
func SetPackageType(value):
	_packageType = value

func SetItchProfileName(value):
	_itchProfileName = value
	
func GetProjectVersion():
	return _projectVersionLabel.text
	
func GetItchProjectName(value):
	return _itchProjectName
	
# Strip off the file name
# /project.godot
func GetProjectPathBaseDir():
	return _projectPathLabel.text.get_base_dir()

func GetProjectPath():
	return _projectPathLabel.text
	
func GetProjectPathWithProjectFile():
	return _projectPathLabel.text
	
func GetGodotVersion():
	return _godotVersionLabel.text

func GetGodotVersionId():
	return _godotVersionId
	
func GetProjectName():
	return _projectNameLabel.text
	
func SetProjectId(value):
	_projectId = value

func GetProjectId():
	return _projectId
	
func ProjectItemSelected(projectItem, _isSelected):
	if projectItem == self:
		return
	
	UnselectProjectItem()

func GetGodotPath(godotVersionId):
	var files = Files.GetFilesFromPath("user://godot-version-items")
	for file in files:
		if !file.ends_with(".cfg"):
			continue

		var fileName = file.trim_suffix(".cfg")
		if fileName != godotVersionId:
			continue
			
		var config = ConfigFile.new()
		var err = config.load("user://" + Game.GetGodotVersionItemFolder() + "/" + fileName + ".cfg")
		if err == OK:
			return config.get_value("GodotVersionSettings", "godot_path", "???")
	
func RestoreDefaultColor():
	color = Color(0.0, 0.0, 0.0, 0.5)

func ShowHoverColor():
	color = Color(0.0, 0.0, 0.0, 0.3)

func ShowSelectedColor():
	color = Color(0.0, 0.0, 0.5, 0.2)

func GetFormattedProjectPath():
	return GetProjectPathBaseDir().to_lower().replace("/", "\\")

func SelectProjectItem():
	ShowSelectedColor()
	_selected = true

func UnselectProjectItem():
	RestoreDefaultColor()
	_selected = false

func SaveProjectItem():
	var config = ConfigFile.new()

	config.set_value("ProjectSettings", "project_name", _projectNameLabel.text)
	config.set_value("ProjectSettings", "godot_version_id", _godotVersionId)
	config.set_value("ProjectSettings", "project_path", _projectPathLabel.text)
	config.set_value("ProjectSettings", "project_version", _projectVersion)
	config.set_value("ProjectSettings", "windows_preset_checked", _windowsChecked)
	config.set_value("ProjectSettings", "linux_preset_checked", _linuxChecked)
	config.set_value("ProjectSettings", "web_preset_checked", _webChecked)
	config.set_value("ProjectSettings", "export_type", _exportType)
	config.set_value("ProjectSettings", "package_type", _packageType)
	config.set_value("ProjectSettings", "itch_profile_name", _itchProfileName)
	
	# Save the config file.
	var err = config.save("user://" + Game.GetProjectItemFolder() + "/" + _projectId + ".cfg")

	if err != OK:
		OS.alert("An error occurred while saving the config file.")
	
func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _selected:
			_selected = false
			Signals.emit_signal("ProjectItemSelected", self, _selected)
		else:
			_selected = true
			Signals.emit_signal("ProjectItemSelected", self, _selected)

func _on_mouse_entered():
	if _selected:
		return
	
	ShowHoverColor()

func _on_mouse_exited():
	if _selected:
		return
	
	RestoreDefaultColor()
	
