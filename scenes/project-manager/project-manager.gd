extends Panel

@onready var _runProjectButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/RunProjectButton
@onready var _editProjectButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/EditProjectButton
@onready var _releaseProjectButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/ReleaseProjectButton
@onready var _openProjectFolderButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/OpenProjectFolderButton

@onready var _changeProjectButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/ChangeProjectButton
@onready var _removeProjectButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/RemoveProjectButton
@onready var _projectItemContainer = $VBoxContainer/HBoxContainer/MarginContainer/ScrollContainer/MarginContainer/ProjectItemContainer
@onready var _customButtonContainer = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/CustomButtonVBoxContainer
@onready var _scrollContainer = $VBoxContainer/HBoxContainer/MarginContainer/ScrollContainer
@onready var _showHiddenCheckBox = %ShowHiddenCheckBox
@onready var _hiddenProjectItemCountLabel = %HiddenProjectItemCountLabel

var _selectedProjectItem = null
var _runProjectThread
var _editProjectThread
var _openGodotProjectManagerThread
var _fileExplorer : FileExplorer

func _ready():
	InitSignals()
	InitProjectSettings()
	LoadTheme()
	LoadBackgroundColor()
	LoadCustomScrollContainerTheme()
	UpdateClaudeButtonVisibility()
	
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
			projectItem.SetExportType(config.get_value("ProjectSettings", "export_type", "Release"))
			projectItem.SetExportFileName(config.get_value("ProjectSettings", "export_file_name", ""))
			projectItem.SetPackageType(config.get_value("ProjectSettings", "package_type", "Zip"))
			projectItem.SetItchProfileName(config.get_value("ProjectSettings", "itch_profile_name", ""))
			projectItem.SetShowTipsForErrors(config.get_value("ProjectSettings", "show_tips_for_errors", true))
			projectItem.SetItchProjectName(config.get_value("ProjectSettings", "itch_project_name", ""))
			var isHidden = config.get_value("ProjectSettings", "is_hidden", false)
			projectItem.SetIsHidden(isHidden)
			projectItem.SetPublishedDate(config.get_value("ProjectSettings", "published_date", {}))
			projectItem.SetCreatedDate(config.get_value("ProjectSettings", "created_date", {}))
			projectItem.SetEditedDate(config.get_value("ProjectSettings", "edited_date", {}))
			projectItem.SetSourceFilters(config.get_value("ProjectSettings", "source_filters", []))
			projectItem.SetThumbnailPath(config.get_value("ProjectSettings", "thumbnail_path", "res://icon.svg"))
			projectItem.SetCustomOrder(config.get_value("ProjectSettings", "custom_order", 999999))

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
			
func InitSignals():
	Signals.connect("ToggleProjectItemSelection", ToggleProjectItemSelection)
	Signals.connect("ProjectSaved", ProjectSaved)
	Signals.connect("GodotVersionManagerClosing", GodotVersionManagerClosing)
	Signals.connect("BackgroundColorChanged", BackgroundColorChanged)
	Signals.connect("HidingProjectItem", HidingProjectItem)
	Signals.connect("ReorderProjectItems", ReorderProjectItems)
	Signals.connect("ClaudeCodeButtonEnabledChanged", ClaudeCodeButtonEnabledChanged)

func HidingProjectItem():
	ToggleHiddenProjectVisibility()

func ReorderProjectItems(dragged_item, target_item):
	var all_items = _projectItemContainer.get_children()
	var dragged_index = all_items.find(dragged_item)
	var target_index = all_items.find(target_item)

	if dragged_index == -1 or target_index == -1:
		return

	_projectItemContainer.move_child(dragged_item, target_index)

	all_items = _projectItemContainer.get_children()
	for i in range(all_items.size()):
		all_items[i].SetCustomOrder(i)
		all_items[i].SaveProjectItem()

func BackgroundColorChanged(color = null):
	LoadBackgroundColor(color)
	# Defer to next frame to ensure theme changes are applied first
	await get_tree().process_frame
	RestoreProjectSelection()

func ClaudeCodeButtonEnabledChanged(_enabled: bool):
	UpdateClaudeButtonVisibility()

func UpdateClaudeButtonVisibility():
	%ClaudeButton.visible = App.GetClaudeCodeButtonEnabled()

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
	_releaseProjectButton.disabled = true
	_openProjectFolderButton.disabled = true
	_changeProjectButton.disabled = true
	_removeProjectButton.disabled = true
	#%FileExplorerButton.disabled = false
	%ClaudeButton.disabled = true

