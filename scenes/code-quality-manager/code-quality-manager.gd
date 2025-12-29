extends Panel

# Preload analyzer scripts
const QubeAnalyzer = preload("res://scripts/code-quality/code-analyzer.gd")
const QubeConfig = preload("res://scripts/code-quality/analysis-config.gd")
const QubeIssue = preload("res://scripts/code-quality/issue.gd")
const QubeResult = preload("res://scripts/code-quality/analysis-result.gd")

# UI References - Project Card Header
@onready var _thumbTextureRect: TextureRect = %ThumbTextureRect
@onready var _projectNameLabel: Label = %ProjectNameLabel
@onready var _projectPathLabel: Label = %ProjectPathLabel
@onready var _folderButton: Button = %FolderButton
@onready var _lastScannedLabel: Label = %LastScannedLabel

# UI References - Footer
@onready var _scanButton: Button = %ScanButton
@onready var _saveButton: Button = %SaveButton
@onready var _resultsVBox: VBoxContainer = %ResultsVBox
@onready var _resultsCountLabel: Label = %ResultsCountLabel
@onready var _exportJSONButton: Button = %ExportJSONButton
@onready var _exportHTMLButton: Button = %ExportHTMLButton

# Filter controls
@onready var _severityFilter: OptionButton = %SeverityFilter
@onready var _typeFilter: OptionButton = %TypeFilter
@onready var _fileFilter: LineEdit = %FileFilter

# Threshold controls - SpinBoxes
@onready var _fileLinesWarn: SpinBox = %FileLinesWarn
@onready var _fileLinesCrit: SpinBox = %FileLinesCrit
@onready var _funcLinesWarn: SpinBox = %FuncLinesWarn
@onready var _funcLinesCrit: SpinBox = %FuncLinesCrit
@onready var _complexityWarn: SpinBox = %ComplexityWarn
@onready var _complexityCrit: SpinBox = %ComplexityCrit
@onready var _godClassWarn: SpinBox = %GodClassWarn
@onready var _maxParamsSpin: SpinBox = %MaxParamsSpin
@onready var _maxNestingSpin: SpinBox = %MaxNestingSpin

# Threshold controls - Enable checkboxes
@onready var _fileLinesCheck: CheckBox = %FileLinesCheck
@onready var _funcLinesCheck: CheckBox = %FuncLinesCheck
@onready var _complexityCheck: CheckBox = %ComplexityCheck
@onready var _godClassCheck: CheckBox = %GodClassCheck
@onready var _maxParamsCheck: CheckBox = %MaxParamsCheck
@onready var _maxNestingCheck: CheckBox = %MaxNestingCheck

# Code checks
@onready var _todoCheck: CheckBox = %TodoCheck
@onready var _printCheck: CheckBox = %PrintCheck
@onready var _emptyFuncCheck: CheckBox = %EmptyFuncCheck
@onready var _magicNumCheck: CheckBox = %MagicNumCheck
@onready var _commentedCodeCheck: CheckBox = %CommentedCodeCheck
@onready var _typeAnnotationsCheck: CheckBox = %TypeAnnotationsCheck
@onready var _longLinesCheck: CheckBox = %LongLinesCheck
@onready var _namingCheck: CheckBox = %NamingCheck

# Help panel
@onready var _helpPanel: Control = %HelpPanel
@onready var _resultsScroll: ScrollContainer = %ResultsScroll
@onready var _closeHelpButton: Button = %CloseHelpButton

# Reset icon
var _resetIcon: Texture2D

# Claude/AI icon
var _sparkleIcon: Texture2D

# Column headers
@onready var _columnHeaderHBox: HBoxContainer = %ColumnHeaderHBox
@onready var _locationHeader: Label = %LocationHeader
@onready var _messageHeader: Label = %MessageHeader
@onready var _typeHeader: Label = %TypeHeader
@onready var _severitySep: VSeparator = %SeveritySep
@onready var _locationSep: VSeparator = %LocationSep
@onready var _messageSep: VSeparator = %MessageSep

# Column widths (for resizable headers)
var _locationColumnWidth: float = 280.0
var _typeColumnWidth: float = 120.0
var _draggingSeparator: VSeparator = null
var _dragStartX: float = 0.0
var _dragStartWidth: float = 0.0

var _selectedProjectItem = null
var _currentConfig: Resource = null
var _currentResult = null
var _allIssues: Array = []
var _lastScannedTimestamp: String = ""

func _ready():
	# Load Claude icon for AI buttons
	_sparkleIcon = load("res://scenes/claude/assets/claude.png")

	# Set up column separator drag handlers
	_setupColumnSeparatorDrag(_locationSep, _locationHeader)
	_setupColumnSeparatorDrag(_messageSep, _typeHeader)

func _setupColumnSeparatorDrag(separator: VSeparator, targetHeader: Label):
	separator.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_draggingSeparator = separator
					_dragStartX = get_global_mouse_position().x
					_dragStartWidth = targetHeader.custom_minimum_size.x
				else:
					_draggingSeparator = null
	)

