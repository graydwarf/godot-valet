extends WizardPageBase

signal publish_started(destination: String)
signal publish_completed(destination: String, success: bool)
signal page_modified()  # Emitted when any input is changed

@onready var _itchCard = %ItchCard
@onready var _itchCheckBox = %ItchCheckBox
@onready var _itchProfileLineEdit = %ItchProfileLineEdit
@onready var _itchProjectLineEdit = %ItchProjectLineEdit
@onready var _githubCard = %GithubCard
@onready var _githubCheckBox = %GithubCheckBox
@onready var _publishButton = %PublishButton
@onready var _butlerHelpButton = %ButlerHelpButton
@onready var _statusLabel = %StatusLabel
@onready var _profileHelpButton = %ProfileHelpButton
@onready var _projectHelpButton = %ProjectHelpButton
@onready var _exportTypeValueLabel = %ValueLabel
@onready var _uploadUrlValue = %UploadUrlValue
@onready var _versionValue = %VersionValue
@onready var _channelsList = %ChannelsList
@onready var _reviewCard = %ReviewCard
@onready var _reviewHeaderContainer = %ReviewHeaderContainer
@onready var _reviewContentContainer = %ReviewContentContainer
@onready var _outputLogCard = %OutputLogCard
@onready var _outputLog = %OutputLog
@onready var _clearLogButton = %ClearLogButton
@onready var _butlerHelpDialog = %ButlerHelpDialog
@onready var _profileHelpDialog = %ProfileHelpDialog
@onready var _projectHelpDialog = %ProjectHelpDialog

# Card styling containers
@onready var _itchHeaderContainer = $MarginContainer/ScrollContainer/ScrollMargin/VBoxContainer/ItchCard/VBoxContainer/HeaderContainer
@onready var _itchContentContainer = $MarginContainer/ScrollContainer/ScrollMargin/VBoxContainer/ItchCard/VBoxContainer/ContentContainer
@onready var _githubHeaderContainer = $MarginContainer/ScrollContainer/ScrollMargin/VBoxContainer/GithubCard/VBoxContainer/HeaderContainer
@onready var _githubContentContainer = $MarginContainer/ScrollContainer/ScrollMargin/VBoxContainer/GithubCard/VBoxContainer/ContentContainer
@onready var _outputLogHeaderContainer = $MarginContainer/ScrollContainer/ScrollMargin/VBoxContainer/OutputLogCard/VBoxContainer/HeaderContainer
@onready var _outputLogContentContainer = $MarginContainer/ScrollContainer/ScrollMargin/VBoxContainer/OutputLogCard/VBoxContainer/ContentContainer

const MOCK_PUBLISH: bool = false  # Set to true for testing without real publishing

var _publishing: bool = false
var _isLoadingData: bool = false  # Suppresses page_modified during _loadPageData()
var _butlerInfo: Dictionary = {"installed": false, "version": "", "path": "butler"}
var _platformPublishCheckboxes: Dictionary = {}  # platform -> CheckBox
var _platformsToPublish: Dictionary = {}  # platform -> bool (saved selections)
var _publishCancelled: bool = false
var _inputBlocker: Control = null  # Full-screen overlay to block all input during publish

func _ready():
	_applyCardStyle()
	_detectButlerInstallation()
	_createInputBlocker()
	_publishButton.pressed.connect(_onPublishPressed)
	_butlerHelpButton.pressed.connect(_onButlerHelpButtonPressed)
	_clearLogButton.pressed.connect(_onClearLogPressed)
	_itchCheckBox.toggled.connect(_onItchToggled)
	_githubCheckBox.toggled.connect(_onDestinationToggled)
	_profileHelpButton.pressed.connect(_onProfileHelpButtonPressed)
	_projectHelpButton.pressed.connect(_onProjectHelpButtonPressed)

	# Connect input change signals for dirty tracking and review updates
	_itchProfileLineEdit.text_changed.connect(_onInputChanged)
	_itchProjectLineEdit.text_changed.connect(_onInputChanged)
	_itchProfileLineEdit.text_changed.connect(_updateReviewSection)
	_itchProjectLineEdit.text_changed.connect(_updateReviewSection)

