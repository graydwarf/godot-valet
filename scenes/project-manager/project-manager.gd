extends Panel

@onready var _runProjectButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/RunProjectButton
@onready var _editProjectButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/EditProjectButton
@onready var _runProjectConsoleButton = %RunProjectConsoleButton
@onready var _editProjectConsoleButton = %EditProjectConsoleButton
@onready var _releaseProjectButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/ReleaseProjectButton
@onready var _changeProjectButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/ChangeProjectButton
@onready var _projectItemContainer = $VBoxContainer/HBoxContainer/MarginContainer/ScrollContainer/MarginContainer/ProjectItemContainer
@onready var _customButtonContainer = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/CustomButtonVBoxContainer
@onready var _scrollContainer = $VBoxContainer/HBoxContainer/MarginContainer/ScrollContainer
@onready var _showHiddenCheckBox = %ShowHiddenCheckBox
@onready var _hiddenProjectItemCountLabel = %HiddenProjectItemCountLabel

var _selectedProjectItem = null
var _runProjectThread
var _editProjectThread
var _openGodotProjectManagerThread
var _assetFinder : AssetFinder
var _current_drop_target = null
var _last_insert_above := true
var _drop_indicator: ColorRect = null
var _drag_scrolling := false
var _drag_scroll_speed := 0.0
const DRAG_SCROLL_ZONE := 60.0
const DRAG_SCROLL_MAX_SPEED := 600.0

func _ready():
	InitSignals()
	InitProjectSettings()
	LoadTheme()
	LoadBackgroundColor()
	LoadCustomScrollContainerTheme()
	UpdateClaudeButtonVisibility()
	UpdateClaudeApiChatButtonVisibility()
	UpdateClaudeMonitorButtonVisibility()
	UpdateRunConsoleButtonVisibility()
	UpdateEditConsoleButtonVisibility()
	# Allow drag-drop events in gaps to fall through to project-manager
	_scrollContainer.mouse_filter = Control.MOUSE_FILTER_PASS
	_scrollContainer.get_node("MarginContainer").mouse_filter = Control.MOUSE_FILTER_PASS
	_projectItemContainer.mouse_filter = Control.MOUSE_FILTER_PASS
	
func LoadCustomScrollContainerTheme():
	var customWidth = 20
	var v_scrollbar : VScrollBar= _scrollContainer.get_v_scroll_bar()
	v_scrollbar.set_custom_minimum_size(Vector2(customWidth, 0))
	
func LoadBackgroundColor(color = null):
	if color == null:
		color = App.GetBackgroundColor()
		
	var style_box = theme.get_stylebox("panel", "Panel") as StyleBoxFlat

	if style_box:
		style_box.bg_color = App.GetBackgroundColor()
	else:
		print("LoadCustomScrollContainerTheme() - StyleBoxFlat not found!")

func LoadTheme():
	theme = load(App.GetThemePath())
	
func InitProjectSettings():
	LoadShowHiddenCheckbox()
	LoadSortType()
	LoadProjectsIntoProjectContainer()
	ToggleHiddenProjectVisibility()
	LoadOpenGodotButtons()

func LoadShowHiddenCheckbox():
	_showHiddenCheckBox.button_pressed = App.GetShowHidden()

func LoadSortType():
	%SortByOptionButton.select(App.GetSortType())
	
func ShowHiddenProjectCount(value):
	_hiddenProjectItemCountLabel.text = "(" + str(value) + ")"

func ClearCustomButtonContainer():
	for button in _customButtonContainer.get_children():
		button.queue_free()

# Creates buttons dynamically based on the godot versions we have configured
func LoadOpenGodotButtons():
	ClearCustomButtonContainer()
	var files = FileHelper.GetFilesFromPath("user://" + App.GetGodotVersionItemFolder())
	var listOfButtons = []
	for file in files:
		if !file.ends_with(".cfg"):
			continue

		var fileName = file.trim_suffix(".cfg")
		
		var config = ConfigFile.new()
		var err = config.load("user://" + App.GetGodotVersionItemFolder() + "/" + fileName + ".cfg")
		if err == OK:
			var godotVersion = config.get_value("GodotVersionSettings", "godot_version", "")
			var sortOrder = config.get_value("GodotVersionSettings", "sort_order", "")
			var button : Button = load("res://scenes/nav-button/nav-button.tscn").instantiate()
			button.text = "Open " + godotVersion
			button.size.x = 140
			button.SetCustomVar1(fileName)
			button.pressed.connect(_on_button_pressed.bind(button))
			button.tooltip_text = "Launches into the Godot Project Manager for the given version."
			listOfButtons.append([sortOrder, button])
	
	listOfButtons.sort()
	
	for button in listOfButtons:
		_customButtonContainer.add_child(button[1])