func _input(event: InputEvent):
	if _draggingSeparator == null:
		return
	if event is InputEventMouseMotion:
		var delta = get_global_mouse_position().x - _dragStartX
		var newWidth: float
		# Location separator adjusts location column
		if _draggingSeparator == _locationSep:
			newWidth = clampf(_dragStartWidth + delta, 100.0, 600.0)
			_locationHeader.custom_minimum_size.x = newWidth
			_locationColumnWidth = newWidth
		# Message separator adjusts type column (inverse - drag right = smaller type)
		elif _draggingSeparator == _messageSep:
			newWidth = clampf(_dragStartWidth - delta, 80.0, 300.0)
			_typeHeader.custom_minimum_size.x = newWidth
			_typeColumnWidth = newWidth
		# Refresh display to apply new widths
		if _currentResult != null:
			_displayResults()

# Called by ProjectManager to configure with selected project
func Configure(selectedProjectItem):
	_selectedProjectItem = selectedProjectItem
	_projectNameLabel.text = selectedProjectItem.GetProjectName()
	_projectPathLabel.text = selectedProjectItem.GetProjectDir()
	_loadThumbnail()
	_loadSettings()
	_loadLastScanned()

func _loadSettings():
	_currentConfig = QubeConfig.new()
	print("=== LOAD SETTINGS ===")
	print("Default line_limit_soft: ", _currentConfig.line_limit_soft)
	# Try to load project-specific config
	var projectDir = _selectedProjectItem.GetProjectDir()
	var configPath = projectDir.path_join(".gdqube.cfg")
	print("projectDir: ", projectDir)
	print("configPath: ", configPath)
	print("File exists check: ", FileAccess.file_exists(configPath))
	if FileAccess.file_exists(configPath):
		print("Calling load_project_config with: ", projectDir)
		_currentConfig.load_project_config(projectDir)
		print("After load_project_config - line_limit_soft: ", _currentConfig.line_limit_soft)
	else:
		print("Config file does not exist, using defaults")
	_applySettingsToUI()
	print("After _applySettingsToUI - _fileLinesWarn.value: ", _fileLinesWarn.value)

func _applySettingsToUI():
	if _currentConfig == null:
		return
	# Apply threshold values
	_fileLinesWarn.value = _currentConfig.line_limit_soft
	_fileLinesCrit.value = _currentConfig.line_limit_hard
	_funcLinesWarn.value = _currentConfig.function_line_limit
	_funcLinesCrit.value = _currentConfig.function_line_critical
	_complexityWarn.value = _currentConfig.cyclomatic_warning
	_complexityCrit.value = _currentConfig.cyclomatic_critical
	_godClassWarn.value = _currentConfig.god_class_functions
	_maxParamsSpin.value = _currentConfig.max_parameters
	_maxNestingSpin.value = _currentConfig.max_nesting

	# Apply threshold enable checkboxes
	_fileLinesCheck.button_pressed = _currentConfig.check_file_length
	_funcLinesCheck.button_pressed = _currentConfig.check_function_length
	_complexityCheck.button_pressed = _currentConfig.check_cyclomatic_complexity
	_godClassCheck.button_pressed = _currentConfig.check_god_class
	_maxParamsCheck.button_pressed = _currentConfig.check_parameters
	_maxNestingCheck.button_pressed = _currentConfig.check_nesting

	# Apply code checks
	_todoCheck.button_pressed = _currentConfig.check_todo_comments
	_printCheck.button_pressed = _currentConfig.check_print_statements
	_emptyFuncCheck.button_pressed = _currentConfig.check_empty_functions
	_magicNumCheck.button_pressed = _currentConfig.check_magic_numbers
	_commentedCodeCheck.button_pressed = _currentConfig.check_commented_code
	_typeAnnotationsCheck.button_pressed = _currentConfig.check_missing_types
	_longLinesCheck.button_pressed = _currentConfig.check_long_lines
	_namingCheck.button_pressed = _currentConfig.check_naming_conventions

func _applyUIToSettings():
	if _currentConfig == null:
		return
	# Apply threshold values
	_currentConfig.line_limit_soft = int(_fileLinesWarn.value)
	_currentConfig.line_limit_hard = int(_fileLinesCrit.value)
	_currentConfig.function_line_limit = int(_funcLinesWarn.value)
	_currentConfig.function_line_critical = int(_funcLinesCrit.value)
	_currentConfig.cyclomatic_warning = int(_complexityWarn.value)
	_currentConfig.cyclomatic_critical = int(_complexityCrit.value)
	_currentConfig.god_class_functions = int(_godClassWarn.value)
	_currentConfig.max_parameters = int(_maxParamsSpin.value)
	_currentConfig.max_nesting = int(_maxNestingSpin.value)

	# Apply threshold enable checkboxes
	_currentConfig.check_file_length = _fileLinesCheck.button_pressed
	_currentConfig.check_function_length = _funcLinesCheck.button_pressed
	_currentConfig.check_cyclomatic_complexity = _complexityCheck.button_pressed
	_currentConfig.check_god_class = _godClassCheck.button_pressed
	_currentConfig.check_parameters = _maxParamsCheck.button_pressed
	_currentConfig.check_nesting = _maxNestingCheck.button_pressed

	# Apply code checks
	_currentConfig.check_todo_comments = _todoCheck.button_pressed
	_currentConfig.check_print_statements = _printCheck.button_pressed
	_currentConfig.check_empty_functions = _emptyFuncCheck.button_pressed
	_currentConfig.check_magic_numbers = _magicNumCheck.button_pressed
	_currentConfig.check_commented_code = _commentedCodeCheck.button_pressed
	_currentConfig.check_missing_types = _typeAnnotationsCheck.button_pressed
	_currentConfig.check_long_lines = _longLinesCheck.button_pressed
	_currentConfig.check_naming_conventions = _namingCheck.button_pressed

