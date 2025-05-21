extends Panel
@onready var _projectNameLineEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ProjectNameHBoxContainer/ProjectNameLineEdit
@onready var _exportPathLineEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ExportPathHBoxContainer2/ExportPathLineEdit
@onready var _godotPathLineEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/GodotPathHBoxContainer/ExportPathLineEdit
@onready var _projectVersionLineEdit = %ProjectVersionLineEdit
@onready var _windowsCheckBox = %WindowsCheckBox
@onready var _linuxCheckBox = %LinuxCheckBox
@onready var _webCheckBox = %WebCheckBox
@onready var _macOsCheckBox = %MacOsCheckBox
@onready var _sourceCheckBox = %SourceCheckBox
@onready var _exportTypeOptionButton = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ExportTypeHBoxContainer/ExportTypeOptionButton
@onready var _exportPreviewTextEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ExportPathHBoxContainer/ExportPreviewTextEdit
@onready var _itchProfileNameLineEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ItchProfileNameHBoxContainer/ItchProfileNameLineEdit
@onready var _itchProjectNameLineEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ItchProjectNameHBoxContainer/ItchProjectNameLineEdit
@onready var _errorCountLabel = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ErrorCountVBoxContainer/HBoxContainer/ErrorCountLabel
@onready var _warningCountLabel = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ErrorCountVBoxContainer/HBoxContainer/MarginContainer/HBoxContainer/WarningsCountLabel
@onready var _packageTypeOptionButton = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/PackageTypeHBoxContainer/PackageTypeOptionButton
@onready var _butlerPreviewTextEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ButlerCommandHBoxContainer/ButlerPreviewTextEdit
@onready var _obfuscationCheckbox = %ObfuscationCheckBox
@onready var _exportFileNameLineEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ExportFileNameHBoxContainer/ExportFileNameLineEdit
@onready var _saveChangesConfirmationDialog = $SaveChangesConfirmationDialog
@onready var _projectPathLineEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ProjectPathHBoxContainer2/ProjectPathLineEdit
@onready var _outputTabContainer = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/OutputHBoxContainer/OutputTabContainer
@onready var _useSha256CheckBox = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/Generate256HashNameHBoxContainer/UseSha256CheckBox
@onready var _autoGenerateExportFileNamesCheckBox = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ExportDetailsHBoxContainer/VBoxContainer/AutomateExportFileNameHBoxContainer/HBoxContainer/HBoxContainer/AutoGenerateExportFileNamesCheckBox

var _executeButlerCommandsThread : Thread
var _exportProjectThread : Thread
var _sourceFilters = []
var _busyBackground
var _selectedProjectItem = null
var _isDirty = false
var _isClosingReleaseManager = false
var _pathToUserTempFolder = OS.get_user_data_dir() + "/temp"
var _pathToUserTempExportFolder = _pathToUserTempFolder + "/export"
var _pathToUserTempSourceFolder = _pathToUserTempFolder + "/source"
var _defaultSupportMessage = "Please jump into the poplava discord and report the issue."
var _zipPackerWriter = null
var _hasWarnedAboutSkippableZippingError = false

func _ready():
	LoadTheme()
	LoadBackgroundColor()
	InitSignals()

func InitSignals():
	Signals.connect("SaveSourceFilterChanges", SaveSourceFilterChanges)
	Signals.connect("SelectedProjecItemUpdated", SelectedProjecItemUpdated)

# When ReleaseManager saves, it triggers a reset of all
# project items on ProjectManager page which invalidates 
# our reference to _selectedProjectItem so we rely on
# ProjectManager to give us an update when that happens.
# It's an unhealthy dependancy on ProjectManager because we're
# passing around ProjectItem node references instead of using an id
# with a DataManager class that can get us what we need.
func SelectedProjecItemUpdated(selectedProjectItem):
	_selectedProjectItem = selectedProjectItem
	
func SaveSourceFilterChanges(listOfSourceFilters):
	_sourceFilters = listOfSourceFilters
	SaveSettings()
	
# Triggered when user closes via X or some other means.
# TODO: We need to block them from closing until we get 
# a prompt/response from the user when we have outstanding changes. 
# Currently forcing saves as that is preferred over losing data.
func _notification(notificationType):
	if notificationType == NOTIFICATION_WM_CLOSE_REQUEST:
		if _isDirty:
			SaveSettings()

func HideExportPresets():
	for node in %ExportPresetCheckboxContainer.get_children():
		node.visible = false

func LoadExportPresets():
	HideExportPresets()
	var exportPresetFilePath = _projectPathLineEdit.text + "/export_presets.cfg"
	
	if !FileAccess.file_exists(exportPresetFilePath):
		OS.alert("Did not find a export_presets.cfg file in the root of your project. Exporting blocked until you add at least one export option (Windows, Web, or Linux).")
		return

	# Always visible (well, it will be if we can get the source zipping up like we want)
	%SourceCheckBox.visible = true

	var lines = FileHelper.GetLinesFromFile(exportPresetFilePath)
	var oneOptionAdded = false
	for line in lines:
		if line.begins_with("platform="):
			var exportType = line.rsplit("=")[1].replace("\"", "")
			if exportType == "Windows Desktop":
				%WindowsCheckBox.visible = true
				oneOptionAdded = true
			elif exportType == "Web":
				%WebCheckBox.visible = true
				oneOptionAdded = true
			elif exportType == "Linux/X11":
				%LinuxCheckBox.visible = true
				oneOptionAdded = true
			elif exportType == "macOS":
				# TODO: Add Mac support
				# %MacOsCheckBox.visible = true
				# oneOptionAdded = true
				pass
	
	if !oneOptionAdded:
		OS.alert("Found an export_presets.cfg but no supported options were found.");

