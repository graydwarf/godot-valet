extends ColorRect

@onready var _projectNameLineEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ProjectNameHBoxContainer/ProjectNameLineEdit
@onready var _exportPathLineEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ExportPathHBoxContainer2/ExportPathLineEdit
@onready var _godotPathLineEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/GodotPathHBoxContainer/ExportPathLineEdit
@onready var _projectVersionLineEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ProjectVersionHBoxContainer/ProjectVersionLineEdit
@onready var _windowsCheckBox = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ExportPresetHBoxContainer/WindowsCheckBox
@onready var _linuxCheckBox = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ExportPresetHBoxContainer/LinuxCheckBox
@onready var _webCheckBox = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ExportPresetHBoxContainer/WebCheckBox
@onready var _exportTypeOptionButton = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ExportTypeHBoxContainer/ExportTypeOptionButton
@onready var _exportPreviewTextEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ExportPathHBoxContainer/ExportPreviewTextEdit
@onready var _itchProfileNameLineEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ItchProfileNameHBoxContainer/ItchProfileNameLineEdit
@onready var _itchProjectNameLineEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ItchProjectNameHBoxContainer/ItchProjectNameLineEdit
@onready var _errorCountLabel = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ErrorCountVBoxContainer/HBoxContainer/ErrorCountLabel
@onready var _warningCountLabel = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ErrorCountVBoxContainer/HBoxContainer/MarginContainer/HBoxContainer/WarningsCountLabel
@onready var _packageTypeOptionButton = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/PackageTypeHBoxContainer/PackageTypeOptionButton
@onready var _butlerPreviewTextEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ButlerCommandHBoxContainer/ButlerPreviewTextEdit
@onready var _exportFileNameLineEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ExportFileNameHBoxContainer/ExportFileNameLineEdit
@onready var _saveChangesConfirmationDialog = $SaveChangesConfirmationDialog
@onready var _projectPathLineEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ProjectPathHBoxContainer2/ProjectPathLineEdit
@onready var _outputTabContainer = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/OutputHBoxContainer/OutputTabContainer
@onready var _useSha256CheckBox = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/Generate256HashNameHBoxContainer/UseSha256CheckBox
@onready var _autoGenerateExportFileNamesCheckBox = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/AutomateExportFileNameHBoxContainer/AutoGenerateExportFileNamesCheckBox

var _busyBackground
var _selectedProjectItem = null
var _isDirty = false
var _isClosingReleaseManager = false

func _ready():
	InitSignals()
	color = Game.GetDefaultBackgroundColor()

func InitSignals():
	pass

func ConfigureReleaseManagementForm(selectedProjectItem):
	_selectedProjectItem = selectedProjectItem
	_projectPathLineEdit.text = selectedProjectItem.GetFormattedProjectPath()
	_projectNameLineEdit.text = selectedProjectItem.GetProjectName()
	_godotPathLineEdit.text = selectedProjectItem.GetGodotPath(selectedProjectItem.GetGodotVersionId())
	_windowsCheckBox.button_pressed = selectedProjectItem.GetWindowsChecked()
	_linuxCheckBox.button_pressed = selectedProjectItem.GetLinuxChecked()
	_webCheckBox.button_pressed = selectedProjectItem.GetWebChecked()
	_exportPathLineEdit.text = selectedProjectItem.GetExportPath()
	_exportFileNameLineEdit.text = selectedProjectItem.GetExportFileName()
	_projectVersionLineEdit.text = selectedProjectItem.GetProjectVersion()
	_exportTypeOptionButton.text = selectedProjectItem.GetExportType()
	_packageTypeOptionButton.text = selectedProjectItem.GetPackageType()
	_itchProjectNameLineEdit.text = selectedProjectItem.GetItchProjectName()
	_itchProfileNameLineEdit.text = selectedProjectItem.GetItchProfileName()
	GenerateExportPreview()
	GenerateButlerPreview()
	
