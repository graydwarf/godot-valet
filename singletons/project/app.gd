extends Node

var _appName = "godot-valet"
var _backgroundColor = Color(0.2, 0.2, 0.2)
var _projectItemFolder = "project-items"
var _solutionFolder = "solution-settings"
var _solutionConfigFile = "user://" + _solutionFolder + ".cfg"
var _godotVersionItemFolder = "godot-version-items"
var _lastUpdateTime
var _themePath = "res://assets/themes/global-themes/godot-dark-default.tres"

# Debug Helpers
var _isDebuggingWithoutThreads = false

func _ready():
	LoadSavedSolutionSettings()
	DebugCheck()

# We display as errors to avoid accidently releasing with debug helpers enabled.
func DebugCheck():
	if _isDebuggingWithoutThreads:
		push_error("DebugCheck: _isDebuggingWithoutThreads is enabled!")

func GetIsDebuggingWithoutThreads():
	return _isDebuggingWithoutThreads
	
func GetAppName():
	return _appName
	
func GetThemePath():
	return _themePath

func GetProjectItemFolder():
	return _projectItemFolder

func GetGodotVersionItemFolder():
	return _godotVersionItemFolder
	
func GetBackgroundColor():
	return _backgroundColor

func GetLastUpdateTime():
	return _lastUpdateTime
	
func SetLastUpdateTime(value):
	_lastUpdateTime = value

func SetBackgroundColor(value):
	_backgroundColor = value
	Signals.emit_signal("BackgroundColorChanged")

func LoadSavedSolutionSettings():
	if !FileAccess.file_exists(_solutionConfigFile):
		return
		
	var config = ConfigFile.new()
	var err = config.load(_solutionConfigFile)
	if err == OK:
		_backgroundColor = config.get_value("SolutionSettings", "bg_color", "")
	else:
		OS.alert("An error occured loading the solution configuration file")
	
func SaveSolutionSettings():
	var config = ConfigFile.new()

	config.set_value("SolutionSettings", "bg_color", _backgroundColor)
	
	# Save the config file.
	var err = config.save(_solutionConfigFile)

	if err != OK:
		OS.alert("An error occurred while saving the solution config file.")

#func GetCustomScrollContainerStyle():
#	var customTheme = Theme.new()
#	var grabberStyle = StyleBoxFlat.new()
#	grabberStyle.set_expand_margin_size(Control.MARGIN_LEFT, 10)
#	grabberStyle.set_expand_margin_size(MARGIN_RIGHT, 10)
#	customTheme.set_stylebox("grabber", "VScrollBar", grabberStyle)
#	customTheme.set_stylebox("grabber", "HScrollBar", grabberStyle)
#	return customTheme	
