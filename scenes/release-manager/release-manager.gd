extends Panel

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
@onready var _autoGenerateExportFileNamesCheckBox = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/ExportDetailsHBoxContainer/VBoxContainer/AutomateExportFileNameHBoxContainer/HBoxContainer/HBoxContainer/AutoGenerateExportFileNamesCheckBox
@onready var _installerConfigurationFileNameLineEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/InstallerConfigurationHBoxContainer/InstallerConfigurationLineEdit

var _busyBackground
var _selectedProjectItem = null
var _isDirty = false
var _isClosingReleaseManager = false
var _exportWithInstallerStep = 0
var _pathToUserTempFolder = OS.get_user_data_dir() + "/temp/" # temp storage.
var _defaultSupportMessage = "Please contact support for assistance."

#
# Dev Note: I was in the middle of prototyping the installer work and then 
# decided to open source the project. I may end up cleaning it out and
# then creating a separate branch for that work if the bugs/features start 
# coming in.
#

func _ready():
	InitSignals()
	LoadTheme()
	LoadBackgroundColor()

# Triggered when user closes via X or some other means.
# TODO: We need to block them from closing until we get 
# a prompt/response from the user when we have outstanding changes. 
# Currently forcing saves as that is preferred over losing data.
func _notification(notificationType):
	if notificationType == NOTIFICATION_WM_CLOSE_REQUEST:
		if _isDirty:
			SaveSettings()

func LoadBackgroundColor():
	var style_box = theme.get_stylebox("panel", "Panel") as StyleBoxFlat

	if style_box:
		style_box.bg_color = App.GetBackgroundColor()
	else:
		print("StyleBoxFlat not found!")

func LoadTheme():
	theme = load(App.GetThemePath())
	
func InitSignals():
	Signals.connect("ExportWithInstaller", ExportWithInstaller)
	Signals.connect("SaveInstallerConfiguration", SaveInstallerConfiguration)

func SaveInstallerConfiguration(installerConfigurationFileName, installerConfigurationFriendlyName):
	if installerConfigurationFriendlyName == "":
		_installerConfigurationFileNameLineEdit.text = ""
		_selectedProjectItem.SetInstallerConfigurationFileName("")
	else:
		_selectedProjectItem.SetInstallerConfigurationFileName(installerConfigurationFileName)
		_installerConfigurationFileNameLineEdit.text = installerConfigurationFriendlyName
	
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
	_isDirty = false
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
	_butlerPreviewTextEdit.text = GetExportPreview()

func ValidateProjectVersionText():
	var text = _projectVersionLineEdit.text
	if ValidateText(text) != OK:
		_projectVersionLineEdit.self_modulate = Color(1.0, 0.0, 0.0, 1.0)
	else:
		_projectVersionLineEdit.self_modulate = Color(1.0, 1.0, 1.0, 1.0)

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
	else:
		OS.alert("Invalid preset type!")
		return "invalid"

# Uppercase
# Windows, Linux, Web
func ExportPreset(presetFullName):
	_busyBackground.SetBusyDoingWhatLabel("Exporting for " + presetFullName + "...")
	var exportType = GetExportType()
	var extensionType = GetExtensionType(presetFullName)
	
	if exportType == "invalid" || extensionType == "invalid":
		return

	var exportOption = "--export-" + exportType.to_lower()
	var output = []
	var args = ['--headless', '--path',  _projectPathLineEdit.text, exportOption, presetFullName, _pathToUserTempFolder + _exportFileNameLineEdit.text + extensionType]
	var readStdeer = true
	var openConsole = false
	var err = OS.execute(_godotPathLineEdit.text, args, output, readStdeer, openConsole) 

	var groomedOutput = str(output).replace("\\r\\n", "\n")
	
	if _useSha256CheckBox.button_pressed && FileAccess.file_exists(_pathToUserTempFolder + _exportFileNameLineEdit.text + extensionType):
		# Create a checksum of the core binary (.exe, .x86_64)
		var checksum = CreateChecksum(_pathToUserTempFolder + _exportFileNameLineEdit.text + extensionType)
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
	return itchPublishType
		