func SaveSettings():
	_selectedProjectItem.SetWindowsChecked(_windowsCheckBox.button_pressed)
	_selectedProjectItem.SetLinuxChecked(_linuxCheckBox.button_pressed)
	_selectedProjectItem.SetWebChecked(_webCheckBox.button_pressed)
	_selectedProjectItem.SetExportPath(_exportPathLineEdit.text)
	_selectedProjectItem.SetProjectVersion(_projectVersionLineEdit.text)
	_selectedProjectItem.SetExportFileName(_exportFileNameLineEdit.text)
	_selectedProjectItem.SetItchProjectName(_itchProfileNameLineEdit.text)
	_selectedProjectItem.SetExportType(_exportTypeOptionButton.text)
	_selectedProjectItem.SetPackageType(_packageTypeOptionButton.text)
	_selectedProjectItem.SetItchProjectName(_itchProjectNameLineEdit.text)
	_selectedProjectItem.SetItchProfileName(_itchProfileNameLineEdit.text)
	_selectedProjectItem.SaveProjectItem()
	
func GenerateExportPreview():
	_exportPreviewTextEdit.text = GetExportPreview()

func GenerateButlerPreview():
	_butlerPreviewTextEdit.text = GetButlerPreview()

func ValidateProjectVersionText():
	var text = _projectVersionLineEdit.text
	if !ValidateFileNameText(text):
		_projectVersionLineEdit.self_modulate = Color(1.0, 0.0, 0.0, 1.0)
	else:
		_projectVersionLineEdit.self_modulate = Color(1.0, 1.0, 1.0, 1.0)

func ValidateExportFilePathText():
	var text = _exportFileNameLineEdit.text
	if !ValidateFileNameText(text):
		_exportFileNameLineEdit.self_modulate = Color(1.0, 0.0, 0.0, 1.0)
	else:
		_exportFileNameLineEdit.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
			
func ValidateFileNameText(text):
	var validCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
	for t in text:
		var a = validCharacters.find(t)
		if a == -1:
			return false
	return true
	
func GetExportType():
	var exportType = _exportTypeOptionButton.text.to_lower()
	if exportType == "debug":
		return "debug"
	elif exportType == "pack":
		return "pack"
	elif exportType == "release":
		return "release"
	else:
		OS.alert("invalid export type")
		return "invalid"

func GetExtensionType(presetFullName):
	if presetFullName == "Windows Desktop":
		#if _packageTypeOptionButton.text == "No Zip":
		return ".exe"
		#else:
		#	return ".zip"
	elif presetFullName == "Linux/X11":
		return ".x86_64"
	elif presetFullName == "Web":
		return ".html"
	else:
		OS.alert("Invalid preset type!")
		return "invalid"

# Uppercase
# Windows, Linux, Web
func ExportPreset(presetFullName):
	var exportType = GetExportType()
	var extensionType = GetExtensionType(presetFullName)
	
	if exportType == "invalid" || extensionType == "invalid":
		return

	var exportOption = "--export-" + exportType

	var releaseProfileName = GetItchReleaseProfileName(presetFullName)
	var versionPath = GetGroomedVersionPath()
	var exportPath = GetFormattedExportPath() + versionPath + "\\" + releaseProfileName + "\\" + exportType

	if !DirAccess.dir_exists_absolute(exportPath):
		DirAccess.make_dir_recursive_absolute(exportPath)

	var output = []
	
	var args = ['--headless', '--path',  _projectPathLineEdit.text, exportOption, presetFullName, exportPath + "\\" + _exportFileNameLineEdit.text + extensionType]
	var readStdeer = true
	var openConsole = false
	OS.execute(_godotPathLineEdit.text, args, output, readStdeer, openConsole) 

	var groomedOutput = str(output).replace("\\r\\n", "\n")
	if _useSha256CheckBox.button_pressed:
		# Create a checksum of the core binary (.exe, .x86_64)
		var checksum = CreateChecksum(exportPath + "\\" + _exportFileNameLineEdit.text + extensionType)
		groomedOutput += "\n"
		groomedOutput += presetFullName + " checksum: " + checksum
		
	call_deferred("CreateOutputTab", groomedOutput, presetFullName)

func CreateOutputTab(outputAsStr, presetFullName = ""):
	var outputTextEdit = TextEdit.new()
	outputTextEdit.name = presetFullName
	_outputTabContainer.add_child(outputTextEdit)
	outputTextEdit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outputTextEdit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outputTextEdit.text = outputAsStr
	
func GetItchReleaseProfileName(presetFullName):
	var itchPublishType = ""
	if presetFullName == "Linux/X11":
		itchPublishType = "linux"
	elif presetFullName == "Windows Desktop":
		itchPublishType = "windows"
	elif presetFullName == "Web":
		itchPublishType = "html5"
	return itchPublishType
	
