extends PanelContainer

@onready var _godotPathLineEdit = $VBoxContainer/GodotPathHBoxContainer/ExportPathLineEdit
@onready var _projectPathLineEdit = $VBoxContainer/ProjectPathHBoxContainer/ProjectPathLineEdit
@onready var _projectVersionLineEdit = $VBoxContainer/ProjectVersionHBoxContainer/ProjectVersionLineEdit
@onready var _windowsCheckBox = $VBoxContainer/ExportPresetHBoxContainer/WindowsCheckBox
@onready var _linuxCheckBox = $VBoxContainer/ExportPresetHBoxContainer/LinuxCheckBox
@onready var _webCheckBox = $VBoxContainer/ExportPresetHBoxContainer/WebCheckBox
@onready var _releaseTypeDdl = $VBoxContainer/ReleaseTypeHBoxContainer/ReleaseTypeOptionButton
@onready var _exportPathLineEdit = $VBoxContainer/ExportPathHBoxContainer/ExportPathLineEdit
@onready var _butlerCommandLineEdit = $VBoxContainer/ButlerCommandHBoxContainer/ButlerCommandLineEdit
@onready var _itchProfileNameLineEdit = $VBoxContainer/ItchNameHBoxContainer/ItchNameLineEdit
@onready var _outputTextEdit = $VBoxContainer/OutputVBoxContainer/OutputTextEdit
@onready var _errorCountLabel = $VBoxContainer/IssuesHBoxContainer/ErrorCountLabel
@onready var _warningCountLabel = $VBoxContainer/IssuesHBoxContainer/MarginContainer/HBoxContainer/WarningsCountLabel
@onready var _packageTypeOptionButton = $VBoxContainer/PackageTypeHBoxContainer/PackageTypeOptionButton
@onready var _loadProjectOptionButton = $VBoxContainer/LoadProjectHBoxContainer/LoadProjectOptionButton
@onready var _deleteConfirmationDialog = $ConfirmationDialog

#var _listOfPresetTypes = ["Windows Desktop", "Linux/X11", "Web"]
var _listOfItchPublishTypes = ["windows", "html5", "linux"]

var _solutionName = "godot-valet"
var _godotPathText = ""
var _projectPathText = ""
var _projectNameText = ""
var _projectVersionText = ""
var _exportPresetText = ""
var _releaseTypeText = ""
var _exportPathText = ""
var _butlerCommandText = ""
var _itchProfileNameText = ""
var _selectedProjectName = ""

func _ready():
	InitSignals()
	InitProjectSettings()

func InitSignals():
	Signals.connect("CreateNewProject", CreateNewProject)
	Signals.connect("SaveSettings", SaveSettings)

# projectName should be valid at this point
func CreateNewProject(projectName):
	ResetFields()
	SaveSettings(projectName)
	_loadProjectOptionButton.add_item(projectName)
	_loadProjectOptionButton.select(_loadProjectOptionButton.item_count - 1)

# Don't fields that are likely to be the same as other projects.
# godot path, itch name
func ResetFields():
	_projectPathLineEdit.text = ""
	_projectVersionLineEdit.text = "v0.0.1"
	_windowsCheckBox.button_pressed = true
	_linuxCheckBox.button_pressed = true
	_webCheckBox.button_pressed = true
	_releaseTypeDdl.text = "Release"
	_exportPathLineEdit.text = ""

func SaveValetSettings():
	var config = ConfigFile.new()
	var err = config.load("user://" + _solutionName + ".cfg")
	if err != OK:
		OS.alert("Error: " + str(err) + " - while opening: " + _solutionName + ".cfg")
		return
		
	config.set_value("Settings", "selected_project_name", _loadProjectOptionButton.text)

func CreateNewValetSettingsFile():
	var config = ConfigFile.new()
	_selectedProjectName = ""
	config.set_value("Settings", "selected_project_name", _selectedProjectName)
	var err = config.save("user://" + _solutionName + ".cfg")

	if err != OK:
		OS.alert("An error occurred while saving the valet configuration file.")
	
func LoadValetSettings():
	if !FileAccess.file_exists("user://" + _solutionName + ".cfg"):
		CreateNewValetSettingsFile()
		return
		
	var config = ConfigFile.new()
	var err = config.load("user://" + _solutionName + ".cfg")
	if err != OK:
		OS.alert("Error: " + str(err) + " - while opening: " + _solutionName + ".cfg")
		return
		
	_selectedProjectName = config.get_value("Settings", "selected_project_name", "")