func PrepUserTempDirectory():
	var err = Files.CreateDirectory(_pathToUserTempFolder)
	if err != OK:
		OS.alert("Failed to create: " + _pathToUserTempFolder + ". " + _defaultSupportMessage)
		return -1
	
	# Clean it up just in case something prevented cleanup
	err = Files.DeleteAllFilesAndFolders(_pathToUserTempFolder)
	if err != OK:
		OS.alert("Failed to delete files and folders in " + _pathToUserTempFolder + ". " + _defaultSupportMessage)
		return -1
	
	# Sanity check because we expect it to be empty.
	# We don't want to end up zipping surprise files.
	if Files.GetFilesFromPath(_pathToUserTempFolder).size() > 0:
		OS.alert("Export cancelled. Found one or more files in " + _pathToUserTempFolder + " which is unexpected. " + _defaultSupportMessage)
		return -1
	
	return OK
#
# ExportWithInstaller will be called multiple times
# In some cases, we'll be on the same step after downloading a file.
#
# Step #0 - Export project files <project>.exe and <project>.pck
# Step #1 - Export godot-ignition if it exists and is valid.
#	Otherwise, trigger download workflows which call back-in to repeat step 1 until complete
# Step #2 - Export godot-fetch if it exists and is valid.
#	Otherwise, trigger download workflows which call back-in to repeat step 2 until complete
# Step #3 - Generate secrets and configuration files
# Step #4 - Package files into final .zip
#
func ExportWithInstaller():
	# WIP
	#	if _exportWithInstallerStep == 0:
	#		# TODO: Doesn't make sense to me after refactoring export files to temp
	#		# ExportWithoutZip()
	#		_exportWithInstallerStep += 1
	#		Signals.emit_signal("ExportWithInstaller")
	#	elif _exportWithInstallerStep == 1:
	#		ExportGodotIgnition()
	#	elif _exportWithInstallerStep == 2:
	#		ExportGodotFetch()
	#		var fileName = "godot-fetch.zip"
	#		var isUnpacking = true
	#		HandleFileExportWorkflow(fileName, isUnpacking)
	#	elif _exportWithInstallerStep == 3:
	#		# At some point, we need godot-iginition to be renamed to <project>-<version>-<os>-installer.exe
	#		# rename_absolute
	#		# godot-ignition.exe, godot-ignition.pck, godot-fetch.exe, godot-fetch.pck, <project>.exe, <project.pck> are in the export dir
	#		GenerateInstallerConfigurationFiles()
	#	elif _exportWithInstallerStep == 4:
	#		PackageInstallerFiles()
	pass

func ExportGodotIgnition():
	# TODO: Load installer configuration
	# 	- extract path to <configs>/<project name>/installer-settings.cfg
	# 
	# godot-ignition.zip
	#
	# TODO: WIP
	#	var userOptionAEnabled = true
	#	var userOptionBEnabled = true
	#	var userOptionCEnabled = true
	#
	#	var windowsChecked = true
	#	var linuxChecked = true
	#	if windowsChecked:
	#		var pathToGodotIgnitionForWindows = ""
	#		if pathToGodotIgnitionForWindows != "":
	#			if FileAccess.file_exists(pathToGodotIgnitionForWindows):
	#				# TODO: Extract windows files to export directory
	#				# TODO: Create matching config and include user-options
	#				pass
	#
	#	if linuxChecked:
	#		var pathToGodotIgnitionForLinux = ""
	#		if pathToGodotIgnitionForLinux != "":
	#			if FileAccess.file_exists(pathToGodotIgnitionForLinux):
	#				# TODO: Extract linux files to export directory
	#				# TODO: Create matching config and include user-options
	#				pass
	#
	#	_exportWithInstallerStep += 1
	#	Signals.emit_signal("ExportWithInstaller")
	pass

