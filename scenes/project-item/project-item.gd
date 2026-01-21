extends Panel
@onready var _projectHeader: ProjectHeader = %ProjectHeader

var _selected := false
var _windowsChecked := false
var _linuxChecked := false
var _webChecked := false
var _macOsChecked := false
var _sourceChecked := false
var _obfuscateFunctionsChecked := false
var _obfuscateVariablesChecked := false
var _obfuscateCommentsChecked := false
var _functionExcludeList : String = ""
var _variableExcludeList : String = ""
var _isHidden := false
var _showTipsForErrors := false

var _godotVersionId := ""
var _projectId := ""
var _exportPath := ""
var _exportType := ""
var _exportFileName := ""
var _packageType := ""
var _itchProjectName := ""
var _itchProfileName := ""
var _itchEnabled := false
var _githubEnabled := false
var _installerConfigurationFileName := ""
var _projectName = ""
var _godotVersion = ""
var _projectPath = ""
var _projectVersion = ""
var _thumbnailPath := ""
var _publishedDate : Dictionary = {}
var _createdDate : Dictionary = {}
var _editedDate : Dictionary = {}
var _sourceFilters := []
var _customOrder := 999999  # Default high value for unordered items
var _platformExportSettings := {}  # Per-platform export settings: {platform_name: {exportPath, exportFilename, obfuscation}}
var _publishPlatformSelections := {}  # Per-platform publish checkbox state: {platform_name: bool}
var _pathTemplateMigrationStatus := ""  # "", "upgraded", "skipped" - tracks path template migration

func _ready():
	InitSignals()
	RefreshBackground()
	UpdateProjectItemUi()

func InitSignals():
	Signals.connect("BackgroundColorChanged", BackgroundColorChanged)

func UpdateProjectItemUi():
	# Update ProjectHeader (handles name, version, path, thumbnail, and all metadata)
	_projectHeader.set_project_name(_projectName)
	_projectHeader.set_godot_version(_godotVersion)
	_projectHeader.set_path(_projectPath)
	_projectHeader.set_current_version(_projectVersion if !_projectVersion.is_empty() else "--")
	var linter_scan = GetLastLinterScanDate()
	_projectHeader.set_last_linter_scan(linter_scan if !linter_scan.is_empty() else "Never")
	_projectHeader.set_last_published(Date.GetCurrentDateAsString(_publishedDate) if !_publishedDate.is_empty() else "--")
	_projectHeader.set_created_date(Date.GetCurrentDateAsString(_createdDate))
	_projectHeader.set_edited_date(Date.GetCurrentDateAsString(_editedDate))
	if _thumbnailPath != "":
		_projectHeader.set_icon_from_path(_thumbnailPath)

func BackgroundColorChanged(_color = null):
	RefreshBackground()

func RefreshBackground():
	theme = GetDefaultTheme()	

func SetGodotVersionId(value):
	_godotVersionId = value
	
func SetProjectVersion(value):
	_projectVersion = value

func SetThumbnailPath(value):
	_thumbnailPath = value
	
func SetProjectPath(value):
	_projectPath = value

func SetExportFileName(value):
	_exportFileName = value
	
func SetProjectName(value):
	_projectName = value
	
func SetGodotVersion(value):
	_godotVersion = value

func SetItchProjectName(value):
	_itchProjectName = value

func SetWindowsChecked(value):
	_windowsChecked = value

func SetLinuxChecked(value):
	_linuxChecked = value
	
func SetWebChecked(value):
	_webChecked = value

func SetMacOsChecked(value):
	_macOsChecked = value

func SetSourceChecked(value):
	_sourceChecked = value
		
func SetExportPath(value):
	_exportPath = value
	
func SetExportType(value):
	_exportType = value
	
func SetPackageType(value):
	_packageType = value

func SetItchProfileName(value):
	_itchProfileName = value

func SetItchEnabled(value):
	_itchEnabled = value

func SetGithubEnabled(value):
	_githubEnabled = value

func SetShowTipsForErrors(value):
	_showTipsForErrors = value
	
func SetPublishedDate(value):
	_publishedDate = value

func SetSourceFilters(value):
	_sourceFilters = value