func LoadConfigSettings():
	var allResourceFiles = Files.GetFilesFromPath("user://")
	var loadedConfigurationFile = false
	for resourceFile in allResourceFiles:
		if resourceFile == "export_presets.cfg" || resourceFile == "godot-valet.cfg":
			continue

		if !resourceFile.ends_with(".cfg"):
			continue

		var projectName = resourceFile.trim_suffix(".cfg")
		
		_loadProjectOptionButton.add_item(projectName)
		
		loadedConfigurationFile = true
	
	# Did we load a config file?
	if !loadedConfigurationFile:
		# No. Create a new default one.
		var newProjectName = "New Project"
		SaveSettings(newProjectName)
		_loadProjectOptionButton.text = newProjectName
		SaveValetSettings()
	else:
		# We loaded a config file. Select it.
		var selectedIndex = FindSelectedProjectIndexByName(_selectedProjectName)
		LoadProjectByIndex(selectedIndex)
		_loadProjectOptionButton.select(selectedIndex)

func SaveSettings(projectName):
	var config = ConfigFile.new()

	config.set_value("ProjectSettings", "project_name", _loadProjectOptionButton.text)
	config.set_value("ProjectSettings", "godot_path", _godotPathLineEdit.text)
	config.set_value("ProjectSettings", "project_path", _projectPathLineEdit.text)
	config.set_value("ProjectSettings", "project_version", _projectVersionLineEdit.text)
	config.set_value("ProjectSettings", "windows_preset_checked", _windowsCheckBox.button_pressed)
	config.set_value("ProjectSettings", "linux_preset_checked", _linuxCheckBox.button_pressed)
	config.set_value("ProjectSettings", "web_preset_checked", _webCheckBox.button_pressed)
	config.set_value("ProjectSettings", "release_type", _releaseTypeDdl.text)
	config.set_value("ProjectSettings", "package_type", _packageTypeOptionButton.text)
	config.set_value("ProjectSettings", "itch_profile_name", _itchProfileNameLineEdit.text)

	# Save the config file.
	var err = config.save("user://" + projectName + ".cfg")

	if err != OK:
		_outputTextEdit.text = ("An error occurred while saving the config file.")

func FindSelectedProjectIndexByName(selectedProjectName):
	if selectedProjectName == "":
		return 0
		
	for itemIndex in _loadProjectOptionButton.item_count:
		var projectName = _loadProjectOptionButton.get_item_text(itemIndex)
		if projectName == selectedProjectName:
			return itemIndex
		
func LoadProjectByIndex(index):
	var projectName = _loadProjectOptionButton.get_item_text(index)
	var config = ConfigFile.new()
	var err = config.load("user://" + projectName + ".cfg")
	if err == OK:
		_godotPathLineEdit.text = config.get_value("ProjectSettings", "godot_path", "")
		_projectPathLineEdit.text = config.get_value("ProjectSettings", "project_path", "")
		_projectVersionLineEdit.text = config.get_value("ProjectSettings", "project_version", "v0.0.1")
		_windowsCheckBox.button_pressed = config.get_value("ProjectSettings", "windows_preset_checked", true)
		_linuxCheckBox.button_pressed = config.get_value("ProjectSettings", "linux_preset_checked", true)
		_webCheckBox.button_pressed = config.get_value("ProjectSettings", "web_preset_checked", true)
		_packageTypeOptionButton.text = config.get_value("ProjectSettings", "package_type", "Zip")
		_releaseTypeDdl.text = config.get_value("ProjectSettings", "release_type", "Release")
		_itchProfileNameLineEdit.text = config.get_value("ProjectSettings", "itch_profile_name", "")
	else:
		OS.alert("Failed to load settings for: " + projectName)
		
	# save project as selected
	
func InitProjectSettings():
	LoadValetSettings()
	LoadConfigSettings()
	GroomFieldText()
	PopulateExportPath()
	PopulateButlerCommand()	

func PopulateExportPath():
	_exportPathLineEdit.text = GetGeneratedExportPath()
	_exportPathText = _exportPathLineEdit.text

func PopulateButlerCommand():
	_butlerCommandLineEdit.text = GetGeneratedButlerCommand()
	_butlerCommandText = _butlerCommandLineEdit.text
	
