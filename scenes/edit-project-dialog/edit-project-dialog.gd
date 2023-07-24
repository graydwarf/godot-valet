extends Panel

@onready var _projectNameLineEdit = $VBoxContainer/ProjectNameHBoxContainer/ProjectNameLineEdit
@onready var _godotVersionOptionButton = $VBoxContainer/GodotVersionHBoxContainer/GodotVersionOptionButton
@onready var _projectPathLineEdit = $VBoxContainer/ProjectPathHBoxContainer/ProjectPathLineEdit
@onready var _fileDialog = $FileDialog
@onready var _selectFolderForNewProjectDialog = $SelectFolderForNewProjectDialog

var _listOfGodotVersionIds = []
var _selectedProjectItem = null
var _isCreatingNewProject = false
var _selectedDirectoryPath = ""

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
	Common.SelectOptionButtonValueByText(_godotVersionOptionButton, _selectedProjectItem.GetGodotVersion())

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
	_listOfGodotVersionIds.clear()
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
			_listOfGodotVersionIds.append(fileName)

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
		godotVersionId = _listOfGodotVersionIds[selectedIndex]

	_selectedProjectItem.SetGodotVersionId(godotVersionId)
	_selectedProjectItem.SaveProjectItem()
	Signals.emit_signal("ProjectSaved")
	queue_free()
	
func SaveNewProjectItem():
	var projectName = _projectNameLineEdit.text.trim_prefix(" ").trim_suffix(" ")
	if projectName == "":
		OS.alert("Invalid project name.")
		return
		
	if !_projectPathLineEdit.text.ends_with(".godot"):
		OS.alert("Please select a valid godot project file and try again.")
		return false
		
	if _isCreatingNewProject:
		CreateNewProject(_projectPathLineEdit.text)

	if !FileAccess.file_exists(_projectPathLineEdit.text):
		OS.alert("Project file was not found at the specified path.")
		return false
				
	var	godotVersionId = _listOfGodotVersionIds[_godotVersionOptionButton.selected]
	var projectId = Common.GetId()
	
	SaveSettingsFile(projectId, godotVersionId)
	Signals.emit_signal("ProjectSaved")
	queue_free()

func AutoExtractProjectName():
	var linesInProjectFile = Files.GetLinesFromFile(_projectPathLineEdit.text)
	for line in linesInProjectFile:
		var projectNameFilter = "config/name"
		if line.begins_with(projectNameFilter):
			line = line.replace("config/name=\"", "")
			line = line.left(-1)
			_projectNameLineEdit.text = line
			break
			
func SaveSettingsFile(projectId, godotVersionId):
	var config = ConfigFile.new()
	config.set_value("ProjectSettings", "project_name", _projectNameLineEdit.text)
	config.set_value("ProjectSettings", "godot_version_id", godotVersionId)
	config.set_value("ProjectSettings", "project_path", _projectPathLineEdit.text)
	var err = config.save("user://" + App.GetProjectItemFolder() + "/" + projectId + ".cfg")

	if err != OK:
		OS.alert("An error occurred while saving the config file.")

func CreateNewProject(filePath : String):
	FileAccess.open(filePath, FileAccess.WRITE)
	var versionMajor = int(_godotVersionOptionButton.get_item_text(_godotVersionOptionButton.selected)[0])
	
	var folderPath = filePath.get_base_dir()
	if versionMajor >= 4:
		DirAccess.copy_absolute("res://icon.svg", folderPath + "/" + "icon.svg")
	else:
		# Copy over pre-4.x specific files.
		# Note: Not clear to me if 0.x, 1.x, 2.x, pre(3.5) had different files. May need to update this.
		# Note: To prevent godot from messing with default_env.tres file, I renamed the extension to .cfg.
		DirAccess.copy_absolute("res://assets/godot-3-resources/icon.png", folderPath + "/" + "icon.png")
		DirAccess.copy_absolute("res://assets/godot-3-resources/default_env.cfg", folderPath + "/" + "default_env.tres")
	
func _on_cancel_button_pressed():
	queue_free()

func _on_save_button_pressed():
	SaveProjectSettings()

func _on_select_project_folder_button_pressed():
	_isCreatingNewProject = false
	_fileDialog.show()

func _on_create_new_project_folder_button_pressed():
	_isCreatingNewProject = true
	_selectFolderForNewProjectDialog.show()
	
func _on_file_dialog_file_selected(path):
	_projectPathLineEdit.text = path
	AutoExtractProjectName()

func _on_godot_version_option_button_item_selected(index):
	_godotVersionOptionButton.text = ""
	_godotVersionOptionButton.text = _godotVersionOptionButton.get_item_text(index)

func _on_select_folder_for_new_project_dialog_dir_selected(dir):
	if !DirAccess.dir_exists_absolute(dir):
		OS.alert("Could not locate the selected directory")
		return
	
	if !Files.IsDirectoryEmpty(dir):
		OS.alert("Unable to create project in directory. Make sure the directory is empty and you have sufficient access to create new files.")
		return

	_projectPathLineEdit.text = dir + "/" + "project.godot"
