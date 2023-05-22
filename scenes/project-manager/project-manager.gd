extends ColorRect

@onready var _runProjectButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/RunProjectButton
@onready var _editProjectButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/EditProjectButton
@onready var _releaseProjectButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/ReleaseProjectButton

@onready var _changeProjectButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/ChangeProjectButton
@onready var _removeProjectButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/RemoveProjectButton
@onready var _projectItemContainer = $VBoxContainer/HBoxContainer/MarginContainer/ScrollContainer/ProjectItemContainer
@onready var _customButtonContainer = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/CustomButtonVBoxContainer

var _selectedProjectItem = null
var _runProjectThread
var _editProjectThread
var _openGodotProjectManagerThread

func _ready():
	InitSignals()
	color = Game.GetDefaultBackgroundColor()
	InitProjectSettings()

func InitProjectSettings():
	#LoadValetSettings()
	LoadProjectsIntoProjectContainer()
	LoadOpenGodotButtons()

func ClearCustomButtonContainer():
	for button in _customButtonContainer.get_children():
		button.queue_free()
		
func LoadOpenGodotButtons():
	ClearCustomButtonContainer()
	var files = Files.GetFilesFromPath("user://" + Game.GetGodotVersionItemFolder())
	for file in files:
		if !file.ends_with(".cfg"):
			continue

		var fileName = file.trim_suffix(".cfg")
		
		var config = ConfigFile.new()
		var err = config.load("user://" + Game.GetGodotVersionItemFolder() + "/" + fileName + ".cfg")
		if err == OK:
			var godotVersion = config.get_value("GodotVersionSettings", "godot_version", "")
			var button = load("res://scenes/nav-button/nav-button.tscn").instantiate()
			button.text = "Open " + godotVersion
			button.size.x = 140
			button.SetCustomVar1(fileName)
			button.pressed.connect(_on_button_pressed.bind(button))
			#button.connect("pressed", _on_button_pressed)
			_customButtonContainer.add_child(button)

func _on_button_pressed(button):
	var godotVersionId = button.GetCustomVar1()
	OpenGodotProjectManager(godotVersionId)
	
func SaveValetSettings():
	pass
#	var config = ConfigFile.new()
#	config.set_value("Settings", "selected_project_name", _loadProjectOptionButton.text)
#	var err = config.save("user://" + _solutionName + ".cfg")
#
#	if err != OK:
#		OS.alert("An error occurred while saving the valet configuration file.")
		
#func CreateNewValetSettingsFile():
#	var config = ConfigFile.new()
#	config.set_value("Settings", "selected_project_name", "")
#	var err = config.save("user://" + _solutionName + ".cfg")
#
#	if err != OK:
#		OS.alert("An error occurred while saving the valet configuration file.")
	
#func LoadValetSettings():
#	if !FileAccess.file_exists("user://" + _solutionName + ".cfg"):
#		CreateNewValetSettingsFile()
#		return
#
#	var config = ConfigFile.new()
#	var err = config.load("user://" + _solutionName + ".cfg")
#	if err != OK:
#		OS.alert("Error: " + str(err) + " - while opening: " + _solutionName + ".cfg")
#		return
#
#	_selectedProjectName = config.get_value("Settings", "selected_project_name", "")

func LoadProjectsIntoProjectContainer():
	var allResourceFiles = Files.GetFilesFromPath("user://" + Game.GetProjectItemFolder())
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
		var err = config.load("user://" + Game.GetProjectItemFolder() + "/" + projectId + ".cfg")
		if err == OK:
			projectItem.SetProjectId(projectId)
			projectItem.SetProjectName(config.get_value("ProjectSettings", "project_name", "New Project"))
			var godotVersionId = config.get_value("ProjectSettings", "godot_version_id", "")
			var projectReleaseId = config.get_value("ProjectSettings", "project_release_id", "v0.0.1")
			var godotVersion = GetGodotVersionFromId(godotVersionId)
			if godotVersion != null:
				projectItem.SetGodotVersionId(godotVersionId)
				projectItem.SetGodotVersion(godotVersion)
	
			projectItem.SetProjectReleaseId(projectReleaseId)
			projectItem.SetProjectPath(config.get_value("ProjectSettings", "project_path", ""))
			projectItem.SetProjectVersion(config.get_value("ProjectSettings", "project_version", "v0.0.1"))
		
		#loadedConfigurationFile = true
	
#	# Did we load a config file?
#	if !loadedConfigurationFile:
#		# No. Create a new default one.
#		newProjectName = "New Project"
#		CreateNewSettingsFile(newProjectName)
#		_loadProjectOptionButton.text = newProjectName
#		SaveValetSettings()
#	else:
#		# We loaded a config file. Select it.
#		if newProjectName != "":
#			_selectedProjectName = newProjectName
#
#		var selectedIndex = FindProjectIndexByName(_selectedProjectName)
#
#		if selectedIndex == null:
#			selectedIndex = 0
#
#		LoadProjectByIndex(selectedIndex)
#		_loadProjectOptionButton.select(selectedIndex)
#		GenerateButlerPreview()
#		GenerateExportPreview()