# Handles events for our dynamic godot version buttons
func _on_button_pressed(button):
	var godotVersionId = button.GetCustomVar1()
	OpenGodotProjectManager(godotVersionId)
	
func LoadProjectsIntoProjectContainer():
	var allResourceFiles = FileHelper.GetFilesFromPath("user://" + App.GetProjectItemFolder())
	var hiddenProjectCount = 0
	var listOfProjectItems = []
	for resourceFile in allResourceFiles:
		if !resourceFile.ends_with(".cfg"):
			continue

		var projectId = resourceFile.trim_suffix(".cfg")
		
		var projectItem = load("res://scenes/project-item/project-item.tscn").instantiate()
		listOfProjectItems.append(projectItem)
		
		if _selectedProjectItem != null:
			var isSelected = true
			ToggleProjectItemSelection(_selectedProjectItem, isSelected)
			
		var config = ConfigFile.new()
		var err = config.load("user://" + App.GetProjectItemFolder() + "/" + projectId + ".cfg")
		if err == OK:
			projectItem.SetProjectId(projectId)
			projectItem.SetProjectName(config.get_value("ProjectSettings", "project_name", "New Project"))
			var godotVersionId = config.get_value("ProjectSettings", "godot_version_id", "")
			var godotVersion = GetGodotVersionFromId(godotVersionId)
			if godotVersion != null:
				projectItem.SetGodotVersionId(godotVersionId)
				projectItem.SetGodotVersion(godotVersion)
	
			projectItem.SetProjectPath(config.get_value("ProjectSettings", "project_path", ""))
			projectItem.SetExportPath(config.get_value("ProjectSettings", "export_path", ""))
			projectItem.SetProjectVersion(config.get_value("ProjectSettings", "project_version", "v0.0.1"))
			projectItem.SetWindowsChecked(config.get_value("ProjectSettings", "windows_preset_checked", false))
			projectItem.SetLinuxChecked(config.get_value("ProjectSettings", "linux_preset_checked", false))
			projectItem.SetWebChecked(config.get_value("ProjectSettings", "web_preset_checked", false))
			projectItem.SetMacOsChecked(config.get_value("ProjectSettings", "macos_preset_checked", false))
			projectItem.SetSourceChecked(config.get_value("ProjectSettings", "source_checked", false))
			projectItem.SetObfuscateFunctionsChecked(config.get_value("ProjectSettings", "obfuscate_functions_checked", false))
			projectItem.SetObfuscateVariablesChecked(config.get_value("ProjectSettings", "obfuscate_variables_checked", false))
			projectItem.SetObfuscateCommentsChecked(config.get_value("ProjectSettings", "obfuscate_comments_checked", false))
			projectItem.SetFunctionExcludeList(config.get_value("ProjectSettings", "function_exclude_list", ""))
			projectItem.SetVariableExcludeList(config.get_value("ProjectSettings", "variable_exclude_list", ""))
			projectItem.SetExportType(config.get_value("ProjectSettings", "export_type", "Release"))
			projectItem.SetExportFileName(config.get_value("ProjectSettings", "export_file_name", ""))
			projectItem.SetPackageType(config.get_value("ProjectSettings", "package_type", "Zip"))
			projectItem.SetItchProfileName(config.get_value("ProjectSettings", "itch_profile_name", ""))
			projectItem.SetItchProjectName(config.get_value("ProjectSettings", "itch_project_name", ""))
			projectItem.SetItchEnabled(config.get_value("ProjectSettings", "itch_enabled", false))
			projectItem.SetGithubEnabled(config.get_value("ProjectSettings", "github_enabled", false))
			projectItem.SetShowTipsForErrors(config.get_value("ProjectSettings", "show_tips_for_errors", true))
			var isHidden = config.get_value("ProjectSettings", "is_hidden", false)
			projectItem.SetIsHidden(isHidden)
			projectItem.SetPublishedDate(config.get_value("ProjectSettings", "published_date", {}))
			projectItem.SetCreatedDate(config.get_value("ProjectSettings", "created_date", {}))
			projectItem.SetEditedDate(config.get_value("ProjectSettings", "edited_date", {}))
			projectItem.SetSourceFilters(config.get_value("ProjectSettings", "source_filters", []))
			projectItem.SetThumbnailPath(config.get_value("ProjectSettings", "thumbnail_path", "res://icon.svg"))
			projectItem.SetCustomOrder(config.get_value("ProjectSettings", "custom_order", 999999))
			projectItem.SetAllPlatformExportSettings(config.get_value("ProjectSettings", "platform_export_settings", {}))
			projectItem.SetPublishPlatformSelections(config.get_value("ProjectSettings", "publish_platform_selections", {}))
			projectItem.SetPathTemplateMigrationStatus(config.get_value("ProjectSettings", "path_template_migration_status", ""))

			if isHidden:
				hiddenProjectCount += 1
				projectItem.HideProjectItem()
			else:
				projectItem.ShowProjectItem()
	
	listOfProjectItems = HandleCustomSorts(listOfProjectItems)

	for sortedProjectItem in listOfProjectItems:
		_projectItemContainer.add_child(sortedProjectItem)
		
	if hiddenProjectCount > 0:
		_hiddenProjectItemCountLabel.visible = true
		ShowHiddenProjectCount(hiddenProjectCount)
	else:
		_hiddenProjectItemCountLabel.visible = false