func _on_scan_button_pressed():
	# Close help panel if open
	_closeHelp()

	_scanButton.disabled = true
	_exportJSONButton.disabled = true
	_exportHTMLButton.disabled = true

	# Force all SpinBoxes to commit any pending text input
	_applySpinBoxValues()

	# Apply current UI settings to config
	_applyUIToSettings()

	# Save settings before scanning
	_saveSettings()

	# Use call_deferred to allow UI to update
	call_deferred("_runAnalysis")

func _applySpinBoxValues():
	_fileLinesWarn.apply()
	_fileLinesCrit.apply()
	_funcLinesWarn.apply()
	_funcLinesCrit.apply()
	_complexityWarn.apply()
	_complexityCrit.apply()
	_godClassWarn.apply()
	_maxParamsSpin.apply()
	_maxNestingSpin.apply()

func _runAnalysis():
	var projectDir = _selectedProjectItem.GetProjectDir()

	var analyzer = QubeAnalyzer.new()
	analyzer.config = _currentConfig

	_currentResult = analyzer.analyze_directory(projectDir)

	_allIssues = _currentResult.issues.duplicate()

	# Update and save last scanned timestamp
	_lastScannedTimestamp = Time.get_datetime_string_from_system().replace("T", " ").substr(0, 16)
	_updateLastScannedLabel()
	_saveLastScanned()

	_displayResults()

	var issueCount = _currentResult.issues.size()
	_scanButton.disabled = false
	_exportJSONButton.disabled = (issueCount == 0)
	_exportHTMLButton.disabled = (issueCount == 0)

func _displayResults():
	# Clear existing results
	for child in _resultsVBox.get_children():
		child.queue_free()

	# Get filtered issues
	var filtered = _getFilteredIssues()
	_resultsCountLabel.text = "%d issues" % filtered.size()

	if filtered.size() == 0:
		var label = Label.new()
		label.text = "No issues found matching filters." if _allIssues.size() > 0 else "No issues found. Great job!"
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_resultsVBox.add_child(label)
		return

	# Display filtered issues
	for issue in filtered:
		var item = _createIssueItem(issue)
		_resultsVBox.add_child(item)

func _getFilteredIssues() -> Array:
	var filtered: Array = []
	var severityIndex = _severityFilter.selected
	var typeIndex = _typeFilter.selected
	var fileFilterText = _fileFilter.text.to_lower()

	for issue in _allIssues:
		var severityStr = issue.get_severity_string()

		# Severity filter
		if severityIndex > 0:
			var severityMatch = false
			match severityIndex:
				1: severityMatch = (severityStr == "critical")
				2: severityMatch = (severityStr == "warning")
				3: severityMatch = (severityStr == "info")
			if not severityMatch:
				continue

		# Type filter
		if typeIndex > 0:
			var typeMatch = false
			var checkId = issue.check_id.to_lower()
			match typeIndex:
				1: typeMatch = checkId.contains("complexity") or checkId.contains("cyclomatic")
				2: typeMatch = checkId.contains("length") or checkId.contains("lines") or checkId.contains("long")
				3: typeMatch = checkId.contains("param")
				4: typeMatch = checkId.contains("nesting")
				5: typeMatch = checkId.contains("god")
			if not typeMatch:
				continue

		# File filter
		if fileFilterText != "" and not issue.file_path.to_lower().contains(fileFilterText):
			continue

		filtered.append(issue)

	return filtered