func GetExportType():
	if _releaseTypeText == "debug":
		return "-debug"
	elif _releaseTypeText == "pack":
		return "-pack"
	elif _releaseTypeText == "release":
		return "-release"
	else:
		OS.alert("invalid export type")
		return "invalid"

func GetExtensionType(presetType):
	if presetType == "Windows":
		if _packageTypeOptionButton.text == "No Zip":
			return ".exe"
		else:
			return ".zip"
	elif presetType == "Linux":
		return ".x86_64"
	elif presetType == "Web":
		return ".html"
	else:
		OS.alert("Invalid preset type!")
		return "invalid"

# Uppercase
# Windows, Linux, Web
func ExportPreset(presetName):
	var exportType = GetExportType()
	var extensionType = GetExtensionType(presetName)
	
	if exportType == "invalid" || extensionType == "invalid":
		return
	
	var exportOption = "--export" + exportType
	
	var releaseProfileName = GetItchReleaseProfileName(presetName)

	var exportPath = _projectPathText + "\\exports\\" + _projectVersionText + "\\" + releaseProfileName + "\\" + _releaseTypeText

	if !DirAccess.dir_exists_absolute(exportPath):
		DirAccess.make_dir_recursive_absolute(exportPath)
	
	var output = []
	var args = ['"--path "' + _projectPathText, exportOption, presetName, exportPath + "\\" + _projectNameText + extensionType]
	var readStdeer = true
	var openConsole = true
	
	var exitCode = OS.execute(_godotPathText, args, output, readStdeer, openConsole) 
	
	_outputTextEdit.text = "Exit code: " + str(exitCode)
	_outputTextEdit.text += "\n"
	_outputTextEdit.text += "Output: " + str(output).replace("\\r\\n", "\n")

func GetItchReleaseProfileName(presetName):
	var publishType = ""
	if presetName.to_lower() == "linux/x11":
		publishType = "linux"
	elif presetName.to_lower() == "windows desktop":
		publishType = "windows"
	elif presetName.to_lower() == "web":
		publishType = "html5"
	return publishType

func GroomFieldText():
	# TODO: Validation
	_godotPathText = _godotPathLineEdit.text
	_projectPathText = _projectPathLineEdit.text
	#_projectNameText = _projectNameLineEdit.text
	_projectVersionText = _projectVersionLineEdit.text
	_releaseTypeText = _releaseTypeDdl.text.to_lower()
	_exportPathText = _exportPathLineEdit.text.to_lower()
	_butlerCommandText = _butlerCommandLineEdit.text.to_lower()
	_itchProfileNameText = _itchProfileNameLineEdit.text.to_lower()

func ExportProject():
	GroomFieldText()
	
	if _packageTypeOptionButton.text == "Zip":
		ExportWithZip()
	elif _packageTypeOptionButton.text == "Zip + Clean":
		var isCleaningUp = true
		ExportWithZip(isCleaningUp)
	elif _packageTypeOptionButton.text == "No Zip":
		ExportWithoutZip()
		
	CountErrors()
	CountWarnings()

func ExportWithoutZip():
	if _windowsCheckBox.pressed:
		var presetName = "windows"
		var listOfExistingFilesToLeaveAlone = GetExistingFiles(presetName)
		listOfExistingFilesToLeaveAlone.append(_projectNameText + ".zip")
		ExportPreset(presetName)
		
	if _linuxCheckBox.pressed:
		var presetName = "linux"
		var listOfExistingFilesToLeaveAlone = GetExistingFiles(presetName)
		listOfExistingFilesToLeaveAlone.append(_projectNameText + ".zip")
		ExportPreset(presetName)
	
	if _webCheckBox.pressed:
		var presetName = "html5"
		var listOfExistingFilesToLeaveAlone = GetExistingFiles(presetName)
		listOfExistingFilesToLeaveAlone.append(_projectNameText + ".zip")
		RenameHomePageToIndex(presetName)