func HandleCustomSorts(listOfProjectItems):
	var sortType = %SortByOptionButton.get_selected_id()
	match sortType:
		Enums.SortByType.None:
			pass
		Enums.SortByType.PublishedDate:
			listOfProjectItems.sort_custom(Callable(CustomSorter, "sort_by_published_date"))
			listOfProjectItems.reverse()
		Enums.SortByType.CreatedDate:
			listOfProjectItems.sort_custom(Callable(CustomSorter, "sort_by_created_date"))
			listOfProjectItems.reverse()
		Enums.SortByType.EditedDate:
			listOfProjectItems.sort_custom(Callable(CustomSorter, "sort_by_edited_date"))
			listOfProjectItems.reverse()
		Enums.SortByType.Alphabetical:
			listOfProjectItems.sort_custom(Callable(CustomSorter, "sort_by_name"))
		Enums.SortByType.Custom:
			listOfProjectItems.sort_custom(Callable(CustomSorter, "sort_by_custom_order"))

	return listOfProjectItems
	
func GetGodotVersionFromId(godotVersionId):
	var files = FileHelper.GetFilesFromPath("user://" + App.GetGodotVersionItemFolder())
	for file in files:
		if !file.ends_with(".cfg"):
			continue

		var fileName = file.trim_suffix(".cfg")
		if fileName != godotVersionId:
			continue
		
		var config = ConfigFile.new()
		var err = config.load("user://" + App.GetGodotVersionItemFolder() + "/" + fileName + ".cfg")
		if err == OK:
			return config.get_value("GodotVersionSettings", "godot_version", "")

func GetGodotPathFromVersionId(godotVersionId):
	var files = FileHelper.GetFilesFromPath("user://" + App.GetGodotVersionItemFolder())
	for file in files:
		if !file.ends_with(".cfg"):
			continue

		var fileName = file.trim_suffix(".cfg")
		if fileName != godotVersionId:
			continue

		var config = ConfigFile.new()
		var err = config.load("user://" + App.GetGodotVersionItemFolder() + "/" + fileName + ".cfg")
		if err == OK:
			return config.get_value("GodotVersionSettings", "godot_path", "")
	return null

func GetConsolePathFromVersionId(godotVersionId):
	var files = FileHelper.GetFilesFromPath("user://" + App.GetGodotVersionItemFolder())
	for file in files:
		if !file.ends_with(".cfg"):
			continue

		var fileName = file.trim_suffix(".cfg")
		if fileName != godotVersionId:
			continue

		var config = ConfigFile.new()
		var err = config.load("user://" + App.GetGodotVersionItemFolder() + "/" + fileName + ".cfg")
		if err == OK:
			var consolePath = config.get_value("GodotVersionSettings", "console_path", "")
			# Fall back to auto-generated path if console path not set
			if consolePath.is_empty():
				var godotPath = config.get_value("GodotVersionSettings", "godot_path", "")
				if not godotPath.is_empty():
					consolePath = godotPath.replace(".exe", "_console.exe")
			return consolePath
	return null
			