func _applyCardStyle():
	_applyCardStyleToPanel(_itchCard, _itchHeaderContainer, _itchContentContainer)
	_applyCardStyleToPanel(_githubCard, _githubHeaderContainer, _githubContentContainer)
	_applyCardStyleToPanel(_reviewCard, _reviewHeaderContainer, _reviewContentContainer)
	_applyCardStyleToPanel(_outputLogCard, _outputLogHeaderContainer, _outputLogContentContainer)

func _applyCardStyleToPanel(outerPanel: PanelContainer, headerPanel: PanelContainer, contentPanel: PanelContainer):
	# Outer panel with rounded corners and border
	var outerTheme = Theme.new()
	var outerStyleBox = StyleBoxFlat.new()
	outerStyleBox.bg_color = _getAdjustedBackgroundColor(-0.08)
	outerStyleBox.border_color = Color(0.6, 0.6, 0.6)
	outerStyleBox.border_width_left = 1
	outerStyleBox.border_width_top = 1
	outerStyleBox.border_width_right = 1
	outerStyleBox.border_width_bottom = 1
	outerStyleBox.corner_radius_top_left = 6
	outerStyleBox.corner_radius_top_right = 6
	outerStyleBox.corner_radius_bottom_right = 6
	outerStyleBox.corner_radius_bottom_left = 6
	outerTheme.set_stylebox("panel", "PanelContainer", outerStyleBox)
	outerPanel.theme = outerTheme

	# Header with transparent background and bottom border only
	var headerTheme = Theme.new()
	var headerStyleBox = StyleBoxFlat.new()
	headerStyleBox.bg_color = Color(0, 0, 0, 0)  # Transparent
	headerStyleBox.border_color = Color(0.6, 0.6, 0.6)
	headerStyleBox.border_width_left = 0
	headerStyleBox.border_width_top = 0
	headerStyleBox.border_width_right = 0
	headerStyleBox.border_width_bottom = 1
	headerTheme.set_stylebox("panel", "PanelContainer", headerStyleBox)
	headerPanel.theme = headerTheme

	# Content with transparent background (no borders)
	var contentTheme = Theme.new()
	var contentStyleBox = StyleBoxFlat.new()
	contentStyleBox.bg_color = Color(0, 0, 0, 0)  # Transparent
	contentStyleBox.border_width_left = 0
	contentStyleBox.border_width_top = 0
	contentStyleBox.border_width_right = 0
	contentStyleBox.border_width_bottom = 0
	contentTheme.set_stylebox("panel", "PanelContainer", contentStyleBox)
	contentPanel.theme = contentTheme

func _getAdjustedBackgroundColor(amount: float) -> Color:
	var colorToSubtract = Color(amount, amount, amount, 0.0)
	var baseColor = App.GetBackgroundColor()
	return Color(
		max(baseColor.r + colorToSubtract.r, 0),
		max(baseColor.g + colorToSubtract.g, 0),
		max(baseColor.b + colorToSubtract.b, 0),
		baseColor.a
	)

# Detect if butler is installed and get version info
func _detectButlerInstallation():
	_butlerInfo = {"installed": false, "version": "", "path": "butler"}

	# Try running butler --version
	var output = []
	var exitCode = OS.execute("butler", ["--version"], output, true, false)

	if exitCode == OK and output.size() > 0:
		_butlerInfo.installed = true
		_butlerInfo.version = output[0].strip_edges()
		_logOutput("[color=green]Butler detected: %s[/color]" % _butlerInfo.version)
	else:
		# Butler not in PATH, try common locations
		var commonPaths = [
			OS.get_environment("USERPROFILE") + "/.config/itch/bin/butler.exe",
			"C:/Users/" + OS.get_environment("USERNAME") + "/.config/itch/bin/butler.exe"
		]

		for butlerPath in commonPaths:
			if FileAccess.file_exists(butlerPath):
				var testOutput = []
				var testExitCode = OS.execute(butlerPath, ["--version"], testOutput, true, false)
				if testExitCode == OK and testOutput.size() > 0:
					_butlerInfo.installed = true
					_butlerInfo.version = testOutput[0].strip_edges()
					_butlerInfo.path = butlerPath
					_logOutput("[color=green]Butler detected at: %s[/color]" % butlerPath)
					_logOutput("[color=green]Version: %s[/color]" % _butlerInfo.version)
					break

		if not _butlerInfo.installed:
			_logOutput("[color=red]Butler not found. Install butler to publish to itch.io.[/color]")
			_logOutput("Download from: https://itch.io/docs/butler/")

