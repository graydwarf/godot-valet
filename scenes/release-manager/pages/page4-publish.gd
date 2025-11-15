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

var _publishing: bool = false
var _currentVersion: String = ""  # Store current version for comparison

func _ready():
	_publishButton.pressed.connect(_onPublishPressed)
	_itchCheckBox.toggled.connect(_onItchToggled)
	_githubCheckBox.toggled.connect(_onDestinationToggled)
	_projectVersionLineEdit.text_changed.connect(_onVersionChanged)

func _loadPageData():
	if _selectedProjectItem == null:
		return

	# Load project version
	_currentVersion = _selectedProjectItem.GetProjectVersion()
	_projectVersionLineEdit.text = _currentVersion

	# Reset state
	_statusLabel.text = ""
	_publishing = false
	_updatePublishButton()

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