func _createIssueItem(issue) -> Control:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)

	# Severity icon - fixed width (matches header)
	var severityLabel = Label.new()
	severityLabel.text = issue.get_severity_icon()
	severityLabel.tooltip_text = issue.get_severity_string().capitalize()
	severityLabel.custom_minimum_size = Vector2(30, 0)
	hbox.add_child(severityLabel)

	# Spacer for separator alignment
	var sep1 = Control.new()
	sep1.custom_minimum_size = Vector2(8, 0)
	hbox.add_child(sep1)

	# Location (file:line) - dynamic width from header
	var locationButton = Button.new()
	var resPath = _toResPath(issue.file_path)
	locationButton.text = "%s:%d" % [resPath, issue.line]
	locationButton.flat = true
	locationButton.custom_minimum_size = Vector2(_locationColumnWidth, 0)
	locationButton.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	locationButton.clip_text = true
	locationButton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	locationButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	locationButton.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	locationButton.add_theme_color_override("font_hover_color", Color(0.6, 0.85, 1.0))
	locationButton.tooltip_text = issue.file_path
	locationButton.pressed.connect(_onLocationPressed.bind(issue))
	hbox.add_child(locationButton)

	# Spacer for separator alignment
	var sep2 = Control.new()
	sep2.custom_minimum_size = Vector2(8, 0)
	hbox.add_child(sep2)

	# Message - expandable with ellipsis
	var messageLabel = Label.new()
	messageLabel.text = issue.message
	messageLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	messageLabel.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hbox.add_child(messageLabel)

	# Spacer for separator alignment
	var sep3 = Control.new()
	sep3.custom_minimum_size = Vector2(8, 0)
	hbox.add_child(sep3)

	# Type badge - dynamic width from header
	var typeBadge = Label.new()
	typeBadge.text = issue.check_id
	typeBadge.add_theme_font_size_override("font_size", 11)
	typeBadge.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	typeBadge.custom_minimum_size = Vector2(_typeColumnWidth, 0)
	typeBadge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(typeBadge)

	# Spacer for Claude column
	var sep4 = Control.new()
	sep4.custom_minimum_size = Vector2(8, 0)
	hbox.add_child(sep4)

	# Claude/AI button - 30px to match header, 16px icon inside
	var claudeButton = TextureButton.new()
	claudeButton.texture_normal = _sparkleIcon
	claudeButton.custom_minimum_size = Vector2(30, 0)
	claudeButton.ignore_texture_size = true
	claudeButton.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	claudeButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	claudeButton.tooltip_text = "Analyze with Claude Code"
	claudeButton.pressed.connect(_onClaudeButtonPressed.bind(issue))
	hbox.add_child(claudeButton)

	return hbox

# Convert absolute path to res:// path relative to project directory
func _toResPath(absolutePath: String) -> String:
	if _selectedProjectItem == null:
		return absolutePath
	var projectDir = _selectedProjectItem.GetProjectDir()
	# Normalize slashes for comparison
	var normalizedPath = absolutePath.replace("\\", "/")
	var normalizedProject = projectDir.replace("\\", "/")
	if normalizedPath.begins_with(normalizedProject):
		var relativePath = normalizedPath.substr(normalizedProject.length())
		if relativePath.begins_with("/"):
			relativePath = relativePath.substr(1)
		return "res://" + relativePath
	return absolutePath

func _onLocationPressed(issue):
	# Copy file path to clipboard for now
	DisplayServer.clipboard_set(issue.file_path + ":" + str(issue.line))

func _onClaudeButtonPressed(issue):
	var projectDir = _selectedProjectItem.GetProjectDir()
	var resPath = _toResPath(issue.file_path)

	# Build prompt with issue context
	var prompt = "I have a code quality issue to address:\\n\\n"
	prompt += "File: %s\\n" % resPath
	prompt += "Line: %d\\n" % issue.line
	prompt += "Issue Type: %s\\n" % issue.check_id
	prompt += "Severity: %s\\n" % issue.get_severity_string()
	prompt += "Message: %s\\n\\n" % issue.message
	prompt += "Please analyze this issue and create a plan to fix it."

	# Escape single quotes for PowerShell
	var escapedPrompt = prompt.replace("'", "''")

	print("Launching Claude Code with issue context:")
	print("  File: ", resPath)
	print("  Line: ", issue.line)
	print("  Type: ", issue.check_id)
	print("  Project: ", projectDir)

	# Launch in Windows Terminal (wt) for better experience
	# Use -NoProfile to skip user profile (avoids posh-git errors etc)
	OS.create_process("wt", ["-d", projectDir, "powershell", "-NoProfile", "-NoExit", "-Command", "claude --permission-mode plan '%s'" % escapedPrompt])

func _on_filter_changed(_value = null):
	if _currentResult != null:
		_displayResults()

func _on_file_filter_changed(_text: String):
	if _currentResult != null:
		_displayResults()

