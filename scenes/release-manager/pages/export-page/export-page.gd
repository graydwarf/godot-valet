extends WizardPageBase

# FluentUI icons for dynamic buttons
const ICON_FOLDER_OPEN = preload("res://scenes/release-manager/assets/fluent-icons/folder-open.svg")
const ICON_SETTINGS = preload("res://scenes/release-manager/assets/fluent-icons/settings.svg")
const ICON_PLAY = preload("res://scenes/release-manager/assets/fluent-icons/play.svg")
const ICON_EDIT = preload("res://scenes/release-manager/assets/fluent-icons/edit.svg")
const ICON_ARROW_EXPORT = preload("res://scenes/release-manager/assets/fluent-icons/arrow-export.svg")
const ICON_DISMISS = preload("res://scenes/release-manager/assets/fluent-icons/dismiss.svg")
const ICON_ARROW_RIGHT = preload("res://scenes/release-manager/assets/fluent-icons/arrow-right.svg")
const ICON_CHEVRON_DOWN = preload("res://scenes/release-manager/assets/fluent-icons/chevron-down.svg")
const ICON_CHEVRON_UP = preload("res://scenes/release-manager/assets/fluent-icons/chevron-up.svg")

signal build_started(platform: String)
signal build_completed(platform: String, success: bool)
signal version_changed(old_version: String, new_version: String)
signal page_modified()  # Emitted when any input is changed
signal page_saved()  # Emitted after successful save to reset dirty flag

@onready var _platformsContainer = %PlatformsContainer
@onready var _exportSelectedButton = %ExportSelectedButton
@onready var _projectVersionLineEdit = %ProjectVersionLineEdit
@onready var _projectVersionCard = %ProjectVersionCard
@onready var _refreshButton = %RefreshButton
@onready var _editProjectButton = %EditProjectButton

var _platformRows: Dictionary = {}  # platform_name -> {mainRow, checkbox, detailsSection, exportPath, exportFilename, obfuscation, button, configButton}
var _exportingPlatforms: Array[String] = []
var _currentVersion: String = ""  # Store current version for comparison
var _platformBuildConfigs: Dictionary = {}  # platform_name -> build config dict
var _platformPathTemplates: Dictionary = {}  # platform_name -> path template array
var _platformRootPaths: Dictionary = {}  # platform_name -> root export path (without template)
var _buildConfigDialog: Control = null
var _pathSettingsDialog: Control = null
var _filterDialog: Control = null
var _yesNoDialog: Control = null
var _inputBlocker: Control = null  # Full-screen overlay to block all input during export
var _exportCancelled: bool = false  # Flag to track if user cancelled export
var _platformFilterConfigs: Dictionary = {}  # platform_name -> filter config dict
var _platformExportFilenameTemplates: Dictionary = {}  # platform_name -> export filename template array
var _platformArchiveFilenameTemplates: Dictionary = {}  # platform_name -> archive filename template array
var _platformArchiveSync: Dictionary = {}  # platform_name -> bool (whether archive syncs with export)
var _filenameSettingsDialog: Control = null
var _currentFilenameDialogPlatform: String = ""  # Platform being configured
var _currentFilenameDialogType: String = ""  # "export" or "archive"
var _isLoadingData: bool = false  # Suppresses page_modified during _loadPageData()
var _platformExportOutput: Dictionary = {}  # platform_name -> last export output string

func _ready():
	_exportSelectedButton.pressed.connect(_onExportSelectedPressed)
	_projectVersionLineEdit.text_changed.connect(_onVersionChanged)
	_refreshButton.pressed.connect(_onRefreshPressed)
	_editProjectButton.pressed.connect(_onEditProjectPressed)

	# Create build config dialog (Control, not Window)
	# Note: Will be added to root when shown so it covers entire wizard
	_buildConfigDialog = load("res://scenes/release-manager/pages/export-page/dialogs/build-config-dialog/build-config-dialog.tscn").instantiate()
	_buildConfigDialog.config_saved.connect(_onBuildConfigSaved)
	_buildConfigDialog.visible = false  # Start hidden

	# Create export path settings page (Control, not Window)
	# Note: Will be added to root when shown so it covers entire wizard
	_pathSettingsDialog = load("res://scenes/release-manager/pages/export-page/dialogs/export-path-settings-dialog/export-path-settings-dialog.tscn").instantiate()
	_pathSettingsDialog.settings_saved.connect(_onPathSettingsSaved)
	_pathSettingsDialog.cancelled.connect(_onPathSettingsCancelled)
	_pathSettingsDialog.visible = false  # Start hidden

	# Create include/exclude filter dialog (Control, not Window)
	_filterDialog = load("res://scenes/release-manager/pages/export-page/dialogs/source-export-filter-dialog/source-export-filter-dialog.tscn").instantiate()
	_filterDialog.settings_saved.connect(_onFilterSettingsSaved)
	_filterDialog.cancelled.connect(_onFilterSettingsCancelled)
	_filterDialog.visible = false  # Start hidden

	# Create yes/no dialog for overwrite confirmation (add to root for full screen coverage)
	_yesNoDialog = load("res://scenes/common/yes-no-dialog.tscn").instantiate()
	# Will be added to root when first shown

	# Create full-screen input blocker overlay (will be added to root when needed)
	_createInputBlocker()

	# Style the Project Version card to match platform cards
	_styleProjectVersionCard()

func _styleProjectVersionCard():
	# Apply card theme (same as platform cards)
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
	_projectVersionCard.theme = panelTheme

	# Style header container (bottom border only)
	var headerContainer = _projectVersionCard.get_node("VBoxContainer/HeaderContainer")
	var headerTheme = Theme.new()
	var headerStyleBox = StyleBoxFlat.new()
	headerStyleBox.bg_color = Color(0, 0, 0, 0)  # Transparent background
	headerStyleBox.border_color = Color(0.6, 0.6, 0.6)
	headerStyleBox.border_width_bottom = 1
	headerTheme.set_stylebox("panel", "PanelContainer", headerStyleBox)
	headerContainer.theme = headerTheme

	# Style content container (transparent)
	var contentContainer = _projectVersionCard.get_node("VBoxContainer/ContentContainer")
	var contentTheme = Theme.new()
	var contentStyleBox = StyleBoxFlat.new()
	contentStyleBox.bg_color = Color(0, 0, 0, 0)
	contentTheme.set_stylebox("panel", "PanelContainer", contentStyleBox)
	contentContainer.theme = contentTheme

func _loadPageData():
	if _selectedProjectItem == null:
		return

	# Suppress page_modified during data loading (not user changes)
	_isLoadingData = true

	# Load project version
	_currentVersion = _selectedProjectItem.GetProjectVersion()
	_projectVersionLineEdit.text = _currentVersion

	_clearPlatformRows()
	_createPlatformRows()
	_loadPlatformSettings()

	# Update Export Selected button state based on loaded settings
	_updateExportSelectedButtonState()

	_isLoadingData = false

func _clearPlatformRows():
	for child in _platformsContainer.get_children():
		child.queue_free()
	_platformRows.clear()

func _loadPlatformSettings():
	if _selectedProjectItem == null:
		return

	var allSettings = _selectedProjectItem.GetAllPlatformExportSettings()

	for platform in _platformRows.keys():
		var data = _platformRows[platform]

		# Clear status label on page load
		data["status"].text = ""

		if platform in allSettings:
			var settings = allSettings[platform]

			# Restore settings
			var rootPath = settings.get("exportPath", "")

			# If no root path saved, use project directory + exports as default
			if rootPath.is_empty() and _selectedProjectItem != null and is_instance_valid(_selectedProjectItem):
				# GetProjectDir() handles both path formats (with or without project.godot)
				var projectDir = _selectedProjectItem.GetProjectDir()
				rootPath = projectDir.path_join("exports")

			_platformRootPaths[platform] = rootPath  # Store root path separately

			# Load filename templates and sync state
			var exportFilenameTemplate = settings.get("exportFilenameTemplate", [{"type": "project"}])
			var archiveFilenameTemplate = settings.get("archiveFilenameTemplate", [{"type": "project"}])
			var archiveSync = settings.get("archiveSync", false)

			_platformExportFilenameTemplates[platform] = exportFilenameTemplate
			_platformArchiveFilenameTemplates[platform] = archiveFilenameTemplate
			_platformArchiveSync[platform] = archiveSync

			# Update filename displays
			_updateExportFilenameDisplay(platform)
			_updateArchiveFilenameDisplay(platform)

			# Restore build config (obfuscation settings)
			if settings.has("buildConfig"):
				_platformBuildConfigs[platform] = settings["buildConfig"]
				_updateObfuscationDisplay(platform, settings["buildConfig"])

			# Restore filter config (include/exclude settings)
			if settings.has("filterConfig"):
				_platformFilterConfigs[platform] = settings["filterConfig"]
				_updateIncludeExcludeDisplay(platform, settings["filterConfig"])

			# Restore path template (default: version then platform)
			if settings.has("pathTemplate"):
				_platformPathTemplates[platform] = settings["pathTemplate"]
			else:
				_platformPathTemplates[platform] = [
					{"type": "version"},
					{"type": "platform"}
				]

			# Update export path display with template
			_updateExportPathDisplay(platform)

			# Restore filter config (include/exclude settings)
			if settings.has("filterConfig"):
				_platformFilterConfigs[platform] = settings["filterConfig"]
				_updateIncludeExcludeDisplay(platform, settings["filterConfig"])

			# Restore export options
			var exportType = settings.get("exportType", 0)  # Default: Release
			var packageType = settings.get("packageType", 0)  # Default: No Zip
			var generateChecksum = settings.get("generateChecksum", false)

			data["exportTypeOption"].selected = exportType
			data["packageTypeOption"].selected = packageType
			data["checksumCheckbox"].button_pressed = generateChecksum

			# Restore rename to index.html setting (Web platform only)
			if platform == "Web" and data["renameToIndexCheckbox"] != null:
				var renameToIndex = settings.get("renameToIndex", false)
				data["renameToIndexCheckbox"].button_pressed = renameToIndex

			# Update checksum tooltip and visibility based on loaded package type
			var isZip = (packageType == 1)
			data["checksumCheckbox"].tooltip_text = _getChecksumTooltip(platform, isZip)

			# Show/hide archive filename based on package type (all platforms use inline container)
			if data.has("archiveContainer") and data["archiveContainer"] != null:
				data["archiveContainer"].visible = isZip
			# For Source platform, show checksum only when Zip selected
			if platform == "Source":
				data["checksumContainer"].visible = isZip

			# Restore enabled state
			var isEnabled = settings.get("enabled", false)
			data["checkbox"].button_pressed = isEnabled

			# Show/hide details section based on enabled state
			data["detailsSection"].visible = isEnabled
			# Enable/disable all export action buttons
			_setExportButtonsDisabled(data, !isEnabled)
			# Keep Export & Run disabled if Zip is selected (can't run a zip file)
			if isZip and is_instance_valid(data["exportAndRunButton"]):
				data["exportAndRunButton"].disabled = true
		else:
			# No saved settings - apply defaults for first-time use
			if _selectedProjectItem != null and is_instance_valid(_selectedProjectItem):
				# GetProjectDir() handles both path formats (with or without project.godot)
				var projectDir = _selectedProjectItem.GetProjectDir()

				# Set default root path: project_directory/exports
				var rootPath = projectDir.path_join("exports")
				_platformRootPaths[platform] = rootPath

				# Set default filename templates: project name only
				_platformExportFilenameTemplates[platform] = [{"type": "project"}]
				_platformArchiveFilenameTemplates[platform] = [{"type": "project"}]
				_platformArchiveSync[platform] = false  # Default to not synced

				# Update filename displays
				_updateExportFilenameDisplay(platform)
				_updateArchiveFilenameDisplay(platform)

				# Set default path template: version, platform
				_platformPathTemplates[platform] = [
					{"type": "version"},
					{"type": "platform"}
				]

				# Update display to show full path with defaults
				_updateExportPathDisplay(platform)

func _createPlatformRows():
	# Get configured export presets from the project
	var platforms = _selectedProjectItem.GetAvailableExportPresets()

	# Always add "Source" as a built-in option (copies project as-is)
	platforms.insert(0, "Source")

	# Create rows for each platform (including Source)
	for platform in platforms:
		var card = _createPlatformCard(platform)
		_platformsContainer.add_child(card)