func ExportProject():
	ClearOutput()
	StartBusyBackground("Exporting...")
	var thread = Thread.new()
	thread.start(ExportProjectThread)
	
	# Call directly to debug 
	# Note: The busy screen doesn't work as expected outside thread.
	# ExportProjectThread()

# Can't debug in threaded operations. Call
# directly to debug
func ExportProjectThread():
	if !FormValidationCheckIsSuccess():
		OS.alert("Invalid export configuration")
		return
	
	if _packageTypeOptionButton.text == "Zip":
		ExportWithZip()
	elif _packageTypeOptionButton.text == "Zip + Clean":
		ExportWithZipWithCleanup()
	elif _packageTypeOptionButton.text == "No Zip":
		ExportWithoutZip()

	# Deferring to make sure the _outputTabs/content get added before counting
	call_deferred("CompleteExport")

func CompleteExport():
	CountErrors()
	CountWarnings()
	ClearBusyBackground()
	if _isDirty:
		_isClosingReleaseManager = false
		ShowSaveChangesDialog()
	
func StartBusyBackground(busyDoingWhat):
	_busyBackground = load("res://scenes/busy-background-blocker/busy_background_blocker_color_rect.tscn").instantiate()
	add_child(_busyBackground)
	_busyBackground.SetBusyDoingWhatLabel(busyDoingWhat)
	
func ClearBusyBackground():
	_busyBackground.queue_free()
	
func ExportWithoutZip():
	if _windowsCheckBox.button_pressed:
		var presetFullName = "Windows Desktop"
		var listOfExistingFilesToLeaveAlone = GetExistingFiles(presetFullName)
		listOfExistingFilesToLeaveAlone.append(_exportFileNameLineEdit.text + ".zip")
		ExportPreset(presetFullName)

	if _linuxCheckBox.button_pressed:
		var presetFullName = "Linux/X11"
		var listOfExistingFilesToLeaveAlone = GetExistingFiles(presetFullName)
		listOfExistingFilesToLeaveAlone.append(_exportFileNameLineEdit.text + ".zip")
		ExportPreset(presetFullName)

	if _webCheckBox.button_pressed:
		var presetFullName = "Web"
		var listOfExistingFilesToLeaveAlone = GetExistingFiles(presetFullName)
		listOfExistingFilesToLeaveAlone.append(_exportFileNameLineEdit.text + ".zip")
		ExportPreset(presetFullName)
		RenameHomePageToIndex(presetFullName)

func ExportWithZipWithCleanup():
	ExportWithZip(true)
	
func ExportWithZip(isCleaningUp = false):
	if _windowsCheckBox.button_pressed:
		_busyBackground.SetBusyDoingWhatLabel("Exporting for Windows...")
		var presetFullName = "Windows Desktop"
		var listOfExistingFilesToLeaveAlone = GetExistingFiles(presetFullName)
		
		listOfExistingFilesToLeaveAlone.append(GetItchReleaseProfileName(presetFullName) + "-" + _projectVersionLineEdit.text + "-" + _exportFileNameLineEdit.text + ".zip")
		ExportPreset(presetFullName)
		var fileToIgnore = ZipFiles(presetFullName)
		listOfExistingFilesToLeaveAlone.append(fileToIgnore)
		if isCleaningUp:
			_busyBackground.SetBusyDoingWhatLabel("Cleaning " + presetFullName + "...")
			Cleanup(presetFullName, listOfExistingFilesToLeaveAlone)
			
	if _linuxCheckBox.button_pressed:
		_busyBackground.SetBusyDoingWhatLabel("Exporting for Linux...")
		var presetFullName = "Linux/X11"
		var listOfExistingFilesToLeaveAlone = GetExistingFiles(presetFullName)
		listOfExistingFilesToLeaveAlone.append(_exportFileNameLineEdit.text + ".zip")
		ExportPreset(presetFullName)
		var fileToIgnore = ZipFiles(presetFullName)
		listOfExistingFilesToLeaveAlone.append(fileToIgnore)
		if isCleaningUp:
			_busyBackground.SetBusyDoingWhatLabel("Cleaning " + presetFullName + "...")
			Cleanup(presetFullName, listOfExistingFilesToLeaveAlone)

	if _webCheckBox.button_pressed:
		_busyBackground.SetBusyDoingWhatLabel("Exporting for Web...")
		var presetFullName = "Web"
		var listOfExistingFilesToLeaveAlone = GetExistingFiles(presetFullName)
		ExportPreset(presetFullName)
		RenameHomePageToIndex(presetFullName)
		var fileToIgnore = ZipFiles(presetFullName)
		listOfExistingFilesToLeaveAlone.append(fileToIgnore)
		if isCleaningUp:
			Cleanup(presetFullName, listOfExistingFilesToLeaveAlone)

