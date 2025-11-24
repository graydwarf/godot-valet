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

# Card styling containers
@onready var _itchHeaderContainer = $MarginContainer/VBoxContainer/ItchCard/VBoxContainer/HeaderContainer
@onready var _itchContentContainer = $MarginContainer/VBoxContainer/ItchCard/VBoxContainer/ContentContainer
@onready var _githubHeaderContainer = $MarginContainer/VBoxContainer/GithubCard/VBoxContainer/HeaderContainer
@onready var _githubContentContainer = $MarginContainer/VBoxContainer/GithubCard/VBoxContainer/ContentContainer

var _publishing: bool = false
var _isLoadingData: bool = false  # Suppresses page_modified during _loadPageData()

func _ready():
	_applyCardStyle()
	_publishButton.pressed.connect(_onPublishPressed)
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

	# Clear existing channel items
	for child in _channelsList.get_children():
		child.queue_free()

	# Get platform settings and build channel list
	var allSettings = _selectedProjectItem.GetAllPlatformExportSettings()
	var hasChannels = false

	# Get project name as fallback for export filename
	var fallbackFilename = ""
	if _selectedProjectItem != null:
		var projectPath = _selectedProjectItem.GetProjectPath()
		if not projectPath.is_empty():
			fallbackFilename = projectPath.get_file().get_basename()

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

			var channelLabel = Label.new()
			channelLabel.text = "  %s → %s:%s" % [platform, projectName, channelName]
			channelLabel.add_theme_font_size_override("font_size", 12)
			_channelsList.add_child(channelLabel)

			# Show full export path with filename
			var pathLabel = Label.new()
			if rootPath.is_empty():
				pathLabel.text = "    (no export path configured)"
				pathLabel.modulate = Color(1.0, 0.6, 0.6, 1)
				pathLabel.add_theme_font_size_override("font_size", 11)
				_channelsList.add_child(pathLabel)
			else:
				var displayPath = ""
				if platform == "Source":
					# Source uploads folder contents, show what's inside
					displayPath = fullPath
					var contentInfo = _getFolderContentInfo(fullPath)
					pathLabel.text = "    %s" % displayPath
					pathLabel.modulate = Color(0.6, 0.6, 0.6, 1)
					pathLabel.add_theme_font_size_override("font_size", 11)
					_channelsList.add_child(pathLabel)

					# Add a line showing folder contents summary
					var contentsLabel = Label.new()
					contentsLabel.text = "    └ %s" % contentInfo
					contentsLabel.modulate = Color(0.5, 0.5, 0.5, 1)
					contentsLabel.add_theme_font_size_override("font_size", 10)
					_channelsList.add_child(contentsLabel)

					# Add last exported date for Source folder
					var sourceLastExportedLabel = Label.new()
					var folderModTime = _getFolderModifiedTime(fullPath)
					sourceLastExportedLabel.text = "    └ Last Exported: %s" % folderModTime
					sourceLastExportedLabel.modulate = Color(0.5, 0.5, 0.5, 1) if folderModTime != "(not found)" else Color(1.0, 0.6, 0.6, 1)
					sourceLastExportedLabel.add_theme_font_size_override("font_size", 10)
					_channelsList.add_child(sourceLastExportedLabel)
					continue  # Skip the normal pathLabel add below
				else:
					displayPath = fullPath.path_join(displayFilename + displayExtension)
				pathLabel.text = "    %s" % displayPath
				pathLabel.modulate = Color(0.6, 0.6, 0.6, 1)
				pathLabel.add_theme_font_size_override("font_size", 11)
				_channelsList.add_child(pathLabel)

				# Add last exported date
				var lastExportedLabel = Label.new()
				var fileModTime = _getFileModifiedTime(displayPath)
				lastExportedLabel.text = "    └ Last Exported: %s" % fileModTime
				lastExportedLabel.modulate = Color(0.5, 0.5, 0.5, 1) if fileModTime != "(not found)" else Color(1.0, 0.6, 0.6, 1)
				lastExportedLabel.add_theme_font_size_override("font_size", 10)
				_channelsList.add_child(lastExportedLabel)

	if not hasChannels:
		var noChannelsLabel = Label.new()
		noChannelsLabel.text = "  (no platforms selected on Build page)"
		noChannelsLabel.modulate = Color(0.7, 0.7, 0.7, 1)
		noChannelsLabel.add_theme_font_size_override("font_size", 12)
		_channelsList.add_child(noChannelsLabel)