func InitSignals():
	Signals.connect("ToggleProjectItemSelection", ToggleProjectItemSelection)
	Signals.connect("ProjectSaved", ProjectSaved)
	Signals.connect("GodotVersionManagerClosing", GodotVersionManagerClosing)
	Signals.connect("BackgroundColorChanged", BackgroundColorChanged)
	Signals.connect("HidingProjectItem", HidingProjectItem)
	Signals.connect("ReorderProjectItems", ReorderProjectItems)
	Signals.connect("ClaudeCodeButtonEnabledChanged", ClaudeCodeButtonEnabledChanged)
	Signals.connect("ClaudeApiChatButtonEnabledChanged", ClaudeApiChatButtonEnabledChanged)
	Signals.connect("ClaudeMonitorButtonEnabledChanged", ClaudeMonitorButtonEnabledChanged)
	Signals.connect("ShowRunConsoleButtonChanged", _on_show_run_console_button_changed)
	Signals.connect("ShowEditConsoleButtonChanged", _on_show_edit_console_button_changed)
	Signals.connect("RemoveProject", RemoveProjectById)
	Signals.connect("DragStarted", _on_drag_started)
	Signals.connect("DragHoverUpdate", _on_drag_hover_update)

func HidingProjectItem():
	ToggleHiddenProjectVisibility()

func _process(delta):
	if not _drag_scrolling:
		return

	var mouse_pos = get_global_mouse_position()
	var scroll_rect = _scrollContainer.get_global_rect()

	# Distance into the top/bottom scroll zone (0 = edge of zone, 1 = edge of container)
	var top_dist = mouse_pos.y - scroll_rect.position.y
	var bottom_dist = scroll_rect.end.y - mouse_pos.y

	var scrolled = false
	if top_dist < DRAG_SCROLL_ZONE and top_dist >= 0:
		var factor = 1.0 - (top_dist / DRAG_SCROLL_ZONE)
		_scrollContainer.scroll_vertical -= int(DRAG_SCROLL_MAX_SPEED * factor * delta)
		scrolled = true
	elif bottom_dist < DRAG_SCROLL_ZONE and bottom_dist >= 0:
		var factor = 1.0 - (bottom_dist / DRAG_SCROLL_ZONE)
		_scrollContainer.scroll_vertical += int(DRAG_SCROLL_MAX_SPEED * factor * delta)
		scrolled = true

	# Reposition the drop indicator after scroll so it tracks the target card
	if scrolled:
		_update_drop_indicator_position()

func _on_drag_started():
	_drag_scrolling = true
	if _drop_indicator == null:
		_drop_indicator = ColorRect.new()
		_drop_indicator.color = Color(0.0, 0.6, 1.0, 0.9)
		_drop_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_drop_indicator.visible = false
		_drop_indicator.z_index = 100
		add_child(_drop_indicator)

# Positions the single overlay drop indicator at the gap midpoint
func _on_drag_hover_update(target_item, insert_above: bool):
	_current_drop_target = target_item
	_last_insert_above = insert_above
	_update_drop_indicator_position()

# Calculates the drop indicator position at the midpoint of the gap between cards
func _update_drop_indicator_position():
	if _drop_indicator == null or _current_drop_target == null or not is_instance_valid(_current_drop_target):
		return

	var target_rect = _current_drop_target.get_global_rect()
	var bar_height = 4.0
	var y_global: float
	var target_index = _current_drop_target.get_index()

	if _last_insert_above:
		if target_index > 0:
			var prev_item = _projectItemContainer.get_child(target_index - 1)
			var prev_rect = prev_item.get_global_rect()
			y_global = (prev_rect.end.y + target_rect.position.y) / 2.0 - bar_height / 2.0
		else:
			y_global = target_rect.position.y - bar_height / 2.0
	else:
		var child_count = _projectItemContainer.get_child_count()
		if target_index < child_count - 1:
			var next_item = _projectItemContainer.get_child(target_index + 1)
			var next_rect = next_item.get_global_rect()
			y_global = (target_rect.end.y + next_rect.position.y) / 2.0 - bar_height / 2.0
		else:
			y_global = target_rect.end.y - bar_height / 2.0

	_drop_indicator.global_position = Vector2(target_rect.position.x, y_global)
	_drop_indicator.size = Vector2(target_rect.size.x, bar_height)
	_drop_indicator.visible = true

func _hide_drop_indicator():
	if _drop_indicator != null:
		_drop_indicator.visible = false

# Handle drag end notification to clean up
func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		_drag_scrolling = false
		_hide_drop_indicator()
		_current_drop_target = null
		Signals.emit_signal("DragEnded")

# Fallback drop handler for gaps between cards, above first card, below last card
func _can_drop_data(_at_position, data) -> bool:
	return _current_drop_target != null and data is Panel and data.has_method("GetProjectId") and data != _current_drop_target

func _drop_data(_at_position, data) -> void:
	if _current_drop_target != null and data is Panel and data.has_method("GetProjectId"):
		ReorderProjectItems(data, _current_drop_target, _last_insert_above)