func _loadPageData():
	if _selectedProjectItem == null:
		return

	# Suppress page_modified during data loading (not user changes)
	_isLoadingData = true

	# Load publish destination checkboxes
	_itchCheckBox.button_pressed = _selectedProjectItem.GetItchEnabled()
	_githubCheckBox.button_pressed = _selectedProjectItem.GetGithubEnabled()

	# Update visibility based on checkbox state
	_itchContentContainer.visible = _itchCheckBox.button_pressed
	_githubContentContainer.visible = _githubCheckBox.button_pressed

	# Load itch.io settings
	_itchProfileLineEdit.text = _selectedProjectItem.GetItchProfileName()
	_itchProjectLineEdit.text = _selectedProjectItem.GetItchProjectName()

	# Load saved publish platform selections
	_platformsToPublish = _selectedProjectItem.GetPublishPlatformSelections()

	# Load selected export platforms from Build page
	_updateExportTypeSummary()

	# Update review section
	_updateReviewSection()

	# Reset state
	_statusLabel.text = ""
	_publishing = false
	_updatePublishButton()

	_isLoadingData = false

func _updateExportTypeSummary():
	# Get all platform export settings from Build page
	var allSettings = _selectedProjectItem.GetAllPlatformExportSettings()
	var selectedPlatforms: Array[String] = []

	# Check which platforms are enabled
	for platform in allSettings.keys():
		var settings = allSettings[platform]
		if settings.get("enabled", false):
			selectedPlatforms.append(platform)

	# Update the label
	if selectedPlatforms.is_empty():
		_exportTypeValueLabel.text = "None selected"
	else:
		_exportTypeValueLabel.text = ", ".join(selectedPlatforms)