func _getButlerChannelName(platform: String) -> String:
	match platform:
		"Windows":
			return "windows"
		"macOS":
			return "mac"
		"Linux":
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
		"Windows":
			return ".exe"
		"macOS":
			return ".zip"  # macOS exports are typically zipped .app bundles
		"Linux":
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
	var anySelected = _itchCheckBox.button_pressed || _githubCheckBox.button_pressed
	_publishButton.disabled = !anySelected || _publishing

func _onPublishPressed():
	if _publishing:
		return

	_publishing = true
	_updatePublishButton()

	var destinations: Array[String] = []
	if _itchCheckBox.button_pressed:
		destinations.append("itch.io")
	if _githubCheckBox.button_pressed:
		destinations.append("GitHub")

	_statusLabel.text = "Publishing to " + ", ".join(destinations) + "..."

	# TODO: Actual publish logic
	# For now, simulate publishing
	for destination in destinations:
		publish_started.emit(destination)
		await get_tree().create_timer(2.0).timeout
		publish_completed.emit(destination, true)

	_statusLabel.text = "Published successfully!"
	_publishing = false
	_updatePublishButton()

func validate() -> bool:
	# Page 4 is always valid (publish is optional)
	return true

func _onProfileHelpButtonPressed():
	var popup = AcceptDialog.new()
	popup.title = "What is a Profile Name?"
	popup.dialog_text = """Your profile name is your itch.io username.

Examples:
• If your itch.io page is: https://johndoe.itch.io
• Your profile name is: johndoe

This is used by butler to identify which account to upload to.
You can find it in your itch.io dashboard URL or profile settings."""
	popup.ok_button_text = "Got it!"
	add_child(popup)
	popup.popup_centered(Vector2i(450, 280))
	popup.confirmed.connect(popup.queue_free)
	popup.close_requested.connect(popup.queue_free)

func _onProjectHelpButtonPressed():
	var popup = AcceptDialog.new()
	popup.title = "What is a Project Slug?"
	popup.dialog_text = """A slug is the URL-friendly identifier for your project on itch.io.

Examples:
• Project name: "My Awesome Game"
• Slug: "my-awesome-game"
• URL: https://username.itch.io/my-awesome-game

The slug is:
• Set when you create your project on itch.io
• Lowercase and URL-friendly
• Used in all API calls and butler uploads

Find your slug in your project's URL on itch.io."""
	popup.ok_button_text = "Got it!"
	add_child(popup)
	popup.popup_centered(Vector2i(500, 350))
	popup.confirmed.connect(popup.queue_free)
	popup.close_requested.connect(popup.queue_free)

func save():
	if _selectedProjectItem == null:
		return

	# Save publish destination checkboxes
	_selectedProjectItem.SetItchEnabled(_itchCheckBox.button_pressed)
	_selectedProjectItem.SetGithubEnabled(_githubCheckBox.button_pressed)

	# Save itch.io settings
	_selectedProjectItem.SetItchProfileName(_itchProfileLineEdit.text)
	_selectedProjectItem.SetItchProjectName(_itchProjectLineEdit.text)

	# Mark project as published with current date if published
	if _publishing:
		var currentDate = Time.get_datetime_string_from_system()
		_selectedProjectItem.SetPublishedDate(currentDate)

	_selectedProjectItem.SaveProjectItem()