func ReorderProjectItems(dragged_item, target_item, insert_above: bool = true):
	_hide_drop_indicator()

	var all_items = _projectItemContainer.get_children()
	var dragged_index = all_items.find(dragged_item)
	var target_index = all_items.find(target_item)

	if dragged_index == -1 or target_index == -1:
		return

	# Calculate insertion index based on drop position
	var insert_index = target_index if insert_above else target_index + 1
	if dragged_index < insert_index:
		insert_index -= 1

	_projectItemContainer.move_child(dragged_item, insert_index)

	# Save all custom orders silently (no signal/reload per item)
	all_items = _projectItemContainer.get_children()
	for i in range(all_items.size()):
		all_items[i].SetCustomOrder(i)
		all_items[i].SaveProjectItem(false)

func BackgroundColorChanged(color = null):
	LoadBackgroundColor(color)
	# Defer to next frame to ensure theme changes are applied first
	await get_tree().process_frame
	RestoreProjectSelection()

func ClaudeCodeButtonEnabledChanged(_enabled: bool):
	UpdateClaudeButtonVisibility()

func ClaudeApiChatButtonEnabledChanged(_enabled: bool):
	UpdateClaudeApiChatButtonVisibility()

func UpdateClaudeButtonVisibility():
	%ClaudeButton.visible = App.GetClaudeCodeButtonEnabled()

func UpdateClaudeApiChatButtonVisibility():
	%ClaudeApiChatButton.visible = App.GetClaudeApiChatButtonEnabled()

func ClaudeMonitorButtonEnabledChanged(_enabled: bool):
	UpdateClaudeMonitorButtonVisibility()

func UpdateClaudeMonitorButtonVisibility():
	%ClaudeMonitorButton.visible = App.GetClaudeMonitorButtonEnabled()

func RestoreProjectSelection():
	if _selectedProjectItem != null and is_instance_valid(_selectedProjectItem):
		_selectedProjectItem.SelectProjectItem()
		EnableEditButtons()

func GodotVersionsChanged():
	ReloadProjectManager()
	
func GodotVersionManagerClosing():
	LoadOpenGodotButtons()

# When we save in ReleaseManager, we want to
# update the Edited Date so we need to redraw the
# list which means we need to save and restore our current selection.
# If project_id_to_select is provided, that project will be selected instead.
func ReloadProjectManager(project_id_to_select: String = ""):
	var indexOfSelectedProject = GetIndexOfSelectedProject()

	# This deletes and then recreates all our projects.
	ClearProjectContainer()
	LoadProjectsIntoProjectContainer()

	# Let the project list redraw so we can find projects because
	# we reference ProjectItem nodes when passing data back
	# and forth with the ReleaseManager page. Needs to be overhauled
	# so the data management is abstracted from the UI.
	await get_tree().create_timer(0.1).timeout

	# If a specific project ID was provided, select it (used for newly created/imported projects)
	if project_id_to_select != "":
		_selectedProjectItem = GetProjectItemByProjectId(project_id_to_select)
	else:
		# Otherwise, restore the previously selected project
		_selectedProjectItem = GetProjectItemFromIndex(indexOfSelectedProject)

	if _selectedProjectItem != null:
		var isSelected = true
		ToggleProjectItemSelection(_selectedProjectItem, isSelected)

func ProjectSaved(project_id: String):
	ReloadProjectManager(project_id)

func ClearProjectContainer():
	for child in _projectItemContainer.get_children():
		child.queue_free()

func ResetExistingSelection():
	if _selectedProjectItem != null:
		_selectedProjectItem.UnselectProjectItem()
	
	_selectedProjectItem = null

func ToggleProjectItemSelection(projectItem, isSelected):
	print("[ProjectManager] ToggleProjectItemSelection called: project=%s, isSelected=%s" % [projectItem.GetProjectName() if projectItem else "null", isSelected])
	ResetExistingSelection()

	if isSelected:
		_selectedProjectItem = projectItem
		_selectedProjectItem.SelectProjectItem()
		EnableEditButtons()
		
		# If ReleaseManager is closed, this does nothing
		Signals.emit_signal("SelectedProjecItemUpdated", _selectedProjectItem)
	else:
		_selectedProjectItem = null
		projectItem.UnselectProjectItem()
		DisableEditButtons()

func DisableEditButtons():
	_runProjectButton.disabled = true
	_editProjectButton.disabled = true
	_runProjectConsoleButton.disabled = true
	# Note: _editProjectConsoleButton stays enabled - it can open project manager without selection
	_releaseProjectButton.disabled = true
	_changeProjectButton.disabled = true
	#%AssetFinderButton.disabled = false
	%ClaudeButton.disabled = true
	%CodeQualityButton.disabled = true