func LoadBackgroundColor():
	var style_box = theme.get_stylebox("panel", "Panel") as StyleBoxFlat

	if style_box:
		style_box.bg_color = App.GetBackgroundColor()
	else:
		print("StyleBoxFlat not found!")

func LoadTheme():
	theme = load(App.GetThemePath())
	
func ConfigureReleaseManagementForm(selectedProjectItem):
	_selectedProjectItem = selectedProjectItem
	_projectPathLineEdit.text = selectedProjectItem.GetFormattedProjectPath()
	_projectNameLineEdit.text = selectedProjectItem.GetProjectName()
	_godotPathLineEdit.text = selectedProjectItem.GetGodotPath(selectedProjectItem.GetGodotVersionId())
	_windowsCheckBox.button_pressed = selectedProjectItem.GetWindowsChecked()
	_linuxCheckBox.button_pressed = selectedProjectItem.GetLinuxChecked()
	_webCheckBox.button_pressed = selectedProjectItem.GetWebChecked()
	_macOsCheckBox.button_pressed = selectedProjectItem.GetMacOsChecked()
	_sourceCheckBox.button_pressed = selectedProjectItem.GetSourceChecked()
	_obfuscationCheckbox.button_pressed = selectedProjectItem.GetObfuscationChecked()
	%SourceFilterTextureButton.visible = %SourceCheckBox.button_pressed
	_exportPathLineEdit.text = selectedProjectItem.GetExportPath()
	_exportFileNameLineEdit.text = selectedProjectItem.GetExportFileName()
	_projectVersionLineEdit.text = selectedProjectItem.GetProjectVersion()
	_exportTypeOptionButton.text = selectedProjectItem.GetExportType()
	_packageTypeOptionButton.text = selectedProjectItem.GetPackageType()
	_itchProjectNameLineEdit.text = selectedProjectItem.GetItchProjectName()
	_itchProfileNameLineEdit.text = selectedProjectItem.GetItchProfileName()
	_sourceFilters = selectedProjectItem.GetSourceFilters()
	%ShowTipsForErrorsCheckBox.button_pressed = selectedProjectItem.GetShowTipsForErrors()
	%LastPublishedLineEdit.text = Date.GetCurrentDateAsString(selectedProjectItem.GetPublishedDate())
	GenerateExportPreview()
	GenerateButlerPreview()
	LoadExportPresets()
	
func SaveSettings():
	_isDirty = false
	_selectedProjectItem.SetWindowsChecked(_windowsCheckBox.button_pressed)
	_selectedProjectItem.SetLinuxChecked(_linuxCheckBox.button_pressed)
	_selectedProjectItem.SetWebChecked(_webCheckBox.button_pressed)
	_selectedProjectItem.SetMacOsChecked(_macOsCheckBox.button_pressed)
	_selectedProjectItem.SetSourceChecked(_sourceCheckBox.button_pressed)
	_selectedProjectItem.SetExportPath(_exportPathLineEdit.text)
	_selectedProjectItem.SetProjectVersion(_projectVersionLineEdit.text)
	_selectedProjectItem.SetExportFileName(_exportFileNameLineEdit.text)
	_selectedProjectItem.SetItchProjectName(_itchProfileNameLineEdit.text)
	_selectedProjectItem.SetExportType(_exportTypeOptionButton.text)
	_selectedProjectItem.SetPackageType(_packageTypeOptionButton.text)
	_selectedProjectItem.SetItchProjectName(_itchProjectNameLineEdit.text)
	_selectedProjectItem.SetItchProfileName(_itchProfileNameLineEdit.text)
	_selectedProjectItem.SetShowTipsForErrors(%ShowTipsForErrorsCheckBox.button_pressed)
	_selectedProjectItem.SetSourceFilters(_sourceFilters)
	_selectedProjectItem.SetObfuscationChecked(_obfuscationCheckbox.button_pressed)
	var lastPublishedDate = %LastPublishedLineEdit.text
	var dateTimeDictionary = {}
	if lastPublishedDate != "":
		dateTimeDictionary = Date.ConvertDateStringToDictionary(lastPublishedDate)

	_selectedProjectItem.SetPublishedDate(dateTimeDictionary)
	_selectedProjectItem.SaveProjectItem()
	
func GenerateExportPreview():
	_exportPreviewTextEdit.text = GetExportPreview()

func GenerateButlerPreview():
	_butlerPreviewTextEdit.text = GetExportPreview()

func ValidateProjectVersionText():
	var text = _projectVersionLineEdit.text
	if ValidateText(text) != OK:
		_projectVersionLineEdit.self_modulate = Color(1.0, 0.0, 0.0, 1.0)
	else:
		_projectVersionLineEdit.self_modulate = Color(1.0, 1.0, 1.0, 1.0)