# Get any existing files in the export path to ignore
func GetExistingFiles(presetFullName):
	var releaseProfileName = GetItchReleaseProfileName(presetFullName)
	var versionPath = GetGroomedVersionPath()
	var exportPath = _exportPathLineEdit.text.replace("/", "\\") + versionPath + "\\" + releaseProfileName + "\\" + _exportTypeOptionButton.text
	return Files.GetFilesFromPath(exportPath)

func Cleanup(presetFullName, listOfExistingFilesToLeaveAlone):
	var releaseProfileName = GetItchReleaseProfileName(presetFullName)
	var groomedExportPath = _exportPathLineEdit.text.replace("/", "\\")
	var versionPath = GetGroomedVersionPath()
	var exportPath = groomedExportPath + versionPath + "\\" + releaseProfileName + "\\" + _exportTypeOptionButton.text
	var isSendingToRecyle = true
	var listOfErrors = Files.DeleteAllFilesAndFolders(exportPath, isSendingToRecyle, listOfExistingFilesToLeaveAlone)
	var errors = ""
	for error in listOfErrors:
		errors += error + "\n"
	
	if errors != "":
		OS.alert(errors)
	
func RenameHomePageToIndex(presetFullName):
	var releaseProfileName = GetItchReleaseProfileName(presetFullName)
	var versionPath = GetGroomedVersionPath()
	var exportPath = _exportPathLineEdit.text + versionPath + "\\" + releaseProfileName + "\\" + _exportTypeOptionButton.text
	DirAccess.rename_absolute(exportPath + "\\" + _exportFileNameLineEdit.text + ".html", exportPath + "\\" + "index.html")

func ValidateChecksum(filePath, checksum):
	return CreateChecksum(filePath) == checksum
	
func CreateChecksum(filePath):
	const CHUNK_SIZE = 1024
	if not FileAccess.file_exists(filePath):
		return

	# Start a SHA-256 context.
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)

	# Open the file to hash.
	var file = FileAccess.open(filePath, FileAccess.READ)

	# Update the context after reading each chunk.
	while not file.eof_reached():
		var buffer = file.get_buffer(CHUNK_SIZE)
		if buffer.size() > 0:
			ctx.update(buffer)

	# Get the computed hash.
	var res = ctx.finish()

	return res.hex_encode()

func ZipFiles(presetFullName):
	_busyBackground.SetBusyDoingWhatLabel("Zipping for " + presetFullName + "...")
	var releaseProfileName = GetItchReleaseProfileName(presetFullName)
	var versionPath = GetGroomedVersionPath()
	var exportPath = _exportPathLineEdit.text + versionPath + "\\" + releaseProfileName + "\\" + _exportTypeOptionButton.text
	var listOfFileNames = Files.GetFilesFromPath(exportPath)
	var listOfFilePaths = []
	for fileName in listOfFileNames:
		listOfFilePaths.append(exportPath + "\\" + fileName)
	
	var zipFileName = ""
	if _autoGenerateExportFileNamesCheckBox.button_pressed:
		zipFileName = _exportFileNameLineEdit.text + "-" + _projectVersionLineEdit.text + "-" + releaseProfileName + ".zip" 
	else:
		zipFileName = _exportFileNameLineEdit.text + ".zip"
		
	CreateZipFile(exportPath + "\\" + zipFileName, listOfFileNames, listOfFilePaths)
	return zipFileName
	
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
	var output = ""
	for child in _outputTabContainer.get_children():
		output += child.text
		
	var errorCount = output.count("ERROR")
	_errorCountLabel.text = str(errorCount)
	if errorCount == 0:
		_errorCountLabel.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		_errorCountLabel.self_modulate = Color(1.0, 0.0, 0.0, 1.0)

