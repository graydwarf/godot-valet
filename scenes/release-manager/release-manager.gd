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
@onready var _autoGenerateExportFileNamesCheckBox = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/AutomateExportFileNameHBoxContainer/AutoGenerateExportFileNamesCheckBox
@onready var _installerConfigurationFileNameLineEdit = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/InstallerConfigurationHBoxContainer/InstallerConfigurationLineEdit

var _busyBackground
var _selectedProjectItem = null
var _isDirty = false
var _isClosingReleaseManager = false
var _exportWithInstallerStep = 0

func _ready():
	InitSignals()
	LoadTheme()
	LoadBackgroundColor()

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
	
	if _useSha256CheckBox.button_pressed && FileAccess.file_exists(exportPath + "\\" + _exportFileNameLineEdit.text + extensionType):
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
	#ExportProjectThread()

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
	elif _packageTypeOptionButton.text == "Installer":
		_exportWithInstallerStep = 0
		ExportWithInstaller()

	# TODO: This will need to be moved to the end of each workflow.
	# Deferring to make sure the _outputTabs/content get added before counting
	call_deferred("CompleteExport")

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
	if _exportWithInstallerStep == 0:
		ExportWithoutZip()
		_exportWithInstallerStep += 1
		Signals.emit_signal("ExportWithInstaller")
	elif _exportWithInstallerStep == 1:
		ExportGodotIgnition()
	elif _exportWithInstallerStep == 2:
		ExportGodotFetch()
		var fileName = "godot-fetch.zip"
		var isUnpacking = true
		HandleFileExportWorkflow(fileName, isUnpacking)
	elif _exportWithInstallerStep == 3:
		# At some point, we need godot-iginition to be renamed to <project>-<version>-<os>-installer.exe
		# rename_absolute
		# godot-ignition.exe, godot-ignition.pck, godot-fetch.exe, godot-fetch.pck, <project>.exe, <project.pck> are in the export dir
		GenerateInstallerConfigurationFiles()
	elif _exportWithInstallerStep == 4:
		PackageInstallerFiles()

func ExportGodotIgnition():
	# TODO: Load installer configuration
	# 	- extract path to <configs>/<project name>/installer-settings.cfg
	# 
	# godot-ignition.zip
	var userOptionAEnabled = true
	var userOptionBEnabled = true
	var userOptionCEnabled = true
	
	var windowsChecked = true
	var linuxChecked = true
	if windowsChecked:
		var pathToGodotIgnitionForWindows = ""
		if pathToGodotIgnitionForWindows != "":
			if FileAccess.file_exists(pathToGodotIgnitionForWindows):
				# TODO: Extract windows files to export directory
				# TODO: Create matching config and include user-options
				pass
	
	if linuxChecked:
		var pathToGodotIgnitionForLinux = ""
		if pathToGodotIgnitionForLinux != "":
			if FileAccess.file_exists(pathToGodotIgnitionForLinux):
				# TODO: Extract linux files to export directory
				# TODO: Create matching config and include user-options
				pass

	_exportWithInstallerStep += 1
	Signals.emit_signal("ExportWithInstaller")

func ExportGodotFetch():
	# TODO: Load installer configuration
	# 	- extract path to <configs>/<project name>/installer-settings.cfg
	# 
	# godot-ignition.zip
	var userOptionAEnabled = true
	var userOptionBEnabled = true
	var userOptionCEnabled = true
	
	var windowsChecked = true
	var linuxChecked = true
	if windowsChecked:
		var pathToGodotIgnitionForWindows = ""
		if pathToGodotIgnitionForWindows != "":
			if FileAccess.file_exists(pathToGodotIgnitionForWindows):
				# TODO: Extract windows files to export directory
				# TODO: Create matching config and include user-options
				pass
	
	if linuxChecked:
		var pathToGodotIgnitionForLinux = ""
		if pathToGodotIgnitionForLinux != "":
			if FileAccess.file_exists(pathToGodotIgnitionForLinux):
				# TODO: Extract linux files to export directory
				# TODO: Create matching config and include user-options
				pass

	_exportWithInstallerStep += 1
	Signals.emit_signal("ExportWithInstaller")
	
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