func ExportGodotFetch():
	# TODO: Load installer configuration
	# 	- extract path to <configs>/<project name>/installer-settings.cfg
	# 
	# godot-ignition.zip
	#
	# WIP
	#	var userOptionAEnabled = true
	#	var userOptionBEnabled = true
	#	var userOptionCEnabled = true
	#
	#	var windowsChecked = true
	#	var linuxChecked = true
	#	if windowsChecked:
	#		var pathToGodotIgnitionForWindows = ""
	#		if pathToGodotIgnitionForWindows != "":
	#			if FileAccess.file_exists(pathToGodotIgnitionForWindows):
	#				# TODO: Extract windows files to export directory
	#				# TODO: Create matching config and include user-options
	#				pass
	#
	#	if linuxChecked:
	#		var pathToGodotIgnitionForLinux = ""
	#		if pathToGodotIgnitionForLinux != "":
	#			if FileAccess.file_exists(pathToGodotIgnitionForLinux):
	#				# TODO: Extract linux files to export directory
	#				# TODO: Create matching config and include user-options
	#				pass
	#
	#	_exportWithInstallerStep += 1
	#	Signals.emit_signal("ExportWithInstaller")
	pass
	
func CheckForNeededSupportFiles(checkingForSupportFileUpdatesState):
	# LEFT OFF HERE:
	# Collect a list of required support files <fileName> and os?
	if checkingForSupportFileUpdatesState == 0: # if user has godot-valet auto-update enabled?
		if HasUpdateTimeExpired():
			App.SetLastUpdateTime(Time.get_unix_time_from_system())
			CheckForSupportFileUpdates(1)
	else:
		# check if any files are missing
		# if so, prompt user to download
		# Trigger download
		pass

func CheckForSupportFileUpdates(supportFileUpdateState):
	if supportFileUpdateState == 0:
		if _windowsCheckBox.button_pressed:
			# Check for support file selections (installer and godot-fetch)
			pass
	elif supportFileUpdateState == 1:
		if _linuxCheckBox.button_pressed:
			pass
	else:
		# Done checking for support file updates
		pass
		
func HasUpdateTimeExpired():
	var currentTime = Time.get_unix_time_from_system()
	var timePasseInHours = (currentTime - App.GetLastUpdateTime()) / 3600
	if timePasseInHours >= 24:
		return true
	return false
		
func PackageInstallerFiles():
	# zip and package into single .zip file named <project><version><os>.zip
	pass
	
func GenerateInstallerConfigurationFiles():
	# Generate secret guid to pass into each
	# Generate godot-ignition.cfg
	# Generate godot-fetch.cfg
	# Generate <project>.cfg
	_exportWithInstallerStep += 1
	Signals.emit_signal("ExportWithInstaller")

func HandleFileExportWorkflow(fileName, isUnpacking = false):
	if App.GetLastAzureUpdateCheck() == true:
		pass
		
	if !FileAccess.file_exists(fileName):
		# TODO: REMEMBER: WE NEED TO DOWNLOAD OS SPECIFIC FILES
		# godot-fetch-v0.0.1.linux.zip
		BeginDownloadingMissingFileWorkflow(fileName)
	else:
		# I think we're going to download a checksum file for each project.
		# We can't bury the checksum in the config of the project because we
		# need to validate the .zip it comes in.
		if true: #expectedChecksum != GetCheckSum(fileName):
			# Inform user and prompt to download. trigger those workflows
			pass
		else:
			ExportPackedFile(fileName, isUnpacking)
			_exportWithInstallerStep += 1
			#yield() # break call chain
			Signals.emit_signal("ExportWithInstaller")
			#return

func BeginDownloadingMissingFileWorkflow(_fileName):
	# TODO: REMEMBER: WE NEED TO DOWNLOAD OS SPECIFIC FILES
	# godot-fetch-v0.0.1.linux.zip
	if App.GetAutoUpdate():
		# Trigger download
		pass
	else:
		pass
	
# App.GetGodotFetchChecksum()
func ExportPackedFile(_fileName, _expectedChecksum):
	# WIP
	#	if !FileAccess.file_exists(fileName):
	#		if true: #expectedChecksum == GetCheckSum(fileName):
	#			#UnpackIntoExportDirectory(fileName)
	#			pass
	#		else:
	#			# Inform user and prompt to download a new version
	#			pass
	#	else:
	#		# Inform user and depending on the auto-install option:
	#		# Prompt user or auto-download .zip
	#		if true: #expectedChecksum == GetCheckSum(fileName):
	#			#UnpackIntoExportDirectory(fileName)
	#			pass
	pass
			