func CountWarnings():
	var output = ""
	for child in _outputTabContainer.get_children():
		output += child.text
		
	var warningCount = output.count("WARNING")
	_warningCountLabel.text = str(warningCount)
	if warningCount == 0:
		_warningCountLabel.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		_warningCountLabel.self_modulate = Color(1.0, 1.0, 0.0, 1.0)

func GetExportPath(presetType):
	var exportPath = _exportPathLineEdit.text.replace("/", "\\")
	var versionPath = GetGroomedVersionPath()
	if presetType == "Windows Desktop":
		exportPath += versionPath + "\\" + GetItchReleaseProfileName(presetType) + "\\" + _exportTypeOptionButton.text + "\\" + _exportFileNameLineEdit.text + ".zip"
	elif presetType == "Linux/X11":
		exportPath += versionPath + "\\" + GetItchReleaseProfileName(presetType) + "\\" + _exportTypeOptionButton.text + "\\" + _exportFileNameLineEdit.text + ".pck"
	elif presetType == "Web":
		exportPath += versionPath + "\\" + GetItchReleaseProfileName(presetType) + "\\" + _exportTypeOptionButton.text + "\\" + _exportFileNameLineEdit.text

	return exportPath.to_lower()

func FormValidationCheckIsSuccess():
	if _exportPathLineEdit.text.to_lower().trim_prefix(" ").trim_suffix(" ") == "":
		return false
			
	if _exportTypeOptionButton.text == "":
		return false
		
	if _packageTypeOptionButton.text == "":
		return false
	
	return true
	
func GetExportPreview():
	if !FormValidationCheckIsSuccess():
		return ""
	
	var exportPreview = ""	
	if _windowsCheckBox.button_pressed:
		exportPreview += AddPreviewLine("windows")
		
	if _linuxCheckBox.button_pressed:
		exportPreview += AddPreviewLine("linux")
	
	if _webCheckBox.button_pressed:
		exportPreview += AddPreviewLine("web")

	return exportPreview

func AddPreviewLine(presetType):
	var versionPath = GetGroomedVersionPath()
	var zipFileName = ""
	if _autoGenerateExportFileNamesCheckBox.button_pressed:
		zipFileName = _exportFileNameLineEdit.text + "-" + _projectVersionLineEdit.text + "-" + presetType
	else:
		zipFileName = _exportFileNameLineEdit.text
	
	var packageType = _packageTypeOptionButton.text.to_lower()
	if packageType == "zip" || packageType == "zip + clean":
		packageType = ".zip"
	else:
		packageType = ""
		
	return GetFormattedExportPath() + versionPath + "\\" + presetType + "\\" + _exportTypeOptionButton.text.to_lower() + "\\" + zipFileName + packageType + "\n"
		
func GetFormattedExportPath():
	return _exportPathLineEdit.text.trim_prefix(" ").trim_suffix(" ").to_lower().replace("/", "\\")

#func GetButlerPreview(presetType):
#	var butlerPreview = ""
#	var versionPath = GetGroomedVersionPath()
#	if _windowsCheckBox.button_pressed:
#		butlerPreview += _exportPathLineEdit.text + versionPath + "\\" + presetType + "\\" + _exportTypeOptionButton.text + "\\" + _exportFileNameLineEdit.text + _packageTypeOptionButton.text + "\n"
#	if _linuxCheckBox.button_pressed:
#		butlerPreview += _exportPathLineEdit.text + versionPath + "\\" + presetType + "\\" + _exportTypeOptionButton.text + "\\" + _exportFileNameLineEdit.text + _packageTypeOptionButton.text + "\n"
#	if _webCheckBox.button_pressed:
#		butlerPreview += _exportPathLineEdit.text + versionPath + "\\" + presetType + "\\" + _exportTypeOptionButton.text + "\\" + _exportFileNameLineEdit.text + _packageTypeOptionButton.text
#
#	return butlerPreview
	