# gdlint:ignore-function:long-function
func _createPlatformCard(platform: String) -> PanelContainer:
	# Outer panel with rounded edges
	var panelContainer = PanelContainer.new()

	# Apply styled theme
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
	panelContainer.theme = panelTheme

	# Platform content - no inner margin, header uses parent's borders
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 0)
	panelContainer.add_child(container)

	# === Header Row Container (bottom border only) ===
	var headerContainer = PanelContainer.new()
	headerContainer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Header container theme (transparent bg, bottom border only)
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

	# Header inner margin
	var headerMargin = MarginContainer.new()
	headerMargin.add_theme_constant_override("margin_left", 10)
	headerMargin.add_theme_constant_override("margin_top", 10)
	headerMargin.add_theme_constant_override("margin_right", 10)
	headerMargin.add_theme_constant_override("margin_bottom", 10)
	headerMargin.mouse_filter = Control.MOUSE_FILTER_PASS  # Pass clicks through to header
	headerContainer.add_child(headerMargin)

	# === Main Row (always visible) ===
	var mainRow = HBoxContainer.new()
	mainRow.add_theme_constant_override("separation", 10)
	mainRow.mouse_filter = Control.MOUSE_FILTER_PASS  # Pass clicks through to header
	headerMargin.add_child(mainRow)

	# Checkbox
	var checkbox = CheckBox.new()
	checkbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	checkbox.name = "Checkbox"
	checkbox.focus_mode = Control.FOCUS_NONE
	checkbox.toggled.connect(_onPlatformToggled.bind(platform))
	checkbox.toggled.connect(_onInputChanged.unbind(1))
	mainRow.add_child(checkbox)

	# Platform name label
	var nameLabel = Label.new()
	nameLabel.text = platform
	nameLabel.custom_minimum_size = Vector2(150, 0)
	nameLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nameLabel.mouse_filter = Control.MOUSE_FILTER_PASS  # Pass clicks through to header
	mainRow.add_child(nameLabel)

	# Spacer to push status and export button to the right
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_PASS  # Pass clicks through to header
	mainRow.add_child(spacer)

	# Status label (now takes up the space where export button was)
	var statusLabel = Label.new()
	statusLabel.text = ""
	statusLabel.custom_minimum_size = Vector2(100, 0)
	statusLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	statusLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	statusLabel.name = "StatusLabel"
	statusLabel.mouse_filter = Control.MOUSE_FILTER_PASS  # Pass clicks through to header
	mainRow.add_child(statusLabel)

	# Make header clickable to toggle checkbox when minimized
	headerContainer.gui_input.connect(_onPlatformHeaderClicked.bind(platform, checkbox))
	headerContainer.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	container.add_child(headerContainer)

	# === Details Section (visible when checkbox checked) ===
	var detailsSection = MarginContainer.new()
	detailsSection.add_theme_constant_override("margin_left", 50)  # Indent from left edge
	detailsSection.add_theme_constant_override("margin_top", 10)  # Top padding
	detailsSection.add_theme_constant_override("margin_right", 10)  # Right padding
	detailsSection.add_theme_constant_override("margin_bottom", 10)  # Bottom padding
	detailsSection.visible = false
	detailsSection.name = "DetailsSection"

	var detailsVBox = VBoxContainer.new()
	detailsVBox.add_theme_constant_override("separation", 8)

	# Export Path Row
	var exportPathRow = HBoxContainer.new()
	exportPathRow.add_theme_constant_override("separation", 5)

	var exportPathLabel = Label.new()
	exportPathLabel.text = "Export Path:"
	exportPathLabel.custom_minimum_size = Vector2(130, 0)
	exportPathLabel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	exportPathLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	exportPathLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exportPathRow.add_child(exportPathLabel)

	var exportPathEdit = LineEdit.new()
	exportPathEdit.placeholder_text = "No export path configured"
	exportPathEdit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exportPathEdit.name = "ExportPathEdit"
	exportPathEdit.editable = false
	exportPathEdit.selecting_enabled = true
	exportPathEdit.context_menu_enabled = true
	exportPathEdit.text_changed.connect(_onInputChanged)
	exportPathRow.add_child(exportPathEdit)

	var openFolderButton = Button.new()
	openFolderButton.icon = ICON_FOLDER_OPEN
	openFolderButton.expand_icon = true
	openFolderButton.custom_minimum_size = Vector2(32, 31)
	openFolderButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	openFolderButton.tooltip_text = "Open export folder"
	openFolderButton.pressed.connect(_onOpenFolderButtonPressed.bind(platform))
	exportPathRow.add_child(openFolderButton)

	var pathSettingsButton = Button.new()
	pathSettingsButton.icon = ICON_SETTINGS
	pathSettingsButton.expand_icon = true
	pathSettingsButton.custom_minimum_size = Vector2(32, 31)
	pathSettingsButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pathSettingsButton.tooltip_text = "Configure export path and structure"
	pathSettingsButton.pressed.connect(_onPathSettingsPressed.bind(platform))
	exportPathRow.add_child(pathSettingsButton)

	detailsVBox.add_child(exportPathRow)

	# Export Filename Row (hidden for Source platform - no executable)
	var filenameRow = HBoxContainer.new()
	filenameRow.add_theme_constant_override("separation", 5)
	filenameRow.visible = (platform != "Source")

	var filenameLabel = Label.new()
	filenameLabel.text = _getExportFileLabel(platform)
	filenameLabel.custom_minimum_size = Vector2(130, 0)
	filenameLabel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	filenameLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	filenameLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	filenameRow.add_child(filenameLabel)

	var filenameEdit = LineEdit.new()
	filenameEdit.placeholder_text = "No filename configured"
	filenameEdit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filenameEdit.name = "ExportFilenameEdit"
	filenameEdit.editable = false
	filenameEdit.selecting_enabled = true
	filenameEdit.context_menu_enabled = true
	filenameRow.add_child(filenameEdit)

	var filenameOptionsButton = Button.new()
	filenameOptionsButton.icon = ICON_SETTINGS
	filenameOptionsButton.expand_icon = true
	filenameOptionsButton.custom_minimum_size = Vector2(32, 31)
	filenameOptionsButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	filenameOptionsButton.tooltip_text = "Configure export filename"
	filenameOptionsButton.pressed.connect(_onExportFilenameOptionsPressed.bind(platform))
	filenameOptionsButton.name = "ExportFilenameOptionsButton"
	filenameRow.add_child(filenameOptionsButton)

	# Rename to index.html checkbox (Web platform only)
	var renameToIndexCheckbox: CheckBox = null
	if platform == "Web":
		renameToIndexCheckbox = CheckBox.new()
		renameToIndexCheckbox.icon = ICON_ARROW_RIGHT
		renameToIndexCheckbox.text = "index.html"
		renameToIndexCheckbox.tooltip_text = "Rename HTML file to index.html (required for itch.io)"
		renameToIndexCheckbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		renameToIndexCheckbox.name = "RenameToIndexCheckbox"
		renameToIndexCheckbox.toggled.connect(_onInputChanged.unbind(1))
		renameToIndexCheckbox.toggled.connect(_onRenameToIndexToggled.bind(platform).unbind(1))
		filenameRow.add_child(renameToIndexCheckbox)

	detailsVBox.add_child(filenameRow)

	# Archive variables (used later when creating inline archive container)
	var archiveEdit: LineEdit = null
	var archiveOptionsButton: Button = null

	# Obfuscation Row
	var obfuscationRow = HBoxContainer.new()
	obfuscationRow.add_theme_constant_override("separation", 5)

	var obfuscationLabel = Label.new()
	obfuscationLabel.text = "Obfuscation:"
	obfuscationLabel.custom_minimum_size = Vector2(130, 0)
	obfuscationLabel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	obfuscationLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	obfuscationLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	obfuscationRow.add_child(obfuscationLabel)

	var obfuscationDisplay = LineEdit.new()
	obfuscationDisplay.placeholder_text = "None"
	obfuscationDisplay.editable = false
	obfuscationDisplay.selecting_enabled = true
	obfuscationDisplay.context_menu_enabled = true
	obfuscationDisplay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	obfuscationDisplay.name = "ObfuscationDisplay"
	obfuscationRow.add_child(obfuscationDisplay)

	# Settings cog button
	var configButton = Button.new()
	configButton.icon = ICON_SETTINGS
	configButton.expand_icon = true
	configButton.custom_minimum_size = Vector2(32, 31)
	configButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	configButton.tooltip_text = "Configure obfuscation settings for this platform"
	configButton.pressed.connect(_onConfigButtonPressed.bind(platform))
	configButton.name = "ConfigButton"
	obfuscationRow.add_child(configButton)

	detailsVBox.add_child(obfuscationRow)

	# Include/Exclude Row
	var includeExcludeRow = HBoxContainer.new()
	includeExcludeRow.add_theme_constant_override("separation", 5)

	var includeExcludeLabel = Label.new()
	includeExcludeLabel.text = "Include/Exclude:"
	includeExcludeLabel.custom_minimum_size = Vector2(130, 0)
	includeExcludeLabel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	includeExcludeLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	includeExcludeLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	includeExcludeRow.add_child(includeExcludeLabel)

	var includeExcludeDisplay = LineEdit.new()
	includeExcludeDisplay.placeholder_text = "No filters configured"
	includeExcludeDisplay.editable = false
	includeExcludeDisplay.selecting_enabled = true
	includeExcludeDisplay.context_menu_enabled = true
	includeExcludeDisplay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	includeExcludeDisplay.name = "IncludeExcludeDisplay"
	includeExcludeRow.add_child(includeExcludeDisplay)

	var includeExcludeConfigButton = Button.new()
	includeExcludeConfigButton.icon = ICON_SETTINGS
	includeExcludeConfigButton.expand_icon = true
	includeExcludeConfigButton.custom_minimum_size = Vector2(32, 31)
	includeExcludeConfigButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	includeExcludeConfigButton.tooltip_text = "Configure include/exclude settings"
	includeExcludeConfigButton.pressed.connect(_onIncludeExcludeConfigPressed.bind(platform))
	includeExcludeConfigButton.name = "IncludeExcludeConfigButton"
	includeExcludeRow.add_child(includeExcludeConfigButton)

	detailsVBox.add_child(includeExcludeRow)

	# Export Options Row
	var exportOptionsRow = HBoxContainer.new()
	exportOptionsRow.add_theme_constant_override("separation", 15)

	var exportOptionsLabel = Label.new()
	exportOptionsLabel.text = "Export Options:"
	exportOptionsLabel.custom_minimum_size = Vector2(130, 0)
	exportOptionsLabel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	exportOptionsLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	exportOptionsLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exportOptionsRow.add_child(exportOptionsLabel)

	# Export Type DDL (hidden for Source platform)
	var exportTypeContainer = HBoxContainer.new()
	exportTypeContainer.add_theme_constant_override("separation", 5)
	exportTypeContainer.visible = (platform != "Source")  # Hide for Source

	var exportTypeLabel = Label.new()
	exportTypeLabel.text = "Type:"
	exportTypeLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exportTypeContainer.add_child(exportTypeLabel)

	var exportTypeOption = OptionButton.new()
	exportTypeOption.add_item("Release", 0)
	exportTypeOption.add_item("Debug", 1)
	exportTypeOption.custom_minimum_size = Vector2(90, 0)
	exportTypeOption.name = "ExportTypeOption"
	exportTypeOption.item_selected.connect(_onInputChanged.unbind(1))
	exportTypeContainer.add_child(exportTypeOption)

	exportOptionsRow.add_child(exportTypeContainer)

	# Package Type DDL
	var packageTypeContainer = HBoxContainer.new()
	packageTypeContainer.add_theme_constant_override("separation", 5)

	var packageTypeLabel = Label.new()
	packageTypeLabel.text = "Package:"
	packageTypeLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	packageTypeContainer.add_child(packageTypeLabel)

	var packageTypeOption = OptionButton.new()
	packageTypeOption.add_item("No Zip", 0)
	packageTypeOption.add_item("Zip", 1)
	packageTypeOption.custom_minimum_size = Vector2(90, 0)
	packageTypeOption.name = "PackageTypeOption"
	packageTypeOption.item_selected.connect(_onInputChanged.unbind(1))
	packageTypeContainer.add_child(packageTypeOption)

	exportOptionsRow.add_child(packageTypeContainer)

	# Archive filename inline with Package dropdown (for all platforms, hidden when No Zip)
	var archiveContainer: HBoxContainer = HBoxContainer.new()
	archiveContainer.add_theme_constant_override("separation", 5)
	archiveContainer.visible = false  # Hidden by default (No Zip is default)
	archiveContainer.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Expand to fill available width

	# Archive name label
	var archiveLabel = Label.new()
	archiveLabel.text = "Archive:"
	archiveLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	archiveContainer.add_child(archiveLabel)

	# Archive filename edit - expand to fill available width
	archiveEdit = LineEdit.new()
	archiveEdit.placeholder_text = "No archive name configured"
	archiveEdit.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Expand to fill available width
	archiveEdit.name = "ArchiveFilenameEdit"
	archiveEdit.editable = false
	archiveEdit.selecting_enabled = true
	archiveEdit.context_menu_enabled = true
	archiveContainer.add_child(archiveEdit)

	# Archive options button
	archiveOptionsButton = Button.new()
	archiveOptionsButton.icon = ICON_SETTINGS
	archiveOptionsButton.expand_icon = true
	archiveOptionsButton.custom_minimum_size = Vector2(32, 31)
	archiveOptionsButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	archiveOptionsButton.tooltip_text = "Configure archive filename"
	archiveOptionsButton.pressed.connect(_onArchiveFilenameOptionsPressed.bind(platform))
	archiveOptionsButton.name = "ArchiveFilenameOptionsButton"
	archiveContainer.add_child(archiveOptionsButton)

	exportOptionsRow.add_child(archiveContainer)

	# Generate Checksum checkbox (hidden for Source platform unless Zip selected)
	var checksumContainer = HBoxContainer.new()
	checksumContainer.add_theme_constant_override("separation", 5)
	checksumContainer.visible = (platform != "Source")  # Hide for Source by default (shows when Zip selected)

	var checksumCheckbox = CheckBox.new()
	checksumCheckbox.text = "Checksum"
	checksumCheckbox.name = "ChecksumCheckbox"
	checksumCheckbox.tooltip_text = _getChecksumTooltip(platform, false)  # false = no zip by default
	checksumCheckbox.toggled.connect(_onInputChanged.unbind(1))
	checksumContainer.add_child(checksumCheckbox)

	exportOptionsRow.add_child(checksumContainer)

	# Update checksum tooltip and visibility when package type changes
	packageTypeOption.item_selected.connect(_onPackageTypeChanged.bind(platform, checksumCheckbox, checksumContainer))

	detailsVBox.add_child(exportOptionsRow)

	# === Export Actions Row (buttons vary by platform) ===
	var exportActionsRow = HBoxContainer.new()
	exportActionsRow.add_theme_constant_override("separation", 15)

	var exportActionsLabel = Label.new()
	exportActionsLabel.text = "Export Actions:"
	exportActionsLabel.custom_minimum_size = Vector2(130, 0)
	exportActionsLabel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	exportActionsLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	exportActionsLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exportActionsRow.add_child(exportActionsLabel)

	# Spacer to push buttons to the right
	var exportActionsSpacer = Control.new()
	exportActionsSpacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exportActionsRow.add_child(exportActionsSpacer)

	# Export & Run button (all platforms)
	var exportAndRunButton = Button.new()
	exportAndRunButton.text = "Export & Run"
	exportAndRunButton.icon = ICON_PLAY
	exportAndRunButton.custom_minimum_size = Vector2(125, 31)
	exportAndRunButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	exportAndRunButton.tooltip_text = "Export and then run the exported application"
	exportAndRunButton.pressed.connect(_onExportAndRunPressed.bind(platform))
	exportAndRunButton.name = "ExportAndRunButton"
	exportAndRunButton.disabled = true
	exportActionsRow.add_child(exportAndRunButton)

	# Export & Edit button (Source platform only)
	var exportAndEditButton: Button = null
	if platform == "Source":
		exportAndEditButton = Button.new()
		exportAndEditButton.text = "Export & Edit"
		exportAndEditButton.icon = ICON_EDIT
		exportAndEditButton.custom_minimum_size = Vector2(125, 31)
		exportAndEditButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		exportAndEditButton.tooltip_text = "Export source and then open in Godot Editor"
		exportAndEditButton.pressed.connect(_onExportAndEditPressed.bind(platform))
		exportAndEditButton.name = "ExportAndEditButton"
		exportAndEditButton.disabled = true
		exportActionsRow.add_child(exportAndEditButton)

	# Export & Open button (all platforms)
	var exportAndOpenButton = Button.new()
	exportAndOpenButton.text = "Export & Open"
	exportAndOpenButton.icon = ICON_FOLDER_OPEN
	exportAndOpenButton.custom_minimum_size = Vector2(130, 31)
	exportAndOpenButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	exportAndOpenButton.tooltip_text = "Export and then open the export folder"
	exportAndOpenButton.pressed.connect(_onExportAndOpenPressed.bind(platform))
	exportAndOpenButton.name = "ExportAndOpenButton"
	exportAndOpenButton.disabled = true
	exportActionsRow.add_child(exportAndOpenButton)

	# Export button (all platforms)
	var exportButton = Button.new()
	exportButton.text = "Export"
	exportButton.icon = ICON_ARROW_EXPORT
	exportButton.custom_minimum_size = Vector2(100, 31)
	exportButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	exportButton.tooltip_text = "Export without any post-export action"
	exportButton.pressed.connect(_onExportPressed.bind(platform))
	exportButton.name = "ExportButton"
	exportButton.disabled = true
	exportActionsRow.add_child(exportButton)

	# Output log toggle button (always visible)
	var outputLogToggle = Button.new()
	outputLogToggle.icon = ICON_CHEVRON_DOWN
	outputLogToggle.expand_icon = true
	outputLogToggle.custom_minimum_size = Vector2(32, 31)
	outputLogToggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	outputLogToggle.tooltip_text = "Show export output"
	outputLogToggle.pressed.connect(_onOutputLogTogglePressed.bind(platform))
	outputLogToggle.name = "OutputLogToggle"
	exportActionsRow.add_child(outputLogToggle)

	detailsVBox.add_child(exportActionsRow)

	# Output log area (hidden by default, shown when toggle clicked)
	var outputLogContainer = HBoxContainer.new()
	outputLogContainer.name = "OutputLogContainer"
	outputLogContainer.visible = false
	outputLogContainer.add_theme_constant_override("separation", 5)

	var outputLogLabel = Label.new()
	outputLogLabel.text = "Export Output:"
	outputLogLabel.custom_minimum_size = Vector2(130, 0)
	outputLogLabel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	outputLogLabel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	outputLogLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	outputLogContainer.add_child(outputLogLabel)

	var outputLogText = TextEdit.new()
	outputLogText.name = "OutputLogText"
	outputLogText.custom_minimum_size = Vector2(0, 450)
	outputLogText.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outputLogText.editable = false
	outputLogText.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.1)
	stylebox.set_content_margin_all(8)
	outputLogText.add_theme_stylebox_override("normal", stylebox)
	outputLogText.add_theme_stylebox_override("read_only", stylebox)
	outputLogContainer.add_child(outputLogText)

	detailsVBox.add_child(outputLogContainer)

	detailsSection.add_child(detailsVBox)
	container.add_child(detailsSection)

	# Store references
	_platformRows[platform] = {
		"container": container,
		"mainRow": mainRow,
		"checkbox": checkbox,
		"detailsSection": detailsSection,
		"exportPath": exportPathEdit,
		"exportFilename": filenameEdit,
		"exportFilenameOptionsButton": filenameOptionsButton,
		"renameToIndexCheckbox": renameToIndexCheckbox,  # Web platform only, null for others
		"archiveFilename": archiveEdit,
		"archiveFilenameOptionsButton": archiveOptionsButton,
		"archiveContainer": archiveContainer,  # Inline archive container (all platforms)
		"obfuscationDisplay": obfuscationDisplay,
		"configButton": configButton,
		"includeExcludeDisplay": includeExcludeDisplay,
		"includeExcludeConfigButton": includeExcludeConfigButton,
		"exportTypeOption": exportTypeOption,
		"packageTypeOption": packageTypeOption,
		"checksumCheckbox": checksumCheckbox,
		"checksumContainer": checksumContainer,
		"button": exportButton,
		"exportAndRunButton": exportAndRunButton,
		"exportAndEditButton": exportAndEditButton,  # Only exists for Source platform
		"exportAndOpenButton": exportAndOpenButton,
		"outputLogToggle": outputLogToggle,
		"outputLogContainer": outputLogContainer,
		"outputLogText": outputLogText,
		"status": statusLabel
	}

	return panelContainer