func _updateReviewSection(_value = null):
	if _selectedProjectItem == null:
		return

	var profileName = _itchProfileLineEdit.text
	var projectName = _itchProjectLineEdit.text

	# Update upload URL
	if profileName.is_empty() or projectName.is_empty():
		_uploadUrlValue.text = "(enter profile and project name)"
		_uploadUrlValue.modulate = Color(0.7, 0.7, 0.7, 1)
	else:
		_uploadUrlValue.text = "%s.itch.io/%s" % [profileName, projectName]
		_uploadUrlValue.modulate = Color(1, 1, 1, 1)

	# Update version
	var version = _selectedProjectItem.GetProjectVersion()
	_versionValue.text = version if not version.is_empty() else "(not set)"

	# Clear existing channel items and checkbox references
	for child in _channelsList.get_children():
		child.queue_free()
	_platformPublishCheckboxes.clear()

	# Get platform settings and build channel list
	var allSettings = _selectedProjectItem.GetAllPlatformExportSettings()
	var hasChannels = false

	# Get project name as fallback for export filename
	var fallbackFilename = ""
	if _selectedProjectItem != null:
		var projectPath = _selectedProjectItem.GetProjectPath()
		if not projectPath.is_empty():
			fallbackFilename = projectPath.get_file().get_basename()
			# If project file is named "project.godot", use actual project name instead
			if fallbackFilename == "project":
				fallbackFilename = _selectedProjectItem.GetProjectName()

	for platform in allSettings.keys():
		var settings = allSettings[platform]
		if settings.get("enabled", false):
			hasChannels = true
			var channelName = _getButlerChannelName(platform)
			var rootPath = settings.get("exportPath", "")
			var pathTemplate = settings.get("pathTemplate", [])
			var packageType = settings.get("packageType", 0)  # 0=No Zip, 1=Zip

			# Use archive filename when zipping, otherwise use export filename
			var displayFilename: String
			var displayExtension: String
			if packageType == 1:  # Zip enabled
				displayFilename = settings.get("archiveFilename", "")
				displayExtension = ".zip"
			else:
				displayFilename = settings.get("exportFilename", "")
				displayExtension = _getFileExtension(platform)

			if displayFilename.is_empty():
				displayFilename = fallbackFilename
			var fullPath = _buildFullExportPath(rootPath, pathTemplate, platform, version)

			# Create row with checkbox for platform selection
			var channelRow = HBoxContainer.new()
			channelRow.add_theme_constant_override("separation", 8)

			var checkbox = CheckBox.new()
			checkbox.text = ""
			checkbox.tooltip_text = "Include %s in publish" % platform
			checkbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			# Default to checked if no saved selection, or use saved value
			checkbox.button_pressed = _platformsToPublish.get(platform, true)
			checkbox.toggled.connect(_onPlatformCheckboxToggled.bind(platform))
			channelRow.add_child(checkbox)
			_platformPublishCheckboxes[platform] = checkbox

			var channelLabel = Label.new()
			channelLabel.text = "%s → %s:%s" % [platform, projectName, channelName]
			channelLabel.add_theme_font_size_override("font_size", 12)
			channelRow.add_child(channelLabel)

			_channelsList.add_child(channelRow)

			# Show full export path with filename
			var pathLabel = Label.new()
			if rootPath.is_empty():
				pathLabel.text = "      (no export path configured)"
				pathLabel.modulate = Color(1.0, 0.6, 0.6, 1)
				pathLabel.add_theme_font_size_override("font_size", 11)
				_channelsList.add_child(pathLabel)
			else:
				var displayPath = ""
				if platform == "Source":
					# Source uploads folder contents, show what's inside
					displayPath = fullPath
					var contentInfo = _getFolderContentInfo(fullPath)
					pathLabel.text = "      %s" % displayPath
					pathLabel.modulate = Color(0.6, 0.6, 0.6, 1)
					pathLabel.add_theme_font_size_override("font_size", 11)
					_channelsList.add_child(pathLabel)

					# Add a line showing folder contents summary
					var contentsLabel = Label.new()
					contentsLabel.text = "      └ %s" % contentInfo
					contentsLabel.modulate = Color(0.5, 0.5, 0.5, 1)
					contentsLabel.add_theme_font_size_override("font_size", 10)
					_channelsList.add_child(contentsLabel)

					# Add last exported date for Source folder
					var sourceLastExportedLabel = Label.new()
					var folderModTime = _getFolderModifiedTime(fullPath)
					sourceLastExportedLabel.text = "      └ Last Exported: %s" % folderModTime
					sourceLastExportedLabel.modulate = Color(0.5, 0.5, 0.5, 1) if folderModTime != "(not found)" else Color(1.0, 0.6, 0.6, 1)
					sourceLastExportedLabel.add_theme_font_size_override("font_size", 10)
					_channelsList.add_child(sourceLastExportedLabel)
					continue  # Skip the normal pathLabel add below
				else:
					displayPath = fullPath.path_join(displayFilename + displayExtension)
				pathLabel.text = "      %s" % displayPath
				pathLabel.modulate = Color(0.6, 0.6, 0.6, 1)
				pathLabel.add_theme_font_size_override("font_size", 11)
				_channelsList.add_child(pathLabel)

				# Add last exported date
				var lastExportedLabel = Label.new()
				var fileModTime = _getFileModifiedTime(displayPath)
				lastExportedLabel.text = "      └ Last Exported: %s" % fileModTime
				lastExportedLabel.modulate = Color(0.5, 0.5, 0.5, 1) if fileModTime != "(not found)" else Color(1.0, 0.6, 0.6, 1)
				lastExportedLabel.add_theme_font_size_override("font_size", 10)
				_channelsList.add_child(lastExportedLabel)

	if not hasChannels:
		var noChannelsLabel = Label.new()
		noChannelsLabel.text = "  (no platforms selected on Export page)"
		noChannelsLabel.modulate = Color(0.7, 0.7, 0.7, 1)
		noChannelsLabel.add_theme_font_size_override("font_size", 12)
		_channelsList.add_child(noChannelsLabel)