func SetObfuscateFunctionsChecked(value : bool):
	_obfuscateFunctionsChecked = value

func SetObfuscateVariablesChecked(value : bool):
	_obfuscateVariablesChecked = value	

func SetObfuscateCommentsChecked(value : bool):
	_obfuscateCommentsChecked = value

func SetFunctionExcludeList(value : String):
	_functionExcludeList = value

func SetVariableExcludeList(value : String):
	_variableExcludeList = value

func SetCreatedDate(value):
	_createdDate = value
	
func SetEditedDate(value):
	_editedDate = value
	
func SetProjectId(value):
	_projectId = value

func SetInstallerConfigurationFileName(value):
	_installerConfigurationFileName = value

func SetIsHidden(value):
	_isHidden = value

func SetCustomOrder(value: int):
	_customOrder = value

func GetCustomOrder() -> int:
	return _customOrder

func SetPlatformExportSettings(platform: String, settings: Dictionary):
	_platformExportSettings[platform] = settings

func GetPlatformExportSettings(platform: String) -> Dictionary:
	if platform in _platformExportSettings:
		return _platformExportSettings[platform]
	return {}  # Return empty dict if platform not configured

func GetAllPlatformExportSettings() -> Dictionary:
	return _platformExportSettings

func SetAllPlatformExportSettings(settings: Dictionary):
	_platformExportSettings = settings

func GetPathTemplateMigrationStatus() -> String:
	return _pathTemplateMigrationStatus

func SetPathTemplateMigrationStatus(status: String):
	_pathTemplateMigrationStatus = status

func GetProjectVersion():
	return _projectVersion
	
func GetItchProjectName():
	return _itchProjectName

func GetWindowsChecked():
	return _windowsChecked

func GetLinuxChecked():
	return _linuxChecked	

func GetWebChecked():
	return _webChecked	

func GetMacOsChecked():
	return _macOsChecked

func GetSourceChecked():
	return _sourceChecked

func GetObfuscateFunctionsChecked():
	return _obfuscateFunctionsChecked

func GetObfuscateVariablesChecked():
	return _obfuscateVariablesChecked

func GetObfuscateCommentsChecked():
	return _obfuscateCommentsChecked

func GetFunctionExcludeList() -> String:
	return _functionExcludeList

func GetVariableExcludeList() -> String:
	return _variableExcludeList


func GetExportType():
	return _exportType

func GetExportFileName():
	return _exportFileName
	
func GetPackageType():
	return _packageType

func GetItchProfileName():
	return _itchProfileName

func GetItchEnabled():
	return _itchEnabled

func GetGithubEnabled():
	return _githubEnabled

func GetPublishPlatformSelections() -> Dictionary:
	return _publishPlatformSelections

func SetPublishPlatformSelections(selections: Dictionary):
	_publishPlatformSelections = selections

func GetShowTipsForErrors():
	return _showTipsForErrors
	
func GetPublishedDate():
	return _publishedDate

func GetCreatedDate():
	return _createdDate
	
func GetEditedDate():
	return _editedDate

# Returns the last linter scan date from .gdlint_state.json
func GetLastLinterScanDate() -> String:
	var projectDir = GetProjectDir()
	var configPath = projectDir + "/.gdlint_state.json"

	if FileAccess.file_exists(configPath):
		var file = FileAccess.open(configPath, FileAccess.READ)
		if file:
			var json = JSON.new()
			var error = json.parse(file.get_as_text())
			file.close()
			if error == OK and json.data is Dictionary:
				return json.data.get("last_scanned", "")
	return ""

# Strip off the file name
# /project.godot
func GetProjectPathBaseDir():
	return _projectPath.get_base_dir()

# Returns the project directory (folder containing project.godot)
# Handles both formats: with or without project.godot at the end
func GetProjectDir() -> String:
	if _projectPath.ends_with("project.godot"):
		return _projectPath.get_base_dir()
	else:
		# Path is already the directory
		return _projectPath

func GetThumbnailPath():
	return _thumbnailPath
	
func GetProjectPath():
	return _projectPath