func _getAdjustedBackgroundColor(amount: float) -> Color:
	var colorToSubtract = Color(amount, amount, amount, 0.0)
	var baseColor = App.GetBackgroundColor()
	return Color(
		max(baseColor.r + colorToSubtract.r, 0),
		max(baseColor.g + colorToSubtract.g, 0),
		max(baseColor.b + colorToSubtract.b, 0),
		baseColor.a
	)

func _onVersionChanged(newText: String):
	# Notify card of version change
	version_changed.emit(_currentVersion, newText)
	if not _isLoadingData:
		page_modified.emit()

	# Update all platform displays (they use the version in their path/filename)
	for platform in _platformRows.keys():
		_updateExportPathDisplay(platform)
		_updateExportFilenameDisplay(platform)
		_updateArchiveFilenameDisplay(platform)

func _onInputChanged(_value = null):
	# Emit signal when any input is modified
	if not _isLoadingData:
		page_modified.emit()

func _onRenameToIndexToggled(platform: String):
	# Update the filename display to show index.html or original name
	_updateExportFilenameDisplay(platform)

func _onPackageTypeChanged(index: int, platform: String, checksumCheckbox: CheckBox, checksumContainer: HBoxContainer):
	# Update checksum tooltip based on package type selection
	var isZip = (index == 1)  # 0 = No Zip, 1 = Zip
	checksumCheckbox.tooltip_text = _getChecksumTooltip(platform, isZip)

	# Show/hide archive filename based on package type
	var data = _platformRows.get(platform)
	if data != null:
		# Show inline archive container only when Zip is selected (all platforms)
		if data.has("archiveContainer") and data["archiveContainer"] != null:
			data["archiveContainer"].visible = isZip
		# Disable Export & Run when Zip is selected (can't run a zip file)
		if is_instance_valid(data["exportAndRunButton"]):
			data["exportAndRunButton"].disabled = isZip or not data["checkbox"].button_pressed

	# For Source platform, show checksum only when Zip is selected
	if platform == "Source":
		checksumContainer.visible = isZip
		# Uncheck checksum when hiding it
		if not isZip:
			checksumCheckbox.button_pressed = false

	_onInputChanged()

func _getChecksumTooltip(platform: String, isZip: bool) -> String:
	if isZip:
		return "Generate SHA256 checksum file for the .zip archive"
	else:
		# Get platform-specific extension
		var extension = _getPlatformExtension(platform)
		return "Generate SHA256 checksum file for the %s binary" % extension

# Returns the label for the export filename field based on platform
func _getExportFileLabel(platform: String) -> String:
	match platform:
		"Windows Desktop":
			return "Exe File Name:"
		"Linux/X11", "Linux":
			return "Binary File Name:"
		"Web":
			return "Web File Names:"  # e.g., game.html, game.js, game.wasm
		"macOS":
			return "App File Name:"
		"Android":
			return "APK File Name:"
		"iOS":
			return "IPA File Name:"
		_:
			return "Export File Name:"

func _getPlatformExtension(platform: String) -> String:
	match platform:
		"Windows Desktop":
			return ".exe"
		"Linux/X11", "Linux":
			return ".x86_64"
		"Web":
			return ".html"
		"Source":
			return "source folder"
		_:
			return "binary"

# Helper function to enable/disable all export action buttons for a platform
func _setExportButtonsDisabled(data: Dictionary, disabled: bool):
	if is_instance_valid(data["button"]):
		data["button"].disabled = disabled
	if is_instance_valid(data["exportAndRunButton"]):
		data["exportAndRunButton"].disabled = disabled
	if is_instance_valid(data["exportAndOpenButton"]):
		data["exportAndOpenButton"].disabled = disabled
	if data["exportAndEditButton"] != null and is_instance_valid(data["exportAndEditButton"]):
		data["exportAndEditButton"].disabled = disabled

func _onPlatformToggled(checked: bool, platform: String):
	var data = _platformRows[platform]

	# Show/hide details section
	data["detailsSection"].visible = checked

	# Update Export Selected button state
	_updateExportSelectedButtonState()

	# Enable/disable all export action buttons
	_setExportButtonsDisabled(data, !checked)

	# Keep Export & Run disabled if Zip is selected (can't run a zip file)
	if checked:
		var isZip = (data["packageTypeOption"].selected == 1)
		if isZip and is_instance_valid(data["exportAndRunButton"]):
			data["exportAndRunButton"].disabled = true

	if checked:
		# Auto-fill from the previous checked platform
		if data["exportPath"].text.is_empty() or data["exportFilename"].text.is_empty():
			_copyFromPreviousPlatform(platform)

func _copyFromPreviousPlatform(targetPlatform: String):
	# Find the last checked platform before this one
	var platforms = ["Windows Desktop", "Linux", "Web", "Source Code"]
	var targetIndex = platforms.find(targetPlatform)

	if targetIndex <= 0:
		return  # No previous platform

	# Search backwards for a checked platform
	for i in range(targetIndex - 1, -1, -1):
		var prevPlatform = platforms[i]
		if prevPlatform in _platformRows:
			var prevData = _platformRows[prevPlatform]
			if prevData["checkbox"].button_pressed:
				var targetData = _platformRows[targetPlatform]

				# Copy export path if empty
				if targetData["exportPath"].text.is_empty():
					targetData["exportPath"].text = prevData["exportPath"].text

				# Copy filename if empty
				if targetData["exportFilename"].text.is_empty():
					targetData["exportFilename"].text = prevData["exportFilename"].text

				# Copy obfuscation setting
				targetData["obfuscation"].button_pressed = prevData["obfuscation"].button_pressed

				return  # Found and copied, we're done

func _onPlatformHeaderClicked(event: InputEvent, _platform: String, checkbox: CheckBox):
	# Toggle checkbox when clicking anywhere in header
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		checkbox.button_pressed = !checkbox.button_pressed

func _onIncludeExcludeConfigPressed(platform: String):
	# Show loading overlay while dialog initializes
	_showLoadingOverlay("Loading project files...")

	# Wait a frame to allow the overlay to render
	await get_tree().process_frame

	# Get project path
	var projectPath = ""
	if _selectedProjectItem != null and is_instance_valid(_selectedProjectItem):
		# GetProjectDir() handles both path formats (with or without project.godot)
		projectPath = _selectedProjectItem.GetProjectDir()

	# Get current filter config for this platform (or empty dict if none)
	var currentConfig = _platformFilterConfigs.get(platform, {})

	# Add to root if not already added
	if _filterDialog.get_parent() == null:
		# Find the ReleaseManager root node
		var root = get_tree().current_scene
		if root == null:
			root = get_tree().root.get_child(get_tree().root.get_child_count() - 1)

		root.add_child(_filterDialog)
		_filterDialog.z_index = 100  # Ensure it's on top

	# Open dialog
	_filterDialog.openForPlatform(platform, projectPath, currentConfig)
	_filterDialog.move_to_front()

	# Hide loading overlay after dialog is shown
	_hideLoadingOverlay()