func ValidateUniqueVersion():
	if ValidateText(_projectVersionLineEdit.text) != OK:
		_projectVersionLineEdit.self_modulate = Color(1.0, 0.0, 0.0, 1.0)
		OS.alert("Invalid project version. Remove any special characters?")
		return -1
		
	if _projectVersionLineEdit.text == "":
		_projectVersionLineEdit.self_modulate = Color(1.0, 0.0, 0.0, 1.0)
		OS.alert("Invalid project version. Cannot be empty.")
		return -1

	if DirAccess.dir_exists_absolute(_exportPathLineEdit.text + "/" + _projectVersionLineEdit.text):
		_projectVersionLineEdit.self_modulate = Color(1.0, 0.0, 0.0, 1.0)
		%SameVersionConfirmationDialog.show()
		return -1
	
	return OK

func ValidateExportFileName():
	var exportFileName = _exportFileNameLineEdit.text
	if exportFileName.strip_edges().length() == 0:
		OS.alert("An export file name is required! Recommend using your project name with all lowercase.")
		return -1
	
	var err = ValidateText(exportFileName)
	if err != OK:
		return -1
		
	return OK
		
func ValidateExportPathText():
	var text = _exportPathLineEdit.text

	if text == null || text.strip_edges() == "" || !DirAccess.dir_exists_absolute(text):
		_exportPathLineEdit.self_modulate = Color(1.0, 0.0, 0.0, 1.0)
		OS.alert("The 'Export Path' doesn't exist. Please select an existing folder and try again.")
		return -1

	ResetExportPathColor()
	return OK

func ResetExportPathColor():
	_exportPathLineEdit.self_modulate = Color(1.0, 1.0, 1.0, 1.0)

# TODO: Considerations for linux/mac users?
func ValidateText(text):
	var validCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
	for t in text:
		var a = validCharacters.find(t)
		if a == -1:
			OS.alert("Invalid characters found in: " + text)
			return -1

	return OK
	
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
		return ".exe"
	elif presetFullName == "Linux/X11":
		return ".x86_64"
	elif presetFullName == "Web":
		return ".html"
	elif presetFullName == "macOS":
		return ".???"
	else:
		OS.alert("Invalid preset type!")
		return "invalid"
			
# Uppercase
# Windows, Linux, Web, Source
func ExportPreset(presetFullName):
	var err
	if presetFullName == "Source":
		err = FileHelper.CopyFoldersAndFilesRecursive(_pathToUserTempSourceFolder, _pathToUserTempExportFolder)
		if err != OK:
			return -1
	
		call_deferred("CreateOutputTab", "Succesfully exported source.", presetFullName)
		return OK
		
	_busyBackground.call_deferred("SetBusyBackgroundLabel", "Exporting for " + presetFullName + "...")
	var exportType = GetExportType()
	var extensionType = GetExtensionType(presetFullName)
	
	if exportType == "invalid" || extensionType == "invalid":
		return -1

	var exportOption = "--export-" + exportType.to_lower()
	var output = []
	var args = ['--headless', '--path',  _pathToUserTempSourceFolder, exportOption, presetFullName, _pathToUserTempExportFolder + "/" + _exportFileNameLineEdit.text + extensionType]
	var readStdeer = true
	var openConsole = false
	
	# Quietly export the project in the tempSource folder 
	# to the tempExport folder for the given preset.
	err = OS.execute(_godotPathLineEdit.text, args, output, readStdeer, openConsole) 

	var groomedOutput = str(output).replace("\\r\\n", "\n")
	
	if _useSha256CheckBox.button_pressed && FileAccess.file_exists(_pathToUserTempExportFolder + "/" + _exportFileNameLineEdit.text + extensionType):
		# Create a checksum of the core binary (.exe, .x86_64)
		var checksum = FileHelper.CreateChecksum(_pathToUserTempExportFolder + "/" + _exportFileNameLineEdit.text + extensionType)
		groomedOutput += "\n"
		groomedOutput += presetFullName + " checksum: " + checksum
		
	call_deferred("CreateOutputTab", groomedOutput, presetFullName)
	
	if err == -1:
		OS.alert("The export command failed. See output for more details")
		return -1
		
	return OK

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
	elif presetFullName == "macOS":
		itchPublishType = "osx"
	elif presetFullName == "Source":
		itchPublishType = "source"
	return itchPublishType

# Delete all files/folders in _pathToUserTempFolder including
# tempExports and tempSource
func PrepUserTempDirectory():
	var err = FileHelper.CreateDirectory(_pathToUserTempFolder)
	if err != OK:
		OS.alert("Failed to create: " + _pathToUserTempFolder + ". " + _defaultSupportMessage)
		return -1
	
	# Clean it up just in case something prevented cleanup
	var isSendingToRecycle = true
	var isIncludingDotFiles = true
	var filesToIgnore = []
	err = FileHelper.DeleteAllFilesAndFolders(_pathToUserTempFolder, filesToIgnore, isSendingToRecycle, isIncludingDotFiles)
	if err != OK:
		OS.alert("Failed to delete files and folders in " + _pathToUserTempFolder + ". " + _defaultSupportMessage)
		return -1
	
	# Sanity check because we expect it to be empty.
	# We don't want to end up zipping surprise files.
	if FileHelper.GetFilesFromPath(_pathToUserTempFolder).size() > 0:
		OS.alert("Export cancelled. Found one or more files in " + _pathToUserTempFolder + " which is unexpected." + _defaultSupportMessage)
		return -1

	err = FileHelper.CreateDirectory(_pathToUserTempSourceFolder)
	if err != OK:
		OS.alert("Failed to create: " + _pathToUserTempSourceFolder + ". " + _defaultSupportMessage)
		return -1
		
	err = FileHelper.CreateDirectory(_pathToUserTempExportFolder)
	if err != OK:
		OS.alert("Failed to create: " + _pathToUserTempExportFolder + ". " + _defaultSupportMessage)
		return -1
		
	return OK