# Returns list of configured export preset names from export_presets.cfg
func GetAvailableExportPresets() -> Array[String]:
	var presets: Array[String] = []
	# Get directory containing project.godot, then append export_presets.cfg
	var projectDir = _projectPath.get_base_dir()
	var presetsPath = projectDir.path_join("export_presets.cfg")

	if not FileAccess.file_exists(presetsPath):
		return presets

	var config = ConfigFile.new()
	var err = config.load(presetsPath)
	if err != OK:
		print("Error loading export_presets.cfg: ", err)
		return presets

	# Parse all [preset.X] sections
	var sections = config.get_sections()
	for section in sections:
		if section.begins_with("preset."):
			var presetName = config.get_value(section, "name", "")
			if presetName != "":
				presets.append(presetName)

	return presets

# Returns include_filter and exclude_filter for a specific export preset
func GetExportPresetFilters(presetName: String) -> Dictionary:
	var result = {"include_filter": "", "exclude_filter": ""}
	var projectDir = _projectPath.get_base_dir()
	var presetsPath = projectDir.path_join("export_presets.cfg")

	if not FileAccess.file_exists(presetsPath):
		return result

	var config = ConfigFile.new()
	var err = config.load(presetsPath)
	if err != OK:
		print("Error loading export_presets.cfg: ", err)
		return result

	# Find the preset section matching the name
	var sections = config.get_sections()
	for section in sections:
		if section.begins_with("preset.") and not section.contains(".options"):
			var sectionName = config.get_value(section, "name", "")
			if sectionName == presetName:
				result["include_filter"] = config.get_value(section, "include_filter", "")
				result["exclude_filter"] = config.get_value(section, "exclude_filter", "")
				break

	return result

# Sets include_filter and exclude_filter for a specific export preset
func SetExportPresetFilters(presetName: String, includeFilter: String, excludeFilter: String) -> bool:
	var projectDir = _projectPath.get_base_dir()
	var presetsPath = projectDir.path_join("export_presets.cfg")

	if not FileAccess.file_exists(presetsPath):
		print("export_presets.cfg not found")
		return false

	var config = ConfigFile.new()
	var err = config.load(presetsPath)
	if err != OK:
		print("Error loading export_presets.cfg: ", err)
		return false

	# Find the preset section matching the name
	var sections = config.get_sections()
	for section in sections:
		if section.begins_with("preset.") and not section.contains(".options"):
			var sectionName = config.get_value(section, "name", "")
			if sectionName == presetName:
				config.set_value(section, "include_filter", includeFilter)
				config.set_value(section, "exclude_filter", excludeFilter)
				err = config.save(presetsPath)
				if err != OK:
					print("Error saving export_presets.cfg: ", err)
					return false
				return true

	print("Preset not found: ", presetName)
	return false

func GetProjectPathWithProjectFile():
	return _projectPath

func GetGodotVersion():
	return _godotVersion

func GetGodotVersionId():
	return _godotVersionId

func GetProjectName():
	return _projectName

func GetExportPath():
	return _exportPath
	
func GetProjectId():
	return _projectId

func GetSourceFilters():
	return _sourceFilters
	
func GetDefaultTheme():
	var customTheme = Theme.new()
	var styleBox = GetDefaultStyleBoxSettings()
	customTheme.set_stylebox("panel", "Panel", styleBox)
	return customTheme

func GetHoverTheme():
	var customTheme = Theme.new()
	var styleBox = GetDefaultStyleBoxSettings()
	styleBox.bg_color = AdjustBackgroundColor(0.001)
	customTheme.set_stylebox("panel", "Panel", styleBox)
	return customTheme

func GetSelectedTheme():
	var customTheme = Theme.new()
	var styleBox = GetDefaultStyleBoxSettings()
	styleBox.bg_color = AdjustBackgroundColor(0.32)
	customTheme.set_stylebox("panel", "Panel", styleBox)
	return customTheme

func GetIsHidden():
	return _isHidden
	
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
	
func GetGodotPath(godotVersionId):
	var files = FileHelper.GetFilesFromPath("user://godot-version-items")
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
	return GetProjectPathBaseDir().to_lower()

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

func GetProjectSelected():
	return _selected
	
