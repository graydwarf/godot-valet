extends Control

signal config_saved(platform: String, config: Dictionary)
signal cancelled()

@onready var _platformLabel = %PlatformLabel
@onready var _cloneOptionButton = %CloneOptionButton
@onready var _obfuscateFunctionsCheckBox = %ObfuscateFunctionsCheckBox
@onready var _obfuscateVariablesCheckBox = %ObfuscateVariablesCheckBox
@onready var _obfuscateCommentsCheckBox = %ObfuscateCommentsCheckBox
@onready var _sourceFiltersLineEdit = %SourceFiltersLineEdit
@onready var _obfuscationCard = %ObfuscationCard
@onready var _sourceFiltersCard = %SourceFiltersCard
@onready var _functionExcludesCard = %FunctionExcludesCard
@onready var _variableExcludesCard = %VariableExcludesCard
@onready var _functionExcludesList = %FunctionExcludesList
@onready var _variableExcludesList = %VariableExcludesList
@onready var _addFunctionButton = %AddFunctionButton
@onready var _addVariableButton = %AddVariableButton
@onready var _functionHelpButton = %FunctionHelpButton
@onready var _variableHelpButton = %VariableHelpButton

var _currentPlatform: String = ""
var _allPlatforms: Array[String] = []
var _platformConfigs: Dictionary = {}  # platform -> config dict
var _isDirty: bool = false
var _originalConfig: Dictionary = {}

const DEFAULT_SOURCE_FILTERS = ".git, .godot, .import, builds, exports, .vscode, .vs"
const FUNCTION_HELP_TEXT = """Add function names that should NOT be obfuscated.

Use this for functions that are called dynamically via reflection:
  - call("get_player_data")
  - call_deferred("process_input")
  - has_method("on_damage_received")

Also exclude functions referenced by string in signals or timers.

Enter exact function names only - no wildcards supported."""

const VARIABLE_HELP_TEXT = """Add variable names that should NOT be obfuscated.

Use this for variables accessed dynamically via reflection:
  - get("player_score")
  - set("health", 100)
  - has("inventory_items")

Also exclude variables that are accessed by string name in serialization or configuration systems.

Enter exact variable names only - no wildcards supported."""

func _ready():
	visible = false
	z_index = 1000  # Above all Release Manager UI (header, breadcrumb, pages, buttons)

	_cloneOptionButton.item_selected.connect(_onCloneSelected)
	_addFunctionButton.pressed.connect(_onAddFunctionPressed)
	_addVariableButton.pressed.connect(_onAddVariablePressed)
	_functionHelpButton.pressed.connect(_onFunctionHelpPressed)
	_variableHelpButton.pressed.connect(_onVariableHelpPressed)
	_applyCardStyling()

	# Connect all input signals to mark dirty
	_obfuscateFunctionsCheckBox.toggled.connect(_onInputChanged.unbind(1))
	_obfuscateVariablesCheckBox.toggled.connect(_onInputChanged.unbind(1))
	_obfuscateCommentsCheckBox.toggled.connect(_onInputChanged.unbind(1))
	_sourceFiltersLineEdit.text_changed.connect(_onInputChanged.unbind(1))

func _onInputChanged():
	_isDirty = true