func GetButlerPreview():
	if !FormValidationCheckIsSuccess():
		return ""

	if _packageTypeOptionButton.text == "No Zip":
		_butlerPreviewTextEdit.text = ""
		return ""

	var versionPath = GetGroomedVersionPath()
	var butlerPreview = ""
	if _windowsCheckBox.button_pressed:
		butlerPreview += "butler push " + GetFormattedExportPath() + versionPath + "\\" + "windows" + "\\" + _exportTypeOptionButton.text.to_lower() + "\\" + _exportFileNameLineEdit.text.to_lower() + ".zip " + _itchProfileNameLineEdit.text.to_lower() + "/" + _itchProjectNameLineEdit.text.to_lower() + ":windows" + "\n"
	if _linuxCheckBox.button_pressed:
		butlerPreview += "butler push " + GetFormattedExportPath() + versionPath + "\\" + "linux" + "\\" + _exportTypeOptionButton.text.to_lower() + "\\" + _exportFileNameLineEdit.text.to_lower() + ".zip " + _itchProfileNameLineEdit.text.to_lower() + "/" + _itchProjectNameLineEdit.text.to_lower() + ":linux" + "\n"
	if _webCheckBox.button_pressed:
		butlerPreview += "butler push " + GetFormattedExportPath() + versionPath + "\\" + "html5" + "\\" + _exportTypeOptionButton.text.to_lower() + "\\" + _exportFileNameLineEdit.text.to_lower() + ".zip " + _itchProfileNameLineEdit.text.to_lower() + "/" + _itchProjectNameLineEdit.text.to_lower() + ":html5"

	return butlerPreview

func GetButlerPushCommand(presetName):
	var versionPath = GetGroomedVersionPath()
	if !FormValidationCheckIsSuccess():
		return []
	elif _packageTypeOptionButton.text == "No Zip":
		_butlerPreviewTextEdit.text = ""
	elif presetName == "windows":
		return ["push", GetFormattedExportPath() + versionPath + "\\" + "windows" + "\\" + _exportTypeOptionButton.text.to_lower() + "\\" + _exportFileNameLineEdit.text.to_lower() + ".zip", _itchProfileNameLineEdit.text.to_lower() + "/" + _exportFileNameLineEdit.text.to_lower() + ":windows"]
	elif presetName == "linux":
		return ["push", GetFormattedExportPath() + versionPath + "\\" + "linux" + "\\" + _exportTypeOptionButton.text.to_lower() + "\\" + _exportFileNameLineEdit.text.to_lower() + ".zip", _itchProfileNameLineEdit.text.to_lower() + "/" + _exportFileNameLineEdit.text.to_lower() + ":linux"]
	elif presetName == "web":
		return ["push", GetFormattedExportPath() + versionPath + "\\" + "html5" + "\\" + _exportTypeOptionButton.text.to_lower() + "\\" + _exportFileNameLineEdit.text.to_lower() + ".zip", _itchProfileNameLineEdit.text.to_lower() + "/" + _exportFileNameLineEdit.text.to_lower() + ":html5"]

	return []
	
# Example: butler push ...\godot-valet\exports\v0.0.1\godot-valet.zip poplava/godot-valet:windows
func GetButlerArguments(publishType):
	#waiting for refactors
	pass
	var butlerArguments = []
	butlerArguments.append("push")

	# Build Path: ...\godot-valet\exports\v0.0.1\godot-valet.zip
	# Surround with \" in case path has spaces
	var buildPath = "\""
	buildPath += GetButlerPushCommand(publishType)
	buildPath += "\\"
	buildPath += publishType
	buildPath += "\\"
	buildPath += _exportTypeOptionButton.text
	buildPath += "\\"
	buildPath += _itchProjectNameLineEdit.text
	buildPath += ".zip"
	buildPath += "\""
	butlerArguments.append(buildPath)

	# Build Itch Config: poplava/godot-valet:windows
	var itchPublishInfo = ""
	itchPublishInfo += _itchProfileNameLineEdit.text
	itchPublishInfo += "/"
	itchPublishInfo += _exportFileNameLineEdit.text
	itchPublishInfo += ":"
	itchPublishInfo += publishType
	butlerArguments.append(itchPublishInfo)

	return butlerArguments