func PackageInstaller():
	# godot-ignition.exe, godot-ignition.pck
	# <project-name>.exe, <project-name>.pck
	# godot-fetch.exe, godot-fetch.pck
	# We need all these in a .zip
	# 	- Rename the project.exe and project.pck to <project>-1.dll & <project>-2.dll
	# 	- Rename godot-ignition.exe to <project>-installer.exe
	# We need the godot-ignition binary to be the clear godot executable
	# We need the other files to be non-executable so the user accepts the license before they can use
	# godot-ignition.exe needs to know to look locally for project files before looking to the cloud (cfg)
	# godot-ignition cfg
	#    - gets relative paths for all files
	#    - gets checksums for all files
	#    - gets, creates and/or passes encryption passwords to projects
	# godot-ignition unpacks other files into working directory
	pass

func BeginGodotIgnitionDownloadWorkflows():
	if true: #auto-install enabled:
		# DownloadGodotIgnition()
		# Define callback to begin checksum valiation and call VerifyInstallerPackages(2)
		pass
	else:
		# Prompt user about missing files to download
		# Else where, define Accept callback
		# Download file
		# Elsewhere, emit_signal or call ExportWithInstaller()
		pass

func CompleteExport():
	CountErrors()
	CountWarnings()
	ClearBusyBackground()
	
func StartBusyBackground(busyDoingWhat):
	_busyBackground = load("res://scenes/busy-background-blocker/busy_background_blocker_color_rect.tscn").instantiate()
	add_child(_busyBackground)
	_busyBackground.SetBusyDoingWhatLabel(busyDoingWhat)
	
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
	
	return listOfSelectedExportTypes

func StartExportingWithoutZip(listOfSelectedExportTypes):
	for exportType in listOfSelectedExportTypes:
		var err = ExportWithoutZip(exportType)
		if err != OK:
			return -1
		
	return OK

func ExportWithoutZip(presetFullName):
	var err = CleanTempFiles(presetFullName)
	if err != OK:
		return -1

	err = ExportPreset(presetFullName)
	if err != OK:
		return -1
		
	if presetFullName == "Web":
		err = RenameHomePageToIndex()
		if err != OK:
			return -1
	
	var exportPath = CreateExportDirectory(presetFullName)
	if exportPath == "":
		return -1
	
	err = CopyExportedFilesToExportDirectory(exportPath)
	if err != OK:
		return -1

	return OK

# Copy the files to the export dirctory
func CopyExportedFilesToExportDirectory(exportPath):
	var exportedFiles = Files.GetFilesFromPath(_pathToUserTempFolder)
	for fileName in exportedFiles:
		var err = CopyFileToExportDirectory(fileName, exportPath)
		if err != OK:
			OS.alert("Failed to copy the zip file to the export directory. " + _defaultSupportMessage)
			return -1
	
	return OK

func ExportProject():
	ClearOutput()
		
	if ValidateExportPathText() != OK:
		return -1
		
	if ValidateText(_exportFileNameLineEdit.text) != OK:
		return -1
		
	if ValidateExportPresetSelections() != OK:
		return -1
		
	if FormValidationCheckIsSuccess() != OK:
		return -1
	
	if PrepUserTempDirectory() != OK:
		return -1
		
	StartBusyBackground("Exporting...")
	
	# Using threaded operation so we can see the UI update 
	# as the project gets exported
	var thread = Thread.new()
	thread.start(ExportProjectThread)
	
	# Note: Comment the thread up above and uncomment this to debug
	# Note: The busy screen doesn't work as expected outside a thread.
	# ExportProjectThread()
	
	return OK
	