func _applyCardStyling():
	# Apply platform card styling to all cards
	var cards = [_obfuscationCard, _sourceFiltersCard, _functionExcludesCard, _variableExcludesCard]

	for card in cards:
		# Outer card panel with rounded edges and border
		var panelTheme = Theme.new()
		var styleBox = StyleBoxFlat.new()
		styleBox.bg_color = _getAdjustedBackgroundColor(-0.08)
		styleBox.border_color = Color(0.6, 0.6, 0.6)
		styleBox.border_width_left = 1
		styleBox.border_width_top = 1
		styleBox.border_width_right = 1
		styleBox.border_width_bottom = 1
		styleBox.corner_radius_top_left = 6
		styleBox.corner_radius_top_right = 6
		styleBox.corner_radius_bottom_right = 6
		styleBox.corner_radius_bottom_left = 6
		panelTheme.set_stylebox("panel", "PanelContainer", styleBox)
		card.theme = panelTheme

		# Find the header container within this card and style it
		var headerContainer = card.find_child("CardHeader", true, false)
		if headerContainer:
			var headerTheme = Theme.new()
			var headerStyleBox = StyleBoxFlat.new()
			headerStyleBox.bg_color = Color(0, 0, 0, 0)  # Transparent background
			headerStyleBox.border_color = Color(0.6, 0.6, 0.6)
			headerStyleBox.border_width_left = 0
			headerStyleBox.border_width_top = 0
			headerStyleBox.border_width_right = 0
			headerStyleBox.border_width_bottom = 1
			headerTheme.set_stylebox("panel", "PanelContainer", headerStyleBox)
			headerContainer.theme = headerTheme

func _getAdjustedBackgroundColor(amount: float) -> Color:
	var colorToSubtract = Color(amount, amount, amount, 0.0)
	var baseColor = App.GetBackgroundColor()
	return Color(
		max(baseColor.r + colorToSubtract.r, 0),
		max(baseColor.g + colorToSubtract.g, 0),
		max(baseColor.b + colorToSubtract.b, 0),
		baseColor.a
	)

# Opens the dialog for a specific platform
func openForPlatform(platform: String, allPlatforms: Array[String], platformConfigs: Dictionary):
	_currentPlatform = platform
	_allPlatforms = allPlatforms
	_platformConfigs = platformConfigs

	# Update title
	_platformLabel.text = "Platform: " + platform

	# Populate clone dropdown
	_populateCloneDropdown()

	# Load current platform config
	_loadPlatformConfig()

	# Store original config for dirty checking
	_originalConfig = _getCurrentConfig()
	_isDirty = false

	# Show dialog as full-screen overlay
	visible = true

func _populateCloneDropdown():
	_cloneOptionButton.clear()
	_cloneOptionButton.add_item("-- Select Platform --", -1)

	var index = 1
	for platform in _allPlatforms:
		if platform != _currentPlatform:
			_cloneOptionButton.add_item(platform, index)
			index += 1

func _loadPlatformConfig():
	# Clear existing exclude lists
	_clearExcludeList(_functionExcludesList)
	_clearExcludeList(_variableExcludesList)

	if _currentPlatform in _platformConfigs:
		var config = _platformConfigs[_currentPlatform]
		_obfuscateFunctionsCheckBox.button_pressed = config.get("obfuscate_functions", false)
		_obfuscateVariablesCheckBox.button_pressed = config.get("obfuscate_variables", false)
		_obfuscateCommentsCheckBox.button_pressed = config.get("obfuscate_comments", false)

		# Load function excludes into dynamic list
		var functionExcludes = config.get("function_excludes", "")
		_populateExcludeList(_functionExcludesList, functionExcludes)

		# Load variable excludes into dynamic list
		var variableExcludes = config.get("variable_excludes", "")
		_populateExcludeList(_variableExcludesList, variableExcludes)

		# Use saved filters or default if empty
		var savedFilters = config.get("source_filters", "")
		_sourceFiltersLineEdit.text = savedFilters if savedFilters != "" else DEFAULT_SOURCE_FILTERS
	else:
		# Default config with common source filters
		_obfuscateFunctionsCheckBox.button_pressed = false
		_obfuscateVariablesCheckBox.button_pressed = false
		_obfuscateCommentsCheckBox.button_pressed = false
		_sourceFiltersLineEdit.text = DEFAULT_SOURCE_FILTERS

func _getCurrentConfig() -> Dictionary:
	return {
		"obfuscate_functions": _obfuscateFunctionsCheckBox.button_pressed,
		"obfuscate_variables": _obfuscateVariablesCheckBox.button_pressed,
		"obfuscate_comments": _obfuscateCommentsCheckBox.button_pressed,
		"function_excludes": _getExcludeListAsString(_functionExcludesList),
		"variable_excludes": _getExcludeListAsString(_variableExcludesList),
		"source_filters": _sourceFiltersLineEdit.text
	}

