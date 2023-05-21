extends ColorRect

@onready var _runProjectButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/RunProjectButton
@onready var _editProjectButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/EditProjectButton
@onready var _changeProjectButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/ChangeProjectButton
@onready var _removeProjectButton = $VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/RemoveProjectButton
@onready var _projectItemContainer = $VBoxContainer/HBoxContainer/MarginContainer/ScrollContainer/ProjectItemContainer

#var _solutionName = "godot-valet-solution"
var _selectedProjectItem = null

func _ready():
	InitSignals()
	color = Game.GetDefaultBackgroundColor()
	InitProjectSettings()

func InitProjectSettings():
	#LoadValetSettings()
	var id = null
	LoadProjectsIntoProjectContainer(id)

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

func LoadProjectsIntoProjectContainer(id):
	var allResourceFiles = Files.GetFilesFromPath("user://" + Game.GetProjectItemFolder())
	for resourceFile in allResourceFiles:
		if !resourceFile.ends_with(".cfg"):
			continue

		var projectId = resourceFile.trim_suffix(".cfg")
		
		var projectItem = load("res://scenes/project-item/project-item.tscn").instantiate()
		_projectItemContainer.add_child(projectItem)

		if projectId == id:
			var isSelected = true
			ProjectItemSelected(projectItem, isSelected)
			
		var config = ConfigFile.new()
		var err = config.load("user://" + Game.GetProjectItemFolder() + "/" + projectId + ".cfg")
		if err == OK:
			projectItem.SetProjectName(config.get_value("ProjectSettings", "project_name", "New Project"))
			projectItem.SetGodotVersion(config.get_value("ProjectSettings", "godot_version", ""))
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

func InitSignals():
	Signals.connect("ProjectItemSelected", ProjectItemSelected)
	Signals.connect("NewProjectCreated", NewProjectCreated)

func NewProjectCreated(id):
	ClearProjectContainer()
	LoadProjectsIntoProjectContainer(id)

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
	_changeProjectButton.disabled = true
	_removeProjectButton.disabled = true
	
func EnableEditButtons():
	_runProjectButton.disabled = false
	_editProjectButton.disabled = false
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
		
	pass
	
func EditProject():
	if !is_instance_valid(_selectedProjectItem):
		return
		
	var projectFile = Files.FindFirstFileWithExtension(_selectedProjectItem.GetProjectPath(), ".godot")
	if projectFile == null || !FileAccess.file_exists(projectFile):
		OS.alert("Did not find a project (.godot) file in the specified project path")
		return
	
	EditProjectInGodotEditorThread()
	var thread = Thread.new()
	thread.start(EditProjectInGodotEditorThread)

func EditProjectInGodotEditorThread():
	var output = []
	var godotArguments = ["--verbose", "--path " + _selectedProjectItem.GetProjectPath(), "--editor"]
	OS.execute(_selectedProjectItem.GetGodotPath(), godotArguments, output)

func OpenSetting():
	var settings = load("res://scenes/settings/settings.tscn").instantiate()
	add_child(settings)

func CreateEditProjectDialog():
	return load("res://scenes/new-project-dialog/edit-project-dialog.tscn").instantiate()

func ChangeProject():
	var editProjectDialog = CreateEditProjectDialog()
	add_child(editProjectDialog)
	var id = null
	if _selectedProjectItem != null:
		id = _selectedProjectItem.GetId()
		
	editProjectDialog.ConfigureForSelectedProject(id)
	
func _on_new_project_button_pressed():
	ChangeProject()
	
func _on_edit_project_button_pressed():
	EditProject()

func _on_settings_button_pressed():
	OpenSetting()

func _on_run_project_button_pressed():
	RunProject()

func _on_change_project_button_pressed():
	ChangeProject()