func _onPlatformCheckboxToggled(checked: bool, platform: String):
	_platformsToPublish[platform] = checked
	if not _isLoadingData:
		page_modified.emit()

func _getButlerChannelName(platform: String) -> String:
	match platform:
		"Windows", "Windows Desktop":
			return "windows"
		"macOS":
			return "mac"
		"Linux", "Linux/X11":
			return "linux"
		"Web":
			return "html5"
		"Android":
			return "android"
		"iOS":
			return "ios"
		"Source":
			return "source"
		_:
			return platform.to_lower().replace(" ", "-")

func _getFolderContentInfo(folderPath: String) -> String:
	var dir = DirAccess.open(folderPath)
	if dir == null:
		return "(folder not found)"

	var fileCount = 0
	var folderCount = 0

	dir.list_dir_begin()
	var fileName = dir.get_next()
	while fileName != "":
		if not fileName.begins_with("."):  # Skip hidden files
			if dir.current_is_dir():
				folderCount += 1
			else:
				fileCount += 1
		fileName = dir.get_next()
	dir.list_dir_end()

	var parts = []
	if folderCount > 0:
		parts.append("%d folder%s" % [folderCount, "s" if folderCount != 1 else ""])
	if fileCount > 0:
		parts.append("%d file%s" % [fileCount, "s" if fileCount != 1 else ""])

	if parts.is_empty():
		return "(empty folder)"
	return "Uploads: " + ", ".join(parts)

func _getFileModifiedTime(filePath: String) -> String:
	if not FileAccess.file_exists(filePath):
		return "(not found)"
	var modTime = FileAccess.get_modified_time(filePath)
	return _formatUnixTime(modTime)

func _getFolderModifiedTime(folderPath: String) -> String:
	if not DirAccess.dir_exists_absolute(folderPath):
		return "(not found)"
	# For folders, get the most recent modification time of any file inside
	var dir = DirAccess.open(folderPath)
	if dir == null:
		return "(not found)"
	var latestTime: int = 0
	dir.list_dir_begin()
	var fileName = dir.get_next()
	while fileName != "":
		if not fileName.begins_with("."):
			var fullPath = folderPath.path_join(fileName)
			if not dir.current_is_dir():
				var fileTime = FileAccess.get_modified_time(fullPath)
				if fileTime > latestTime:
					latestTime = fileTime
		fileName = dir.get_next()
	dir.list_dir_end()
	if latestTime == 0:
		return "(empty folder)"
	return _formatUnixTime(latestTime)

func _formatUnixTime(unixTime: int) -> String:
	var datetime = Time.get_datetime_dict_from_unix_time(unixTime)
	return "%02d/%02d/%04d %02d:%02d" % [datetime.month, datetime.day, datetime.year, datetime.hour, datetime.minute]

func _getFileExtension(platform: String) -> String:
	match platform:
		"Windows", "Windows Desktop":
			return ".exe"
		"macOS":
			return ".zip"  # macOS exports are typically zipped .app bundles
		"Linux", "Linux/X11":
			return ".x86_64"
		"Web":
			return ".html"
		"Android":
			return ".apk"
		"iOS":
			return ".ipa"
		"Source":
			return ""  # Source is a folder, no extension
		_:
			return ""

func _buildFullExportPath(rootPath: String, pathTemplate: Array, platform: String, version: String) -> String:
	if rootPath.is_empty():
		return ""

	var fullPath = rootPath

	for segment in pathTemplate:
		var segmentType = segment.get("type", "")
		var segmentValue = ""

		match segmentType:
			"version":
				segmentValue = version if not version.is_empty() else "v1.0.0"
			"platform":
				segmentValue = platform
			"custom":
				segmentValue = segment.get("value", "")

		if not segmentValue.is_empty():
			fullPath = fullPath.path_join(segmentValue)

	return fullPath