func EnableEditButtons():
	_runProjectButton.disabled = false
	_editProjectButton.disabled = false
	_releaseProjectButton.disabled = false
	_openProjectFolderButton.disabled = false
	_changeProjectButton.disabled = false
	_removeProjectButton.disabled = false
	#%FileExplorerButton.disabled = true
	%ClaudeButton.disabled = false

func RunProject():
	if !is_instance_valid(_selectedProjectItem):
		return

	if App.GetIsDebuggingWithoutThreads():
		StartProjectThread()
	else:
		_runProjectThread = Thread.new()
		_runProjectThread.start(StartProjectThread)

# When Godot Valet exits, it calls this method.
# We don't want to wait for threads to exit. 
# Commenting and leaving as a reminder.
func _exit_tree():
#	if is_instance_valid(_runProjectThread):
#		_runProjectThread.wait_to_finish()
	pass
	
func StartProjectThread():
	var output = []
	var godotArguments = ["--path", _selectedProjectItem.GetProjectPathBaseDir()]
	var versionId = _selectedProjectItem.GetGodotVersionId()
	var godotPath = _selectedProjectItem.GetGodotPath(versionId)
	OS.execute(godotPath, godotArguments, output, false, false)
	
func EditProject():
	if !is_instance_valid(_selectedProjectItem):
		return
		
	var projectFile = _selectedProjectItem.GetProjectPath()
	if projectFile == null || !FileAccess.file_exists(projectFile):
		OS.alert("Did not find a project (.godot) file in the specified project path")
		return
	
	_selectedProjectItem.SetEditedDate(Date.GetCurrentDateAsDictionary())
	_selectedProjectItem.SaveProjectItem()
	
	if App.GetIsDebuggingWithoutThreads():
		EditProjectInGodotEditorThread()
	else:
		_editProjectThread = Thread.new()
		_editProjectThread.start(EditProjectInGodotEditorThread)
	
	ReloadProjectManager()
	
func EditProjectInGodotEditorThread():
	var output = []
	var projectPath = _selectedProjectItem.GetProjectPathBaseDir()
	var godotArguments = ["--editor", "--path", projectPath] 
	var pathToGodot = _selectedProjectItem.GetGodotPath(_selectedProjectItem.GetGodotVersionId())
	if pathToGodot == null:
		OS.alert("Unable to locate godot at the given path. Use settings to review godot configurations.")
		return
	OS.execute(pathToGodot, godotArguments, output, false, false)

func OpenGodotProjectManager(godotVersionId = null):
	if godotVersionId == null:
		godotVersionId = _selectedProjectItem.GetGodotVersionId()
	var godotPath = GetGodotPathFromVersionId(godotVersionId)
	
	if App.GetIsDebuggingWithoutThreads():
		RunGodotProjectManagerThread(godotPath)
	else:
		_openGodotProjectManagerThread = Thread.new()
		_openGodotProjectManagerThread.start(RunGodotProjectManagerThread.bind(godotPath))

func RunGodotProjectManagerThread(godotPath):
	var output = []
	var godotArguments = ["--project-manager"]
	OS.execute(godotPath, godotArguments, output, false, false)
	
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

func OpenProjectFolder():
	var projectPath = _selectedProjectItem.GetProjectPathBaseDir()
	OS.shell_open(projectPath)

func LaunchClaudeCode():
	if !is_instance_valid(_selectedProjectItem):
		OS.alert("No project selected")
		return

	var projectPath = _selectedProjectItem.GetProjectPathBaseDir()
	var commandTemplate = App.GetClaudeCodeLaunchCommand()

	# Replace {project_path} placeholder with actual project path
	var command = commandTemplate.replace("{project_path}", projectPath)
	var args = ["/c", command]
	var pid = OS.create_process("cmd.exe", args)

	if pid == -1:
		OS.alert("Failed to launch Claude Code.\n\nMake sure it's installed and check your launch command in Settings.\nCurrent command: %s" % command)

func OpenFileExplorer():
	if _fileExplorer == null:
		_fileExplorer = load("res://scenes/file-explorer/file-explorer.tscn").instantiate()
		add_child(_fileExplorer)

	_fileExplorer.visible = true
	_fileExplorer.ConfigureProject(_selectedProjectItem)
	
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

func _on_remove_project_button_pressed():
	RemoveProject()

func _on_delete_confirmation_dialog_confirmed():
	DeleteSelectedProject()

func _on_release_project_button_pressed():
	if _selectedProjectItem == null:
		return
		
	var releaseManager = load("res://scenes/release-manager/release-manager.tscn").instantiate()
	add_child(releaseManager)
	releaseManager.ConfigureReleaseManagementForm(_selectedProjectItem)
	
func _on_open_project_folder_button_pressed():
	OpenProjectFolder()

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

func _on_file_explorer_button_pressed() -> void:
	OpenFileExplorer()
