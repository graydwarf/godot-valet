extends Control

@onready var _projectItemContainer = $HBoxContainer/MarginContainer/ScrollContainer/VBoxContainer
var _solutionName = "godot-valet-solution"
var _selectedProjectItem = null

func _ready():
	InitSignals()
	InitProjectSettings()

func InitProjectSettings():
	#LoadValetSettings()
	LoadConfigSettings()

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

func LoadConfigSettings(newProjectName = ""):
	var allResourceFiles = Files.GetFilesFromPath("user://")
	var loadedConfigurationFile = false
	for resourceFile in allResourceFiles:
		if resourceFile == "export_presets.cfg" || resourceFile == "godot-valet-solution.cfg":
			continue

		if !resourceFile.ends_with(".cfg"):
			continue

		var projectName = resourceFile.trim_suffix(".cfg")
		
		var projectItem = load("res://scenes/scenes/project-item/project-item.tscn").instantiate()
		_projectItemContainer.add_child(projectItem)
		
		var config = ConfigFile.new()
		var err = config.load("user://" + projectName + ".cfg")
		if err == OK:
			projectItem.SetProjectPath(config.get_value("ProjectSettings", "project_path", ""))
			projectItem.SetGodotVersion(config.get_value("ProjectSettings", "godot_path", ""))
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
	Signals.connect("ProjectItemClicked", ProjectItemClicked)

func ProjectItemClicked(projectItem):
	_selectedProjectItem = projectItem
	EnableEditButtons()

func EnableEditButtons():
	pass
	
# projectName should be valid at this point
#func CreateNewProject(projectName):
#	CreateNewSettingsFile(projectName)
	#_loadProjectOptionButton.add_item(projectName)
	#_loadProjectOptionButton.select(_loadProjectOptionButton.item_count - 1)

func EditProject():
	
	var projectFile = Files.FindFirstFileWithExtension(_selectedProjectItem.GetProjectPath(), ".godot")
	if projectFile == null || !FileAccess.file_exists(projectFile):
		OS.alert("Did not find a project (.godot) file in the specified project path")
		return
		
	var thread = Thread.new()
	thread.start(EditProjectInGodotEditorThread)

func EditProjectInGodotEditorThread():
	var output = []
	var godotArguments = ["--verbose", "--path " + _selectedProjectItem.GetProjectPath(), "--editor"]
	OS.execute(_selectedProjectItem.GetGodotPath(), godotArguments, output)

func OpenNewProjectDialog():
	var newProjectDialog = load("res://scenes/scenes/new-project-dialog/new-project-dialog.tscn").instantiate()
	add_child(newProjectDialog)

func OpenSetting():
	var settings = load("res://scenes/scenes/settings/settings.tscn").instantiate()
	add_child(settings)
	
func _on_new_project_button_pressed():
	OpenNewProjectDialog()
	
func _on_edit_project_button_pressed():
	EditProject()

func _on_settings_button_pressed():
	OpenSetting()