func _onCloneSelected(index: int):
	if index <= 0:
		return  # "-- Select Platform --" selected

	var selectedPlatform = _cloneOptionButton.get_item_text(index)

	if selectedPlatform in _platformConfigs:
		var sourceConfig = _platformConfigs[selectedPlatform]

		# Copy all settings from source platform
		_obfuscateFunctionsCheckBox.button_pressed = sourceConfig.get("obfuscate_functions", false)
		_obfuscateVariablesCheckBox.button_pressed = sourceConfig.get("obfuscate_variables", false)
		_obfuscateCommentsCheckBox.button_pressed = sourceConfig.get("obfuscate_comments", false)
		_sourceFiltersLineEdit.text = sourceConfig.get("source_filters", "")

		# Clone function excludes to dynamic list
		_clearExcludeList(_functionExcludesList)
		_populateExcludeList(_functionExcludesList, sourceConfig.get("function_excludes", ""))

		# Clone variable excludes to dynamic list
		_clearExcludeList(_variableExcludesList)
		_populateExcludeList(_variableExcludesList, sourceConfig.get("variable_excludes", ""))

		_isDirty = true

	# Reset dropdown to default
	_cloneOptionButton.select(0)

func _onSavePressed():
	# Get current config
	var config = _getCurrentConfig()

	# Emit signal to save changes
	config_saved.emit(_currentPlatform, config)

	# Mark as clean and close
	_isDirty = false
	visible = false

func _onCancelPressed():
	# Cancel just discards changes and closes - no prompt
	_isDirty = false
	cancelled.emit()
	visible = false

# Dynamic exclude list management functions

func _onAddFunctionPressed():
	_addExcludeEntry(_functionExcludesList, "")
	_isDirty = true

func _onAddVariablePressed():
	_addExcludeEntry(_variableExcludesList, "")
	_isDirty = true

func _onFunctionHelpPressed():
	_showHelpDialog("Function Excludes", FUNCTION_HELP_TEXT)

func _onVariableHelpPressed():
	_showHelpDialog("Variable Excludes", VARIABLE_HELP_TEXT)