func EnableEditButtons():
	_runProjectButton.disabled = false
	_editProjectButton.disabled = false
	_runProjectConsoleButton.disabled = false
	_releaseProjectButton.disabled = false
	_changeProjectButton.disabled = false
	#%AssetFinderButton.disabled = true
	%ClaudeButton.disabled = false
	%CodeQualityButton.disabled = false

func RunProject(use_console: bool = false):
	if !is_instance_valid(_selectedProjectItem):
		return

	if App.GetIsDebuggingWithoutThreads():
		StartProjectThread(use_console)
	else:
		_runProjectThread = Thread.new()
		_runProjectThread.start(StartProjectThread.bind(use_console))

# When Godot Valet exits, it calls this method.
# We don't want to wait for threads to exit.
# Commenting and leaving as a reminder.
func _exit_tree():
#	if is_instance_valid(_runProjectThread):
#		_runProjectThread.wait_to_finish()
	pass

func StartProjectThread(use_console: bool = false):
	var output = []
	var godotArguments = ["--path", _selectedProjectItem.GetProjectPathBaseDir()]
	var versionId = _selectedProjectItem.GetGodotVersionId()
	if use_console:
		var consolePath = GetConsolePathFromVersionId(versionId)
		# Use create_process for console mode - allows real-time output to console window
		OS.create_process(consolePath, godotArguments, use_console)
	else:
		var godotPath = _selectedProjectItem.GetGodotPath(versionId)
		OS.execute(godotPath, godotArguments, output, false, false)
	
func EditProject(use_console: bool = false):
	if !is_instance_valid(_selectedProjectItem):
		if use_console:
			# No project selected - open Godot project manager with console
			OpenGodotProjectManager(null, true)
		return

	var projectFile = _selectedProjectItem.GetProjectPath()

	# Normalize path - ensure it ends with project.godot
	if projectFile != null and not projectFile.ends_with("project.godot"):
		projectFile = projectFile.path_join("project.godot")

	if projectFile == null || !FileAccess.file_exists(projectFile):
		OS.alert("Did not find a project (.godot) file in the specified project path")
		return

	_selectedProjectItem.SetEditedDate(Date.GetCurrentDateAsDictionary())
	_selectedProjectItem.SaveProjectItem()

	if App.GetIsDebuggingWithoutThreads():
		EditProjectInGodotEditorThread(use_console)
	else:
		_editProjectThread = Thread.new()
		_editProjectThread.start(EditProjectInGodotEditorThread.bind(use_console))

	ReloadProjectManager()

func EditProjectInGodotEditorThread(use_console: bool = false):
	var output = []
	var projectPath = _selectedProjectItem.GetProjectPathBaseDir()
	var godotArguments = ["--editor", "--path", projectPath]
	var versionId = _selectedProjectItem.GetGodotVersionId()
	if use_console:
		var consolePath = GetConsolePathFromVersionId(versionId)
		if consolePath == null or consolePath.is_empty():
			OS.alert("Unable to locate console executable. Use settings to review godot configurations.")
			return
		# Use create_process for console mode - allows real-time output to console window
		OS.create_process(consolePath, godotArguments, use_console)
	else:
		var pathToGodot = _selectedProjectItem.GetGodotPath(versionId)
		if pathToGodot == null:
			OS.alert("Unable to locate godot at the given path. Use settings to review godot configurations.")
			return
		OS.execute(pathToGodot, godotArguments, output, false, false)

func OpenGodotProjectManager(godotVersionId = null, use_console: bool = false):
	if godotVersionId == null:
		if is_instance_valid(_selectedProjectItem):
			godotVersionId = _selectedProjectItem.GetGodotVersionId()
		else:
			# Get first available Godot version
			godotVersionId = GetFirstAvailableGodotVersionId()

	if godotVersionId == null:
		OS.alert("No Godot version configured. Please add a Godot version in Settings.")
		return

	if App.GetIsDebuggingWithoutThreads():
		RunGodotProjectManagerThread(godotVersionId, use_console)
	else:
		_openGodotProjectManagerThread = Thread.new()
		_openGodotProjectManagerThread.start(RunGodotProjectManagerThread.bind(godotVersionId, use_console))