func _onFilterSettingsSaved(platform: String, filterConfig: Dictionary):
	# Store the filter config for this platform
	_platformFilterConfigs[platform] = filterConfig

	# Update include/exclude display text
	_updateIncludeExcludeDisplay(platform, filterConfig)

	# Immediately save to project item (don't wait for page save)
	if _selectedProjectItem != null:
		var platformSettings = _selectedProjectItem.GetPlatformExportSettings(platform)

		if platformSettings.is_empty():
			# Create new settings if platform not configured yet
			platformSettings = {
				"enabled": false,
				"exportPath": "",
				"exportFilename": ""
			}

		# Update filter config in platform settings
		platformSettings["filterConfig"] = filterConfig

		# Save to project item immediately
		_selectedProjectItem.SetPlatformExportSettings(platform, platformSettings)
		_selectedProjectItem.SaveProjectItem()

func _onFilterSettingsCancelled():
	# User cancelled the filter settings dialog, no action needed
	pass

func _onConfigButtonPressed(platform: String):
	# Get all platform names for the clone dropdown
	var allPlatforms: Array[String] = []
	allPlatforms.assign(_platformRows.keys())

	# Add dialog to root if not already added (covers entire Release Manager)
	if _buildConfigDialog.get_parent() == null:
		# Find the ReleaseManager root node
		var root = get_tree().current_scene
		if root == null:
			root = get_tree().root.get_child(get_tree().root.get_child_count() - 1)

		root.add_child(_buildConfigDialog)
		_buildConfigDialog.z_index = 1000  # Ensure it's on top

	# Open the dialog
	_buildConfigDialog.openForPlatform(platform, allPlatforms, _platformBuildConfigs)
	_buildConfigDialog.move_to_front()  # Ensure it's rendered on top

func _onBuildConfigSaved(platform: String, config: Dictionary):
	# Store the config for this platform
	_platformBuildConfigs[platform] = config

	# Update obfuscation display text
	_updateObfuscationDisplay(platform, config)

	# Immediately save to project item (don't wait for page save)
	if _selectedProjectItem != null:
		var platformSettings = _selectedProjectItem.GetPlatformExportSettings(platform)
		if platformSettings.is_empty():
			# Create new settings if platform not configured yet
			platformSettings = {
				"enabled": false,
				"exportPath": "",
				"exportFilename": ""
			}

		# Update build config in platform settings
		platformSettings["buildConfig"] = config

		# Save to project item immediately
		_selectedProjectItem.SetPlatformExportSettings(platform, platformSettings)
		_selectedProjectItem.SaveProjectItem()

	# Don't mark page as modified since we saved immediately
	# page_modified.emit()

func _onPathSettingsPressed(platform: String):
	# Get current path template for this platform (default: version then platform)
	var currentTemplate = _platformPathTemplates.get(platform, [
		{"type": "version"},
		{"type": "platform"}
	])

	# Get root export path from stored dictionary
	var rootPath = _platformRootPaths.get(platform, "")
	if rootPath.is_empty():
		# Default to project directory + exports subfolder
		if _selectedProjectItem != null and is_instance_valid(_selectedProjectItem):
			# GetProjectDir() handles both path formats (with or without project.godot)
			var projectDir = _selectedProjectItem.GetProjectDir()
			rootPath = projectDir.path_join("exports")
		else:
			rootPath = "C:/exports"  # Fallback if no project selected

	# Add to root if not already added
	if _pathSettingsDialog.get_parent() == null:
		# Find the ReleaseManager root node
		var root = get_tree().current_scene
		if root == null:
			root = get_tree().root.get_child(get_tree().root.get_child_count() - 1)

		root.add_child(_pathSettingsDialog)
		_pathSettingsDialog.z_index = 100  # Ensure it's on top

	# Open dialog (will cover entire wizard)
	var projectVersion = _projectVersionLineEdit.text if _projectVersionLineEdit.text != "" else "v1.0.0"

	_pathSettingsDialog.openForPlatform(platform, rootPath, currentTemplate, projectVersion)
	_pathSettingsDialog.move_to_front()  # Ensure it's rendered on top

func _onPathSettingsSaved(platform: String, rootPath: String, pathTemplate: Array):
	# Store the template and root path for this platform
	_platformPathTemplates[platform] = pathTemplate
	_platformRootPaths[platform] = rootPath

	# Update the Export Path display to show full path with template
	_updateExportPathDisplay(platform)

	# Save to project item immediately
	if _selectedProjectItem != null and is_instance_valid(_selectedProjectItem):
		var platformSettings = _selectedProjectItem.GetPlatformExportSettings(platform)
		if platformSettings.is_empty():
			# Create new settings if platform not configured yet
			platformSettings = {
				"enabled": false,
				"exportPath": "",
				"exportFilename": ""
			}

		# Update root path and path template in platform settings
		platformSettings["exportPath"] = rootPath
		platformSettings["pathTemplate"] = pathTemplate

		# Save to project item immediately
		_selectedProjectItem.SetPlatformExportSettings(platform, platformSettings)
		_selectedProjectItem.SaveProjectItem()

func _onPathSettingsCancelled():
	# User cancelled the path settings dialog, no action needed
	pass

# ============== Export/Archive Filename Handlers ==============

func _onExportFilenameOptionsPressed(platform: String):
	_openFilenameSettingsDialog(platform, "export")

func _onArchiveFilenameOptionsPressed(platform: String):
	_openFilenameSettingsDialog(platform, "archive")

func _openFilenameSettingsDialog(platform: String, filenameType: String):
	# Source platform doesn't have export filename - only archive
	if filenameType == "export" and platform == "Source":
		return

	_currentFilenameDialogPlatform = platform
	_currentFilenameDialogType = filenameType

	# Create dialog if not exists
	if _filenameSettingsDialog == null:
		_filenameSettingsDialog = load("res://scenes/release-manager/pages/export-page/dialogs/filename-settings-dialog/filename-settings-dialog.tscn").instantiate()
		_filenameSettingsDialog.settings_saved.connect(_onFilenameSettingsSaved)
		_filenameSettingsDialog.cancelled.connect(_onFilenameSettingsCancelled)
		_filenameSettingsDialog.visible = false

	# Add to root if not already added
	if _filenameSettingsDialog.get_parent() == null:
		var root = get_tree().current_scene
		if root == null:
			root = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
		root.add_child(_filenameSettingsDialog)
		_filenameSettingsDialog.z_index = 100

	# Get current template
	var currentTemplate: Array
	if filenameType == "export":
		currentTemplate = _platformExportFilenameTemplates.get(platform, [{"type": "project"}])
	else:
		currentTemplate = _platformArchiveFilenameTemplates.get(platform, [{"type": "project"}])

	# Get project name for preview (uses folder name, not "project.godot")
	var projectName = _getProjectNameForFilename()

	var projectVersion = _projectVersionLineEdit.text if _projectVersionLineEdit.text != "" else "v1.0.0"
	var extension = _getExportExtension(platform) if filenameType == "export" else ".zip"

	# Get export template and sync state for archive dialogs
	var exportTemplate = _platformExportFilenameTemplates.get(platform, [{"type": "project"}])
	var isSynced = _platformArchiveSync.get(platform, false)

	_filenameSettingsDialog.openForFilename(filenameType, platform, currentTemplate, projectName, projectVersion, extension, exportTemplate, isSynced)
	_filenameSettingsDialog.move_to_front()

func _onFilenameSettingsSaved(filenameType: String, filenameTemplate: Array, isSynced: bool):
	var platform = _currentFilenameDialogPlatform

	if filenameType == "export":
		_platformExportFilenameTemplates[platform] = filenameTemplate
		_updateExportFilenameDisplay(platform)
		# If archive is synced, update its display too
		if _platformArchiveSync.get(platform, false):
			_updateArchiveFilenameDisplay(platform)
	else:
		_platformArchiveFilenameTemplates[platform] = filenameTemplate
		_platformArchiveSync[platform] = isSynced
		_updateArchiveFilenameDisplay(platform)

	# Save immediately
	_saveFilenameSettings(platform)

func _onFilenameSettingsCancelled():
	# User cancelled, no action needed
	pass

# Returns the actual export filename (with extension) for a platform, computed from the template
# This is used for actual exports - NOT for display (which may show examples for Web)
func _getActualExportFilename(platform: String) -> String:
	var template = _platformExportFilenameTemplates.get(platform, [{"type": "project"}])
	var filename = _buildFileNameFromTemplate(template, platform)
	var extension = _getExportExtension(platform)
	return filename + extension

func _updateExportFilenameDisplay(platform: String):
	var data = _platformRows.get(platform)
	if data == null or not data.has("exportFilename"):
		return

	var fullFilename = _getActualExportFilename(platform)

	# Web platform shows multiple files with rename preview
	if platform == "Web":
		var htmlName = fullFilename
		# Check if rename to index.html is enabled
		if data.has("renameToIndexCheckbox") and data["renameToIndexCheckbox"] != null:
			if data["renameToIndexCheckbox"].button_pressed:
				htmlName = "index.html"
		var filename = fullFilename.get_basename()  # Remove extension for .js/.wasm display
		var displayText = "%s, %s.js, %s.wasm, etc..." % [htmlName, filename, filename]
		data["exportFilename"].text = displayText
		data["exportFilename"].tooltip_text = "Showing a few examples of the web file names that will be generated."
	else:
		data["exportFilename"].text = fullFilename
		data["exportFilename"].tooltip_text = fullFilename

func _updateArchiveFilenameDisplay(platform: String):
	var data = _platformRows.get(platform)
	if data == null or not data.has("archiveFilename"):
		return

	# Use export template if synced, otherwise use archive template
	var template: Array
	if _platformArchiveSync.get(platform, false):
		template = _platformExportFilenameTemplates.get(platform, [{"type": "project"}])
	else:
		template = _platformArchiveFilenameTemplates.get(platform, [{"type": "project"}])

	var filename = _buildFileNameFromTemplate(template, platform)
	var fullFilename = filename + ".zip"
	data["archiveFilename"].text = fullFilename
	data["archiveFilename"].tooltip_text = fullFilename + "\nClick to configure"

func _getExportExtension(platform: String) -> String:
	match platform:
		"Windows", "Windows Desktop":
			return ".exe"
		"macOS":
			return ".zip"
		"Linux", "Linux/X11":
			return ".x86_64"
		"Web":
			return ".html"
		"Android":
			return ".apk"
		"iOS":
			return ".ipa"
		"Source":
			return ""
		_:
			return ""

func _saveFilenameSettings(platform: String):
	if _selectedProjectItem == null or not is_instance_valid(_selectedProjectItem):
		return

	var platformSettings = _selectedProjectItem.GetPlatformExportSettings(platform)
	if platformSettings.is_empty():
		platformSettings = {
			"enabled": false,
			"exportPath": "",
			"exportFilename": ""
		}

	# Save filename templates and sync state
	platformSettings["exportFilenameTemplate"] = _platformExportFilenameTemplates.get(platform, [{"type": "project"}])
	platformSettings["archiveFilenameTemplate"] = _platformArchiveFilenameTemplates.get(platform, [{"type": "project"}])
	platformSettings["archiveSync"] = _platformArchiveSync.get(platform, false)

	# Build the actual filenames (use export template for archive if synced)
	var exportFilename = _buildFileNameFromTemplate(platformSettings["exportFilenameTemplate"], platform)
	platformSettings["exportFilename"] = exportFilename

	var archiveTemplate = platformSettings["exportFilenameTemplate"] if platformSettings["archiveSync"] else platformSettings["archiveFilenameTemplate"]
	var archiveFilename = _buildFileNameFromTemplate(archiveTemplate, platform)
	platformSettings["archiveFilename"] = archiveFilename

	_selectedProjectItem.SetPlatformExportSettings(platform, platformSettings)
	_selectedProjectItem.SaveProjectItem()

# Builds the export filename from a filename template
func _buildFileNameFromTemplate(filenameTemplate: Array, platform: String) -> String:
	if filenameTemplate.is_empty():
		# Default to project name if no template
		if _selectedProjectItem != null and is_instance_valid(_selectedProjectItem):
			var projectName = _getProjectNameForFilename()
			return projectName
		return "export"

	var parts: Array[String] = []
	var version = _projectVersionLineEdit.text if _projectVersionLineEdit.text != "" else "v1.0.0"

	for segment in filenameTemplate:
		match segment["type"]:
			"project":
				if _selectedProjectItem != null and is_instance_valid(_selectedProjectItem):
					var projectName = _getProjectNameForFilename()
					parts.append(projectName)
				else:
					parts.append("export")
			"version":
				parts.append(version)
			"platform":
				parts.append(platform.to_lower().replace(" ", "-"))
			"custom":
				var customValue = segment.get("value", "")
				if not customValue.is_empty():
					parts.append(customValue)

	if parts.is_empty():
		return "export"

	return "-".join(parts)

# Gets the project name for use in filenames
# Uses the project folder name (e.g., "godot-valet" from the path)
# Falls back to GetProjectName() if folder name extraction fails
func _getProjectNameForFilename() -> String:
	if _selectedProjectItem == null or not is_instance_valid(_selectedProjectItem):
		return "export"

	# GetProjectPath returns path to project.godot, e.g., "C:/path/to/godot-valet/project.godot"
	# We want the folder name "godot-valet", not the file name "project"
	var projectPath = _selectedProjectItem.GetProjectPath()
	var folderPath = projectPath.get_base_dir()  # "C:/path/to/godot-valet"
	var folderName = folderPath.get_file()  # "godot-valet"

	if folderName.is_empty():
		# Fall back to configured project name
		var configuredName = _selectedProjectItem.GetProjectName()
		if not configuredName.is_empty():
			return configuredName
		return "export"

	return folderName

