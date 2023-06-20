extends Panel
@onready var _projectNameLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/ProjectNameLabel
@onready var _godotVersionLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/HBoxContainer/GodotVersionLabel
@onready var _projectPathLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer/ProjectPathLabel
@onready var _projectVersionLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer3/ProjectVersionLabel

var _selected = false
var _projectId = ""
var _godotVersionId = null

# Release Management Vars
var _windowsChecked = false
var _linuxChecked = false
var _webChecked = false
var _exportPath = ""
var _exportType = ""
var _exportFileName = ""
var _packageType = ""
var _itchProjectName = ""
var _itchProfileName = ""
var _installerConfigurationFileName = ""

func _ready():
	InitSignals()
	RefreshBackground()

func InitSignals():
	Signals.connect("ProjectItemSelected", ProjectItemSelected)
	Signals.connect("BackgroundColorChanged", BackgroundColorChanged)

func BackgroundColorChanged(_color = null):
	RefreshBackground()

func RefreshBackground():
	theme = GetDefaultTheme()	

func SetGodotVersionId(value):
	_godotVersionId = value
	
func SetProjectVersion(value):
	_projectVersionLabel.text = value
	
func SetProjectPath(value):
	_projectPathLabel.text = value

func SetExportFileName(value):
	_exportFileName = value
	
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

func SetExportPath(value):
	_exportPath = value
	
func SetExportType(value):
	_exportType = value
	
func SetPackageType(value):
	_packageType = value

func SetItchProfileName(value):
	_itchProfileName = value

func SetProjectId(value):
	_projectId = value

func SetInstallerConfigurationFileName(value):
	_installerConfigurationFileName = value
	
func GetProjectVersion():
	return _projectVersionLabel.text
	
func GetItchProjectName():
	return _itchProjectName

func GetWindowsChecked():
	return _windowsChecked

func GetLinuxChecked():
	return _linuxChecked	

func GetWebChecked():
	return _webChecked	

func GetExportType():
	return _exportType

func GetExportFileName():
	return _exportFileName
	
func GetPackageType():
	return _packageType

func GetItchProfileName():
	return _itchProfileName
	
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

func GetExportPath():
	return _exportPath
	
func GetProjectId():
	return _projectId

func GetDefaultTheme():
	var customTheme = Theme.new()
	var styleBox = GetDefaultStyleBoxSettings()
	customTheme.set_stylebox("panel", "Panel", styleBox)
	return customTheme

func GetHoverTheme():
	var customTheme = Theme.new()
	var styleBox = GetDefaultStyleBoxSettings()
	styleBox.bg_color = AdjustBackgroundColor(0.12)
	customTheme.set_stylebox("panel", "Panel", styleBox)
	return customTheme

func GetSelectedTheme():
	var customTheme = Theme.new()
	var styleBox = GetDefaultStyleBoxSettings()
	styleBox.bg_color = AdjustBackgroundColor(0.32)
	customTheme.set_stylebox("panel", "Panel", styleBox)
	return customTheme

func AdjustBackgroundColor(amount):
	var colorToSubtract = Color(amount, amount, amount, 0.0)

	var newColor = Color(
		max(App.GetBackgroundColor().r + colorToSubtract.r, 0),
		max(App.GetBackgroundColor().g + colorToSubtract.g, 0),
		max(App.GetBackgroundColor().b + colorToSubtract.b, 0),
		max(App.GetBackgroundColor().a + colorToSubtract.a, 0)
	)
	
	return newColor
	
func GetDefaultStyleBoxSettings():
	var styleBox = StyleBoxFlat.new()
	styleBox.bg_color = AdjustBackgroundColor(-0.08)
	styleBox.border_color = Color(0.6, 0.6, 0.6)
	styleBox.border_width_left = 2
	styleBox.border_width_top = 2
	styleBox.border_width_right = 2
	styleBox.border_width_bottom = 2
	styleBox.corner_radius_top_left = 6
	styleBox.corner_radius_top_right = 6
	styleBox.corner_radius_bottom_right = 6
	styleBox.corner_radius_bottom_left = 6
	return styleBox
	
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
		var err = config.load("user://" + App.GetGodotVersionItemFolder() + "/" + fileName + ".cfg")
		if err == OK:
			return config.get_value("GodotVersionSettings", "godot_path", "???")

func GetFormattedProjectPath():
	return GetProjectPathBaseDir().to_lower()#.replace("/", "\\")

func RestoreDefaultColor():
	theme = GetDefaultTheme()
	
func ShowHoverColor():
	theme = GetHoverTheme()
	
func ShowSelectedColor():
	theme = GetSelectedTheme()
	
func SelectProjectItem():
	ShowSelectedColor()
	_selected = true

func UnselectProjectItem():
	RestoreDefaultColor()
	_selected = false

func SaveProjectItem():
	var config = ConfigFile.new()

	config.set_value("ProjectSettings", "project_name", _projectNameLabel.text)
	config.set_value("ProjectSettings", "export_path", _exportPath)
	config.set_value("ProjectSettings", "godot_version_id", _godotVersionId)
	config.set_value("ProjectSettings", "project_path", _projectPathLabel.text)
	config.set_value("ProjectSettings", "export_file_name", _exportFileName)
	config.set_value("ProjectSettings", "project_version", _projectVersionLabel.text)
	config.set_value("ProjectSettings", "windows_preset_checked", _windowsChecked)
	config.set_value("ProjectSettings", "linux_preset_checked", _linuxChecked)
	config.set_value("ProjectSettings", "web_preset_checked", _webChecked)
	config.set_value("ProjectSettings", "export_type", _exportType)
	config.set_value("ProjectSettings", "package_type", _packageType)
	config.set_value("ProjectSettings", "itch_profile_name", _itchProfileName)
	config.set_value("ProjectSettings", "itch_project_name", _itchProjectName)
	
	# Save the config file.
	var err = config.save("user://" + App.GetProjectItemFolder() + "/" + _projectId + ".cfg")

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
	