func ExportProjectThread():
	var result = OK
	var listOfExportTypes = GetSelectedExportTypes()
	if _packageTypeOptionButton.text == "Zip":
		result = StartExportingWithZip(listOfExportTypes)
	elif _packageTypeOptionButton.text == "No Zip":
		result = StartExportingWithoutZip(listOfExportTypes)
	elif _packageTypeOptionButton.text == "Installer":
		_exportWithInstallerStep = 0
		result = ExportWithInstaller()

	# Deferred to make sure the data is available for display in the output tabs
	call_deferred("CompleteExport")
	return result

func StartExportingWithZip(listOfSelectedExportTypes):
	for exportType in listOfSelectedExportTypes:
		var err = ExportZipPackage(exportType)
		if err != OK:
			return -1
		
	return OK
	
func ExportZipPackage(presetFullName):
	var err = ExportPreset(presetFullName)
	if err != OK:
		return -1
	
	# Rename the .html file to index.html
	if presetFullName == "Web":
		err = RenameHomePageToIndex()
		if err != OK:
			return -1
		
	# Zip up the export files
	var zipFileName = ZipFiles(presetFullName)
	if zipFileName == "error":
		return -1
	
	var exportPath = CreateExportDirectory(presetFullName)
	if exportPath == "":
		return -1
		
	_busyBackground.SetBusyDoingWhatLabel("Copying files to export directory...")
	err = CopyFileToExportDirectory(zipFileName, exportPath)
	if err != OK:
		OS.alert("Failed to copy the zip file to the export directory. " + _defaultSupportMessage)
		return -1
		
	err = CleanTempFiles(presetFullName)
	if err != OK:
		return err
	
	return OK

func CreateExportDirectory(presetFullName):
	var releaseProfileName = GetItchReleaseProfileName(presetFullName)
	var exportPath = _exportPathLineEdit.text + GetGroomedVersionPath() + "/" + releaseProfileName.to_lower() + "/" + _exportTypeOptionButton.text.to_lower()
	var err = CreateExportPath(exportPath)
	if err != OK:
		OS.alert("An error occured when creating the export path")
		return ""
	
	return exportPath

func CopyFileToExportDirectory(fileName, exportPath):
	return DirAccess.copy_absolute(_pathToUserTempFolder + fileName, exportPath + "/" + fileName)

func CreateExportPath(exportPath):
	if !DirAccess.dir_exists_absolute(exportPath):
		var err = DirAccess.make_dir_recursive_absolute(exportPath)
		if err != OK:
			OS.alert("Failed to create the export directory: " + exportPath + ". " + _defaultSupportMessage)
			return -1
	return OK
			
func CleanTempFiles(presetFullName):
	_busyBackground.SetBusyDoingWhatLabel("Cleaning " + presetFullName + "...")
	return Cleanup()

# Get any existing files in the export path to ignore
func GetExistingFiles(presetFullName):
	var releaseProfileName = GetItchReleaseProfileName(presetFullName)
	var versionPath = GetGroomedVersionPath()
	var exportPath = _exportPathLineEdit.text + versionPath + "/" + releaseProfileName + "/" + _exportTypeOptionButton.text
	return Files.GetFilesFromPath(exportPath)

func Cleanup():
	var isSendingToRecyle = true
	var err = Files.DeleteAllFilesAndFolders(_pathToUserTempFolder, isSendingToRecyle)

	if err != OK:
		OS.alert("Failed to cleanup temp export files. This is unexpected and can result in problems. " + _defaultSupportMessage)
		return -1
		
	return OK
	
func RenameHomePageToIndex():
	var err = DirAccess.rename_absolute(_pathToUserTempFolder + "/" + _exportFileNameLineEdit.text + ".html", _pathToUserTempFolder + "/" + "index.html")
	if err != OK:
		OS.alert("Failed while renaming the html home page")
		return -1
	return OK

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
	var listOfFileNames = Files.GetFilesFromPath(_pathToUserTempFolder)
	var zipFileName = ""
	if _autoGenerateExportFileNamesCheckBox.button_pressed:
		zipFileName = _exportFileNameLineEdit.text + "-" + _projectVersionLineEdit.text + "-" + releaseProfileName + ".zip" 
	else:
		zipFileName = _exportFileNameLineEdit.text + ".zip"
		
	var err = CreateZipFile(_pathToUserTempFolder + "/" + zipFileName, listOfFileNames)
	if err != OK:
		OS.alert("Failed to create the zip file! " + _defaultSupportMessage)
		return "error"
		
	return zipFileName
	