# butler push godot-valet.zip poplava/godot-valet:windows
func PublishToItchUsingButler():
	ClearOutput()
	
	if !FormValidationCheckIsSuccess():
		OS.alert("Invalid publish configuration")
		return
		
	if _windowsCheckBox.button_pressed:
		var output = []
		var butlerCommand = GetButlerPushCommand("windows")
		var exitCode = OS.execute("butler", butlerCommand, output, true)
		LogButlerResults(exitCode, output, "Butler Windows")
		
	if _linuxCheckBox.button_pressed:
		var output = []
		var butlerCommand = GetButlerPushCommand("linux")
		var exitCode = OS.execute("butler", butlerCommand, output, true)
		LogButlerResults(exitCode, output, "Butler Linux")
	
	if _webCheckBox.button_pressed:
		var output = []
		var butlerCommand = GetButlerPushCommand("web")
		var exitCode = OS.execute("butler", butlerCommand, output, true)
		LogButlerResults(exitCode, output, "Butler Html5")

func LogButlerResults(exitCode, output, tabName):
	var results = []
	results.append("------------------ Butler ------------------")
	results.append("Exit code: " + str(exitCode))
	
	var butlerOutput = ""
	
	# If we received expected output, clean it up.
	# Otherwise, leave it as-is
	if exitCode == 0:
		var regex = RegEx.new()
		regex.compile("For channel `(.+?)`: last build is (\\d+),|Pushing (.+?) MiB|Re-used (.+?)% of old, added (.+?) KiB fresh data|(\\d+\\.\\d+ KiB) patch \\((.+)% savings\\)|Build is now processing, should be up in a bit\\.|Use the `(.+?)` for more information\\.|ERROR: (.+)")

		for line in output:
			butlerOutput += line + "\n"
			
		for result in regex.search_all(butlerOutput):
			results.push_back(result.get_string())
		
		butlerOutput = ""
		
		for result in results:
			butlerOutput += result + "\n"
	else:
		# Build failure output
		for result in output:
			butlerOutput += result + "\n"

	butlerOutput = butlerOutput.replace("\\r\\n", "\n")
	call_deferred("CreateOutputTab", butlerOutput, tabName)
	
	if _isDirty:
		_isClosingReleaseManager = false
		ShowSaveChangesDialog()

func GetGroomedVersionPath():
	if _projectVersionLineEdit.text == "":
		return ""
	else:
		return "\\" + _projectVersionLineEdit.text
		
func OpenRootExportPath():
	var versionPath = GetGroomedVersionPath()
	var rootExportPath = _exportPathLineEdit.text + versionPath
	var err = OS.shell_open(rootExportPath)
	if err == 7:
		OS.alert("Unable to open export folder. Did you export yet?")

func ShowSelectExportPathDialog():
	$SelectFolderFileDialog.show()
	
func OpenProjectPathFolder():
	var err = OS.shell_open(_projectNameLineEdit.text)
	if err == 7:
		OS.alert("Unable to open project folder. Did it get moved or renamed?")
		
func ClearOutput():
	for child in _outputTabContainer.get_children():
		child.queue_free()

func DisplayOutput(output):
	var groomedOutput = str(output).replace("\\r\\n", "\n")
	call_deferred("SetOutputText", groomedOutput)
#
#func RunProjectWithConsoleThread():
#	var output = []
#	var godotArguments = ["/C", _godotPathLineEdit.text,  "--path", _exportPathLineEdit.text]
#	OS.execute("CMD.exe", godotArguments, output, true, true)
#	DisplayOutput(output)
	
	#_outputTextEdit.text += "Output: " + str(output).replace("\\r\\n", "\n")
	
#func EditProjectInEditorWithConsoleThread():
#	var output = []
#	var godotArguments = ["/C", _godotPathLineEdit.text, "--editor", "--verbose", "--debug", "--path", _exportPathLineEdit.text]
#	OS.execute("CMD.exe", godotArguments, output, true, true)
#	DisplayOutput(output)


	
#func RunProjectWithConsole():
#	var projectFile = Files.FindFirstFileWithExtension(GetFormattedProjectPath(), ".godot")
#	if projectFile == null || !FileAccess.file_exists(projectFile):
#		OS.alert("Did not find a project (.godot) file in the specified project path")
#		return
#
#	ClearOutput()
#	var thread = Thread.new()
#	thread.start(RunProjectWithConsoleThread)
#
#func EditProjectWithConsole():
#	var projectFile = Files.FindFirstFileWithExtension(GetFormattedProjectPath(), ".godot")
#	if projectFile == null || !FileAccess.file_exists(projectFile):
#		OS.alert("Did not find a project (.godot) file in the specified project path")
#		return
#
#	ClearOutput()
#	var thread = Thread.new()
#	thread.start(EditProjectInEditorWithConsoleThread)