func RunGodotProjectManagerThread(godotVersionId, use_console: bool = false):
	var output = []
	var godotArguments = ["--project-manager"]
	if use_console:
		var consolePath = GetConsolePathFromVersionId(godotVersionId)
		# Use create_process for console mode - allows real-time output to console window
		OS.create_process(consolePath, godotArguments, use_console)
	else:
		var godotPath = GetGodotPathFromVersionId(godotVersionId)
		OS.execute(godotPath, godotArguments, output, false, false)

# Returns the first available Godot version ID from the configured versions
func GetFirstAvailableGodotVersionId():
	var files = FileHelper.GetFilesFromPath("user://" + App.GetGodotVersionItemFolder())
	for file in files:
		if file.ends_with(".cfg"):
			return file.trim_suffix(".cfg")
	return null
	
func OpenSetting():
	var settings = load("res://scenes/settings/settings.tscn").instantiate()
	add_child(settings)

func CreateEditProjectDialog():
	return load("res://scenes/edit-project-dialog/edit-project-dialog.tscn").instantiate()

func GodotVersionCreatedCheck():
	var allResourceFiles = FileHelper.GetFilesFromPath("user://godot-version-items")
	for resourceFile in allResourceFiles:
		if !resourceFile.ends_with(".cfg"):
			continue
		
		# Found at least one version.
		return true
	
	# No Godot Version items have been created yet.
	return false
			
func CreateNewProject():
	if !GodotVersionCreatedCheck():
		OS.alert("Please setup a Godot Version before adding new projects. See 'Settings'.")
		return
		
	var editProjectDialog = CreateEditProjectDialog()
	add_child(editProjectDialog)
	
func ChangeProject():
	if _selectedProjectItem == null:
		return
		
	var editProjectDialog = CreateEditProjectDialog()
	add_child(editProjectDialog)
	editProjectDialog.ConfigureForSelectedProject(_selectedProjectItem)

func DeleteSelectedProject():
	_projectItemContainer.remove_child(_selectedProjectItem)
	DirAccess.remove_absolute("user://" + App.GetProjectItemFolder() + "/" + _selectedProjectItem.GetProjectId() + ".cfg")
	_selectedProjectItem = null
	DisableEditButtons()
	
func RemoveProject():
	$DeleteConfirmationDialog.show()

# Remove project by ID (called from edit-project-dialog via signal)
func RemoveProjectById(project_id: String):
	# Find and select the project item first
	for projectItem in _projectItemContainer.get_children():
		if projectItem.GetProjectId() == project_id:
			_selectedProjectItem = projectItem
			# Delete without confirmation (user already confirmed in edit dialog)
			DeleteSelectedProject()
			return

func OpenProjectFolder():
	var projectPath = _selectedProjectItem.GetProjectPathBaseDir()
	OS.shell_open(projectPath)

func LaunchClaudeCode():
	if !is_instance_valid(_selectedProjectItem):
		OS.alert("No project selected")
		return

	var project_path = _selectedProjectItem.GetProjectPathBaseDir()
	var command = App.GetClaudeCodeLaunchCommand()

	# Launch via Windows Terminal with PowerShell
	var args: PackedStringArray = [
		"-d", project_path,
		"powershell", "-NoProfile", "-NoExit",
		"-Command", command
	]
	var pid = OS.create_process("wt", args)

	if pid == -1:
		OS.alert("Failed to launch Claude Code.\n\nMake sure Windows Terminal is installed.\nCommand: %s" % command)

func LaunchClaudeMonitor():
	var command = App.GetClaudeMonitorLaunchCommand()

	# Launch via Windows Terminal with cmd (cmd inherits PATH better than PowerShell)
	var args: PackedStringArray = [
		"cmd", "/k", command
	]
	var pid = OS.create_process("wt", args)

	if pid == -1:
		OS.alert("Failed to launch Claude Monitor.\n\nMake sure Windows Terminal is installed and claude-monitor is in PATH.\nCommand: %s" % command)

func OpenAssetFinder():
	if _assetFinder == null:
		_assetFinder = load("res://scenes/file-explorer/file-explorer.tscn").instantiate()
		add_child(_assetFinder)

	_assetFinder.visible = true
	_assetFinder.ConfigureProject(_selectedProjectItem)
	
func GetProjectItemFromIndex(indexOfSelectedProjectItem):
	var index = 0;
	for projectItem in _projectItemContainer.get_children():
		if index == indexOfSelectedProjectItem:
			return projectItem
		index += 1

# Returns the project item node with the matching project ID
func GetProjectItemByProjectId(project_id: String):
	for projectItem in _projectItemContainer.get_children():
		if projectItem.GetProjectId() == project_id:
			return projectItem
	return null

