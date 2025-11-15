extends WizardPageBase

signal publish_started(destination: String)
signal publish_completed(destination: String, success: bool)
signal version_changed(old_version: String, new_version: String)

@onready var _projectVersionLineEdit = %ProjectVersionLineEdit
@onready var _itchCheckBox = %ItchCheckBox
@onready var _itchDetailsMargin = %ItchDetailsMargin
@onready var _githubCheckBox = %GithubCheckBox
@onready var _publishButton = %PublishButton
@onready var _statusLabel = %StatusLabel
@onready var _helpButton = %HelpButton
@onready var _exportTypeValueLabel = %ValueLabel

var _publishing: bool = false
var _currentVersion: String = ""  # Store current version for comparison

func _ready():
	_publishButton.pressed.connect(_onPublishPressed)
	_itchCheckBox.toggled.connect(_onItchToggled)
	_githubCheckBox.toggled.connect(_onDestinationToggled)
	_projectVersionLineEdit.text_changed.connect(_onVersionChanged)
	_helpButton.pressed.connect(_onHelpButtonPressed)

func _loadPageData():
	if _selectedProjectItem == null:
		return

	# Load project version
	_currentVersion = _selectedProjectItem.GetProjectVersion()
	_projectVersionLineEdit.text = _currentVersion

	# Load selected export platforms from Build page
	_updateExportTypeSummary()

	# Reset state
	_statusLabel.text = ""
	_publishing = false
	_updatePublishButton()

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

func _onVersionChanged(newText: String):
	# Notify card of version change
	version_changed.emit(_currentVersion, newText)

func _onItchToggled(checked: bool):
	# Show/hide itch.io details
	_itchDetailsMargin.visible = checked
	_updatePublishButton()

func _onDestinationToggled(_value: bool):
	_updatePublishButton()

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

func _onHelpButtonPressed():
	# Create a simple info popup
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

	# Save project version
	_selectedProjectItem.SetProjectVersion(_projectVersionLineEdit.text)

	# Mark project as published with current date if published
	if _publishing:
		var currentDate = Time.get_datetime_string_from_system()
		_selectedProjectItem.SetPublishedDate(currentDate)

	_selectedProjectItem.SaveProjectItem()
