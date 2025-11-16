extends Window

signal config_saved(platform: String, config: Dictionary)

@onready var _platformLabel = %PlatformLabel
@onready var _cloneOptionButton = %CloneOptionButton
@onready var _obfuscateFunctionsCheckBox = %ObfuscateFunctionsCheckBox
@onready var _obfuscateVariablesCheckBox = %ObfuscateVariablesCheckBox
@onready var _obfuscateCommentsCheckBox = %ObfuscateCommentsCheckBox
@onready var _functionExcludeLineEdit = %FunctionExcludeLineEdit
@onready var _variableExcludeLineEdit = %VariableExcludeLineEdit
@onready var _sourceFiltersLineEdit = %SourceFiltersLineEdit
@onready var _backgroundPanel = %BackgroundPanel

var _currentPlatform: String = ""
var _allPlatforms: Array[String] = []
var _platformConfigs: Dictionary = {}  # platform -> config dict
var _isDirty: bool = false
var _originalConfig: Dictionary = {}

const DEFAULT_SOURCE_FILTERS = ".git, .godot, .import, builds, exports, .vscode, .vs"

func _ready():
	_cloneOptionButton.item_selected.connect(_onCloneSelected)
	_applyTheme()

	# Connect all input signals to mark dirty
	_obfuscateFunctionsCheckBox.toggled.connect(_onInputChanged.unbind(1))
	_obfuscateVariablesCheckBox.toggled.connect(_onInputChanged.unbind(1))
	_obfuscateCommentsCheckBox.toggled.connect(_onInputChanged.unbind(1))
	_functionExcludeLineEdit.text_changed.connect(_onInputChanged.unbind(1))
	_variableExcludeLineEdit.text_changed.connect(_onInputChanged.unbind(1))
	_sourceFiltersLineEdit.text_changed.connect(_onInputChanged.unbind(1))

func _onInputChanged():
	_isDirty = true

func _applyTheme():
	# Apply the app's background color theme to the background panel
	var customTheme = Theme.new()
	var styleBox = StyleBoxFlat.new()
	styleBox.bg_color = _getAdjustedBackgroundColor(-0.08)
	styleBox.border_color = Color(0.6, 0.6, 0.6)
	styleBox.border_width_left = 2
	styleBox.border_width_top = 2
	styleBox.border_width_right = 2
	styleBox.border_width_bottom = 2
	styleBox.corner_radius_top_left = 6
	styleBox.corner_radius_top_right = 6
	styleBox.corner_radius_bottom_right = 6
	styleBox.corner_radius_bottom_left = 6

	customTheme.set_stylebox("panel", "Panel", styleBox)
	_backgroundPanel.theme = customTheme

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

	# Show as modal dialog
	popup_centered()
	grab_focus()

	# Make it modal (blocks interaction with parent window)
	transient = true
	exclusive = true

func _populateCloneDropdown():
	_cloneOptionButton.clear()
	_cloneOptionButton.add_item("-- Select Platform --", -1)

	var index = 1
	for platform in _allPlatforms:
		if platform != _currentPlatform:
			_cloneOptionButton.add_item(platform, index)
			index += 1

func _loadPlatformConfig():
	if _currentPlatform in _platformConfigs:
		var config = _platformConfigs[_currentPlatform]
		_obfuscateFunctionsCheckBox.button_pressed = config.get("obfuscate_functions", false)
		_obfuscateVariablesCheckBox.button_pressed = config.get("obfuscate_variables", false)
		_obfuscateCommentsCheckBox.button_pressed = config.get("obfuscate_comments", false)
		_functionExcludeLineEdit.text = config.get("function_excludes", "")
		_variableExcludeLineEdit.text = config.get("variable_excludes", "")

		# Use saved filters or default if empty
		var savedFilters = config.get("source_filters", "")
		_sourceFiltersLineEdit.text = savedFilters if savedFilters != "" else DEFAULT_SOURCE_FILTERS
	else:
		# Default config with common source filters
		_obfuscateFunctionsCheckBox.button_pressed = false
		_obfuscateVariablesCheckBox.button_pressed = false
		_obfuscateCommentsCheckBox.button_pressed = false
		_functionExcludeLineEdit.text = ""
		_variableExcludeLineEdit.text = ""
		_sourceFiltersLineEdit.text = DEFAULT_SOURCE_FILTERS

func _getCurrentConfig() -> Dictionary:
	return {
		"obfuscate_functions": _obfuscateFunctionsCheckBox.button_pressed,
		"obfuscate_variables": _obfuscateVariablesCheckBox.button_pressed,
		"obfuscate_comments": _obfuscateCommentsCheckBox.button_pressed,
		"function_excludes": _functionExcludeLineEdit.text,
		"variable_excludes": _variableExcludeLineEdit.text,
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
		_functionExcludeLineEdit.text = sourceConfig.get("function_excludes", "")
		_variableExcludeLineEdit.text = sourceConfig.get("variable_excludes", "")
		_sourceFiltersLineEdit.text = sourceConfig.get("source_filters", "")

	# Reset dropdown to default
	_cloneOptionButton.select(0)

func _onSavePressed():
	# Get current config
	var config = _getCurrentConfig()

	# Emit signal to save changes
	config_saved.emit(_currentPlatform, config)

	# Mark as clean and close
	_isDirty = false
	hide()

func _onCancelPressed():
	# Cancel just discards changes and closes - no prompt
	_isDirty = false
	hide()

func _onCloseRequested():
	# X button prompts if dirty
	if _isDirty:
		# Prompt user to save changes
		var confirmDialog = _getConfirmationDialog()
		confirmDialog.show_dialog("You have unsaved changes. What would you like to do?")
		var choice = await confirmDialog.confirmed

		if choice == "save":
			# Save and close
			_onSavePressed()
		elif choice == "dont_save":
			# Discard changes and close
			_isDirty = false
			hide()
		# else "cancel": Keep dialog open
	else:
		# No changes, just close
		hide()

func _getConfirmationDialog():
	# Get or create confirmation dialog
	var confirmDialog = get_node_or_null("ConfirmationDialog")
	if confirmDialog == null:
		# Load the confirmation dialog scene
		confirmDialog = load("res://scenes/common/confirmation-dialog.tscn").instantiate()
		confirmDialog.name = "ConfirmationDialog"
		add_child(confirmDialog)
	return confirmDialog