func BeginDownloadingMissingFileWorkflow(fileName):
	# TODO: REMEMBER: WE NEED TO DOWNLOAD OS SPECIFIC FILES
	# godot-fetch-v0.0.1.linux.zip
	if App.GetAutoUpdate():
		# Trigger download
		pass
	else:
		pass
	
# App.GetGodotFetchChecksum()
func ExportPackedFile(fileName, expectedChecksum):
	if !FileAccess.file_exists(fileName):
		if true: #expectedChecksum == GetCheckSum(fileName):
			#UnpackIntoExportDirectory(fileName)
			pass
		else:
			# Inform user and prompt to download a new version
			pass
	else:
		# Inform user and depending on the auto-install option:
		# Prompt user or auto-download .zip
		if true: #expectedChecksum == GetCheckSum(fileName):
			#UnpackIntoExportDirectory(fileName)
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
		# TODO: Refactor so we only touch files we generate. We know what we're
		# generating so no need to ignore anything.
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
		# TODO: Refactor so we only touch files we generate. We know what we're
		# generating so no need to ignore anything.
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
		# TODO: Refactor so we only touch files we generate. We know what we're
		# generating so no need to ignore anything.
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
		exportPreview += AddPreviewLine("html5")

	return exportPreview

func AddPreviewLine(presetType):
	var versionPath = GetGroomedVersionPath()
	var zipFileName = GetZipFileName(presetType)
	var packageType = _packageTypeOptionButton.text.to_lower()
	if packageType == "zip" || packageType == "zip + clean":
		packageType = ".zip"
	else:
		packageType = ""
		
	return GetFormattedExportPath() + versionPath + "\\" + presetType + "\\" + _exportTypeOptionButton.text.to_lower() + "\\" + zipFileName + packageType + "\n"

func GetZipFileName(presetType):
	var zipFileName = ""
	if _autoGenerateExportFileNamesCheckBox.button_pressed:
		zipFileName = _exportFileNameLineEdit.text + "-" + _projectVersionLineEdit.text + "-" + presetType
	else:
		zipFileName = _exportFileNameLineEdit.text
	return zipFileName
	
func GetFormattedExportPath():
	return _exportPathLineEdit.text.trim_prefix(" ").trim_suffix(" ").to_lower().replace("/", "\\")

func GetButlerPreview():
	if !FormValidationCheckIsSuccess():
		return ""

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
	return "butler push " + GetFormattedExportPath() + versionPath + "\\" + presetType + "\\" + _exportTypeOptionButton.text.to_lower() + "\\" + zipFileName + ".zip " + _itchProfileNameLineEdit.text.to_lower() + "/" + _itchProjectNameLineEdit.text.to_lower() + ":" + presetType + "\n"
	
func GetButlerPushCommand(presetName):
	var versionPath = GetGroomedVersionPath()
	if !FormValidationCheckIsSuccess():
		return []
	elif _packageTypeOptionButton.text == "No Zip":
		_butlerPreviewTextEdit.text = ""

	return ["push", GetFormattedExportPath() + versionPath + "\\" + presetName + "\\" + _exportTypeOptionButton.text.to_lower() + "\\" + GetZipFileName(presetName)  + ".zip", _itchProfileNameLineEdit.text.to_lower() + "/" + _exportFileNameLineEdit.text.to_lower() + ":" + presetName]
	
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
	
	StartBusyBackground("")
	
	var thread = Thread.new()
	thread.start(ExecuteButlerCommandsThread)

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

func _on_configure_installer_button_pressed():
	var installerConfigurationDialog = load("res://scenes/installer-configuration-dialog/installer-configuration-dialog.tscn").instantiate()
	add_child(installerConfigurationDialog)
	