func _updateExportPathDisplay(platform: String):
	# Update the export path LineEdit to show the full path with template
	var data = _platformRows[platform]
	var rootPath = _platformRootPaths.get(platform, "")

	if rootPath.is_empty():
		return

	# Build preview path based on template
	var fullPath = rootPath
	var template = _platformPathTemplates.get(platform, [])

	# Get current version for display
	var version = _projectVersionLineEdit.text
	if version.is_empty():
		version = "v1.0.0"

	for segment in template:
		match segment["type"]:
			"version":
				fullPath = fullPath.path_join(version)
			"platform":
				fullPath = fullPath.path_join(platform)
			"date":
				var dateFormat = segment.get("value", "{year}-{month}-{day}")
				var processedDate = _processDatetimeTokens(dateFormat)
				fullPath = fullPath.path_join(processedDate)
			"custom":
				var customValue = segment.get("value", "custom")
				var processedCustom = _processDatetimeTokens(customValue)
				# Custom paths can contain slashes for nested folders
				# Normalize to forward slashes first
				processedCustom = processedCustom.replace("\\", "/")
				# If it contains slashes, append directly; otherwise use path_join
				if "/" in processedCustom:
					fullPath = fullPath + "/" + processedCustom
				else:
					fullPath = fullPath.path_join(processedCustom)

	# Use forward slashes (cross-platform compatible)
	data["exportPath"].text = fullPath
	data["exportPath"].tooltip_text = fullPath

# Build the actual export path from template for export operations
func _buildExportPathFromTemplate(platform: String, rootPath: String, version: String) -> String:
	var fullPath = rootPath
	var template = _platformPathTemplates.get(platform, [
		{"type": "version"},
		{"type": "platform"}
	])

	for segment in template:
		match segment["type"]:
			"version":
				fullPath = fullPath.path_join(version)
			"platform":
				fullPath = fullPath.path_join(platform)
			"date":
				var dateFormat = segment.get("value", "{year}-{month}-{day}")
				var processedDate = _processDatetimeTokens(dateFormat)
				fullPath = fullPath.path_join(processedDate)
			"custom":
				var customValue = segment.get("value", "custom")
				var processedCustom = _processDatetimeTokens(customValue)
				# Custom paths can contain slashes for nested folders
				# Normalize to forward slashes first, then join
				processedCustom = processedCustom.replace("\\", "/")
				# If it contains slashes, append directly; otherwise use path_join
				if "/" in processedCustom:
					fullPath = fullPath + "/" + processedCustom
				else:
					fullPath = fullPath.path_join(processedCustom)

	return fullPath

# Processes datetime tokens like {year}, {month}, {day}, etc.
func _processDatetimeTokens(text: String) -> String:
	var now = Time.get_datetime_dict_from_system()

	var result = text
	result = result.replace("{year}", str(now.year))
	result = result.replace("{month}", str(now.month).pad_zeros(2))
	result = result.replace("{day}", str(now.day).pad_zeros(2))
	result = result.replace("{hour}", str(now.hour).pad_zeros(2))
	result = result.replace("{minute}", str(now.minute).pad_zeros(2))
	result = result.replace("{second}", str(now.second).pad_zeros(2))

	return result

func _onExportPressed(platform: String):
	# Validate project item before export
	if _selectedProjectItem == null or not is_instance_valid(_selectedProjectItem):
		print("Error: Cannot export - project item is null or invalid")
		return

	# Save current settings before exporting
	save()

	# Note: UI blocker will be shown by _exportPlatform after confirmation dialog
	await _exportPlatform(platform)

	# Re-enable UI after export completes
	_setUIEnabled(true)

# Exports and then runs the exported application
func _onExportAndRunPressed(platform: String):
	if _selectedProjectItem == null or not is_instance_valid(_selectedProjectItem):
		print("Error: Cannot export - project item is null or invalid")
		return

	# Capture godot path for Source platform before await (may become invalid)
	var godotPath = ""
	if platform == "Source":
		var godotVersionId = _selectedProjectItem.GetGodotVersionId()
		godotPath = _selectedProjectItem.GetGodotPath(godotVersionId)
		if godotPath == null or godotPath == "???" or godotPath.is_empty():
			godotPath = "C:/dad/apps/godot/godot-4.5-stable/Godot_v4.5-stable_win64.exe"

	save()
	# Pass runAfterExport=true so the app runs BEFORE zipping (which deletes the exe)
	await _exportPlatform(platform, true, godotPath)
	_setUIEnabled(true)

# Exports and then opens the export folder (Source only)
func _onExportAndEditPressed(platform: String):
	if _selectedProjectItem == null or not is_instance_valid(_selectedProjectItem):
		print("Error: Cannot export - project item is null or invalid")
		return

	# CRITICAL: Capture paths BEFORE await, as _selectedProjectItem may become invalid
	var exportedFilePath = _getExportedFilePath(platform)
	var godotVersionId = _selectedProjectItem.GetGodotVersionId()
	var godotPath = _selectedProjectItem.GetGodotPath(godotVersionId)
	if godotPath == null or godotPath == "???" or godotPath.is_empty():
		godotPath = "C:/dad/apps/godot/godot-4.5-stable/Godot_v4.5-stable_win64.exe"

	save()
	await _exportPlatform(platform)
	_setUIEnabled(true)

	# Check if export was cancelled or failed
	if _exportCancelled:
		return

	# Use pre-captured path
	var exportPath = exportedFilePath
	if exportPath.is_empty():
		print("Error: Could not determine exported path")
		return

	# Open in Godot Editor (using pre-captured godotPath)
	var args = ["--editor", "--path", exportPath]
	var pid = OS.create_process(godotPath, args)
	if pid == -1:
		print("Error: Failed to open exported source in Godot Editor")
	else:
		print("Opened exported source in Godot Editor: ", exportPath)

# Exports and then opens the export folder
func _onExportAndOpenPressed(platform: String):
	if _selectedProjectItem == null or not is_instance_valid(_selectedProjectItem):
		print("Error: Cannot export - project item is null or invalid")
		return

	save()
	await _exportPlatform(platform)
	_setUIEnabled(true)

	# Check if export was cancelled or failed
	if _exportCancelled:
		return

	# Open the export folder
	_onOpenFolderButtonPressed(platform)

# Returns the full path to the exported file/folder for a platform
func _getExportedFilePath(platform: String) -> String:
	var rootPath = _platformRootPaths.get(platform, "")
	if rootPath.is_empty():
		return ""

	var version = _projectVersionLineEdit.text
	if version.is_empty():
		version = "v1.0.0"

	var exportDestPath = _buildExportPathFromTemplate(platform, rootPath, version)

	if platform == "Source":
		# For Source, return the folder path
		return exportDestPath
	else:
		# For other platforms, return the executable path
		var exportFilename = _getActualExportFilename(platform)
		return exportDestPath.path_join(exportFilename)

func _onOpenFolderButtonPressed(platform: String):
	var rootPath = _platformRootPaths.get(platform, "")

	if rootPath.is_empty():
		print("Export path not set for platform: ", platform)
		return

	# Get version from version field
	var version = _projectVersionLineEdit.text
	if version.is_empty():
		version = "v1.0.0"

	# Build full path with template
	var fullPath = _buildExportPathFromTemplate(platform, rootPath, version)

	# Open the full path if it exists, otherwise try parent folders until we find one that exists
	var pathToOpen = fullPath
	while not pathToOpen.is_empty() and not DirAccess.dir_exists_absolute(pathToOpen):
		# Try parent directory
		pathToOpen = pathToOpen.get_base_dir()

	# If we found an existing directory, open it
	if not pathToOpen.is_empty() and DirAccess.dir_exists_absolute(pathToOpen):
		OS.shell_open(pathToOpen)
	else:
		print("Export folder does not exist: ", fullPath)

func _onRefreshPressed():
	# Refresh the export packages list by reloading platform settings
	_clearPlatformRows()
	_createPlatformRows()
	_loadPlatformSettings()
	_updateExportSelectedButtonState()

func _onEditProjectPressed():
	# Open the project in Godot Editor
	if _selectedProjectItem == null or not is_instance_valid(_selectedProjectItem):
		print("Error: No project selected")
		return

	# GetProjectDir() handles both path formats (with or without project.godot)
	var projectPath = _selectedProjectItem.GetProjectDir()
	if projectPath.is_empty():
		print("Error: Project path not set")
		return

	# Get Godot path from the project's configured version
	var godotVersionId = _selectedProjectItem.GetGodotVersionId()
	var godotPath = _selectedProjectItem.GetGodotPath(godotVersionId)

	if godotPath == null or godotPath == "???" or godotPath.is_empty():
		# Fallback to default
		godotPath = "C:/dad/apps/godot/godot-4.5-stable/Godot_v4.5-stable_win64.exe"

	# Launch Godot editor for this project
	var args = ["--editor", "--path", projectPath]
	var pid = OS.create_process(godotPath, args)

	if pid == -1:
		print("Error: Failed to launch Godot editor")
	else:
		print("Opened project in Godot editor: ", projectPath)

func _onSavePressed():
	# Save all current settings
	save()
	# Notify parent to reset dirty flag
	page_saved.emit()

func _onExportSelectedPressed():
	# Export platforms sequentially with status updates
	# Note: UI blocker will be shown by _exportPlatform after confirmation dialogs
	for platform in _platformRows.keys():
		var data = _platformRows[platform]
		if data["checkbox"].button_pressed:
			await _exportPlatform(platform)

			# Check if user cancelled
			if _exportCancelled:
				break

			# Small delay between platform exports to show progress
			await get_tree().create_timer(0.3).timeout

	# Re-enable UI after all exports complete
	_setUIEnabled(true)

# Returns context dictionary with all data needed for export, or {"error": "message"} on failure
func _prepareExportContext(platform: String, runAfterExport: bool, godotPathForRun: String) -> Dictionary:
	# Abort if we're no longer in the scene tree (user navigated away)
	if not is_inside_tree():
		return {"error": "Not in scene tree"}

	# CRITICAL: Capture all data from _selectedProjectItem BEFORE any awaits
	if _selectedProjectItem == null or not is_instance_valid(_selectedProjectItem):
		print("Error: Cannot export - project item is null or invalid")
		return {"error": "Project item invalid"}

	var projectDir = _selectedProjectItem.GetProjectDir()
	var godotPath = ""
	var godotVersionId = ""

	if platform != "Source":
		godotVersionId = _selectedProjectItem.GetGodotVersionId()
		godotPath = _selectedProjectItem.GetGodotPath(godotVersionId)

	var exportFilename = _getActualExportFilename(platform)
	var data = _platformRows[platform]
	var exportPath = _platformRootPaths.get(platform, "")
	var archiveFilename = data["archiveFilename"].text

	# Get export options from UI
	var isDebug = (data["exportTypeOption"].selected == 1)
	var shouldZip = (data["packageTypeOption"].selected == 1)
	var shouldChecksum = data["checksumCheckbox"].button_pressed
	var shouldRenameToIndex = (platform == "Web" and data["renameToIndexCheckbox"] != null and data["renameToIndexCheckbox"].button_pressed)

	# Check if obfuscation is enabled
	var obfuscationEnabled = false
	if platform in _platformBuildConfigs:
		var config = _platformBuildConfigs[platform]
		obfuscationEnabled = config.get("obfuscate_functions", false) or config.get("obfuscate_variables", false) or config.get("obfuscate_comments", false)

	# Validate export path and filename
	if exportPath.is_empty() or exportFilename.is_empty():
		return {"error": "Missing path/filename"}

	# Validate Godot path for non-Source platforms
	var presetName = ""
	if platform != "Source":
		if godotPath == null or godotPath == "???":
			return {"error": "Godot path not found"}
		presetName = _getExportPresetName(platform)
		if presetName.is_empty():
			return {"error": "Unknown platform"}

	# Get version
	var version = _projectVersionLineEdit.text
	if version.is_empty():
		version = "v1.0.0"

	# Build and validate export destination path
	var exportDestPath = _buildExportPathFromTemplate(platform, exportPath, version)
	var validation = _validateExportPath(projectDir, exportPath, exportDestPath)
	if not validation["valid"]:
		return {"error": validation["error"]}

	return {
		"platform": platform,
		"project_dir": projectDir,
		"godot_path": godotPath,
		"export_filename": exportFilename,
		"export_path": exportPath,
		"export_dest_path": exportDestPath,
		"archive_filename": archiveFilename,
		"preset_name": presetName,
		"is_debug": isDebug,
		"should_zip": shouldZip,
		"should_checksum": shouldChecksum,
		"should_rename_to_index": shouldRenameToIndex,
		"obfuscation_enabled": obfuscationEnabled,
		"run_after_export": runAfterExport,
		"godot_path_for_run": godotPathForRun,
		"temp_obfuscated_dir": ""
	}

