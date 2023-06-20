extends Panel

@onready var _projectNameLineEdit = $VBoxContainer/ProjectNameHBoxContainer/ProjectNameLineEdit
@onready var _godotVersionOptionButton = $VBoxContainer/GodotVersionHBoxContainer/GodotVersionOptionButton
@onready var _projectPathLineEdit = $VBoxContainer/ProjectPathHBoxContainer/ProjectPathLineEdit
@onready var _fileDialog = $FileDialog
@onready var _extractProjectNameCheckBox = $VBoxContainer/OptionsHBoxContainer/ExtractProjectNameCheckBox

var _litOfGodotVersionIds = []
var _selectedProjectItem = null

func _ready():
	LoadTheme()
	LoadGodotVersion()

func LoadTheme():
	theme = load(App.GetThemePath())
	
func ConfigureForSelectedProject(selectedProjectItem):
	_selectedProjectItem = selectedProjectItem
	LoadProject()

func LoadProject():
	_projectNameLineEdit.text = _selectedProjectItem.GetProjectName()
	_projectPathLineEdit.text = _selectedProjectItem.GetProjectPath()
	var version = _selectedProjectItem.GetGodotVersion()
	#if version.find("???") == -1:
	_godotVersionOptionButton.text = _selectedProjectItem.GetGodotVersion()

func GetGodotVersion(godotVersionId):
	var files = Files.GetFilesFromPath("user://godot-version-items")
	for file in files:
		if !file.ends_with(".cfg"):
			continue

		var fileName = file.trim_suffix(".cfg")
		if fileName != godotVersionId:
			continue
			
		var config = ConfigFile.new()
		var err = config.load("user://" + App.GetGodotVersionItemFolder() + "/" + fileName + ".cfg")
		if err == OK:
			return config.get_value("GodotVersionSettings", "godot_version", "???")
			
func LoadGodotVersion():
	_litOfGodotVersionIds.clear()
	var allResourceFiles = Files.GetFilesFromPath("user://godot-version-items")
	for resourceFile in allResourceFiles:
		if !resourceFile.ends_with(".cfg"):
			continue

		var fileName = resourceFile.trim_suffix(".cfg")
		
		var config = ConfigFile.new()
		var err = config.load("user://godot-version-items//" + fileName + ".cfg")
		if err == OK:
			var godotVersion = config.get_value("GodotVersionSettings", "godot_version", "???")
			_godotVersionOptionButton.add_item(godotVersion)
			_litOfGodotVersionIds.append(fileName)

func SaveProjectSettings():
	if _selectedProjectItem != null:
		SaveExistingProjectItem()
	else:
		SaveNewProjectItem()

func SaveExistingProjectItem():
	var projectName = _projectNameLineEdit.text.trim_prefix(" ").trim_suffix(" ")
	if projectName == "":
		OS.alert("Invalid project name. Cancel to close.")
		return
	
	_selectedProjectItem.SetProjectName(projectName)
	_selectedProjectItem.SetProjectPath(_projectPathLineEdit.text)

	var selectedIndex = _godotVersionOptionButton.selected
	var godotVersionId = null
	if selectedIndex >= 0:
		godotVersionId = _litOfGodotVersionIds[selectedIndex]

	_selectedProjectItem.SetGodotVersionId(godotVersionId)
	_selectedProjectItem.SaveProjectItem()
	Signals.emit_signal("ProjectSaved")
	queue_free()
	
func SaveNewProjectItem():
	var projectName = _projectNameLineEdit.text.trim_prefix(" ").trim_suffix(" ")
	if projectName == "":
		OS.alert("Invalid project name. Cancel to close.")
		return
	
	if !FileAccess.file_exists(_projectPathLineEdit.text):
		OS.alert("Project not found at specified path.")
		return
		
	var	godotVersionId = _litOfGodotVersionIds[_godotVersionOptionButton.selected]
	var projectId = Common.GetId()
	
	SaveSettingsFile(projectId, godotVersionId)
	Signals.emit_signal("ProjectSaved")
	queue_free()

func SaveSettingsFile(projectId, godotVersionId):
	var config = ConfigFile.new()

	config.set_value("ProjectSettings", "project_name", _projectNameLineEdit.text)
	config.set_value("ProjectSettings", "godot_version_id", godotVersionId)
	config.set_value("ProjectSettings", "project_path", _projectPathLineEdit.text)

	# Save the config file.
	var err = config.save("user://" + App.GetProjectItemFolder() + "/" + projectId + ".cfg")

	if err != OK:
		OS.alert("An error occurred while saving the config file.")

func ProcessSelectedProject(path):
	if !path.ends_with(".godot"):
		OS.alert("Invalid Godot project selected!")
		return
	
	_projectPathLineEdit.text = path
	
	if _extractProjectNameCheckBox.button_pressed:
		var linesInProjectFile = Files.GetLinesFromFile(_projectPathLineEdit.text)
		for line in linesInProjectFile:
			var projectNameFilter = "config/name"
			if line.begins_with(projectNameFilter):
				line = line.replace("config/name=\"", "")
				line = line.left(-1)
				_projectNameLineEdit.text = line
				break

func _on_cancel_button_pressed():
	queue_free()

func _on_save_button_pressed():
	SaveProjectSettings()

func _on_select_project_folder_button_pressed():
	_fileDialog.show()

func _on_file_dialog_file_selected(path):
	ProcessSelectedProject(path)

func _on_godot_version_option_button_item_selected(index):
	_godotVersionOptionButton.text = ""
	_godotVersionOptionButton.text = _godotVersionOptionButton.select(index)