func _showHelpDialog(titleText: String, content: String):
	# Create card-styled help dialog overlay
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100

	# Semi-transparent background to dim the dialog behind
	var dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.5)
	overlay.add_child(dimmer)

	# Center container for the dialog card
	var centerContainer = CenterContainer.new()
	centerContainer.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(centerContainer)

	# The dialog card panel
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(450, 0)
	centerContainer.add_child(card)

	# Apply card styling (rounded edges, border)
	var cardTheme = Theme.new()
	var cardStyleBox = StyleBoxFlat.new()
	cardStyleBox.bg_color = _getAdjustedBackgroundColor(-0.08)
	cardStyleBox.border_color = Color(0.6, 0.6, 0.6)
	cardStyleBox.border_width_left = 1
	cardStyleBox.border_width_top = 1
	cardStyleBox.border_width_right = 1
	cardStyleBox.border_width_bottom = 1
	cardStyleBox.corner_radius_top_left = 6
	cardStyleBox.corner_radius_top_right = 6
	cardStyleBox.corner_radius_bottom_right = 6
	cardStyleBox.corner_radius_bottom_left = 6
	cardTheme.set_stylebox("panel", "PanelContainer", cardStyleBox)
	card.theme = cardTheme

	# Card content VBox
	var cardContent = VBoxContainer.new()
	cardContent.add_theme_constant_override("separation", 0)
	card.add_child(cardContent)

	# Card header
	var header = PanelContainer.new()
	cardContent.add_child(header)

	# Header styling (bottom border only)
	var headerTheme = Theme.new()
	var headerStyleBox = StyleBoxFlat.new()
	headerStyleBox.bg_color = Color(0, 0, 0, 0)
	headerStyleBox.border_color = Color(0.6, 0.6, 0.6)
	headerStyleBox.border_width_bottom = 1
	headerTheme.set_stylebox("panel", "PanelContainer", headerStyleBox)
	header.theme = headerTheme

	# Header margin and label
	var headerMargin = MarginContainer.new()
	headerMargin.add_theme_constant_override("margin_left", 10)
	headerMargin.add_theme_constant_override("margin_top", 10)
	headerMargin.add_theme_constant_override("margin_right", 10)
	headerMargin.add_theme_constant_override("margin_bottom", 10)
	header.add_child(headerMargin)

	var headerLabel = Label.new()
	headerLabel.text = titleText
	headerLabel.add_theme_font_size_override("font_size", 16)
	headerMargin.add_child(headerLabel)

	# Card body with content
	var bodyMargin = MarginContainer.new()
	bodyMargin.add_theme_constant_override("margin_left", 15)
	bodyMargin.add_theme_constant_override("margin_top", 15)
	bodyMargin.add_theme_constant_override("margin_right", 15)
	bodyMargin.add_theme_constant_override("margin_bottom", 15)
	cardContent.add_child(bodyMargin)

	var bodyVBox = VBoxContainer.new()
	bodyVBox.add_theme_constant_override("separation", 12)
	bodyMargin.add_child(bodyVBox)

	# Help content label
	var contentLabel = Label.new()
	contentLabel.text = content
	contentLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bodyVBox.add_child(contentLabel)

	# Close button at bottom
	var buttonContainer = HBoxContainer.new()
	buttonContainer.alignment = BoxContainer.ALIGNMENT_END
	bodyVBox.add_child(buttonContainer)

	var closeButton = Button.new()
	closeButton.text = "Got it"
	closeButton.custom_minimum_size = Vector2(80, 32)
	closeButton.focus_mode = Control.FOCUS_NONE
	closeButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	closeButton.pressed.connect(func(): overlay.queue_free())
	buttonContainer.add_child(closeButton)

	# Click on dimmer also closes
	dimmer.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			overlay.queue_free()
	)

	add_child(overlay)

# Clears all entries from an exclude list
func _clearExcludeList(listContainer: VBoxContainer):
	for child in listContainer.get_children():
		child.queue_free()

# Populates an exclude list from a comma-separated string
func _populateExcludeList(listContainer: VBoxContainer, commaSeparatedString: String):
	if commaSeparatedString.strip_edges().is_empty():
		return

	var items = commaSeparatedString.split(",")
	for item in items:
		var trimmed = item.strip_edges()
		if not trimmed.is_empty():
			_addExcludeEntry(listContainer, trimmed)

# Adds a new exclude entry row (LineEdit + Remove button)
func _addExcludeEntry(listContainer: VBoxContainer, initialValue: String):
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lineEdit = LineEdit.new()
	lineEdit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lineEdit.text = initialValue
	lineEdit.placeholder_text = "Enter name..."
	lineEdit.text_changed.connect(_onInputChanged.unbind(1))
	row.add_child(lineEdit)

	var removeButton = Button.new()
	removeButton.text = "X"
	removeButton.custom_minimum_size = Vector2(28, 28)
	removeButton.focus_mode = Control.FOCUS_NONE
	removeButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	removeButton.pressed.connect(func(): _removeExcludeEntry(row))
	row.add_child(removeButton)

	listContainer.add_child(row)

	# Focus the new LineEdit if it's empty (user just clicked Add)
	if initialValue.is_empty():
		lineEdit.call_deferred("grab_focus")

# Removes an exclude entry row
func _removeExcludeEntry(row: HBoxContainer):
	row.queue_free()
	_isDirty = true

# Converts an exclude list to a comma-separated string for storage
func _getExcludeListAsString(listContainer: VBoxContainer) -> String:
	var items: Array[String] = []
	for child in listContainer.get_children():
		if child is HBoxContainer:
			var lineEdit = child.get_child(0)
			if lineEdit is LineEdit:
				var text = lineEdit.text.strip_edges()
				if not text.is_empty():
					items.append(text)
	return ", ".join(items)