func ExportWithZip(isCleaningUp = false):
	if _windowsCheckBox.pressed:
		var presetName = "windows"
		var listOfExistingFilesToLeaveAlone = GetExistingFiles(presetName)
		listOfExistingFilesToLeaveAlone.append(_projectNameText + ".zip")
		ExportPreset(presetName)
		
	if _linuxCheckBox.pressed:
		var presetName = "linux"
		var listOfExistingFilesToLeaveAlone = GetExistingFiles(presetName)
		listOfExistingFilesToLeaveAlone.append(_projectNameText + ".zip")
		ExportPreset(presetName)
		ZipFiles(presetName)
		if isCleaningUp:
			Cleanup(presetName, listOfExistingFilesToLeaveAlone)
	
	if _webCheckBox.pressed:
		var presetName = "html5"
		var listOfExistingFilesToLeaveAlone = GetExistingFiles(presetName)
		listOfExistingFilesToLeaveAlone.append(_projectNameText + ".zip")
		RenameHomePageToIndex(presetName)
		ZipFiles(presetName)
		if isCleaningUp:
			Cleanup(presetName, listOfExistingFilesToLeaveAlone)
	
func GetExistingFiles(presetName):
	var releaseProfileName = GetItchReleaseProfileName(presetName)
	var exportPath = _projectPathText + "\\exports\\" + _projectVersionText + "\\" + releaseProfileName + "\\" + _releaseTypeText
	return Files.GetFilesFromPath(exportPath)

func Cleanup(presetName, listOfExistingFilesToLeaveAlone):
	var releaseProfileName = GetItchReleaseProfileName(presetName)
	var exportPath = _projectPathText + "\\exports\\" + _projectVersionText + "\\" + releaseProfileName + "\\" + _releaseTypeText
	var isSendingToRecyle = true
	var errors = Files.DeleteAllFilesAndFolders(exportPath, isSendingToRecyle, listOfExistingFilesToLeaveAlone)
	for error in errors:
		_outputTextEdit.text += "\\n ERROR: Cleanup - Code: #" + str(error)
	
func RenameHomePageToIndex(presetName):
	var releaseProfileName = GetItchReleaseProfileName(presetName)
	var exportPath = _projectPathText + "\\exports\\" + _projectVersionText + "\\" + releaseProfileName + "\\" + _releaseTypeText
	DirAccess.rename_absolute(exportPath + "\\" + _projectNameText + ".html", exportPath + "\\" + "index.html")
		
func ZipFiles(presetName):
	var releaseProfileName = GetItchReleaseProfileName(presetName)
	var exportPath = _projectPathText + "\\exports\\" + _projectVersionText + "\\" + releaseProfileName + "\\" + _releaseTypeText
	var listOfFileNames = Files.GetFilesFromPath(exportPath)
	var listOfFilePaths = []
	for fileName in listOfFileNames:
		listOfFilePaths.append(exportPath + "\\" + fileName)
		
	var zipFileName = _projectNameText + ".zip" 
	CreateZipFile(exportPath + "\\" + zipFileName, listOfFileNames, listOfFilePaths)
	
func CreateZipFile(zipFilePath, listOfFileNames : Array, listOfFilePaths : Array):
	var writer := ZIPPacker.new()
	
	# "user://archive.zip"
	var err := writer.open(zipFilePath)
	
	if err != OK:
		return err
	
	var index = 0
	for fileName in listOfFileNames:
		writer.start_file(fileName)
		writer.write_file(FileAccess.get_file_as_bytes(listOfFilePaths[index]))
		writer.close_file()
		index += 1

	writer.close()
	return OK

func CountErrors():
	var output : String = _outputTextEdit.text
	var errorCount = output.count("ERROR")
	_errorCountLabel.text = str(errorCount)
	if errorCount == 0:
		_errorCountLabel.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		_errorCountLabel.self_modulate = Color(1.0, 0.0, 0.0, 1.0)

func CountWarnings():
	var output : String = _outputTextEdit.text
	var warningCount = output.count("WARNING")
	_warningCountLabel.text = str(warningCount)
	if warningCount == 0:
		_warningCountLabel.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		_warningCountLabel.self_modulate = Color(1.0, 1.0, 0.0, 1.0)
		
func GetGeneratedExportPath():
	return _projectPathText + "\\exports\\" + _projectVersionText

func GetGeneratedButlerCommand():
	var butlerCommand = ""
	if _exportPresetText == "all":
		butlerCommand = "* (we're publishing windows, linux and html5)"
	else:
		butlerCommand = "TODO: converted from string to array" #GetButlerPathForPublishType(_exportPresetText)

	return butlerCommand
	