func GetGodotVersionFromId(godotVersionId):
	var files = Files.GetFilesFromPath("user://" + Game.GetGodotVersionItemFolder())
	for file in files:
		if !file.ends_with(".cfg"):
			continue

		var fileName = file.trim_suffix(".cfg")
		if fileName != godotVersionId:
			continue
		
		var config = ConfigFile.new()
		var err = config.load("user://" + Game.GetGodotVersionItemFolder() + "/" + fileName + ".cfg")
		if err == OK:
			return config.get_value("GodotVersionSettings", "godot_version", "")

func GetGodotPathFromVersionId(godotVersionId):
	var files = Files.GetFilesFromPath("user://" + Game.GetGodotVersionItemFolder())
	for file in files:
		if !file.ends_with(".cfg"):
			continue

		var fileName = file.trim_suffix(".cfg")
		if fileName != godotVersionId:
			continue
		
		var config = ConfigFile.new()
		var err = config.load("user://" + Game.GetGodotVersionItemFolder() + "/" + fileName + ".cfg")
		if err == OK:
			return config.get_value("GodotVersionSettings", "godot_path", "")
			
func InitSignals():
	Signals.connect("ProjectItemSelected", ProjectItemSelected)
	Signals.connect("ProjectSaved", ProjectSaved)
	Signals.connect("GodotVersionManagerClosing", GodotVersionManagerClosing)
	Signals.connect("NewGodotVersionAdded", NewGodotVersionAdded)

func NewGodotVersionAdded():
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
	
	_changeProjectButton.disabled = true
	_removeProjectButton.disabled = true
	
func EnableEditButtons():
	_runProjectButton.disabled = false
	_editProjectButton.disabled = false
	_releaseProjectButton.disabled = false
	_changeProjectButton.disabled = false
	_removeProjectButton.disabled = false
		
# projectName should be valid at this point
#func CreateNewProject(projectName):
#	CreateNewSettingsFile(projectName)
	#_loadProjectOptionButton.add_item(projectName)
	#_loadProjectOptionButton.select(_loadProjectOptionButton.item_count - 1)

func RunProject():
	if !is_instance_valid(_selectedProjectItem):
		return

	_runProjectThread = Thread.new()
	_runProjectThread.start(StartProjectThread)

func _exit_tree():
	if is_instance_valid(_runProjectThread):
		_runProjectThread.wait_to_finish()

	if is_instance_valid(_editProjectThread):
		_editProjectThread.wait_to_finish()
	
	if is_instance_valid(_openGodotProjectManagerThread):
		_openGodotProjectManagerThread.wait_to_finish()
		
func StartProjectThread():
	var output = []
	var godotArguments = ["--path " + _selectedProjectItem.GetProjectPathBaseDir()]
	OS.execute(_selectedProjectItem.GetGodotPath(_selectedProjectItem.GetGodotVersionId()), godotArguments, output)
	#DisplayOutput(output)
	
func EditProject():
	if !is_instance_valid(_selectedProjectItem):
		return
		
	var projectFile = _selectedProjectItem.GetProjectPath()
	if projectFile == null || !FileAccess.file_exists(projectFile):
		OS.alert("Did not find a project (.godot) file in the specified project path")
		return
	
	_editProjectThread = Thread.new()
	_editProjectThread.start(EditProjectInGodotEditorThread)

func EditProjectInGodotEditorThread():
	var output = []
	var godotArguments = ["--verbose", "--path " + _selectedProjectItem.GetProjectPathBaseDir(), "--editor"]
	var pathToGodot = _selectedProjectItem.GetGodotPath(_selectedProjectItem.GetGodotVersionId())
	OS.execute(pathToGodot, godotArguments, output)

func OpenGodotProjectManager(godotVersionId = null):
	if godotVersionId == null:
		godotVersionId = _selectedProjectItem.GetGodotVersionId()
	var godotPath = GetGodotPathFromVersionId(godotVersionId)
	_openGodotProjectManagerThread = Thread.new()
	_openGodotProjectManagerThread.start(RunGodotProjectManagerThread.bind(godotPath))

func RunGodotProjectManagerThread(godotPath):
	var output = []
	var godotArguments = ["--project-manager"]
	OS.execute(godotPath, godotArguments, output, true, true)
	
func OpenSetting():
	var settings = load("res://scenes/settings/settings.tscn").instantiate()
	add_child(settings)

func CreateEditProjectDialog():
	return load("res://scenes/new-project-dialog/edit-project-dialog.tscn").instantiate()

func CreateNewProject():
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
	DirAccess.remove_absolute("user://" + Game.GetProjectItemFolder() + "/" + _selectedProjectItem.GetProjectId() + ".cfg")
	_selectedProjectItem = null
	DisableEditButtons()
	
func RemoveProject():
	$DeleteConfirmationDialog.show()
	
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
