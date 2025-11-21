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
@onready var _helpButton = %HelpButton
@onready var _exportTypeValueLabel = %ValueLabel

# Card styling containers
@onready var _itchHeaderContainer = $MarginContainer/VBoxContainer/ItchCard/VBoxContainer/HeaderContainer
@onready var _itchContentContainer = $MarginContainer/VBoxContainer/ItchCard/VBoxContainer/ContentContainer
@onready var _githubHeaderContainer = $MarginContainer/VBoxContainer/GithubCard/VBoxContainer/HeaderContainer
@onready var _githubContentContainer = $MarginContainer/VBoxContainer/GithubCard/VBoxContainer/ContentContainer

var _publishing: bool = false

func _ready():
	_applyCardStyle()
	_publishButton.pressed.connect(_onPublishPressed)
	_itchCheckBox.toggled.connect(_onItchToggled)
	_githubCheckBox.toggled.connect(_onDestinationToggled)
	_helpButton.pressed.connect(_onHelpButtonPressed)

	# Connect input change signals for dirty tracking
	_itchProfileLineEdit.text_changed.connect(_onInputChanged)
	_itchProjectLineEdit.text_changed.connect(_onInputChanged)

func _applyCardStyle():
	_applyCardStyleToPanel(_itchCard, _itchHeaderContainer, _itchContentContainer)
	_applyCardStyleToPanel(_githubCard, _githubHeaderContainer, _githubContentContainer)

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

func _onInputChanged(_value = null):
	# Emit signal when any input is modified
	page_modified.emit()

func _onItchToggled(checked: bool):
	# Show/hide itch.io content
	_itchContentContainer.visible = checked
	_updatePublishButton()
	page_modified.emit()

func _onDestinationToggled(checked: bool):
	# Show/hide GitHub content
	_githubContentContainer.visible = checked
	_updatePublishButton()
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