# Handles folder existence check, overwrite dialog, and directory creation. Returns false on failure/cancel.
func _setupExportDestination(ctx: Dictionary, data: Dictionary) -> bool:
	var exportDestPath = ctx["export_dest_path"]
	var shouldZip = ctx["should_zip"]

	if DirAccess.dir_exists_absolute(exportDestPath):
		# Hide blocker before showing dialog
		_setUIEnabled(true)

		var confirmDialog = _getYesNoDialog()
		_updateStatus(data, "Awaiting confirmation...")
		await get_tree().process_frame

		var buttons: Array[String]
		if shouldZip:
			buttons = ["Clear & Export", "Cancel"]
		else:
			buttons = ["Clear & Export", "Overwrite", "Cancel"]

		confirmDialog.show_dialog_with_buttons(
			"Export folder already exists:\n" + exportDestPath + "\n\nHow would you like to proceed?",
			buttons
		)
		var choice = await confirmDialog.confirmed

		if choice == "Cancel":
			_updateStatus(data, "Export cancelled")
			await get_tree().create_timer(0.5).timeout
			return false

		# User confirmed, show blocker
		_setUIEnabled(false)

		if choice == "Clear & Export":
			_updateStatus(data, "Clearing export folder...")
			await get_tree().process_frame
			if not _clearDirectory(exportDestPath):
				_updateStatus(data, "Error: Failed to clear folder")
				_setUIEnabled(true)
				return false

		_updateStatus(data, "Preparing export...")
		await get_tree().create_timer(0.5).timeout
	else:
		_setUIEnabled(false)
		_updateStatus(data, "Creating version folder...")
		await get_tree().create_timer(0.5).timeout

		var err = DirAccess.make_dir_recursive_absolute(exportDestPath)
		if err != OK:
			_updateStatus(data, "Error: Cannot create export folder")
			return false

	return true

# Runs obfuscation if enabled and updates context with temp directory. Returns success status.
func _runObfuscationIfEnabled(ctx: Dictionary, data: Dictionary) -> bool:
	if not ctx["obfuscation_enabled"] or _exportCancelled:
		return true

	_updateStatus(data, "Obfuscating project...")
	await get_tree().process_frame

	var obfResult = await _runObfuscation(ctx["project_dir"], ctx["platform"], data)
	if not obfResult["success"] or _exportCancelled:
		return false

	ctx["working_dir"] = obfResult["obfuscated_dir"]
	ctx["temp_obfuscated_dir"] = obfResult["obfuscated_dir"]

	_updateStatus(data, "Obfuscation complete")
	await get_tree().create_timer(0.5).timeout
	return true

# Exports Source platform by copying files. Returns success status.
func _exportSourcePlatform(ctx: Dictionary, data: Dictionary) -> bool:
	var sourceDirToCopy = ctx.get("working_dir", ctx["project_dir"])

	if not await _runObfuscationIfEnabled(ctx, data):
		return false

	# Update source dir if obfuscation created a new one
	sourceDirToCopy = ctx.get("working_dir", ctx["project_dir"])

	if _exportCancelled:
		return false

	_updateStatus(data, "Copying source files...")
	await get_tree().process_frame

	var filterConfig = _platformFilterConfigs.get(ctx["platform"], {})
	return await _copySourceFiles(sourceDirToCopy, ctx["export_dest_path"], ctx["export_path"], data, filterConfig)

# Exports regular platforms using Godot export. Returns success status.
func _exportRegularPlatform(ctx: Dictionary, data: Dictionary) -> bool:
	var projectDirToExport = ctx["project_dir"]

	if not await _runObfuscationIfEnabled(ctx, data):
		return false

	# Update project dir if obfuscation created a new one
	projectDirToExport = ctx.get("working_dir", ctx["project_dir"])

	if _exportCancelled:
		return false

	var filenameWithExtension = _addPlatformExtension(ctx["export_filename"], ctx["platform"])
	var outputPath = ctx["export_dest_path"].path_join(filenameWithExtension)

	var exportTypeText = "debug" if ctx["is_debug"] else "release"
	_updateStatus(data, "Exporting %s to %s..." % [exportTypeText, ctx["platform"]])
	await get_tree().process_frame

	return await _runGodotExport(ctx["godot_path"], projectDirToExport, ctx["preset_name"], outputPath, data, ctx["is_debug"], ctx["platform"])

# Handles post-export steps: HTML rename, run app, zip, checksum. Returns success status.
func _runPostExportSteps(ctx: Dictionary, data: Dictionary, success: bool) -> bool:
	if not success or _exportCancelled:
		return success

	var platform = ctx["platform"]
	var exportDestPath = ctx["export_dest_path"]
	var exportFilename = ctx["export_filename"]

	# Rename HTML to index.html for Web platform
	if ctx["should_rename_to_index"]:
		_updateStatus(data, "Renaming to index.html...")
		await get_tree().process_frame
		var htmlFilename = _addPlatformExtension(exportFilename, platform)
		var originalHtmlPath = exportDestPath.path_join(htmlFilename)
		var indexHtmlPath = exportDestPath.path_join("index.html")
		if FileAccess.file_exists(originalHtmlPath):
			var renameErr = DirAccess.rename_absolute(originalHtmlPath, indexHtmlPath)
			if renameErr != OK:
				push_warning("Failed to rename HTML to index.html: %s" % renameErr)
		else:
			push_warning("HTML file not found for rename: %s" % originalHtmlPath)

	# Run exported application if requested (before zipping)
	if ctx["run_after_export"]:
		_runExportedApplication(ctx)

	# Create zip archive
	var finalOutputPath = exportDestPath
	if ctx["should_zip"]:
		_updateStatus(data, "Creating zip archive...")
		await get_tree().process_frame
		var zipPath = await _createZipArchive(exportDestPath, ctx["archive_filename"])
		if zipPath.is_empty():
			return false
		finalOutputPath = zipPath

	# Generate checksum
	if ctx["should_checksum"]:
		_updateStatus(data, "Generating checksum...")
		await get_tree().process_frame
		var checksumSuccess = _generateChecksum(finalOutputPath, ctx["should_zip"], platform, exportFilename)
		if not checksumSuccess:
			print("Warning: Failed to generate checksum for ", finalOutputPath)

	return true

# Runs the exported application (non-async helper)
func _runExportedApplication(ctx: Dictionary):
	var platform = ctx["platform"]
	var exportDestPath = ctx["export_dest_path"]
	var exportFilename = ctx["export_filename"]

	if platform != "Source":
		var executablePath = exportDestPath.path_join(_addPlatformExtension(exportFilename, platform))
		if FileAccess.file_exists(executablePath):
			var runPid = OS.create_process(executablePath, [])
			if runPid == -1:
				print("Error: Failed to run exported application: ", executablePath)
			else:
				print("Running exported application: ", executablePath)
		else:
			print("Error: Exported file not found for run: ", executablePath)
	else:
		var args = ["--path", exportDestPath]
		var runPid = OS.create_process(ctx["godot_path_for_run"], args)
		if runPid == -1:
			print("Error: Failed to run exported source project")
		else:
			print("Running exported source project: ", exportDestPath)

# Cleans up export state and updates final status
func _finalizeExport(ctx: Dictionary, data: Dictionary, success: bool):
	# Clean up temp obfuscated directory
	if ctx["temp_obfuscated_dir"] != "":
		_updateStatus(data, "Cleaning up...")
		await get_tree().create_timer(0.3).timeout
		_cleanupTempDir(ctx["temp_obfuscated_dir"])

	# Update final status
	if _exportCancelled:
		_updateStatus(data, "✗ Cancelled")
	elif success:
		_updateStatus(data, "✓ Complete")
	else:
		_updateStatus(data, "✗ Failed")
	await get_tree().create_timer(1.0).timeout

	_setExportButtonsDisabled(data, false)
	_exportingPlatforms.erase(ctx["platform"])
	build_completed.emit(ctx["platform"], success)

# Helper to handle early exit with proper cleanup
func _abortExport(ctx: Dictionary, data: Dictionary, errorMsg: String):
	_updateStatus(data, errorMsg)
	_setExportButtonsDisabled(data, false)
	_exportingPlatforms.erase(ctx["platform"])
	build_completed.emit(ctx["platform"], false)

func _exportPlatform(platform: String, runAfterExport: bool = false, godotPathForRun: String = ""):
	if platform in _exportingPlatforms:
		return

	# Phase 1: Prepare context with all needed data (before any awaits)
	var ctx = _prepareExportContext(platform, runAfterExport, godotPathForRun)
	if ctx.has("error"):
		if ctx["error"] != "Not in scene tree" and ctx["error"] != "Project item invalid":
			var data = _platformRows[platform]
			_updateStatus(data, "Error: " + ctx["error"])
		return

	var data = _platformRows[platform]
	_exportingPlatforms.append(platform)

	# Initialize UI
	_updateStatus(data, "")
	await get_tree().process_frame
	_updateStatus(data, "Exporting...")
	_setExportButtonsDisabled(data, true)
	build_started.emit(platform)

	# Phase 2: Setup export destination (handles overwrite dialog)
	if not await _setupExportDestination(ctx, data):
		_abortExport(ctx, data, "")  # Status already set by _setupExportDestination
		return

	# Phase 3-4: Run export (source or regular platform)
	var success: bool
	if platform == "Source":
		success = await _exportSourcePlatform(ctx, data)
	else:
		success = await _exportRegularPlatform(ctx, data)

	# Phase 5: Post-export steps (rename, run, zip, checksum)
	success = await _runPostExportSteps(ctx, data, success)

	# Phase 6: Finalize (cleanup and status)
	await _finalizeExport(ctx, data, success)

func validate() -> bool:
	# Only block navigation if export path equals project path (dangerous)
	# Empty export paths are allowed - user can configure them later
	for platform in _platformRows.keys():
		var data = _platformRows[platform]
		if data["checkbox"].button_pressed:
			var exportPath = data["exportPath"].text
			# Export path cannot equal project path (would overwrite source files)
			if not exportPath.is_empty() and _selectedProjectItem != null:
				var projectPath = _selectedProjectItem.GetProjectPath()
				if exportPath == projectPath:
					print("Validation FAIL: ", platform, " export path equals project path!")
					return false

	return true

func save():
	if _selectedProjectItem == null or not is_instance_valid(_selectedProjectItem):
		return

	# Save project version
	_selectedProjectItem.SetProjectVersion(_projectVersionLineEdit.text)

	# Save all platform settings
	for platform in _platformRows.keys():
		var data = _platformRows[platform]

		# Get root path from stored dictionary (not from text field which is cleared for placeholder)
		var rootPath = _platformRootPaths.get(platform, "")

		# Only save settings for platforms that have been configured (checkbox checked at some point)
		if data["checkbox"].button_pressed or rootPath != "" or data["exportFilename"].text != "":
			var platformSettings = {
				"enabled": data["checkbox"].button_pressed,
				"exportPath": rootPath,
				"exportFilename": data["exportFilename"].text,
				"archiveFilename": data["archiveFilename"].text.get_basename(),  # Remove .zip extension for storage
				"exportType": data["exportTypeOption"].selected,  # 0=Release, 1=Debug
				"packageType": data["packageTypeOption"].selected,  # 0=No Zip, 1=Zip
				"generateChecksum": data["checksumCheckbox"].button_pressed
			}

			# Save rename to index.html setting (Web platform only)
			if platform == "Web" and data["renameToIndexCheckbox"] != null:
				platformSettings["renameToIndex"] = data["renameToIndexCheckbox"].button_pressed

			# Save build config if exists
			if platform in _platformBuildConfigs:
				platformSettings["buildConfig"] = _platformBuildConfigs[platform]

			# Save filter config if exists
			if platform in _platformFilterConfigs:
				platformSettings["filterConfig"] = _platformFilterConfigs[platform]

			# Save path template if exists
			if platform in _platformPathTemplates:
				platformSettings["pathTemplate"] = _platformPathTemplates[platform]

			# Save filename templates and sync state
			if platform in _platformExportFilenameTemplates:
				platformSettings["exportFilenameTemplate"] = _platformExportFilenameTemplates[platform]
			if platform in _platformArchiveFilenameTemplates:
				platformSettings["archiveFilenameTemplate"] = _platformArchiveFilenameTemplates[platform]
			if platform in _platformArchiveSync:
				platformSettings["archiveSync"] = _platformArchiveSync[platform]

			_selectedProjectItem.SetPlatformExportSettings(platform, platformSettings)

	_selectedProjectItem.SaveProjectItem()

func _getExportPresetName(platform: String) -> String:
	# Platform name IS the preset name (read from export_presets.cfg)
	return platform

func _addPlatformExtension(filename: String, platform: String) -> String:
	# Don't add extension if filename already has one
	if filename.get_extension() != "":
		return filename

	# Get extension for this platform
	var extension = _getPlatformExtension(platform)
	if extension == "source folder" or extension == "binary":
		return filename  # No extension for Source or unknown platforms

	return filename + extension

func _runGodotExport(godotPath: String, projectPath: String, presetName: String, outputPath: String, data: Dictionary, isDebug: bool = false, platform: String = "") -> bool:
	# Build Godot export command
	var exportFlag = "--export-debug" if isDebug else "--export-release"
	var command = "\"%s\" --headless --path \"%s\" %s \"%s\" \"%s\"" % [godotPath, projectPath, exportFlag, presetName, outputPath]

	# Capture output to a temp file for debugging export failures
	var tempOutputFile = ProjectSettings.globalize_path("user://temp_export_output_%s.txt" % str(Time.get_ticks_msec()))
	var fullCommand = "%s > \"%s\" 2>&1" % [command, tempOutputFile]

	# Execute export command in background
	var pid = OS.create_process("cmd.exe", ["/c", fullCommand])

	if pid == -1:
		_updateStatus(data, "Error: Failed to start export")
		return false

	# Poll until process completes, checking for cancellation
	while OS.is_process_running(pid):
		if _exportCancelled:
			# User cancelled - kill the export process
			OS.kill(pid)
			_updateStatus(data, "Export process terminated")
			_cleanupTempOutputFile(tempOutputFile)
			return false

		await get_tree().create_timer(0.1).timeout  # Check every 100ms

	# Check if cancelled after process completed naturally
	if _exportCancelled:
		_cleanupTempOutputFile(tempOutputFile)
		return false

	# Read and store the export output
	var exportOutput = _readTempOutputFile(tempOutputFile)
	_cleanupTempOutputFile(tempOutputFile)

	# Verify output file was created
	if not FileAccess.file_exists(outputPath):
		print("Export command completed but output file not found: ", outputPath)
		_updateStatus(data, "Error: Output file not created")
		# Store output and show toggle on failure
		if platform != "":
			_storeExportOutput(platform, exportOutput)
		return false

	# On success, clear any previous output
	if platform != "":
		_clearExportOutput(platform)

	return true

