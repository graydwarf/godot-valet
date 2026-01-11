extends Panel

@onready var _projectNameLineEdit = $VBoxContainer/ProjectNameHBoxContainer/ProjectNameLineEdit
@onready var _godotVersionOptionButton = $VBoxContainer/GodotVersionHBoxContainer/GodotVersionOptionButton
@onready var _projectPathLineEdit = $VBoxContainer/ProjectPathHBoxContainer/ProjectPathLineEdit
@onready var _fileDialog = $FileDialog
@onready var _selectFolderForNewProjectDialog = $SelectFolderForNewProjectDialog
@onready var _hideProjectCheckbox = %HideProjectCheckbox
@onready var _removeProjectButton = %RemoveProjectButton
@onready var _hideProjectRow = $VBoxContainer/HideProjectHBoxContainer
@onready var _removeProjectRow = $VBoxContainer/RemoveProjectHBoxContainer
@onready var _customIconLineEdit = %CustomIconLineEdit
@onready var _iconFileDialog = $IconFileDialog
@onready var _customIconRow = $VBoxContainer/CustomIconHBoxContainer

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
	# Show options for existing projects
	_hideProjectRow.visible = true
	_removeProjectRow.visible = true
	_customIconRow.visible = true

func ConfigureForNewProject():
	# Hide options when creating new project
	_hideProjectRow.visible = false
	_removeProjectRow.visible = false
	_customIconRow.visible = false

func LoadProject():
	_projectNameLineEdit.text = _selectedProjectItem.GetProjectName()
	_projectPathLineEdit.text = _selectedProjectItem.GetProjectPath()
	Common.SelectOptionButtonValueByText(_godotVersionOptionButton, _selectedProjectItem.GetGodotVersion())
	_hideProjectCheckbox.button_pressed = _selectedProjectItem.GetIsHidden()
	_customIconLineEdit.text = _selectedProjectItem.GetThumbnailPath()

func GetGodotVersion(godotVersionId):
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
			return config.get_value("GodotVersionSettings", "godot_version", "???")
			
func LoadGodotVersion():
	_listOfGodotVersionIds.clear()
	var allResourceFiles = FileHelper.GetFilesFromPath("user://godot-version-items")
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
	_selectedProjectItem.SetIsHidden(_hideProjectCheckbox.button_pressed)
	_selectedProjectItem.SetThumbnailPath(_customIconLineEdit.text)

	var selectedIndex = _godotVersionOptionButton.selected
	var godotVersionId = null
	if selectedIndex >= 0:
		godotVersionId = _listOfGodotVersionIds[selectedIndex]

	_selectedProjectItem.SetGodotVersionId(godotVersionId)
	_selectedProjectItem.SaveProjectItem()

	# Emit signal if hiding the project
	if _hideProjectCheckbox.button_pressed:
		Signals.emit_signal("HidingProjectItem")

	Signals.emit_signal("ProjectSaved", _selectedProjectItem.GetProjectId())
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
	Signals.emit_signal("ProjectSaved", projectId)
	queue_free()

func AutoExtractProjectName():
	var linesInProjectFile = FileHelper.GetLinesFromFile(_projectPathLineEdit.text)
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
	config.set_value("ProjectSettings", "created_date", Date.GetCurrentDateAsDictionary())
	config.set_value("ProjectSettings", "edited_date", Date.GetCurrentDateAsDictionary())

	var err = config.save("user://" + App.GetProjectItemFolder() + "/" + projectId + ".cfg")

	if err != OK:
		OS.alert("An error occurred while saving the config file.")

# Returns array of filenames that will be overwritten when creating a new project
func GetProjectFileConflicts(dir_path: String) -> Array[String]:
	var conflicts: Array[String] = []
	var files_to_check = ["project.godot", "icon.png", "default_env.tres"]

	for file_name in files_to_check:
		var full_path = dir_path + "/" + file_name
		if FileAccess.file_exists(full_path):
			conflicts.append(file_name)

	return conflicts

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

	# Store the selected directory for use after confirmation
	_selectedDirectoryPath = dir

	# Check for file conflicts instead of requiring empty directory
	var conflicts = GetProjectFileConflicts(dir)

	if conflicts.size() > 0:
		# Show confirmation dialog with list of files that will be overwritten
		var file_list = ", ".join(conflicts)
		var message = "The following files will be overwritten:\n\n%s\n\nContinue?" % file_list
		$OverwriteConfirmationDialog.dialog_text = message
		$OverwriteConfirmationDialog.popup_centered()
	else:
		# No conflicts, proceed directly
		_projectPathLineEdit.text = dir + "/" + "project.godot"

func _on_overwrite_confirmation_dialog_confirmed():
	# User confirmed overwriting files, proceed with project creation
	_projectPathLineEdit.text = _selectedDirectoryPath + "/" + "project.godot"

func _on_remove_project_button_pressed():
	if _selectedProjectItem == null:
		return

	# Emit signal to remove the project from the project manager
	Signals.emit_signal("RemoveProject", _selectedProjectItem.GetProjectId())
	queue_free()

func _on_select_icon_button_pressed():
	# Set initial directory based on current icon path or Pictures folder
	var currentPath = _customIconLineEdit.text
	if currentPath != "" and FileAccess.file_exists(currentPath):
		_iconFileDialog.current_dir = currentPath.get_base_dir()
		_iconFileDialog.current_file = currentPath.get_file()
	else:
		_iconFileDialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	_iconFileDialog.show()

func _on_clear_icon_button_pressed():
	_customIconLineEdit.text = ""

func _on_icon_file_dialog_file_selected(path: String):
	if not FileAccess.file_exists(path):
		OS.alert("Error: File does not exist: " + path)
		return
	_customIconLineEdit.text = path