func SaveProjectItem():
	var config = ConfigFile.new()
	config.set_value("ProjectSettings", "project_name", _projectName)
	config.set_value("ProjectSettings", "export_path", _exportPath)
	config.set_value("ProjectSettings", "godot_version_id", _godotVersionId)
	config.set_value("ProjectSettings", "project_path", _projectPath)
	config.set_value("ProjectSettings", "export_file_name", _exportFileName)
	config.set_value("ProjectSettings", "project_version", _projectVersion)
	config.set_value("ProjectSettings", "windows_preset_checked", _windowsChecked)
	config.set_value("ProjectSettings", "linux_preset_checked", _linuxChecked)
	config.set_value("ProjectSettings", "web_preset_checked", _webChecked)
	config.set_value("ProjectSettings", "macos_preset_checked", _macOsChecked)
	config.set_value("ProjectSettings", "source_checked", _sourceChecked)
	config.set_value("ProjectSettings", "obfuscate_functions_checked", _obfuscateFunctionsChecked)
	config.set_value("ProjectSettings", "obfuscate_variables_checked", _obfuscateVariablesChecked)
	config.set_value("ProjectSettings", "obfuscate_comments_checked", _obfuscateCommentsChecked)
	config.set_value("ProjectSettings", "function_exclude_list", _functionExcludeList)
	config.set_value("ProjectSettings", "variable_exclude_list", _variableExcludeList)
	config.set_value("ProjectSettings", "export_type", _exportType)
	config.set_value("ProjectSettings", "package_type", _packageType)
	config.set_value("ProjectSettings", "itch_profile_name", _itchProfileName)
	config.set_value("ProjectSettings", "itch_project_name", _itchProjectName)
	config.set_value("ProjectSettings", "itch_enabled", _itchEnabled)
	config.set_value("ProjectSettings", "github_enabled", _githubEnabled)
	config.set_value("ProjectSettings", "show_tips_for_errors", _showTipsForErrors)
	config.set_value("ProjectSettings", "is_hidden", _isHidden)
	config.set_value("ProjectSettings", "published_date", _publishedDate)
	config.set_value("ProjectSettings", "created_date", _createdDate)
	config.set_value("ProjectSettings", "edited_date", _editedDate)
	config.set_value("ProjectSettings", "source_filters", _sourceFilters)
	config.set_value("ProjectSettings", "thumbnail_path", _thumbnailPath)
	config.set_value("ProjectSettings", "custom_order", _customOrder)
	config.set_value("ProjectSettings", "platform_export_settings", _platformExportSettings)
	config.set_value("ProjectSettings", "publish_platform_selections", _publishPlatformSelections)
	config.set_value("ProjectSettings", "path_template_migration_status", _pathTemplateMigrationStatus)

	# Save the config file.
	var err = config.save("user://" + App.GetProjectItemFolder() + "/" + _projectId + ".cfg")

	if err != OK:
		OS.alert("An error occurred while saving the config file.")

	Signals.emit_signal("ProjectSaved", _projectId)

func HideProjectItem():
	visible = false
	
func ShowProjectItem():
	visible = true

func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("[ProjectItem] gui_input received: pos=%s, global=%s, project=%s" % [event.position, event.global_position, _projectName])
		Signals.emit_signal("ToggleProjectItemSelection", self, !_selected)

func _on_mouse_entered():
	if _selected:
		return
	
	ShowHoverColor()

func _on_mouse_exited():
	if _selected:
		return

	RestoreDefaultColor()

# Drag and drop functionality for custom ordering
func _get_drag_data(_at_position):
	if not _is_custom_sort_enabled():
		return null

	var preview = Panel.new()
	var label = Label.new()
	label.text = _projectName
	label.add_theme_color_override("font_color", Color.WHITE)
	preview.add_child(label)
	preview.custom_minimum_size = Vector2(200, 50)
	set_drag_preview(preview)

	return self

# Only allow dropping project items when Custom sort is enabled
func _can_drop_data(_at_position, data) -> bool:
	return _is_custom_sort_enabled() and data is Panel and data.has_method("GetProjectId") and data != self

func _drop_data(_at_position, data) -> void:
	if data is Panel and data.has_method("GetProjectId"):
		Signals.emit_signal("ReorderProjectItems", data, self)

# Check if the current sort mode is Custom
func _is_custom_sort_enabled() -> bool:
	return App.GetSortType() == Enums.SortByType.Custom
