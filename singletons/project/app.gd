extends Node

var _appName = "godot-valet"
var _projectItemFolder = "project-items"
var _solutionFolder = "solution-settings"
var _solutionConfigFile = "user://" + _solutionFolder + ".cfg"
var _godotVersionItemFolder = "godot-version-items"
var _lastUpdateTime
var _themePath = "res://assets/themes/global-themes/godot-dark-default.tres"

# Debug Helpers
# Set this to true anytime you are learning/testing/debugging
var _isDebuggingWithoutThreads = false

# Solution Settings
var _backgroundColor = Color(0.2, 0.2, 0.2)
var _showHidden = false
var _sortType = Enums.SortByType.EditedDate
var _claudeCodeLaunchCommand = 'start cmd /k "cd /d {project_path} && claude"'
var _claudeCodeButtonEnabled = true
var _claudeApiChatButtonEnabled = false
var _disclaimerAccepted = false

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

func GetShowHidden():
	return _showHidden

func GetSortType():
	return _sortType

func GetClaudeCodeLaunchCommand():
	return _claudeCodeLaunchCommand

func SetClaudeCodeLaunchCommand(value):
	_claudeCodeLaunchCommand = value
	SaveSolutionSettings()

func GetDefaultClaudeCodeLaunchCommand():
	return 'start cmd /k "cd /d {project_path} && claude"'

func GetClaudeCodeButtonEnabled():
	return _claudeCodeButtonEnabled

func SetClaudeCodeButtonEnabled(value):
	_claudeCodeButtonEnabled = value
	SaveSolutionSettings()

func GetClaudeApiChatButtonEnabled():
	return _claudeApiChatButtonEnabled

func SetClaudeApiChatButtonEnabled(value):
	_claudeApiChatButtonEnabled = value
	SaveSolutionSettings()

func GetDisclaimerAccepted():
	return _disclaimerAccepted

func SetDisclaimerAccepted(value):
	_disclaimerAccepted = value
	SaveSolutionSettings()

# Returns true if running as exported binary (not from editor)
func IsRunningAsBinary() -> bool:
	return not OS.has_feature("editor")

# Returns true if we need to show the disclaimer (binary + not yet accepted)
func ShouldShowDisclaimer() -> bool:
	return IsRunningAsBinary() and not _disclaimerAccepted

func SetLastUpdateTime(value):
	_lastUpdateTime = value

func SetBackgroundColor(value):
	_backgroundColor = value
	Signals.emit_signal("BackgroundColorChanged")

# API Key Management
func SaveKey(serviceName: String, apiKey: String):
	var config = ConfigFile.new()
	
	var err
	# Load existing config if it exists
	if FileAccess.file_exists(_solutionConfigFile):
		err = config.load(_solutionConfigFile)
		if err != OK:
			OS.alert("Error loading config file for API key storage")
			return
	
	# Set the API key in the APIKeys section
	config.set_value("APIKeys", serviceName, apiKey)
	
	# Save the config file
	err = config.save(_solutionConfigFile)
	if err != OK:
		OS.alert("Error saving API key to config file")

func GetKey(serviceName: String) -> String:
	if !FileAccess.file_exists(_solutionConfigFile):
		return ""
		
	var config = ConfigFile.new()
	var err = config.load(_solutionConfigFile)
	if err != OK:
		return ""
	
	return config.get_value("APIKeys", serviceName, "")

func HasKey(serviceName: String) -> bool:
	return GetKey(serviceName) != ""

func LoadSavedSolutionSettings():
	if !FileAccess.file_exists(_solutionConfigFile):
		return

	var config = ConfigFile.new()
	var err = config.load(_solutionConfigFile)
	if err == OK:
		_backgroundColor = config.get_value("SolutionSettings", "bg_color", "")
		_showHidden = config.get_value("SolutionSettings", "show_hidden", false)
		_sortType = config.get_value("SolutionSettings", "sort_type", Enums.SortByType.EditedDate)
		_claudeCodeLaunchCommand = config.get_value("SolutionSettings", "claude_code_launch_command", GetDefaultClaudeCodeLaunchCommand())
		_claudeCodeButtonEnabled = config.get_value("SolutionSettings", "claude_code_button_enabled", true)
		_claudeApiChatButtonEnabled = config.get_value("SolutionSettings", "claude_api_chat_button_enabled", false)
		_disclaimerAccepted = config.get_value("SolutionSettings", "disclaimer_accepted", false)
	else:
		OS.alert("An error occured loading the solution configuration file")
	
func SaveSolutionSettings():
	var config = ConfigFile.new()

	# Load existing config to preserve API keys
	if FileAccess.file_exists(_solutionConfigFile):
		config.load(_solutionConfigFile)

	config.set_value("SolutionSettings", "bg_color", _backgroundColor)
	config.set_value("SolutionSettings", "show_hidden", _showHidden)
	config.set_value("SolutionSettings", "sort_type", _sortType)
	config.set_value("SolutionSettings", "claude_code_launch_command", _claudeCodeLaunchCommand)
	config.set_value("SolutionSettings", "claude_code_button_enabled", _claudeCodeButtonEnabled)
	config.set_value("SolutionSettings", "claude_api_chat_button_enabled", _claudeApiChatButtonEnabled)
	config.set_value("SolutionSettings", "disclaimer_accepted", _disclaimerAccepted)

	# Save the config file.
	var err = config.save(_solutionConfigFile)

	if err != OK:
		OS.alert("An error occurred while saving the solution config file.")

func SetShowHidden(value):
	_showHidden = value
	SaveSolutionSettings()

func SetSortType(value):
	_sortType = value
	SaveSolutionSettings()
	
#func GetCustomScrollContainerStyle():
#	var customTheme = Theme.new()
#	var grabberStyle = StyleBoxFlat.new()
#	grabberStyle.set_expand_margin_size(Control.MARGIN_LEFT, 10)
#	grabberStyle.set_expand_margin_size(MARGIN_RIGHT, 10)
#	customTheme.set_stylebox("grabber", "VScrollBar", grabberStyle)
#	customTheme.set_stylebox("grabber", "HScrollBar", grabberStyle)
#	return customTheme