func _onInputChanged(_value = null):
	# Emit signal when any input is modified
	if not _isLoadingData:
		page_modified.emit()

func _onItchToggled(checked: bool):
	# Show/hide itch.io content
	_itchContentContainer.visible = checked
	_updatePublishButton()
	if not _isLoadingData:
		page_modified.emit()

func _onDestinationToggled(checked: bool):
	# Show/hide GitHub content
	_githubContentContainer.visible = checked
	_updatePublishButton()
	if not _isLoadingData:
		page_modified.emit()

func _updatePublishButton():
	var anyDestinationSelected = _itchCheckBox.button_pressed || _githubCheckBox.button_pressed
	var anyPlatformSelected = _getSelectedPlatformsToPublish().size() > 0
	_publishButton.disabled = !anyDestinationSelected || !anyPlatformSelected || _publishing || !_butlerInfo.installed

func _getSelectedPlatformsToPublish() -> Array[String]:
	var selected: Array[String] = []
	for platform in _platformPublishCheckboxes.keys():
		if _platformPublishCheckboxes[platform].button_pressed:
			selected.append(platform)
	return selected

func _onPublishPressed():
	if _publishing:
		return

	if not _butlerInfo.installed:
		_logOutput("[color=red]Error: Butler is not installed. Cannot publish.[/color]")
		return

	var profileName = _itchProfileLineEdit.text.strip_edges()
	var projectSlug = _itchProjectLineEdit.text.strip_edges()

	if profileName.is_empty() or projectSlug.is_empty():
		_logOutput("[color=red]Error: Profile name and project slug are required.[/color]")
		return

	var platformsToPublish = _getSelectedPlatformsToPublish()
	if platformsToPublish.is_empty():
		_logOutput("[color=red]Error: No platforms selected to publish.[/color]")
		return

	# Clear output log for fresh publish attempt
	_outputLog.clear()

	_publishing = true
	_publishCancelled = false
	_updatePublishButton()
	_statusLabel.text = "Publishing..."
	_setUIEnabled(false)

	_logOutput("=".repeat(60))
	_logOutput("[color=cyan]Starting publish to itch.io...[/color]")
	_logOutput("Profile: %s" % profileName)
	_logOutput("Project: %s" % projectSlug)
	_logOutput("Platforms: %s" % ", ".join(platformsToPublish))
	_logOutput("=".repeat(60) + "\n")

	var version = _selectedProjectItem.GetProjectVersion()
	var allSettings = _selectedProjectItem.GetAllPlatformExportSettings()
	var successCount = 0
	var failCount = 0

	for platform in platformsToPublish:
		if _publishCancelled:
			_logOutput("[color=yellow]Publishing cancelled by user.[/color]")
			break

		var settings = allSettings.get(platform, {})
		if settings.is_empty():
			_logOutput("[color=red]No settings found for %s, skipping.[/color]" % platform)
			failCount += 1
			continue

		var success = await _publishPlatform(platform, settings, profileName, projectSlug, version)
		if success:
			successCount += 1
		else:
			failCount += 1

	_logOutput("\n" + "=".repeat(60))
	if failCount == 0:
		_logOutput("[color=green]All %d platform(s) published successfully![/color]" % successCount)
		_statusLabel.text = "Published successfully!"
	elif successCount > 0:
		_logOutput("[color=yellow]%d succeeded, %d failed.[/color]" % [successCount, failCount])
		_statusLabel.text = "Partial success (%d/%d)" % [successCount, successCount + failCount]
	else:
		_logOutput("[color=red]All %d platform(s) failed to publish.[/color]" % failCount)
		_statusLabel.text = "Publish failed"
	_logOutput("=".repeat(60))

	_publishing = false
	_updatePublishButton()
	_setUIEnabled(true)

	# Update review section to refresh "Last Exported" times
	_updateReviewSection()