func _runObfuscation(projectDir: String, platform: String, data: Dictionary) -> Dictionary:
	# Create temp directory for obfuscated project
	var tempDir = "user://temp_obfuscated_" + str(Time.get_ticks_msec())
	var tempDirGlobal = ProjectSettings.globalize_path(tempDir)

	# Create temp directory
	var dir = DirAccess.open("user://")
	if dir == null:
		_updateStatus(data, "Error: Cannot access user directory")
		return {"success": false, "obfuscated_dir": ""}

	var err = dir.make_dir_recursive(tempDir)
	if err != OK:
		_updateStatus(data, "Error: Cannot create temp directory")
		return {"success": false, "obfuscated_dir": ""}

	# Copy project to temp directory
	_updateStatus(data, "Copying project files...")
	await get_tree().process_frame
	if not _copyDirectory(projectDir, tempDirGlobal):
		_updateStatus(data, "Error: Failed to copy project")
		return {"success": false, "obfuscated_dir": ""}

	# Get obfuscation settings from platform build config
	var buildConfig = _platformBuildConfigs.get(platform, {})
	var obfuscateFunctions = buildConfig.get("obfuscate_functions", false)
	var obfuscateVariables = buildConfig.get("obfuscate_variables", false)
	var obfuscateComments = buildConfig.get("obfuscate_comments", false)

	# Parse exclude lists (comma-separated to array)
	var functionExcludes = _parseExcludeList(buildConfig.get("function_excludes", ""))
	var variableExcludes = _parseExcludeList(buildConfig.get("variable_excludes", ""))

	# Set exclude lists in obfuscator
	ObfuscateHelper.SetFunctionExcludeList(functionExcludes)
	ObfuscateHelper.SetVariableExcludeList(variableExcludes)

	# Run obfuscation on temp directory
	_updateStatus(data, "Processing scripts...")
	await get_tree().process_frame
	ObfuscateHelper.ObfuscateScripts(tempDirGlobal, tempDirGlobal, obfuscateFunctions, obfuscateVariables, obfuscateComments)

	# Allow UI to update
	await get_tree().process_frame

	return {"success": true, "obfuscated_dir": tempDirGlobal}

func _parseExcludeList(excludeListString: String) -> Array[String]:
	var result: Array[String] = []
	if excludeListString.is_empty():
		return result

	var items = excludeListString.split(",")
	for item in items:
		var trimmed = item.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)

	return result

# Copy source files for "Source" platform (no filtering - copies everything except exports folder)
func _copySourceFiles(projectDir: String, versionPath: String, exportPath: String, data: Dictionary, filterConfig: Dictionary = {}) -> bool:
	# Reset cancellation flag for this export
	_exportCancelled = false

	# Copy entire project directory to version folder (excluding exports folder and respecting filters)
	_updateStatus(data, "Copying project files...")
	await get_tree().process_frame

	# Normalize export path to skip during copy
	var normalizedExportPath = exportPath.replace("\\", "/").trim_suffix("/")

	var success = await _copyDirectoryUnfiltered(projectDir, versionPath, normalizedExportPath, data, filterConfig)

	if _exportCancelled:
		return false

	if not success:
		_updateStatus(data, "Error: Failed to copy project files")
		return false

	_updateStatus(data, "Copy complete")
	return true

# Check if a path should be excluded based on filter config
func _shouldExcludePath(relativePath: String, filterConfig: Dictionary) -> bool:
	# Check against excluded_paths (exact matches)
	var excludedPaths = filterConfig.get("excluded_paths", [])
	for excluded in excludedPaths:
		if relativePath == excluded or relativePath.begins_with(excluded + "/"):
			return true

	# Check against exclude_patterns (glob patterns)
	var excludePatterns = filterConfig.get("exclude_patterns", [])
	for pattern in excludePatterns:
		# Handle directory patterns (end with /)
		if pattern.ends_with("/"):
			var patternWithoutSlash = pattern.trim_suffix("/")
			if relativePath == patternWithoutSlash or relativePath.begins_with(patternWithoutSlash + "/"):
				return true
		# Handle file glob patterns (*.ext)
		elif pattern.begins_with("*"):
			var extension = pattern.trim_prefix("*")
			if relativePath.ends_with(extension):
				return true
		# Handle exact file patterns
		else:
			if relativePath == pattern or relativePath.ends_with("/" + pattern):
				return true

	return false

# Copy directory without filtering (includes hidden folders like .git, .godot)
# excludePath is a path to skip during copy (e.g., the exports folder)
# filterConfig contains excluded_paths and exclude_patterns to skip
# visited tracks directories we've already processed to prevent symlink loops
# projectRoot is the original project directory (for calculating relative paths)
func _copyDirectoryUnfiltered(source: String, dest: String, excludePath: String, data: Dictionary, filterConfig: Dictionary = {}, visited: Dictionary = {}, projectRoot: String = "") -> bool:
	# On first call, projectRoot will be empty - set it to source
	if projectRoot.is_empty():
		projectRoot = source
	# Check for cancellation
	if _exportCancelled:
		return false

	# Normalize source for visited tracking (case-insensitive on Windows)
	var normalizedSource = source.replace("\\", "/").trim_suffix("/").to_lower()

	# Check if we've already visited this directory (prevents symlink loops)
	if normalizedSource in visited:
		print("WARNING: Circular reference detected at ", source, " - skipping")
		return true

	# Mark as visited
	visited[normalizedSource] = true

	# Create destination directory
	var destDir = DirAccess.open(dest.get_base_dir())
	if destDir == null:
		return false

	destDir.make_dir_recursive(dest)

	# Copy all files recursively (no filtering except excludePath)
	var sourceDir = DirAccess.open(source)
	if sourceDir == null:
		return false

	sourceDir.list_dir_begin()
	var fileName = sourceDir.get_next()

	while fileName != "":
		# Check for cancellation during copy
		if _exportCancelled:
			sourceDir.list_dir_end()
			return false

		var sourcePath = source.path_join(fileName)
		var destPath = dest.path_join(fileName)

		# Normalize source path for comparison (case-insensitive on Windows)
		var normalizedSourcePath = sourcePath.replace("\\", "/").trim_suffix("/").to_lower()
		var normalizedExcludePath = excludePath.to_lower()

		if sourceDir.current_is_dir():
			# Skip . and ..
			if fileName == "." or fileName == "..":
				fileName = sourceDir.get_next()
				continue

			# Skip if this directory matches the exclude path or is inside it
			if normalizedSourcePath == normalizedExcludePath or normalizedSourcePath.begins_with(normalizedExcludePath + "/"):
				fileName = sourceDir.get_next()
				continue

			# Check against filter config (convert to relative path first)
			var relativePath = sourcePath.replace(projectRoot + "/", "").replace(projectRoot + "\\", "")
			if _shouldExcludePath(relativePath, filterConfig):
				fileName = sourceDir.get_next()
				continue

			# Recursively copy directory, passing visited dictionary, filterConfig, and projectRoot
			var success = await _copyDirectoryUnfiltered(sourcePath, destPath, excludePath, data, filterConfig, visited, projectRoot)
			if not success:
				sourceDir.list_dir_end()
				return false

			# Yield every directory to keep UI responsive
			await get_tree().process_frame
		else:
			# Check against filter config (convert to relative path first)
			var relativePath = sourcePath.replace(projectRoot + "/", "").replace(projectRoot + "\\", "")
			if _shouldExcludePath(relativePath, filterConfig):
				fileName = sourceDir.get_next()
				continue

			# Copy file
			DirAccess.copy_absolute(sourcePath, destPath)

		fileName = sourceDir.get_next()

	sourceDir.list_dir_end()
	return true