func CompleteExport():
	CountErrors()
	CountWarnings()
	ClearBusyBackground()
	SearchForKnownErrorsAndInform()
	
func StartBusyBackground(busyDoingWhat):
	_busyBackground = load("res://scenes/busy-background-blocker/busy_background_blocker_color_rect.tscn").instantiate()
	add_child(_busyBackground)
	_busyBackground.call_deferred("SetBusyBackgroundLabel", busyDoingWhat)
	
func ClearBusyBackground():
	_busyBackground.queue_free()
	
func GetSelectedExportTypes():
	var listOfSelectedExportTypes = []
	if _windowsCheckBox.button_pressed:
		listOfSelectedExportTypes.append("Windows Desktop")
	if _linuxCheckBox.button_pressed:
		listOfSelectedExportTypes.append("Linux/X11")
	if _webCheckBox.button_pressed:
		listOfSelectedExportTypes.append("Web")
	if _macOsCheckBox.button_pressed:
		listOfSelectedExportTypes.append("macOS")
	if _sourceCheckBox.button_pressed:
		listOfSelectedExportTypes.append("Source")
	
	return listOfSelectedExportTypes

func StartExportingWithoutZip(listOfSelectedExportTypes):
	for exportType in listOfSelectedExportTypes:
		var err = await ExportWithoutZip(exportType)
		if err != OK:
			return err
		
		# For effect so user can see and understand workflow.
		# Otherwise, we flicker too quickly between states and
		# its confusing.
		await get_tree().create_timer(0.3).timeout

		err = CleanupTempFolder(_pathToUserTempExportFolder)
		if err != OK:
			return err
			
	return OK

func ExportWithoutZip(presetFullName):
	var err = PerformExportPrep(presetFullName)
	if err != OK:
		return -1
		
	var exportPath = CreateExportDirectory(presetFullName)
	if exportPath == "":
		return -1
	
	err = CopyTempExportToExportPath(exportPath)
	if err != OK:
		return err
	
	return OK

func CopyTempExportToExportPath(exportPath):
	var err = FileHelper.CopyFoldersAndFilesRecursive(_pathToUserTempExportFolder, exportPath)
	if err != OK:
		OS.alert("Failed to copy the temp export files to the export directory. " + _defaultSupportMessage)
		return -1
	
	return OK
	
# Copy the files to the export dirctory
func CopyExportedFilesToExportDirectory(exportPath):
	var exportedFiles = FileHelper.GetFilesFromPath(_pathToUserTempExportFolder)
	for fileName in exportedFiles:
		var err = CopyFileToExportDirectory(fileName, exportPath)
		if err != OK:
			OS.alert("Failed to copy the zip file to the export directory. " + _defaultSupportMessage)
			return -1
	
	return OK

func ExportProject():
	ClearOutputText()

	if ValidateExportFileName() != OK:
		return
		
	if ValidateExportPathText() != OK:
		return

	var versionUnique = ValidateUniqueVersion()
	if versionUnique != OK:
		return
	
	ContinueExportingProject()

func ContinueExportingProject():
	# Reset. All validations passed
	_projectVersionLineEdit.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
			
	if FormValidationCheckIsSuccess() != OK:
		return -1

	# This creates and/or clears the entire temp working directoy
	if PrepUserTempDirectory() != OK:
		return -1
	
	StartBusyBackground("Exporting...")
	
	# For effect but also to prevent our overwrite 
	# warning dialog from blocking the status
	await get_tree().create_timer(0.2).timeout
	
	if App.GetIsDebuggingWithoutThreads():
		# Note: Debugging inside a thread is painful 
		# so we disable it when we want to step through.
		# IF YOU ARE HERE TRYING TO FIGURE THIS OUT, DISABLE
		# THREADING UNTIL YOU ARE SATISIFIED WITH EVERYTHING AND
		# WANT TO SEE A SMOOTH REAL-TIME STATUS.
		ExportProjectThread()
	else:
		# Threaded so we can see the UI update during exports.
		# Made global to avoid the function exiting while the local
		# thread object was still running which would result in a warning
		# to use _exportProjectThread.wait_to_finish()
		_exportProjectThread = Thread.new()
		_exportProjectThread.start(ExportProjectThread)
	
	return OK

func ExportSourceToTempWorkingDirectory():
	var err = ExportSource()
	if err != OK:
		call_deferred("CreateOutputTab", "Error Code: " + str(err))
		return err
	
	return OK