#func EditProject():
#	var projectFile = Files.FindFirstFileWithExtension(GetFormattedProjectPath(), ".godot")
#	if projectFile == null || !FileAccess.file_exists(projectFile):
#		OS.alert("Did not find a project (.godot) file in the specified project path")
#		return
#
#	ClearOutput()
#	var thread = Thread.new()
#	thread.start(EditProjectInGodotEditorThread)
	


#func OpenGodotProjectManager():
#	ClearOutput()
#	var thread = Thread.new()
#	thread.start(RunGodotProjectManagerThread)

func ShowSaveChangesDialog():
	_saveChangesConfirmationDialog.show()

func GetUniqueFileName(a):
#	var zipFileName = _exportFileNameLineEdit.text + "-" + _projectVersionLineEdit.text + "-" + releaseProfileName + ".zip" 
#
#	if _autoGenerateExportFileNamesCheckBox.button_pressed:
#
#	return _exportFileNameLineEdit.text
	pass
	
	
func _on_export_button_pressed():
	ExportProject()

func _on_open_project_folder_button_pressed():
	OpenProjectPathFolder()

func _on_preview_butler_command_button_pressed():
	GenerateButlerPreview()

func _on_preview_export_path_button_pressed():
	GenerateExportPreview()

func _on_open_export_path_folder_button_pressed():
	OpenRootExportPath()

func _on_project_path_line_edit_text_changed(_new_text):
	_isDirty = true
	GenerateExportPreview()
	GenerateButlerPreview()

func _on_project_version_line_edit_text_changed(_new_text):
	_isDirty = true
	GenerateExportPreview()
	GenerateButlerPreview()
	ValidateProjectVersionText()

func _on_windows_check_box_pressed():
	_isDirty = true
	GenerateExportPreview()
	GenerateButlerPreview()

func _on_linux_check_box_pressed():
	_isDirty = true
	GenerateExportPreview()
	GenerateButlerPreview()

func _on_web_check_box_pressed():
	_isDirty = true
	GenerateExportPreview()
	GenerateButlerPreview()

func _on_export_type_option_button_item_selected(_index):
	_isDirty = true
	GenerateExportPreview()
	GenerateButlerPreview()

func _on_package_type_option_button_item_selected(_index):
	_isDirty = true
	GenerateExportPreview()
	GenerateButlerPreview()

func _on_itch_name_line_edit_text_changed(_new_text):
	_isDirty = true
	GenerateExportPreview()
	GenerateButlerPreview()

func _on_select_folder_file_dialog_dir_selected(dir):
	_exportPathLineEdit.text = dir
	GenerateExportPreview()
	GenerateButlerPreview()

func _on_save_button_pressed():	
	SaveSettings()
	_isDirty = false

func _on_open_project_path_button_pressed():
	OpenProjectPathFolder()

func _on_export_project_pressed():
	ExportProject()

func _on_open_project_folder_pressed():
	OpenRootExportPath()

func _on_itch_project_name_line_edit_text_changed(_new_text):
	GenerateExportPreview()
	GenerateButlerPreview()
	_isDirty = true

func _on_select_export_path_button_pressed():
	ShowSelectExportPathDialog()

func _on_close_button_pressed():
	if _isDirty:
		_isClosingReleaseManager = true
		ShowSaveChangesDialog()
	else:
		queue_free()

func _on_save_changes_confirmation_dialog_confirmed():
	SaveSettings()
	if _isClosingReleaseManager:
		queue_free()

func _on_save_changes_confirmation_dialog_canceled():
	if _isClosingReleaseManager:
		queue_free()

func _on_publish_button_pressed():
	PublishToItchUsingButler()

func _on_export_file_name_line_edit_text_changed(_new_text):
	GenerateExportPreview()
	GenerateButlerPreview()
	ValidateExportFilePathText()
	_isDirty = true

func _on_export_path_line_edit_text_changed(_new_text):
	GenerateExportPreview()
	GenerateButlerPreview()
	ValidateExportFilePathText()
	_isDirty = true


func _on_auto_generate_export_file_names_check_box_pressed():
	GenerateExportPreview()
	GenerateButlerPreview()
	ValidateExportFilePathText()
	_isDirty = true