func _publishPlatform(platform: String, settings: Dictionary, profileName: String, projectSlug: String, version: String) -> bool:
	var channelName = _getButlerChannelName(platform)

	# Mock publish mode for testing
	if MOCK_PUBLISH:
		_logOutput("\n[color=yellow][MOCK] [%s] Simulating publish...[/color]" % platform)
		_logOutput("[MOCK] Channel: %s/%s:%s" % [profileName, projectSlug, channelName])
		publish_started.emit(platform)

		# Simulate 5 second publish with progress updates
		for i in range(5):
			if _publishCancelled:
				_logOutput("[color=yellow][MOCK] [%s] Publish cancelled.[/color]" % platform)
				publish_completed.emit(platform, false)
				return false
			await get_tree().create_timer(1.0).timeout
			_logOutput("[MOCK] [%s] Progress: %d%%..." % [platform, (i + 1) * 20])

		_logOutput("[color=green][MOCK] [%s] Published successfully![/color]" % platform)
		publish_completed.emit(platform, true)
		return true

	var rootPath = settings.get("exportPath", "")
	var pathTemplate = settings.get("pathTemplate", [])
	var packageType = settings.get("packageType", 0)

	if rootPath.is_empty():
		_logOutput("[color=red][%s] No export path configured, skipping.[/color]" % platform)
		return false

	var fullPath = _buildFullExportPath(rootPath, pathTemplate, platform, version)
	var uploadPath: String

	if platform == "Source":
		# For Source, upload the folder directly
		uploadPath = fullPath
		if not DirAccess.dir_exists_absolute(uploadPath):
			_logOutput("[color=red][%s] Source folder not found: %s[/color]" % [platform, uploadPath])
			return false
	else:
		# For other platforms, upload the file
		var displayFilename: String
		var displayExtension: String
		if packageType == 1:  # Zip enabled
			displayFilename = settings.get("archiveFilename", "")
			displayExtension = ".zip"
		else:
			displayFilename = settings.get("exportFilename", "")
			displayExtension = _getFileExtension(platform)

		if displayFilename.is_empty():
			var projectPath = _selectedProjectItem.GetProjectPath()
			displayFilename = projectPath.get_file().get_basename()
			if displayFilename == "project":
				displayFilename = _selectedProjectItem.GetProjectName()

		uploadPath = fullPath.path_join(displayFilename + displayExtension)

		if not FileAccess.file_exists(uploadPath):
			_logOutput("[color=red][%s] Export file not found: %s[/color]" % [platform, uploadPath])
			return false

	# Build butler command
	var target = "%s/%s:%s" % [profileName, projectSlug, channelName]
	var args = ["push", uploadPath, target]

	# Add version if available
	if not version.is_empty():
		args.append("--userversion")
		args.append(version.trim_prefix("v"))

	_logOutput("\n[color=cyan][%s] Publishing...[/color]" % platform)
	_logOutput("Command: butler %s" % " ".join(args))
	_logOutput("File: %s" % uploadPath)
	_logOutput("")

	publish_started.emit(platform)

	# Execute butler command and capture output
	var output = []
	var exitCode = OS.execute(_butlerInfo.path, args, output, true, false)

	# Display output
	for line in output:
		var cleanLine = line.strip_edges()
		if not cleanLine.is_empty():
			_logOutput("  " + cleanLine)

	if exitCode == OK:
		_logOutput("[color=green][%s] Published successfully![/color]" % platform)
		publish_completed.emit(platform, true)
		return true
	else:
		_logOutput("[color=red][%s] Failed with exit code: %d[/color]" % [platform, exitCode])
		publish_completed.emit(platform, false)
		return false

func _logOutput(message: String):
	_outputLog.append_text(message + "\n")

func _onClearLogPressed():
	_outputLog.clear()
	_outputLog.append_text("Ready to publish...\n")

func validate() -> bool:
	# Page 4 is always valid (publish is optional)
	return true