# From here on out, we have many options which we branch
# and/or iterate on. The first branching logic is whether we're
# zipping packages or not. Either all export types get
# zipped or none of them do.
func ExportProjectThread():
	var err = ExportSourceToTempWorkingDirectory()
	if err != OK:
		return err
	
	if _obfuscationCheckbox.button_pressed:
		err = ObfuscateSource()
		if err != OK:
			return err
			
	var listOfExportTypes = GetSelectedExportTypes()
	if _packageTypeOptionButton.text == "Zip":
		err = await StartExportingWithZip(listOfExportTypes)
	elif _packageTypeOptionButton.text == "No Zip":
		err = await StartExportingWithoutZip(listOfExportTypes)

	# Deferred to make sure the data is available for display in the output tabs
	call_deferred("CompleteExport")
	
	if err != OK:
		OS.alert("An error occured while exporting. ErrorCode: " + err)
		return err
	
	err = CleanupTempFolder()
	if err != OK:
		return err
		
	# We don't actually use this return value
	return OK

# We obfuscate in the source in-place in the
# temp directory.
func ObfuscateSource():
	var err = ObfuscateHelper.ObfuscateScripts(_pathToUserTempSourceFolder, _pathToUserTempSourceFolder)
	if err != OK:
		OS.alert("Failed during obfuscation! Halting export.")
		return -1

	return OK	
	
func StartExportingWithZip(listOfSelectedExportTypes):
	for presetFullName in listOfSelectedExportTypes:
		var err = await ExportZipPackage(presetFullName)
		if err != OK:
			return err
			
		# For effect so user can see and understand workflow.
		# Otherwise, we flicker too quickly between states and
		# its confusing.
		await get_tree().create_timer(0.3).timeout

		err = CleanupTempFolder(_pathToUserTempExportFolder)
		if err != OK:
			return err
	
	return OK

func ExportSource():
	var sourcePath = _projectPathLineEdit.text
	var err = FileHelper.CopyFoldersAndFilesRecursive(sourcePath, _pathToUserTempSourceFolder, _sourceFilters)

	if err != OK:
		return -1

	return OK
	
func PerformExportPrep(presetFullName):
	var err = ExportPreset(presetFullName)
	if err != OK:
		return -1

	# Rename the .html file to index.html
	if presetFullName == "Web":
		err = RenameHomePageToIndex()
		if err != OK:
			return -1

	return OK
	
func ExportZipPackage(presetFullName):
	var err = PerformExportPrep(presetFullName)
	if err != OK:
		return -1
		
	var exportPath = CreateExportDirectory(presetFullName)
	if exportPath == "":
		return -1
		
	# Zip up the export files
	var releaseProfileName = GetItchReleaseProfileName(presetFullName)
	var zipFileName = _exportFileNameLineEdit.text
	if _autoGenerateExportFileNamesCheckBox.button_pressed:
		zipFileName += "-" + _projectVersionLineEdit.text + "-" + releaseProfileName + ".zip" 
	else:
		zipFileName += ".zip"
		
	err = ZipFiles(zipFileName, presetFullName, exportPath)
	if err != OK:
		return err
	
	return OK

func CopySourceToExportDirectory():
	var err = FileHelper.CopyFoldersAndFilesRecursive(_pathToUserTempSourceFolder, _pathToUserTempExportFolder)
	if err != OK:
		return err
	
	return OK
	
func CreateExportDirectory(presetFullName) -> String:
	var releaseProfileName = GetItchReleaseProfileName(presetFullName)
	var exportPath = _exportPathLineEdit.text + GetGroomedVersionPath() + "/" + releaseProfileName.to_lower() + "/" + _exportTypeOptionButton.text.to_lower()
	var err = CreateExportPath(exportPath)
	if err != OK:
		OS.alert("An error occured when creating the export path: " + exportPath)
		return ""
	
	return exportPath

func CopyFileToExportDirectory(fileName, exportPath):
	return DirAccess.copy_absolute(_pathToUserTempExportFolder + "/" + fileName, exportPath + "/" + fileName)

func CreateExportPath(exportPath):
	if !DirAccess.dir_exists_absolute(exportPath):
		var err = DirAccess.make_dir_recursive_absolute(exportPath)
		if err != OK:
			OS.alert("Failed to create the export directory: " + exportPath + ". " + _defaultSupportMessage)
			return -1

	return OK
			
# Get any existing files in the export path to ignore
func GetExistingFiles(presetFullName):
	var releaseProfileName = GetItchReleaseProfileName(presetFullName)
	var versionPath = GetGroomedVersionPath()
	var exportPath = _exportPathLineEdit.text + versionPath + "/" + releaseProfileName + "/" + _exportTypeOptionButton.text
	return FileHelper.GetFilesFromPath(exportPath)

func CleanupTempFolder(pathToFolder = _pathToUserTempFolder):
	_busyBackground.call_deferred("SetBusyBackgroundLabel", "Clearing Temp Export Working Directory...")
	
	var isSendingToRecyle = true
	var isIncludingDotFiles = true
	var filesToIgnore = []
	var err = FileHelper.DeleteAllFilesAndFolders(pathToFolder, filesToIgnore, isSendingToRecyle, isIncludingDotFiles)

	if err != OK:
		OS.alert("Failed to cleanup temp export files. This is unexpected and can result in problems. " + _defaultSupportMessage)
		return -1
		
	return OK
	