func _on_export_json_pressed():
	if _currentResult == null:
		return

	var projectDir = _selectedProjectItem.GetProjectDir()
	var exportPath = projectDir + "/code_quality_report.json"

	var data = {
		"project": _selectedProjectItem.GetProjectName(),
		"path": projectDir,
		"timestamp": Time.get_datetime_string_from_system(),
		"summary": {
			"total_issues": _allIssues.size(),
			"critical": _allIssues.filter(func(i): return i.get_severity_string() == "critical").size(),
			"warning": _allIssues.filter(func(i): return i.get_severity_string() == "warning").size(),
			"info": _allIssues.filter(func(i): return i.get_severity_string() == "info").size()
		},
		"issues": []
	}

	for issue in _allIssues:
		data["issues"].append({
			"file": issue.file_path,
			"line": issue.line,
			"severity": issue.get_severity_string(),
			"type": issue.check_id,
			"message": issue.message
		})

	var file = FileAccess.open(exportPath, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		# Open the folder containing the file
		OS.shell_show_in_file_manager(exportPath)
	else:
		push_error("Could not write JSON file: " + exportPath)

func _on_export_html_pressed():
	if _currentResult == null:
		return

	var projectDir = _selectedProjectItem.GetProjectDir()
	var exportPath = projectDir + "/code_quality_report.html"

	var html = _generateHTMLReport()

	var file = FileAccess.open(exportPath, FileAccess.WRITE)
	if file:
		file.store_string(html)
		file.close()
		OS.shell_open(exportPath)
	else:
		push_error("Could not write HTML file: " + exportPath)

# Issue type display names
const ISSUE_TYPES := {
	"file-length": "File Length",
	"long-function": "Long Function",
	"long-line": "Long Line",
	"todo-comment": "TODO/FIXME",
	"print-statement": "Print Statement",
	"empty-function": "Empty Function",
	"magic-number": "Magic Number",
	"commented-code": "Commented Code",
	"missing-type-hint": "Missing Type Hint",
	"missing-return-type": "Missing Return Type",
	"too-many-params": "Too Many Params",
	"deep-nesting": "Deep Nesting",
	"high-complexity": "High Complexity",
	"god-class": "God Class",
	"naming-class": "Naming: Class",
	"naming-function": "Naming: Function",
	"naming-signal": "Naming: Signal",
	"naming-const": "Naming: Constant",
	"naming-enum": "Naming: Enum"
}

func _generateHTMLReport() -> String:
	var critical: Array = _currentResult.get_issues_by_severity(QubeIssue.Severity.CRITICAL)
	var warnings: Array = _currentResult.get_issues_by_severity(QubeIssue.Severity.WARNING)
	var info: Array = _currentResult.get_issues_by_severity(QubeIssue.Severity.INFO)

	# Collect types by severity for linked filtering
	var types_by_severity: Dictionary = {
		"all": {},
		"critical": {},
		"warning": {},
		"info": {}
	}
	for issue in _currentResult.issues:
		types_by_severity["all"][issue.check_id] = true
	for issue in critical:
		types_by_severity["critical"][issue.check_id] = true
	for issue in warnings:
		types_by_severity["warning"][issue.check_id] = true
	for issue in info:
		types_by_severity["info"][issue.check_id] = true

	# Build type name mapping for JS
	var type_names_json := "{"
	var first := true
	for check_id in types_by_severity["all"].keys():
		if not first:
			type_names_json += ","
		first = false
		var display_name: String = ISSUE_TYPES.get(check_id, check_id)
		type_names_json += "\"%s\":\"%s\"" % [check_id, display_name]
	type_names_json += "}"

	# Build severity->types mapping for JS
	var severity_types_json := "{"
	for sev in ["all", "critical", "warning", "info"]:
		if sev != "all":
			severity_types_json += ","
		var types_arr: Array = types_by_severity[sev].keys()
		types_arr.sort()
		severity_types_json += "\"%s\":%s" % [sev, JSON.stringify(types_arr)]
	severity_types_json += "}"

	var html := """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Godot Qube - Code Quality Report</title>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #1a1a2e; color: #eee; padding: 20px; line-height: 1.6; }
.container { max-width: 1200px; margin: 0 auto; }
h1 { color: #00d4ff; margin-bottom: 10px; }
h2 { color: #888; font-size: 1.2em; margin: 20px 0 10px; border-bottom: 1px solid #333; padding-bottom: 5px; }
.header { text-align: center; margin-bottom: 30px; }
.subtitle { color: #888; font-size: 0.9em; }
.filters { background: #16213e; border-radius: 8px; padding: 15px; margin-bottom: 20px; display: flex; flex-wrap: wrap; gap: 15px; align-items: center; }
.filters label { color: #aaa; font-size: 0.95em; font-weight: bold; }
.filters select, .filters input { background: #0f3460; border: 1px solid #333; color: #eee; padding: 8px 12px; border-radius: 4px; font-size: 0.9em; }
.filters input { min-width: 400px; }
.filters select:focus, .filters input:focus { outline: none; border-color: #00d4ff; }
.filter-count { color: #00d4ff; font-weight: bold; margin-left: auto; }
.summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px; margin-bottom: 30px; }
.stat-card { background: #16213e; border-radius: 8px; padding: 15px; text-align: center; }
.stat-card .value { font-size: 2em; font-weight: bold; }
.stat-card .label { color: #888; font-size: 0.85em; }
.stat-card.critical .value { color: #ff6b6b; }
.stat-card.warning .value { color: #ffd93d; }
.stat-card.info .value { color: #6bcb77; }
.issues-section { margin-bottom: 30px; }
.section-header { display: flex; align-items: center; gap: 10px; margin-bottom: 15px; }
.section-header .icon { font-size: 1.5em; }
.section-header.critical { color: #ff6b6b; }
.section-header.warning { color: #ffd93d; }
.section-header.info { color: #6bcb77; }
.section-header .count { font-size: 0.8em; color: #888; }
.issue { background: #16213e; border-radius: 6px; padding: 12px 15px; margin-bottom: 8px; display: grid; grid-template-columns: minmax(280px, 350px) 1fr auto; gap: 15px; align-items: center; }
.issue.hidden { display: none; }
.issue .location { font-family: 'Consolas', 'Monaco', monospace; font-size: 0.85em; color: #00d4ff; word-break: break-all; }
.issue .message { color: #ccc; }
.issue .check-id { font-size: 0.75em; background: #0f3460; padding: 2px 8px; border-radius: 4px; color: #888; white-space: nowrap; }
.footer { text-align: center; margin-top: 40px; padding-top: 20px; border-top: 1px solid #333; color: #666; font-size: 0.85em; }
.footer a { color: #00d4ff; text-decoration: none; }
.no-results { text-align: center; color: #666; padding: 40px; }
</style>
</head>
<body>
<div class="container">
<div class="header">
<h1>Code Quality Report</h1>
<p class="subtitle">%s</p>
</div>

<div class="summary">
<div class="stat-card"><div class="value">%d</div><div class="label">Files Analyzed</div></div>
<div class="stat-card"><div class="value">%d</div><div class="label">Lines of Code</div></div>
<div class="stat-card critical"><div class="value">%d</div><div class="label">Critical Issues</div></div>
<div class="stat-card warning"><div class="value">%d</div><div class="label">Warnings</div></div>
<div class="stat-card info"><div class="value">%d</div><div class="label">Info</div></div>
<div class="stat-card"><div class="value">%d</div><div class="label">Debt Score</div></div>
</div>

<div class="filters">
<label>Severity:</label>
<select id="severityFilter" onchange="onSeverityChange()">
<option value="all">All Severities</option>
<option value="critical">Critical</option>
<option value="warning">Warning</option>
<option value="info">Info</option>
</select>
<label>Type:</label>
<select id="typeFilter" onchange="applyFilters()">
<option value="all">All Types</option>
</select>
<label>File:</label>
<input type="text" id="fileFilter" placeholder="Filter by filename..." oninput="applyFilters()">
<span class="filter-count" id="filterCount"></span>
</div>

<div id="issuesContainer">
""" % [_selectedProjectItem.GetProjectName(), _currentResult.files_analyzed, _currentResult.total_lines, critical.size(), warnings.size(), info.size(), _currentResult.get_total_debt_score()]

	if critical.size() > 0:
		html += "<div class=\"issues-section\" data-severity=\"critical\"><div class=\"section-header critical\"><span class=\"icon\">🔴</span><h2>Critical Issues (<span class=\"count\">%d</span>)</h2></div>\n" % critical.size()
		for issue in critical:
			html += _formatHTMLIssue(issue, "critical")
		html += "</div>\n"

	if warnings.size() > 0:
		html += "<div class=\"issues-section\" data-severity=\"warning\"><div class=\"section-header warning\"><span class=\"icon\">🟡</span><h2>Warnings (<span class=\"count\">%d</span>)</h2></div>\n" % warnings.size()
		for issue in warnings:
			html += _formatHTMLIssue(issue, "warning")
		html += "</div>\n"

	if info.size() > 0:
		html += "<div class=\"issues-section\" data-severity=\"info\"><div class=\"section-header info\"><span class=\"icon\">🔵</span><h2>Info (<span class=\"count\">%d</span>)</h2></div>\n" % info.size()
		for issue in info:
			html += _formatHTMLIssue(issue, "info")
		html += "</div>\n"

	html += """</div>
<div id="noResults" class="no-results" style="display:none;">No issues match the current filters</div>

<div class="footer">
<p>Generated by <a href="https://github.com/graydwarf/godot-qube">Godot Qube</a> in %dms</p>
</div>
</div>

<script>
// Type name mapping and severity->types data for linked filtering
const TYPE_NAMES = %s;
const SEVERITY_TYPES = %s;

function populateTypeFilter(severity) {
	const typeFilter = document.getElementById('typeFilter');
	const prevValue = typeFilter.value;

	// Clear and rebuild options
	typeFilter.innerHTML = '<option value="all">All Types</option>';

	const types = SEVERITY_TYPES[severity] || [];
	types.forEach(checkId => {
		const option = document.createElement('option');
		option.value = checkId;
		option.textContent = TYPE_NAMES[checkId] || checkId;
		typeFilter.appendChild(option);
	});

	// Try to restore previous selection if it still exists
	const options = Array.from(typeFilter.options);
	const found = options.find(opt => opt.value === prevValue);
	if (found) {
		typeFilter.value = prevValue;
	} else {
		typeFilter.value = 'all';
	}
}

function onSeverityChange() {
	const severity = document.getElementById('severityFilter').value;
	populateTypeFilter(severity);
	applyFilters();
}

function applyFilters() {
	const severity = document.getElementById('severityFilter').value;
	const type = document.getElementById('typeFilter').value;
	const file = document.getElementById('fileFilter').value.toLowerCase();

	const issues = document.querySelectorAll('.issue');
	let visibleCount = 0;

	issues.forEach(issue => {
		const issueSeverity = issue.dataset.severity;
		const issueType = issue.dataset.type;
		const issueFile = issue.dataset.file.toLowerCase();

		const matchSeverity = severity === 'all' || issueSeverity === severity;
		const matchType = type === 'all' || issueType === type;
		const matchFile = file === '' || issueFile.includes(file);

		if (matchSeverity && matchType && matchFile) {
			issue.classList.remove('hidden');
			visibleCount++;
		} else {
			issue.classList.add('hidden');
		}
	});

	// Update section visibility and counts
	document.querySelectorAll('.issues-section').forEach(section => {
		const visibleInSection = section.querySelectorAll('.issue:not(.hidden)').length;
		section.querySelector('.count').textContent = visibleInSection;
		section.style.display = visibleInSection > 0 ? 'block' : 'none';
	});

	// Show/hide no results message
	document.getElementById('noResults').style.display = visibleCount === 0 ? 'block' : 'none';

	// Update filter count
	const total = issues.length;
	document.getElementById('filterCount').textContent = visibleCount === total ? '' : visibleCount + ' / ' + total + ' shown';
}

// Initialize
populateTypeFilter('all');
applyFilters();
</script>
</body>
</html>
""" % [_currentResult.analysis_time_ms, type_names_json, severity_types_json]

	return html

func _formatHTMLIssue(issue, severity: String) -> String:
	var escaped_message: String = issue.message.replace("<", "&lt;").replace(">", "&gt;")
	var full_path: String = issue.file_path.replace("\\", "/")

	# Convert full path to res:// path
	var project_dir: String = _selectedProjectItem.GetProjectDir().replace("\\", "/")
	if not project_dir.ends_with("/"):
		project_dir += "/"
	var res_path: String = full_path
	if full_path.begins_with(project_dir):
		res_path = "res://" + full_path.substr(project_dir.length())

	return "<div class=\"issue\" data-severity=\"%s\" data-type=\"%s\" data-file=\"%s\"><span class=\"location\">%s:%d</span><span class=\"message\">%s</span><span class=\"check-id\">%s</span></div>\n" % [severity, issue.check_id, res_path, res_path, issue.line, escaped_message, issue.check_id]

func _on_back_button_pressed():
	queue_free()

func _on_folder_button_pressed():
	if _selectedProjectItem != null:
		var projectDir = _selectedProjectItem.GetProjectDir()
		OS.shell_open(projectDir)

func _on_save_button_pressed():
	_saveSettings()

func _on_help_button_pressed():
	_resultsScroll.visible = false
	_helpPanel.visible = true

func _on_close_help_pressed():
	_closeHelp()

func _closeHelp():
	_helpPanel.visible = false
	_resultsScroll.visible = true

func _on_close_help_mouse_entered():
	_closeHelpButton.modulate = Color(1, 1, 1, 1)

func _on_close_help_mouse_exited():
	_closeHelpButton.modulate = Color(1, 1, 1, 0.5)

func _loadThumbnail():
	if _selectedProjectItem == null:
		return
	var thumbnailPath = _selectedProjectItem.GetThumbnailPath()
	if thumbnailPath == "":
		return

	# Check if this is a Godot resource path (res://)
	if thumbnailPath.begins_with("res://"):
		var texture = load(thumbnailPath)
		if texture:
			_thumbTextureRect.texture = texture
	else:
		# Load from filesystem
		var image = Image.new()
		var error = image.load(thumbnailPath)
		if error == OK:
			var texture = ImageTexture.create_from_image(image)
			_thumbTextureRect.texture = texture

func _loadLastScanned():
	var projectDir = _selectedProjectItem.GetProjectDir()
	var configPath = projectDir + "/.gdqube_state.json"

	if FileAccess.file_exists(configPath):
		var file = FileAccess.open(configPath, FileAccess.READ)
		if file:
			var json = JSON.new()
			var error = json.parse(file.get_as_text())
			file.close()
			if error == OK and json.data is Dictionary:
				_lastScannedTimestamp = json.data.get("last_scanned", "")

	_updateLastScannedLabel()

func _saveLastScanned():
	var projectDir = _selectedProjectItem.GetProjectDir()
	var configPath = projectDir + "/.gdqube_state.json"

	var data = {
		"last_scanned": _lastScannedTimestamp
	}

	var file = FileAccess.open(configPath, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func _updateLastScannedLabel():
	if _lastScannedTimestamp.is_empty():
		_lastScannedLabel.text = "Last Scanned: Never"
	else:
		_lastScannedLabel.text = "Last Scanned: " + _lastScannedTimestamp

func _saveSettings():
	if _selectedProjectItem == null or _currentConfig == null:
		return

	# Force all SpinBoxes to commit any pending text input
	_applySpinBoxValues()
	_applyUIToSettings()

	var projectDir = _selectedProjectItem.GetProjectDir()
	var configPath = projectDir.path_join(".gdqube.cfg")

	var file = FileAccess.open(configPath, FileAccess.WRITE)
	if file:
		# Write threshold limits
		file.store_line("[limits]")
		file.store_line("file_lines_soft = %d" % _currentConfig.line_limit_soft)
		file.store_line("file_lines_hard = %d" % _currentConfig.line_limit_hard)
		file.store_line("function_lines = %d" % _currentConfig.function_line_limit)
		file.store_line("function_lines_critical = %d" % _currentConfig.function_line_critical)
		file.store_line("max_parameters = %d" % _currentConfig.max_parameters)
		file.store_line("max_nesting = %d" % _currentConfig.max_nesting)
		file.store_line("cyclomatic_warning = %d" % _currentConfig.cyclomatic_warning)
		file.store_line("cyclomatic_critical = %d" % _currentConfig.cyclomatic_critical)
		file.store_line("god_class_functions = %d" % _currentConfig.god_class_functions)
		file.store_line("")

		# Write enabled checks
		file.store_line("[checks]")
		file.store_line("file_length = %s" % str(_currentConfig.check_file_length).to_lower())
		file.store_line("function_length = %s" % str(_currentConfig.check_function_length).to_lower())
		file.store_line("cyclomatic_complexity = %s" % str(_currentConfig.check_cyclomatic_complexity).to_lower())
		file.store_line("god_class = %s" % str(_currentConfig.check_god_class).to_lower())
		file.store_line("parameters = %s" % str(_currentConfig.check_parameters).to_lower())
		file.store_line("nesting = %s" % str(_currentConfig.check_nesting).to_lower())
		file.store_line("todo_comments = %s" % str(_currentConfig.check_todo_comments).to_lower())
		file.store_line("print_statements = %s" % str(_currentConfig.check_print_statements).to_lower())
		file.store_line("empty_functions = %s" % str(_currentConfig.check_empty_functions).to_lower())
		file.store_line("magic_numbers = %s" % str(_currentConfig.check_magic_numbers).to_lower())
		file.store_line("commented_code = %s" % str(_currentConfig.check_commented_code).to_lower())
		file.store_line("missing_types = %s" % str(_currentConfig.check_missing_types).to_lower())
		file.store_line("long_lines = %s" % str(_currentConfig.check_long_lines).to_lower())
		file.store_line("naming_conventions = %s" % str(_currentConfig.check_naming_conventions).to_lower())
		file.store_line("")

		file.close()
		print("Settings saved to: ", configPath)
	else:
		print("ERROR: Failed to open file for writing: ", configPath)

func _verifySavedFile(path: String):
	print("=== VERIFY SAVED FILE ===")
	print("Checking file exists: ", FileAccess.file_exists(path))
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		print("File contents:")
		print(file.get_as_text())
		file.close()
	else:
		print("ERROR: Could not open saved file for verification")

func _on_reset_all_pressed():
	# Reset all settings to defaults
	_fileLinesWarn.value = 200
	_fileLinesCrit.value = 300
	_funcLinesWarn.value = 30
	_funcLinesCrit.value = 60
	_complexityWarn.value = 10
	_complexityCrit.value = 15
	_godClassWarn.value = 20
	_maxParamsSpin.value = 4
	_maxNestingSpin.value = 3

	# Enable all checks
	_fileLinesCheck.button_pressed = true
	_funcLinesCheck.button_pressed = true
	_complexityCheck.button_pressed = true
	_godClassCheck.button_pressed = true
	_maxParamsCheck.button_pressed = true
	_maxNestingCheck.button_pressed = true
	_todoCheck.button_pressed = true
	_printCheck.button_pressed = true
	_emptyFuncCheck.button_pressed = true
	_magicNumCheck.button_pressed = true
	_commentedCodeCheck.button_pressed = true
	_typeAnnotationsCheck.button_pressed = true
	_longLinesCheck.button_pressed = true
	_namingCheck.button_pressed = true

# Individual reset handlers
func _on_file_lines_reset():
	_fileLinesWarn.value = 200
	_fileLinesCrit.value = 300
	_fileLinesCheck.button_pressed = true

func _on_func_lines_reset():
	_funcLinesWarn.value = 30
	_funcLinesCrit.value = 60
	_funcLinesCheck.button_pressed = true

func _on_complexity_reset():
	_complexityWarn.value = 10
	_complexityCrit.value = 15
	_complexityCheck.button_pressed = true

func _on_max_params_reset():
	_maxParamsSpin.value = 4
	_maxParamsCheck.button_pressed = true

func _on_max_nesting_reset():
	_maxNestingSpin.value = 3
	_maxNestingCheck.button_pressed = true

func _on_god_class_reset():
	_godClassWarn.value = 20
	_godClassCheck.button_pressed = true
