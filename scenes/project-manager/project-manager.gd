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

var _selectedProjectItem = null
var _runProjectThread
var _editProjectThread
var _openGodotProjectManagerThread

func _ready():
	InitSignals()
	InitProjectSettings()
	LoadTheme()
	LoadBackgroundColor()
	LoadCustomScrollContainerTheme()
#
func LoadCustomScrollContainerTheme():
	var customWidth = 20
	var v_scrollbar : VScrollBar= _scrollContainer.get_v_scroll_bar()
	v_scrollbar.set_custom_minimum_size(Vector2(customWidth, 0))
	
#	_scrollContainer.theme = App.GetCu
#	add_child(v_scrollbar)
	
func LoadBackgroundColor(color = null):
	if color == null:
		color = App.GetBackgroundColor()
		
	var style_box = theme.get_stylebox("panel", "Panel") as StyleBoxFlat

	if style_box:
		style_box.bg_color = App.GetBackgroundColor()
	else:
		print("StyleBoxFlat not found!")

func LoadTheme():
	theme = load(App.GetThemePath())
	
func InitProjectSettings():
	LoadProjectsIntoProjectContainer()
	LoadOpenGodotButtons()

func ClearCustomButtonContainer():
	for button in _customButtonContainer.get_children():
		button.queue_free()

# Creates buttons dynamically based on the godot versions we have configured
func LoadOpenGodotButtons():
	ClearCustomButtonContainer()
	var files = Files.GetFilesFromPath("user://" + App.GetGodotVersionItemFolder())
	for file in files:
		if !file.ends_with(".cfg"):
			continue

		var fileName = file.trim_suffix(".cfg")
		
		var config = ConfigFile.new()
		var err = config.load("user://" + App.GetGodotVersionItemFolder() + "/" + fileName + ".cfg")
		if err == OK:
			var godotVersion = config.get_value("GodotVersionSettings", "godot_version", "")
			var button : Button = load("res://scenes/nav-button/nav-button.tscn").instantiate()
			button.text = "Open " + godotVersion
			button.size.x = 140
			button.SetCustomVar1(fileName)
			button.pressed.connect(_on_button_pressed.bind(button))
			button.tooltip_text = "Launches into the Godot Project Manager for the given version."
			_customButtonContainer.add_child(button)

# Handles events for our dynamic godot version buttons
func _on_button_pressed(button):
	var godotVersionId = button.GetCustomVar1()
	OpenGodotProjectManager(godotVersionId)
	
func LoadProjectsIntoProjectContainer():
	var allResourceFiles = Files.GetFilesFromPath("user://" + App.GetProjectItemFolder())
	for resourceFile in allResourceFiles:
		if !resourceFile.ends_with(".cfg"):
			continue

		var projectId = resourceFile.trim_suffix(".cfg")
		
		var projectItem = load("res://scenes/project-item/project-item.tscn").instantiate()
		_projectItemContainer.add_child(projectItem)
		
		if _selectedProjectItem != null:
			var isSelected = true
			ProjectItemSelected(_selectedProjectItem, isSelected)
			
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
			projectItem.SetExportType(config.get_value("ProjectSettings", "export_type", "Release"))
			projectItem.SetExportFileName(config.get_value("ProjectSettings", "export_file_name", ""))
			projectItem.SetPackageType(config.get_value("ProjectSettings", "package_type", "Zip + Clean"))
			projectItem.SetItchProfileName(config.get_value("ProjectSettings", "itch_profile_name", ""))
			projectItem.SetItchProjectName(config.get_value("ProjectSettings", "itch_project_name", ""))

func GetGodotVersionFromId(godotVersionId):
	var files = Files.GetFilesFromPath("user://" + App.GetGodotVersionItemFolder())
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
	var files = Files.GetFilesFromPath("user://" + App.GetGodotVersionItemFolder())
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
	Signals.connect("ProjectItemSelected", ProjectItemSelected)
	Signals.connect("ProjectSaved", ProjectSaved)
	Signals.connect("GodotVersionManagerClosing", GodotVersionManagerClosing)
	Signals.connect("GodotVersionsChanged", GodotVersionsChanged)
	Signals.connect("BackgroundColorChanged", BackgroundColorChanged)

func BackgroundColorChanged(color = null):
	LoadBackgroundColor(color)

func GodotVersionsChanged():
	ReloadProjectManager()
	
func GodotVersionManagerClosing():
	LoadOpenGodotButtons()

func ReloadProjectManager():
	ClearProjectContainer()
	LoadProjectsIntoProjectContainer()
	
func ProjectSaved():
	ReloadProjectManager()

func ClearProjectContainer():
	for child in _projectItemContainer.get_children():
		child.queue_free()
		
func ProjectItemSelected(projectItem, isSelected):
	if !isSelected:
		DisableEditButtons()
		_selectedProjectItem.UnselectProjectItem()
		_selectedProjectItem = null
	else:
		_selectedProjectItem = projectItem
		_selectedProjectItem.SelectProjectItem()
		EnableEditButtons()

func DisableEditButtons():
	_runProjectButton.disabled = true
	_editProjectButton.disabled = true
	_releaseProjectButton.disabled = true
	_openProjectFolderButton.disabled = true
	_changeProjectButton.disabled = true
	_removeProjectButton.disabled = true
	
func EnableEditButtons():
	_runProjectButton.disabled = false
	_editProjectButton.disabled = false
	_releaseProjectButton.disabled = false
	_openProjectFolderButton.disabled = false
	_changeProjectButton.disabled = false
	_removeProjectButton.disabled = false

func RunProject():
	if !is_instance_valid(_selectedProjectItem):
		return

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
	
	_editProjectThread = Thread.new()
	_editProjectThread.start(EditProjectInGodotEditorThread)
	#EditProjectInGodotEditorThread()

func EditProjectInGodotEditorThread():
	var output = []
	var projectPath = _selectedProjectItem.GetProjectPathBaseDir()
	var godotArguments = ["--verbose", "--editor", "--path", projectPath] 
	var pathToGodot = _selectedProjectItem.GetGodotPath(_selectedProjectItem.GetGodotVersionId())
	OS.execute(pathToGodot, godotArguments, output, false, false)

func OpenGodotProjectManager(godotVersionId = null):
	if godotVersionId == null:
		godotVersionId = _selectedProjectItem.GetGodotVersionId()
	var godotPath = GetGodotPathFromVersionId(godotVersionId)
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
	var allResourceFiles = Files.GetFilesFromPath("user://godot-version-items")
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

func _on_new_project_button_pressed():
	CreateNewProject()
	
func _on_edit_project_button_pressed():
	EditProject()

func _on_settings_button_pressed():
	OpenSetting()

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