# Example: butler push ...\godot-valet\exports\v0.0.1\godot-valet.zip poplava/godot-valet:windows
func GetButlerArguments(publishType):
	var butlerArguments = []
	butlerArguments.append("push")
	
	# Build Path: ...\godot-valet\exports\v0.0.1\godot-valet.zip
	# Surround with \" in case path has spaces
	var buildPath = "\""
	buildPath += _exportPathText
	buildPath += "\\"
	buildPath += publishType
	buildPath += "\\"
	buildPath += _releaseTypeText
	buildPath += "\\"
	buildPath += _projectNameText
	buildPath += ".zip"
	buildPath += "\""
	butlerArguments.append(buildPath)
	
	# Build Itch Config: poplava/godot-valet:windows
	var itchPublishInfo = ""
	itchPublishInfo += _itchProfileNameText
	itchPublishInfo += "/"
	itchPublishInfo += _projectNameText
	itchPublishInfo += ":"
	itchPublishInfo += publishType
	butlerArguments.append(itchPublishInfo)
	
	return butlerArguments

func GetItchReleaseType():
	if _exportPresetText == "windows desktop":
		return "windows"
	elif _exportPresetText == "linux/x11":
		return "linux"
	elif _exportPresetText == "web":
		return "html5"
	else:
		OS.alert("Critical failure. Unknown Export Preset")

# butler push godot-valet.zip poplava/godot-valet:windows
func PublishToButler():
	var output = []
	var exitCode = 0
	if _exportPresetText == "all":
		for publishType in _listOfItchPublishTypes:
			var butlerArguments = GetButlerArguments(publishType)
			#var projectPath = _exportPathText + "\\" + publishType + "\\" + _releaseTypeText + "\\" + _projectNameText + ".zip"
			exitCode = OS.execute("butler", butlerArguments, output)
	else:
		# need to convert butlerArguments from string to array
#		var butlerCommand = GetButlerPathForPublishType(GetItchReleaseProfileName(_exportPresetText))
#		var exportPath = _exportPathText + "\\" + GetItchReleaseProfileName(_exportPresetText) + "\\" + _releaseTypeText + "\\" + _projectNameText + ".zip"
#		exitCode = OS.execute("CMD.exe", ["/C", "cd " + exportPath + " && " + butlerCommand], output)
		pass

	_outputTextEdit.text = "\n\n"
	_outputTextEdit.text = "------------------ Butler ------------------"
	_outputTextEdit.text = "Exit code: " + str(exitCode)
	_outputTextEdit.text += "\n"
	_outputTextEdit.text += "Output: " + str(output).replace("\\r\\n", "\n")
	
func OpenExportPathFolder():
	OS.shell_open(_exportPathText)

func OpenNewProjectDialog():
	var newProjectDialog = load("res://scenes/scenes/new-project-dialog/new-project-dialog.tscn").instantiate()
	add_child(newProjectDialog)

func OpenEditProjectDialog():
	var editProjectDialog = load("res://scenes/scenes/edit-project-dialog/edit-project-dialog.tscn").instantiate()
	add_child(editProjectDialog)
	editProjectDialog.SetProjectName(_loadProjectOptionButton.text)
		
func DisplayDeleteProjectConfirmationDialog():
	_deleteConfirmationDialog.dialog_text = "Are you sure you want to delete this project?\n " + _loadProjectOptionButton.text
	_deleteConfirmationDialog.position = Vector2(400, 200)
	_deleteConfirmationDialog.show()

func DeleteProject():
	var projectName = _loadProjectOptionButton.text
	_loadProjectOptionButton.remove_item(projectName)
	DirAccess.remove_absolute("user://" + projectName + ".cfg")

func _on_publish_button_pressed():
	PublishToButler()

func _on_open_folder_button_pressed():
	OpenExportPathFolder()

func _on_export_button_pressed():
	ExportProject()

func _on_new_project_button_pressed():
	OpenNewProjectDialog()

func _on_save_settings_button_pressed():
	SaveSettings(_loadProjectOptionButton.text)

func _on_delete_project_button_pressed():
	DisplayDeleteProjectConfirmationDialog()

func _on_confirmation_dialog_canceled():
	pass # Replace with function body.

func _on_confirmation_dialog_confirmed():
	DeleteProject()

func _on_load_project_option_button_item_selected(index):
	LoadProjectByIndex(index)
	SaveSettings(_loadProjectOptionButton.text)

func _on_edit_project_button_pressed():
	OpenEditProjectDialog()