func RenameHomePageToIndex():
	var err = DirAccess.rename_absolute(_pathToUserTempExportFolder + "/" + _exportFileNameLineEdit.text + ".html", _pathToUserTempExportFolder + "/" + "index.html")
	if err != OK:
		OS.alert("Failed while renaming the html home page")
		return -1
	return OK

func ValidateChecksum(filePath, checksum):
	return FileHelper.CreateChecksum(filePath) == checksum

func ZipFiles(zipFileName, presetFullName, exportPath):
	_busyBackground.call_deferred("SetBusyBackgroundLabel", "Zipping for " + presetFullName + "...")
	var err = CreateZipFile(_pathToUserTempExportFolder, zipFileName, exportPath)
	if err != OK:
		return err
		
	return OK
	
func CreateZipFile(folderToZip, zipFileName, exportPath):
	#DirAccess.remove_absolute(_pathToUserTempExportFolder + "/" + zipFileName)
	_zipPackerWriter = ZIPPacker.new()
	var err = _zipPackerWriter.open(exportPath + "/" + zipFileName)
	if err != OK:
		return err
	
	_hasWarnedAboutSkippableZippingError = false
	err = RecursivelyAddContentsToExistingZipFile(folderToZip, "")
	_zipPackerWriter.close()
	
	if err != OK:
		return err
		
	return OK

func RecursivelyAddContentsToExistingZipFile(folderToZip, zipFolder = ""):
	var dir = DirAccess.open(folderToZip)
	if dir == null:
		OS.alert("Failed to open directory for zipping!: " + folderToZip + "Error Code: " + str(DirAccess.get_open_error()) + " - Search godot help for Error to see list of enum error codes.")
		return -1
		
	dir.list_dir_begin()
	var fileOrFolder = dir.get_next()
	while fileOrFolder != "":
		if fileOrFolder == "." || fileOrFolder == "..":
			fileOrFolder = dir.get_next()
			continue
				
		if dir.current_is_dir():
			var tempFolder = zipFolder + "/" + fileOrFolder
			var nextDir = folderToZip + "/" + fileOrFolder
			tempFolder = tempFolder.trim_prefix("/")
			RecursivelyAddContentsToExistingZipFile(nextDir, tempFolder)
		else:
			var slash = ""
			var modifiedPath = ""
			if zipFolder != "":
				modifiedPath = zipFolder.trim_prefix("/")
				slash = "/"

			_zipPackerWriter.start_file(modifiedPath + slash + fileOrFolder)
			_zipPackerWriter.write_file(FileAccess.get_file_as_bytes(folderToZip + "/" + fileOrFolder))
			_zipPackerWriter.close_file()

		fileOrFolder = dir.get_next()
	return OK
	
func SearchForKnownErrorsAndInform():
	if !%ShowTipsForErrorsCheckBox.button_pressed:
		return
		
	var output = ""
	for child in _outputTabContainer.get_children():
		output += child.text
	
	if output.contains("No export template found at the expected path"):
		OS.alert("Looks like you're missing export templates. Open your project in Godot, go into 'Project', 'Exports' and add any missing export templates. You may need to update them if upgrading a project.")
	
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
	var exportPath = _exportPathLineEdit.text
	var versionPath = GetGroomedVersionPath()
	if presetType == "Windows Desktop":
		exportPath += versionPath + "/" + GetItchReleaseProfileName(presetType) + "/" + _exportTypeOptionButton.text + "/" + _exportFileNameLineEdit.text + ".zip"
	elif presetType == "Linux/X11":
		exportPath += versionPath + "/" + GetItchReleaseProfileName(presetType) + "/" + _exportTypeOptionButton.text + "/" + _exportFileNameLineEdit.text + ".pck"
	elif presetType == "Web":
		exportPath += versionPath + "/" + GetItchReleaseProfileName(presetType) + "/" + _exportTypeOptionButton.text + "/" + _exportFileNameLineEdit.text
	if presetType == "macOS":
		exportPath += versionPath + "/" + GetItchReleaseProfileName(presetType) + "/" + _exportTypeOptionButton.text + "/" + _exportFileNameLineEdit.text + ".zip"
		
	return exportPath.to_lower()

func ValidateExportPresetSelections():
	if !_windowsCheckBox.button_pressed && !_linuxCheckBox.button_pressed && !_webCheckBox.button_pressed && !_macOsCheckBox.button_pressed && !_sourceCheckBox.button_pressed: 
		OS.alert("One or more 'Export Presets' must be selected")
		return -1
	
	return OK
	
func FormValidationCheckIsSuccess():
	if ValidateText(_exportFileNameLineEdit.text) != OK:
		return -1
		
	if ValidateExportPresetSelections() != OK:
		return -1
		
	if _exportPathLineEdit.text.to_lower().trim_prefix(" ").trim_suffix(" ") == "":
		OS.alert("Found invalid characters in export path")
		return -1
		
	if _exportTypeOptionButton.text == "":
		OS.alert("Invalid export type selected")
		return -1
		
	if _packageTypeOptionButton.text == "":
		OS.alert("Invalid package type selected")
		return -1
	
	return OK
	