func _copyDirectory(source: String, dest: String) -> bool:
	# Create destination directory
	var destDir = DirAccess.open(dest.get_base_dir())
	if destDir == null:
		return false

	destDir.make_dir_recursive(dest)

	# Copy all files recursively
	var sourceDir = DirAccess.open(source)
	if sourceDir == null:
		return false

	sourceDir.list_dir_begin()
	var fileName = sourceDir.get_next()

	# Windows reserved names that cannot be copied
	var reservedNames = ["con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5", "com6", "com7", "com8", "com9", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7", "lpt8", "lpt9"]

	while fileName != "":
		var sourcePath = source.path_join(fileName)
		var destPath = dest.path_join(fileName)

		# Skip Windows reserved names
		if fileName.to_lower() in reservedNames:
			fileName = sourceDir.get_next()
			continue

		if sourceDir.current_is_dir():
			# Skip . and .. and hidden directories
			if fileName != "." and fileName != ".." and not fileName.begins_with("."):
				_copyDirectory(sourcePath, destPath)
		else:
			# Copy file
			DirAccess.copy_absolute(sourcePath, destPath)

		fileName = sourceDir.get_next()

	sourceDir.list_dir_end()
	return true

# Clear all contents of a directory but keep the directory itself
func _clearDirectory(dirPath: String) -> bool:
	var dir = DirAccess.open(dirPath)
	if dir == null:
		print("Error: Cannot open directory to clear: ", dirPath)
		return false

	dir.list_dir_begin()
	var fileName = dir.get_next()

	while fileName != "":
		if fileName == "." or fileName == "..":
			fileName = dir.get_next()
			continue

		var filePath = dirPath.path_join(fileName)

		if dir.current_is_dir():
			# Recursively delete subdirectory
			_cleanupTempDir(filePath)
		else:
			# Delete file
			var err = dir.remove(fileName)
			if err != OK:
				print("Error: Failed to remove file: ", filePath)
				dir.list_dir_end()
				return false

		fileName = dir.get_next()

	dir.list_dir_end()
	return true

func _cleanupTempDir(tempDir: String):
	# Recursively delete temp directory
	var dir = DirAccess.open(tempDir)
	if dir == null:
		return

	dir.list_dir_begin()
	var fileName = dir.get_next()

	while fileName != "":
		var filePath = tempDir.path_join(fileName)

		if dir.current_is_dir():
			if fileName != "." and fileName != "..":
				_cleanupTempDir(filePath)
		else:
			dir.remove(fileName)

		fileName = dir.get_next()

	dir.list_dir_end()

	# Remove the directory itself
	DirAccess.remove_absolute(tempDir)

func _getYesNoDialog() -> Control:
	# Add to root if not already added (for full screen coverage)
	if _yesNoDialog.get_parent() == null:
		var root = owner  # Get release-manager panel
		if root:
			root.add_child(_yesNoDialog)
	return _yesNoDialog

func _updateStatus(data: Dictionary, status: String):
	# Safely update status label only if it's still valid
	if is_instance_valid(data.get("status")):
		data["status"].text = status
		# Color error messages red
		if status.begins_with("Error:") or status.begins_with("✗"):
			data["status"].add_theme_color_override("font_color", Color.RED)
		else:
			data["status"].remove_theme_color_override("font_color")

func _updateObfuscationDisplay(platform: String, config: Dictionary):
	if platform not in _platformRows:
		return

	var display = _platformRows[platform]["obfuscationDisplay"]
	var options: Array[String] = []

	if config.get("obfuscate_functions", false):
		options.append("Functions")
	if config.get("obfuscate_variables", false):
		options.append("Variables")
	if config.get("obfuscate_comments", false):
		options.append("Comments")

	if options.is_empty():
		display.text = ""
		display.placeholder_text = "None"
	else:
		display.text = ", ".join(options)
		display.placeholder_text = ""

func _updateIncludeExcludeDisplay(platform: String, config: Dictionary):
	if platform not in _platformRows:
		return

	var display = _platformRows[platform]["includeExcludeDisplay"]
	var summary: Array[String] = []

	# Count excluded paths
	var excludedPaths = config.get("excluded_paths", [])
	var excludePatterns = config.get("exclude_patterns", [])
	var additionalFiles = config.get("additional_files", [])

	if excludedPaths.size() > 0:
		summary.append("%d paths" % excludedPaths.size())
	if excludePatterns.size() > 0:
		summary.append("%d patterns" % excludePatterns.size())
	if additionalFiles.size() > 0:
		summary.append("+%d files" % additionalFiles.size())

	if summary.is_empty():
		display.text = ""
		display.placeholder_text = "No filters configured"
	else:
		display.text = ", ".join(summary)
		display.placeholder_text = ""

func _createInputBlocker():
	# Create overlay container
	_inputBlocker = Control.new()
	_inputBlocker.name = "ExportBlockerOverlay"
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
	statusLabel.text = "Exporting..."
	statusLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	statusLabel.add_theme_font_size_override("font_size", 18)
	vbox.add_child(statusLabel)

	# Cancel button
	var cancelButton = Button.new()
	cancelButton.name = "CancelButton"
	cancelButton.text = "Cancel Export"
	cancelButton.icon = ICON_DISMISS
	cancelButton.custom_minimum_size = Vector2(160, 40)
	cancelButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancelButton.pressed.connect(_onCancelExportPressed)
	vbox.add_child(cancelButton)

	# Start spinner animation timer
	var timer = Timer.new()
	timer.name = "SpinnerTimer"
	timer.wait_time = 0.15  # Rotate every 150ms
	timer.autostart = false
	timer.timeout.connect(_updateSpinner.bind(spinnerLabel))
	_inputBlocker.add_child(timer)

func _updateSpinner(spinnerLabel: Label):
	# Rotate through spinner characters
	const SPINNER_FRAMES = ["◜", "◝", "◞", "◟"]
	var currentIndex = SPINNER_FRAMES.find(spinnerLabel.text)
	if currentIndex == -1:
		currentIndex = 0
	else:
		currentIndex = (currentIndex + 1) % SPINNER_FRAMES.size()
	spinnerLabel.text = SPINNER_FRAMES[currentIndex]

func _onCancelExportPressed():
	# Set cancellation flag
	_exportCancelled = true

	# Update blocker status
	if is_instance_valid(_inputBlocker):
		var statusLabel = _inputBlocker.get_node_or_null("CenterContainer/VBoxContainer/StatusLabel")
		if is_instance_valid(statusLabel):
			statusLabel.text = "Cancelling..."

		# Disable cancel button
		var cancelButton = _inputBlocker.get_node_or_null("CenterContainer/VBoxContainer/CancelButton")
		if is_instance_valid(cancelButton):
			cancelButton.disabled = true

func _setUIEnabled(enabled: bool):
	# Show/hide full-screen input blocker overlay
	if not is_instance_valid(_inputBlocker):
		return

	if not enabled:
		# Reset cancellation flag when starting export
		_exportCancelled = false

		# Add to root if not already added
		if _inputBlocker.get_parent() == null:
			var root = owner  # Get release-manager panel
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
			statusLabel.text = "Exporting..."

		# Re-enable cancel button
		var cancelButton = _inputBlocker.get_node_or_null("CenterContainer/VBoxContainer/CancelButton")
		if is_instance_valid(cancelButton):
			cancelButton.disabled = false
	else:
		# Hide blocker and stop spinner
		_inputBlocker.visible = false

		var timer = _inputBlocker.get_node_or_null("SpinnerTimer")
		if is_instance_valid(timer):
			timer.stop()

# Shows a loading overlay with custom message (no cancel button)
func _showLoadingOverlay(message: String = "Loading..."):
	if not is_instance_valid(_inputBlocker):
		return

	# Add to root if not already added
	if _inputBlocker.get_parent() == null:
		var root = owner
		if root:
			root.add_child(_inputBlocker)

	# Update status text
	var statusLabel = _inputBlocker.get_node_or_null("CenterContainer/VBoxContainer/StatusLabel")
	if is_instance_valid(statusLabel):
		statusLabel.text = message

	# Hide cancel button for loading operations
	var cancelButton = _inputBlocker.get_node_or_null("CenterContainer/VBoxContainer/CancelButton")
	if is_instance_valid(cancelButton):
		cancelButton.visible = false

	# Show blocker and start spinner
	_inputBlocker.visible = true
	_inputBlocker.move_to_front()

	var timer = _inputBlocker.get_node_or_null("SpinnerTimer")
	if is_instance_valid(timer):
		timer.start()

# Hides the loading overlay
func _hideLoadingOverlay():
	if not is_instance_valid(_inputBlocker):
		return

	_inputBlocker.visible = false

	var timer = _inputBlocker.get_node_or_null("SpinnerTimer")
	if is_instance_valid(timer):
		timer.stop()

	# Restore cancel button visibility for future export operations
	var cancelButton = _inputBlocker.get_node_or_null("CenterContainer/VBoxContainer/CancelButton")
	if is_instance_valid(cancelButton):
		cancelButton.visible = true

func _updateExportSelectedButtonState():
	# Check if any platform is selected
	var anyPlatformSelected = false
	for platform in _platformRows.keys():
		var data = _platformRows[platform]
		if is_instance_valid(data["checkbox"]) and data["checkbox"].button_pressed:
			anyPlatformSelected = true
			break

	# Enable button only if at least one platform is selected
	if is_instance_valid(_exportSelectedButton):
		_exportSelectedButton.disabled = not anyPlatformSelected

# Normalizes a path to absolute with forward slashes and resolved .. segments
func _normalizePath(path: String) -> String:
	var absolute = path

	# Use ProjectSettings.globalize_path if it's a Godot path
	if absolute.contains("://"):
		absolute = ProjectSettings.globalize_path(absolute)

	# Convert backslashes to forward slashes
	absolute = absolute.replace("\\", "/")

	# Remove trailing slashes
	absolute = absolute.trim_suffix("/")

	# Normalize .. segments
	var parts = absolute.split("/")
	var normalized: Array[String] = []
	for part in parts:
		if part == "..":
			if not normalized.is_empty() and normalized[-1] != "..":
				normalized.pop_back()
			else:
				normalized.append(part)
		elif part != "." and part != "":
			normalized.append(part)

	absolute = "/".join(normalized)

	# Convert to lowercase for case-insensitive comparison on Windows
	return absolute.to_lower()

# Validates that export path won't cause recursive loops
func _validateExportPath(projectDir: String, exportRootPath: String, finalExportPath: String) -> Dictionary:
	var projectNorm = _normalizePath(projectDir)
	var exportRootNorm = _normalizePath(exportRootPath)
	var finalNorm = _normalizePath(finalExportPath)

	# Check 1: Export root cannot be same as project
	if exportRootNorm == projectNorm:
		return {"valid": false, "error": "Export root cannot be the same as project directory"}

	# Check 2: Export root cannot be a parent of project
	if projectNorm.begins_with(exportRootNorm + "/"):
		return {"valid": false, "error": "Export root cannot be a parent of the project directory"}

	# Check 3: Final export path cannot be same as project
	if finalNorm == projectNorm:
		return {"valid": false, "error": "Final export path cannot be the same as project directory"}

	# Check 4: Final export path cannot be a parent of project
	if projectNorm.begins_with(finalNorm + "/"):
		return {"valid": false, "error": "Final export path cannot be a parent of the project directory"}

	# Note: We ALLOW exports inside the project directory (e.g., project/exports/)
	# The _copyDirectoryUnfiltered function excludes the export root path during copy
	# which prevents recursive loops. This is a common and valid use case.

	return {"valid": true, "error": ""}

# Creates a zip archive of the export folder
# Returns the path to the zip file, or empty string on failure
func _createZipArchive(exportDir: String, archiveFilename: String) -> String:
	# Use archive filename directly (already includes version/platform from template)
	# Strip .zip if already present to avoid double extension
	var zipFilename = archiveFilename
	if not zipFilename.ends_with(".zip"):
		zipFilename = zipFilename + ".zip"

	# For Source platform, we need to:
	# 1. Create zip from the source files that were copied into exportDir
	# 2. Place the zip directly in exportDir (replacing the source files)
	# For binary platforms, the exportDir contains the exported binary, so zip goes there too

	# Zip is placed in the exportDir itself
	var zipPath = exportDir.path_join(zipFilename)

	# For Source platform, the source files are directly in exportDir
	# We need to zip them, then delete them, leaving only the zip
	# To avoid including the zip in itself, we'll zip to a temp location first
	var tempZipPath = exportDir.get_base_dir().path_join("_temp_" + zipFilename)

	# Use PowerShell to create zip (Windows)
	var command = "powershell -Command \"Compress-Archive -Path '%s\\*' -DestinationPath '%s' -Force\"" % [exportDir.replace("/", "\\"), tempZipPath.replace("/", "\\")]

	var pid = OS.create_process("cmd.exe", ["/c", command])
	if pid == -1:
		print("Error: Failed to start zip process")
		return ""

	# Wait for process to complete
	while OS.is_process_running(pid):
		if _exportCancelled:
			OS.kill(pid)
			return ""
		await get_tree().create_timer(0.1).timeout

	# Verify temp zip was created
	if not FileAccess.file_exists(tempZipPath):
		print("Error: Zip file not created: ", tempZipPath)
		return ""

	# Clear the exportDir contents and move zip into it
	_clearDirectoryContents(exportDir)

	# Move zip from temp location to final location
	var moveErr = DirAccess.rename_absolute(tempZipPath, zipPath)
	if moveErr != OK:
		print("Error: Failed to move zip to final location: ", moveErr)
		# Try to clean up temp file
		DirAccess.remove_absolute(tempZipPath)
		return ""

	return zipPath

# Clears all contents of a directory but keeps the directory itself
func _clearDirectoryContents(path: String) -> bool:
	var dir = DirAccess.open(path)
	if dir == null:
		return false

	dir.list_dir_begin()
	var fileName = dir.get_next()

	while fileName != "":
		if fileName == "." or fileName == "..":
			fileName = dir.get_next()
			continue

		var fullPath = path.path_join(fileName)

		if dir.current_is_dir():
			_deleteDirectoryRecursive(fullPath)
		else:
			dir.remove(fileName)

		fileName = dir.get_next()

	dir.list_dir_end()
	return true

# Recursively deletes a directory and all its contents
func _deleteDirectoryRecursive(path: String) -> bool:
	var dir = DirAccess.open(path)
	if dir == null:
		return false

	dir.list_dir_begin()
	var fileName = dir.get_next()

	while fileName != "":
		if fileName == "." or fileName == "..":
			fileName = dir.get_next()
			continue

		var fullPath = path.path_join(fileName)

		if dir.current_is_dir():
			_deleteDirectoryRecursive(fullPath)
		else:
			dir.remove(fileName)

		fileName = dir.get_next()

	dir.list_dir_end()

	# Remove the now-empty directory
	return DirAccess.remove_absolute(path) == OK

# Generates a SHA256 checksum file
# Returns true on success
func _generateChecksum(targetPath: String, isZip: bool, platform: String, filename: String) -> bool:
	# Determine what to checksum
	var fileToChecksum = targetPath
	if not isZip:
		# For non-zip, checksum the primary binary
		var extension = _getPlatformExtension(platform)
		if extension == "source folder":
			# For Source platform without zip, checksum the folder contents would be complex
			# Skip checksum for non-zipped source exports
			print("Skipping checksum for non-zipped Source export")
			return true
		fileToChecksum = targetPath.path_join(filename + extension)

	# Verify target exists
	if not FileAccess.file_exists(fileToChecksum):
		print("Error: Cannot checksum - file not found: ", fileToChecksum)
		return false

	# Use existing FileHelper to generate checksum
	var checksumHash = FileHelper.CreateChecksum(fileToChecksum)
	if checksumHash == null or checksumHash.is_empty():
		print("Error: Failed to generate checksum for ", fileToChecksum)
		return false

	# Write checksum file in BSD-style format
	var checksumPath = fileToChecksum + ".sha256"
	var checksumFilename = fileToChecksum.get_file()
	var checksumContent = "SHA256 (%s) = %s\n" % [checksumFilename, checksumHash]

	var file = FileAccess.open(checksumPath, FileAccess.WRITE)
	if file == null:
		print("Error: Cannot write checksum file: ", checksumPath)
		return false

	file.store_string(checksumContent)
	file.close()

	return true

# Reads content from a temp output file
func _readTempOutputFile(filePath: String) -> String:
	if not FileAccess.file_exists(filePath):
		return ""
	var file = FileAccess.open(filePath, FileAccess.READ)
	if file == null:
		return ""
	var content = file.get_as_text()
	file.close()
	return content

# Deletes a temp output file
func _cleanupTempOutputFile(filePath: String):
	if FileAccess.file_exists(filePath):
		DirAccess.remove_absolute(filePath)

# Stores export output and populates the output text
func _storeExportOutput(platform: String, output: String):
	_platformExportOutput[platform] = output
	var data = _platformRows.get(platform)
	if data == null:
		return
	# Populate output text
	if data.has("outputLogText") and is_instance_valid(data["outputLogText"]):
		data["outputLogText"].text = output if output != "" else "(No output captured)"

# Clears export output and hides the output area
func _clearExportOutput(platform: String):
	_platformExportOutput.erase(platform)
	var data = _platformRows.get(platform)
	if data == null:
		return
	# Hide output area and clear text
	if data.has("outputLogContainer") and is_instance_valid(data["outputLogContainer"]):
		data["outputLogContainer"].visible = false
	if data.has("outputLogText") and is_instance_valid(data["outputLogText"]):
		data["outputLogText"].text = ""

# Toggles visibility of the output log area
func _onOutputLogTogglePressed(platform: String):
	var data = _platformRows.get(platform)
	if data == null:
		return
	if not data.has("outputLogContainer") or not is_instance_valid(data["outputLogContainer"]):
		return
	if not data.has("outputLogToggle") or not is_instance_valid(data["outputLogToggle"]):
		return

	var container = data["outputLogContainer"]
	var toggle = data["outputLogToggle"]
	container.visible = not container.visible

	# Update icon based on visibility
	if container.visible:
		toggle.icon = ICON_CHEVRON_UP
		toggle.tooltip_text = "Hide export output"
	else:
		toggle.icon = ICON_CHEVRON_DOWN
		toggle.tooltip_text = "Show export output"