func CreateZipFile(zipFilePath, listOfFileNames : Array):
	var writer := ZIPPacker.new()
	
	# "user://archive.zip"
	var err := writer.open(zipFilePath)
	
	if err != OK:
		return err
	
	var index = 0
	for fileName in listOfFileNames:
		writer.start_file(fileName)
		writer.write_file(FileAccess.get_file_as_bytes(_pathToUserTempFolder + listOfFileNames[index]))
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
	var exportPath = _exportPathLineEdit.text#.replace("/", "\\")
	var versionPath = GetGroomedVersionPath()
	if presetType == "Windows Desktop":
		exportPath += versionPath + "/" + GetItchReleaseProfileName(presetType) + "/" + _exportTypeOptionButton.text + "/" + _exportFileNameLineEdit.text + ".zip"
	elif presetType == "Linux/X11":
		exportPath += versionPath + "/" + GetItchReleaseProfileName(presetType) + "/" + _exportTypeOptionButton.text + "/" + _exportFileNameLineEdit.text + ".pck"
	elif presetType == "Web":
		exportPath += versionPath + "/" + GetItchReleaseProfileName(presetType) + "/" + _exportTypeOptionButton.text + "/" + _exportFileNameLineEdit.text

	return exportPath.to_lower()

func ValidateExportPresetSelections():
	if !_windowsCheckBox.button_pressed && !_linuxCheckBox.button_pressed && !_webCheckBox.button_pressed:
		OS.alert("One or more 'Export Presets' must be selected")
		return -1
	
	return OK
	
func FormValidationCheckIsSuccess():
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
	ClearOutput()
	
	if FormValidationCheckIsSuccess() == -1:
		return -1
	
	StartBusyBackground("")
	
	# Using threaded operation so we can see UI updates while things are happening
	var thread = Thread.new()
	thread.start(ExecuteButlerCommandsThread)
	
	# Comment the thread above and uncomment this line to debug
	# ExecuteButlerCommandsThread()

func ExecuteButlerCommandsThread():
	if _windowsCheckBox.button_pressed:
		_busyBackground.SetBusyDoingWhatLabel("Publishing Windows...")
		var butlerCommand = GetButlerPushCommand("windows")
		ExecuteButlerCommand(butlerCommand, "Butler Windows")
		
	if _linuxCheckBox.button_pressed:
		var butlerCommand = GetButlerPushCommand("linux")
		_busyBackground.SetBusyDoingWhatLabel("Publishing Linux...")
		ExecuteButlerCommand(butlerCommand, "Butler Linux")

	if _webCheckBox.button_pressed:
		var butlerCommand = GetButlerPushCommand("html5")
		_busyBackground.SetBusyDoingWhatLabel("Publishing Web...")
		ExecuteButlerCommand(butlerCommand, "Butler Html5")
	
	ClearBusyBackground()
	
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
	var err = OS.shell_open(_projectNameLineEdit.text)
	if err == 7:
		OS.alert("Unable to open project folder. Did it get moved or renamed?")
		
func ClearOutput():
	for child in _outputTabContainer.get_children():
		child.queue_free()

func DisplayOutput(output):
	var groomedOutput = str(output).replace("\\r\\n", "\n")
	call_deferred("SetOutputText", groomedOutput)

func ShowSaveChangesDialog():
	_saveChangesConfirmationDialog.show()

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
	_isDirty = true
	_exportPathLineEdit.text = dir
	ResetExportPathColor()
	GenerateExportPreview()
	GenerateButlerPreview()

func _on_save_button_pressed():	
	SaveSettings()

func _on_open_project_path_button_pressed():
	OpenProjectPathFolder()

func _on_export_project_pressed():
	ExportProject()

func _on_open_project_folder_pressed():
	OpenRootExportPath()

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