func GetIndexOfSelectedProject():
	var indexOfSelectedProjectItem = 0
	for projectItem in _projectItemContainer.get_children():
		if projectItem == _selectedProjectItem:
			break
		indexOfSelectedProjectItem += 1
		
	return indexOfSelectedProjectItem

func ToggleHiddenProjectVisibility():
	var hiddenProjectCount = 0
	App.SetShowHidden(_showHiddenCheckBox.button_pressed)
	for projectItem in _projectItemContainer.get_children():
		if App._showHidden:
			# Show all projects regardless of Hide selection.
			projectItem.ShowProjectItem()
		else:
			# Hide selected projects 
			if !projectItem.GetIsHidden():
				continue
				
			hiddenProjectCount += 1
			projectItem.HideProjectItem()
			
			if projectItem != _selectedProjectItem:
				continue
				
			ToggleProjectItemSelection(projectItem, false)
	
	if hiddenProjectCount > 0:
		_hiddenProjectItemCountLabel.visible = true
		ShowHiddenProjectCount(hiddenProjectCount)
	else:
		_hiddenProjectItemCountLabel.visible = false
	
func _on_new_project_button_pressed():
	CreateNewProject()
	
func _on_edit_project_button_pressed():
	EditProject()

func _on_settings_button_pressed():
	OpenSetting()

func _on_about_button_pressed():
	var aboutDialog = load("res://scenes/about-dialog/about-dialog.tscn").instantiate()
	add_child(aboutDialog)

func _on_run_project_button_pressed():
	RunProject()

func _on_change_project_button_pressed():
	ChangeProject()

func _on_delete_confirmation_dialog_confirmed():
	DeleteSelectedProject()

func _on_release_project_button_pressed():
	if _selectedProjectItem == null:
		return

	var scene = load("res://scenes/release-manager/release-manager.tscn")
	if scene == null:
		print("ERROR: Failed to load release-manager.tscn")
		return

	var releaseManager = scene.instantiate()
	if releaseManager == null:
		print("ERROR: Failed to instantiate release manager")
		return

	add_child(releaseManager)
	releaseManager.ConfigureReleaseManagementForm(_selectedProjectItem)

func _on_check_box_pressed():
	ToggleHiddenProjectVisibility()
	
func _on_option_button_item_selected(index: int) -> void:
	App.SetSortType(index)

	# If switching to Custom sort mode, initialize custom order values
	if index == Enums.SortByType.Custom:
		InitializeCustomOrderIfNeeded()

	ReloadProjectManager()

func InitializeCustomOrderIfNeeded():
	# Check if any project has uninitialized custom order (999999)
	var all_items = _projectItemContainer.get_children()
	var needs_initialization = false

	for item in all_items:
		if item.GetCustomOrder() == 999999:
			needs_initialization = true
			break

	# If initialization is needed, set custom order based on current display order
	if needs_initialization:
		for i in range(all_items.size()):
			all_items[i].SetCustomOrder(i)
			all_items[i].SaveProjectItem()

func _on_claude_button_pressed() -> void:
	LaunchClaudeCode()

func _on_code_quality_button_pressed() -> void:
	if _selectedProjectItem == null:
		return

	var scene = load("res://scenes/code-quality-manager/code-quality-manager.tscn")
	if scene == null:
		push_error("ERROR: Failed to load code-quality-manager.tscn")
		return

	var manager = scene.instantiate()
	if manager == null:
		push_error("ERROR: Failed to instantiate code quality manager")
		return

	add_child(manager)
	manager.move_to_front()
	manager.Configure(_selectedProjectItem)

func _on_claude_api_chat_button_pressed() -> void:
	OpenClaudeApiChat()

func OpenClaudeApiChat():
	var claudeChat = load("res://scenes/claude/claude.tscn").instantiate()
	add_child(claudeChat)

func _on_asset_finder_button_pressed() -> void:
	OpenAssetFinder()

func _on_claude_monitor_button_pressed() -> void:
	LaunchClaudeMonitor()

func _on_show_run_console_button_changed(_enabled: bool):
	UpdateRunConsoleButtonVisibility()

func _on_show_edit_console_button_changed(_enabled: bool):
	UpdateEditConsoleButtonVisibility()

func UpdateRunConsoleButtonVisibility():
	_runProjectConsoleButton.visible = App.GetShowRunConsoleButton()

func UpdateEditConsoleButtonVisibility():
	_editProjectConsoleButton.visible = App.GetShowEditConsoleButton()

func _on_run_project_console_button_pressed():
	RunProject(true)

func _on_edit_project_console_button_pressed():
	EditProject(true)
