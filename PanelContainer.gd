extends PanelContainer

@onready var _godotPathLineEdit = $VBoxContainer/GodotPathHBoxContainer/ExportPathLineEdit
@onready var _projectPathLineEdit = $VBoxContainer/ProjectPathHBoxContainer/ProjectPathLineEdit
@onready var _projectNameLineEdit = $VBoxContainer/ProjectNameHBoxContainer/ProjectNameLineEdit
@onready var _projectVersionLineEdit = $VBoxContainer/ProjectVersionHBoxContainer/ProjectVersionLineEdit
@onready var _exportPresetLineEdit = $VBoxContainer/ExportPresetHBoxContainer/ExportPresetLineEdit
@onready var _releaseTypeLineEdit = $VBoxContainer/ReleaseTypeHBoxContainer/ReleaseTypeLineEdit
@onready var _exportPathLineEdit = $VBoxContainer/ExportPathHBoxContainer/ExportPathLineEdit
@onready var _butlerCommandLineEdit = $VBoxContainer/ButlerCommandHBoxContainer/ButlerCommandLineEdit
@onready var _itchProfileNameLineEdit = $VBoxContainer/ItchNameHBoxContainer/ItchNameLineEdit
@onready var _outputTextEdit = $VBoxContainer/OutputVBoxContainer/OutputTextEdit
@onready var _errorLabel = $VBoxContainer/ErrorsHBoxContainer/ErrorCountLabel

var _listOfPresetTypes = ["Windows Desktop", "Linux/X11", "Web"]
var _listOfItchPublishTypes = ["windows", "html5", "linux"]

var _godotPathText = ""
var _projectPathText = ""
var _projectNameText = ""
var _projectVersionText = ""
var _exportPresetText = ""
var _releaseTypeText = ""
var _exportPathText = ""
var _butlerCommandText = ""
var _itchProfileNameText = ""

func _ready():
	InitProjectSettings()

func InitProjectSettings():
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

func GetPackageType(presetType):
	if presetType == "Windows Desktop":
		return ".zip"
	elif presetType == "Linux/X11":
		return ".x86_64"
	elif presetType == "Web":
		return ".html"
	else:
		OS.alert("Invalid package type!")
		return "invalid"

# Uppercase
func ExportPreset(presetName):
	var exportType = GetExportType()
	var packageType = GetPackageType(presetName)
	
	if exportType == "invalid" || packageType == "invalid":
		return
	
	var exportOption = "--export" + exportType
	
	var releaseProfileName = GetItchReleaseProfileName(presetName)

	var exportPath = _projectPathText + "\\exports\\" + _projectVersionText + "\\" + releaseProfileName + "\\" + _releaseTypeText

	if !DirAccess.dir_exists_absolute(exportPath):
		DirAccess.make_dir_recursive_absolute(exportPath)
	
	var output = []
	var args = ['"--path "' + _projectPathText, exportOption, presetName, exportPath + "\\" + _projectNameText + packageType]
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
	_godotPathText = _godotPathLineEdit.text.to_lower()
	_projectPathText = _projectPathLineEdit.text.to_lower()
	_projectNameText = _projectNameLineEdit.text.to_lower()
	_projectVersionText = _projectVersionLineEdit.text.to_lower()
	_exportPresetText = _exportPresetLineEdit.text.to_lower()
	_releaseTypeText = _releaseTypeLineEdit.text.to_lower()
	_exportPathText = _exportPathLineEdit.text.to_lower()
	_butlerCommandText = _butlerCommandLineEdit.text.to_lower()
	_itchProfileNameText = _itchProfileNameLineEdit.text.to_lower()

func ExportProject():
	GroomFieldText()
	
	if _exportPresetText == "all":
		for preset in _listOfPresetTypes:
			ExportPreset(preset)
	else:
		ExportPreset(_exportPresetText)

	CountErrors()

func CountErrors():
	var output : String = _outputTextEdit.text
	var errorCount = output.count("ERROR")
	_errorLabel.text = str(errorCount)
	if errorCount == 0:
		_errorLabel.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		_errorLabel.self_modulate = Color(1.0, 0.0, 0.0, 1.0)

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
		#for publishType in _listOfItchPublishTypes:
		var publishType = "windows"
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
	
func _on_generate_path_button_pressed():
	var exportPath = GetGeneratedExportPath()
	_exportPathLineEdit.text = exportPath
	_exportPathLineEdit = exportPath

func _on_publish_button_pressed():
	PublishToButler()

func _on_generate_butler_path_button_pressed():
	var butlerCommand = GetGeneratedButlerCommand()
	_butlerCommandLineEdit.text = butlerCommand
	
func _on_open_folder_button_pressed():
	OpenExportPathFolder()

func _on_export_button_pressed():
	ExportProject()