func GetExportPreview():
	var exportPreview = ""	
	if _windowsCheckBox.button_pressed:
		exportPreview += AddPreviewLine("windows")
		
	if _linuxCheckBox.button_pressed:
		exportPreview += AddPreviewLine("linux")
	
	if _webCheckBox.button_pressed:
		exportPreview += AddPreviewLine("html5")

	if _macOsCheckBox.button_pressed:
		exportPreview += AddPreviewLine("mac")

	if _sourceCheckBox.button_pressed:
		exportPreview += AddPreviewLine("source")
		
	return exportPreview

func AddPreviewLine(presetType):
	var versionPath = GetGroomedVersionPath()
	var zipFileName = GetZipFileName(presetType)
	var packageType = _packageTypeOptionButton.text.to_lower()
	if packageType == "zip":
		packageType = ".zip"
	else:
		packageType = ""
		
	return GetFormattedExportPath() + versionPath + "/" + presetType + "/" + _exportTypeOptionButton.text.to_lower() + "/" + zipFileName + packageType + "\n"

func GetZipFileName(presetType):
	var zipFileName = ""
	if _autoGenerateExportFileNamesCheckBox.button_pressed:
		if _projectVersionLineEdit.text == "":
			zipFileName = _exportFileNameLineEdit.text + "-" + presetType
		else:
			zipFileName = _exportFileNameLineEdit.text + "-" + _projectVersionLineEdit.text + "-" + presetType
	else:
		zipFileName = _exportFileNameLineEdit.text
	return zipFileName
	
func GetFormattedExportPath():
	return _exportPathLineEdit.text.trim_prefix(" ").trim_suffix(" ").to_lower()

func GetButlerPreview():
	if FormValidationCheckIsSuccess() == -1:
		return -1

	if _packageTypeOptionButton.text == "No Zip":
		_butlerPreviewTextEdit.text = ""
		return ""
	
	var butlerPreview = ""
	if _windowsCheckBox.button_pressed:
		butlerPreview += AddButlerPreviewLine("windows")

	if _linuxCheckBox.button_pressed:
		butlerPreview += AddButlerPreviewLine("linux")
		
	if _webCheckBox.button_pressed:
		butlerPreview += AddButlerPreviewLine("html5")

	if _macOsCheckBox.button_pressed:
		butlerPreview += AddButlerPreviewLine("mac")
		
	return butlerPreview

func AddButlerPreviewLine(presetType):
	var zipFileName = GetZipFileName(presetType)	
	var versionPath = GetGroomedVersionPath()
	return "butler push " + GetFormattedExportPath() + versionPath + "/" + presetType + "/" + _exportTypeOptionButton.text.to_lower() + "/" + zipFileName + ".zip " + _itchProfileNameLineEdit.text.to_lower() + "/" + _itchProjectNameLineEdit.text.to_lower() + ":" + presetType + "\n"
	
func GetButlerPushCommand(presetName):
	var versionPath = GetGroomedVersionPath()
	if FormValidationCheckIsSuccess() == -1:
		return -1
	
	if _packageTypeOptionButton.text == "No Zip":
		_butlerPreviewTextEdit.text = ""

	return ["push", GetFormattedExportPath() + versionPath + "/" + presetName + "/" + _exportTypeOptionButton.text.to_lower() + "/" + GetZipFileName(presetName)  + ".zip", _itchProfileNameLineEdit.text.to_lower() + "/" + _exportFileNameLineEdit.text.to_lower() + ":" + presetName]
	
# Example: butler push ...\godot-valet\exports\v0.0.1\godot-valet.zip poplava/godot-valet:windows
func GetButlerArguments(publishType):
	var butlerArguments = []
	butlerArguments.append("push")

	# Export Path Example: ...\godot-valet\exports\v0.0.1\godot-valet.zip
	# Surround with \" in case path has spaces
	var buildPath = "\""
	buildPath += GetButlerPushCommand(publishType)
	buildPath += "/"
	buildPath += publishType
	buildPath += "/"
	buildPath += _exportTypeOptionButton.text
	buildPath += "/"
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
	ClearOutputText()
	
	if FormValidationCheckIsSuccess() == -1:
		return -1
	
	StartBusyBackground("")
	
	if App.GetIsDebuggingWithoutThreads():
		# For debugging
		ExecuteButlerCommandsThread()
	else:
		# Using threaded operation so we can see UI updates
		_executeButlerCommandsThread = Thread.new()
		_executeButlerCommandsThread.start(ExecuteButlerCommandsThread)

func ExecuteButlerCommandsThread():
	if _windowsCheckBox.button_pressed:
		_busyBackground.call_deferred("SetBusyBackgroundLabel", "Publishing Windows...")
		var butlerCommand = GetButlerPushCommand("windows")
		ExecuteButlerCommand(butlerCommand, "Butler Windows")
		
	if _linuxCheckBox.button_pressed:
		var butlerCommand = GetButlerPushCommand("linux")
		_busyBackground.call_deferred("SetBusyBackgroundLabel", "Publishing Linux...")
		ExecuteButlerCommand(butlerCommand, "Butler Linux")

	if _webCheckBox.button_pressed:
		var butlerCommand = GetButlerPushCommand("html5")
		_busyBackground.call_deferred("SetBusyBackgroundLabel", "Publishing Web...")
		ExecuteButlerCommand(butlerCommand, "Butler Html5")
	
	if _macOsCheckBox.button_pressed:
		var butlerCommand = GetButlerPushCommand("osx")
		_busyBackground.call_deferred("SetBusyBackgroundLabel", "Publishing Mac...")
		ExecuteButlerCommand(butlerCommand, "Butler Mac")
	
	if _sourceCheckBox.button_pressed:
		var butlerCommand = GetButlerPushCommand("source")
		_busyBackground.call_deferred("SetBusyBackgroundLabel", "Publishing Source...")
		ExecuteButlerCommand(butlerCommand, "Butler Source")
		
	ClearBusyBackground()
	call_deferred("UpdatePublishedDate")