func _onButlerHelpButtonPressed():
	_butlerHelpDialog.showDialog(_butlerInfo)

func _onProfileHelpButtonPressed():
	_profileHelpDialog.showDialog()

func _onProjectHelpButtonPressed():
	_projectHelpDialog.showDialog()

func save():
	if _selectedProjectItem == null:
		return

	# Save publish destination checkboxes
	_selectedProjectItem.SetItchEnabled(_itchCheckBox.button_pressed)
	_selectedProjectItem.SetGithubEnabled(_githubCheckBox.button_pressed)

	# Save itch.io settings
	_selectedProjectItem.SetItchProfileName(_itchProfileLineEdit.text)
	_selectedProjectItem.SetItchProjectName(_itchProjectLineEdit.text)

	# Save publish platform selections
	_selectedProjectItem.SetPublishPlatformSelections(_platformsToPublish)

	_selectedProjectItem.SaveProjectItem()

func _createInputBlocker():
	# Create overlay container
	_inputBlocker = Control.new()
	_inputBlocker.name = "PublishBlockerOverlay"
	_inputBlocker.mouse_filter = Control.MOUSE_FILTER_STOP  # Block all mouse input
	_inputBlocker.focus_mode = Control.FOCUS_ALL  # Block keyboard input
	_inputBlocker.visible = false
	_inputBlocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inputBlocker.z_index = 1000  # Very high z-index to be above everything

	# Semi-transparent black background
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inputBlocker.add_child(background)

	# Center container for spinner and cancel button
	var centerContainer = CenterContainer.new()
	centerContainer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inputBlocker.add_child(centerContainer)

	# VBox for vertical layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	centerContainer.add_child(vbox)

	# Spinner label (animated)
	var spinnerLabel = Label.new()
	spinnerLabel.name = "SpinnerLabel"
	spinnerLabel.text = "◜"  # First frame of spinner
	spinnerLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spinnerLabel.add_theme_font_size_override("font_size", 48)
	vbox.add_child(spinnerLabel)

	# Status message label
	var statusLabel = Label.new()
	statusLabel.name = "StatusLabel"
	statusLabel.text = "Publishing..."
	statusLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	statusLabel.add_theme_font_size_override("font_size", 18)
	vbox.add_child(statusLabel)

	# Start spinner animation timer
	var timer = Timer.new()
	timer.name = "SpinnerTimer"
	timer.wait_time = 0.15  # Rotate every 150ms
	timer.autostart = false
	timer.timeout.connect(_updateSpinner.bind(spinnerLabel))
	_inputBlocker.add_child(timer)

func _updateSpinner(spinnerLabel: Label):
	# Rotate through spinner characters
	var spinnerChars = ["◜", "◝", "◞", "◟"]
	var currentIndex = spinnerChars.find(spinnerLabel.text)
	var nextIndex = (currentIndex + 1) % spinnerChars.size()
	spinnerLabel.text = spinnerChars[nextIndex]

func _setUIEnabled(enabled: bool):
	# Show/hide full-screen input blocker overlay
	if not is_instance_valid(_inputBlocker):
		return

	if not enabled:
		# Reset cancellation flag when starting publish
		_publishCancelled = false

		# Add to root if not already added
		if _inputBlocker.get_parent() == null:
			var root = get_tree().current_scene
			if root == null:
				root = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
			if root:
				root.add_child(_inputBlocker)

		# Show blocker and start spinner
		_inputBlocker.visible = true
		_inputBlocker.move_to_front()

		var timer = _inputBlocker.get_node_or_null("SpinnerTimer")
		if is_instance_valid(timer):
			timer.start()

		# Reset status text
		var statusLabel = _inputBlocker.get_node_or_null("CenterContainer/VBoxContainer/StatusLabel")
		if is_instance_valid(statusLabel):
			statusLabel.text = "Publishing..."
	else:
		# Hide blocker and stop spinner
		_inputBlocker.visible = false
		var timer = _inputBlocker.get_node_or_null("SpinnerTimer")
		if is_instance_valid(timer):
			timer.stop()