func UpdatePublishedDate():
	%LastPublishedLineEdit.text = Date.GetCurrentDateAsString(Date.GetCurrentDateAsDictionary())
	_isDirty = true
	
func ExecuteButlerCommand(butlerCommand, outputName):
	var output = []
	var exitCode = OS.execute("butler", butlerCommand, output, true)
	LogButlerResults(exitCode, output, outputName)
		
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

func GetGroomedVersionPath():
	if _projectVersionLineEdit.text == "":
		return ""
	else:
		return "/" + _projectVersionLineEdit.text
		
func OpenRootExportPath():
	var versionPath = GetGroomedVersionPath()
	var rootExportPath = _exportPathLineEdit.text + versionPath
	var err = OS.shell_open(rootExportPath)
	if err == 7:
		OS.alert("Unable to open export folder. Did you export yet?")

func ShowSelectExportPathDialog():
	$SelectFolderFileDialog.show()
	
func OpenProjectPathFolder():
	var projectPath = _projectPathLineEdit.text
	var err = OS.shell_open(projectPath)
	if err == 7:
		OS.alert("Unable to open project folder. Did it get moved or renamed?")
		
func ClearOutputText():
	for child in _outputTabContainer.get_children():
		child.queue_free()

func DisplayOutput(output):
	var groomedOutput = str(output).replace("\\r\\n", "\n")
	call_deferred("SetOutputText", groomedOutput)

func ShowSaveChangesDialog():
	_saveChangesConfirmationDialog.show()
	
func ShowSourceFilterDialog():
	var sourceFilterDialog = load("res://scenes/source-filter-dialog/source-filter-dialog.tscn").instantiate()
	add_child(sourceFilterDialog)
	sourceFilterDialog.AddSourceFilters(_sourceFilters)
	var viewportSize = get_viewport_rect().size
	var dialogSize = sourceFilterDialog.custom_minimum_size
	var dialogPosition = (viewportSize - dialogSize) / 2
	sourceFilterDialog.position = dialogPosition

func _on_export_button_pressed():
	ExportProject()

func _on_preview_butler_command_button_pressed():
	GenerateButlerPreview()

func _on_preview_export_path_button_pressed():
	GenerateExportPreview()

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

func _on_mac_os_check_box_pressed():
	_isDirty = true
	GenerateExportPreview()
	GenerateButlerPreview()

func _on_source_check_box_pressed() -> void:
	_isDirty = true
	GenerateExportPreview()
	GenerateButlerPreview()
	await get_tree().create_timer(0.1).timeout
	%SourceFilterTextureButton.visible = %SourceCheckBox.button_pressed
	
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
	_isDirty = true
	_exportPathLineEdit.text = dir
	ResetExportPathColor()
	GenerateExportPreview()
	GenerateButlerPreview()

func _on_save_button_pressed():	
	SaveSettings()

func _on_export_project_pressed():
	ExportProject()

func _on_itch_project_name_line_edit_text_changed(_new_text):
	_isDirty = true
	GenerateExportPreview()
	GenerateButlerPreview()

func _on_select_export_path_button_pressed():
	ShowSelectExportPathDialog()

func _on_close_button_pressed():
	if _isDirty:
		_isClosingReleaseManager = true
		ShowSaveChangesDialog()
	else:
		SaveSettings()
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
	_isDirty = true
	GenerateExportPreview()
	GenerateButlerPreview()

func _on_export_path_line_edit_text_changed(_new_text):
	_isDirty = true
	ResetExportPathColor()
	GenerateExportPreview()
	GenerateButlerPreview()

func _on_auto_generate_export_file_names_check_box_pressed():
	_isDirty = true
	GenerateExportPreview()
	GenerateButlerPreview()
	
func _on_configure_installer_button_pressed():
	var installerConfigurationDialog = load("res://scenes/installer-configuration-dialog/installer-configuration-dialog.tscn").instantiate()
	add_child(installerConfigurationDialog)

func _on_same_version_confirmation_dialog_confirmed() -> void:
	ContinueExportingProject()

func _on_source_filter_texture_button_pressed() -> void:
	ShowSourceFilterDialog()

func _on_open_export_folder_pressed() -> void:
	OpenRootExportPath()

func _on_test_button_pressed() -> void:
	ValidateExportPathText()
	var err = await ExportZipPackage(Enums.ExportType.Source)
	var inputPath = %ProjectPathLineEdit.text
	var outputPath = %ExportPathLineEdit.text
	ObfuscateHelper.ObfuscateScripts(inputPath, outputPath)
