extends Control

signal settings_saved(platform: String, filter_config: Dictionary)
signal cancelled()

# Node references
@onready var _platformLabel = %PlatformLabel
@onready var _tree = %Tree
@onready var _expandAllButton = %ExpandAllButton
@onready var _helpButton = %HelpButton
@onready var _patternsList = %PatternsList
@onready var _addPatternButton = %AddPatternButton
@onready var _filesList = %FilesList
@onready var _addFileButton = %AddFileButton
@onready var _cancelButton = %CancelButton
@onready var _saveButton = %SaveButton
@onready var _excludePatternsHelpButton = %ExcludePatternsHelpButton
@onready var _additionalFilesHelpButton = %AdditionalFilesHelpButton

# Tab buttons
@onready var _projectFilesTab = %ProjectFilesTab
@onready var _excludePatternsTab = %ExcludePatternsTab
@onready var _additionalFilesTab = %AdditionalFilesTab
@onready var _tabButtonsContainer = %TabButtons

# Cards
@onready var _projectTreeCard = %ProjectTreeCard
@onready var _excludePatternsCard = %ExcludePatternsCard
@onready var _additionalFilesCard = %AdditionalFilesCard
@onready var _cardContainer = %CardContainer

# Dynamic nodes (created for binary platforms)
var _includePatternsTab: Button = null
var _includePatternsCard: PanelContainer = null
var _includePatternsList: VBoxContainer = null
var _addIncludePatternButton: Button = null
var _includePatternsHelpButton: Button = null

# State
var _platform: String = ""
var _projectPath: String = ""
var _excludePatterns: Array[String] = []
var _includePatterns: Array[String] = []  # For binary exports (from export_presets.cfg)
var _additionalFiles: Array[Dictionary] = []  # [{source: "", target: ""}]
var _treeExpanded: bool = false
var _currentTab: int = 0  # 0=Project Files/Include Patterns, 1=Exclude Patterns, 2=Additional Files
var _isDirty: bool = false  # Track unsaved changes
var _lastSavedConfig: Dictionary = {}  # Track last saved state for comparison
var _initialExcludePatterns: Array[String] = []  # Original patterns when dialog opened
var _initialIncludePatterns: Array[String] = []  # Original include patterns when dialog opened
var _initialAdditionalFiles: Array[Dictionary] = []  # Original files when dialog opened
var _initialExcludedPaths: Array[String] = []  # Original excluded paths when dialog opened
var _projectItem = null  # Reference to ProjectItem for reading/writing export_presets.cfg
var _isBinaryPlatform: bool = false  # True for Windows, Linux, etc. False for Source

# Checkbox icons
var _iconChecked: Texture2D
var _iconUnchecked: Texture2D

# Busy overlay
var _busy_overlay: Control
var _busy_spinner: Label
var _busy_animation_timer: Timer
var _spinner_frames := ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
var _spinner_frame_index: int = 0

const PROJECT_FILES_HELP_TEXT = """Use the checkboxes to include or exclude files and folders from the Source export.

- Click a folder to toggle all its contents
- Checked items will be included in the export
- Unchecked items will be excluded

Greyed out items match an Exclude Pattern and cannot be selected. They will always be excluded from the export. To include a pattern-excluded item, remove or modify the pattern in the Exclude Patterns tab.

This tree shows all files in your project. Use it for fine-grained control over exactly which files are exported."""

const EXCLUDE_PATTERNS_HELP_TEXT = """Add patterns to automatically exclude matching files and folders.

Examples:
- .git/ - Exclude the .git folder
- .godot/ - Exclude the .godot cache folder
- *.tmp - Exclude all .tmp files
- exports/ - Exclude the exports folder

Patterns support wildcards:
- * matches any characters within a filename
- Trailing / indicates a folder

Patterns are applied in addition to unchecked items in Project Files."""

const ADDITIONAL_FILES_HELP_TEXT = """Add files or folders from outside your project to include in the export.

Use this to bundle external assets, documentation, or dependencies with your Source export.

- Source: The path to the file or folder to include
- Target: Where to place it in the export (relative to export root)

For example, add a README.txt from your documents folder to appear at the root of your exported source."""

const INCLUDE_PATTERNS_HELP_TEXT = """Add patterns to include non-resource files in the exported binary.

By default, Godot only includes recognized resources (images, scenes, scripts, etc.) in the .pck file. Use this to include additional files like:
- *.sql - SQL migration files
- *.json - JSON data files
- data/* - Entire data folder

Examples:
- *.sql - Include all .sql files
- supabase-migrations/* - Include the supabase-migrations folder
- *.json, *.xml - Multiple patterns

These files will be accessible via res:// at runtime."""

func _ready():
	visible = false
	z_index = 100  # Above other UI

	# Apply card styling
	_applyCardStyling()

	# Connect tab buttons
	if _projectFilesTab:
		_projectFilesTab.pressed.connect(_onTabPressed.bind(0))
	if _excludePatternsTab:
		_excludePatternsTab.pressed.connect(_onTabPressed.bind(1))
	if _additionalFilesTab:
		_additionalFilesTab.pressed.connect(_onTabPressed.bind(2))

	# Initialize tab button states (default to first tab)
	_updateTabButtonStates(0)

	# Connect signals (with null checks)
	if _expandAllButton:
		_expandAllButton.pressed.connect(_onExpandAllPressed)
	if _helpButton:
		_helpButton.pressed.connect(_onHelpPressed)
	if _addPatternButton:
		_addPatternButton.pressed.connect(_onAddPatternPressed)
	if _addFileButton:
		_addFileButton.pressed.connect(_onAddFilePressed)
	if _cancelButton:
		_cancelButton.pressed.connect(_onCancelPressed)
	if _saveButton:
		_saveButton.pressed.connect(_onSavePressed)
	if _excludePatternsHelpButton:
		_excludePatternsHelpButton.pressed.connect(_onExcludePatternsHelpPressed)
	if _additionalFilesHelpButton:
		_additionalFilesHelpButton.pressed.connect(_onAdditionalFilesHelpPressed)

	# Load checkbox icons
	_iconChecked = load("res://scenes/release-manager/assets/checkbox-checked.svg")
	_iconUnchecked = load("res://scenes/release-manager/assets/checkbox-unchecked.svg")

	# Set up tree (with null check)
	if _tree:
		# Configure columns
		_tree.set_column_expand(0, true)   # Name column expands
		_tree.set_column_expand(1, false)  # Size column fixed width
		_tree.set_column_custom_minimum_width(1, 150)

		# Make tree more responsive
		_tree.allow_reselect = true  # Allow clicking selected item to trigger signal again

		# Use item_mouse_selected to toggle on every click (not just selection change)
		_tree.item_mouse_selected.connect(_onTreeItemClicked)

	# Setup busy overlay
	_setup_busy_overlay()

# Setup busy overlay for loading state
func _setup_busy_overlay() -> void:
	_busy_overlay = Control.new()
	_busy_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_busy_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_busy_overlay.visible = false
	_busy_overlay.z_index = 150
	add_child(_busy_overlay)
	move_child(_busy_overlay, -1)

	# Semi-transparent dark background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.1, 0.12, 0.15, 0.85)
	_busy_overlay.add_child(bg)

	# Centered container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_busy_overlay.add_child(center)

	# Panel with loading content
	var panel := PanelContainer.new()
	var panelStyle := StyleBoxFlat.new()
	panelStyle.bg_color = Color(0.15, 0.17, 0.21, 0.95)
	panelStyle.set_corner_radius_all(8)
	panelStyle.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panelStyle)
	center.add_child(panel)

	# VBox for spinner and label
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Spinner
	_busy_spinner = Label.new()
	_busy_spinner.text = _spinner_frames[0]
	_busy_spinner.add_theme_font_size_override("font_size", 32)
	_busy_spinner.add_theme_color_override("font_color", Color(0.4, 0.6, 0.9))
	_busy_spinner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_busy_spinner)

	# Status label
	var statusLabel := Label.new()
	statusLabel.text = "Loading project files..."
	statusLabel.add_theme_font_size_override("font_size", 14)
	statusLabel.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	statusLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(statusLabel)

	# Animation timer
	_busy_animation_timer = Timer.new()
	_busy_animation_timer.wait_time = 0.08
	_busy_animation_timer.timeout.connect(_on_busy_animation_tick)
	add_child(_busy_animation_timer)

func _show_busy_overlay() -> void:
	_busy_overlay.visible = true
	_busy_animation_timer.start()

func _hide_busy_overlay() -> void:
	_busy_overlay.visible = false
	_busy_animation_timer.stop()

func _on_busy_animation_tick() -> void:
	_spinner_frame_index = (_spinner_frame_index + 1) % _spinner_frames.size()
	_busy_spinner.text = _spinner_frames[_spinner_frame_index]

# Open dialog for a specific platform with current settings
# projectItem is optional - needed for binary platforms to read/write export_presets.cfg
func openForPlatform(platform: String, projectPath: String, currentConfig: Dictionary, projectItem = null):
	_platform = platform
	_projectPath = projectPath
	_projectItem = projectItem
	_isBinaryPlatform = (platform != "Source")

	# Update UI
	_platformLabel.text = "Platform: " + platform

	# Set up platform-specific UI
	_setupPlatformUI()

	# Load existing config
	# WORKAROUND: Create NEW array to avoid GDScript iteration bug with Dictionary.get() arrays
	var patternsRaw = currentConfig.get("exclude_patterns", [])

	# Create fresh array and copy items manually
	var patterns: Array[String] = []
	for i in range(patternsRaw.size()):
		var item = patternsRaw[i]
		if item is String:
			patterns.append(item)

	_excludePatterns.clear()

	# Iterate the fresh array
	for pattern in patterns:
		_excludePatterns.append(pattern)

	# Load excluded paths (same workaround for GDScript bug) - only for Source
	var excludedPaths: Array[String] = []
	if not _isBinaryPlatform:
		var excludedPathsRaw = currentConfig.get("excluded_paths", [])
		for i in range(excludedPathsRaw.size()):
			var item = excludedPathsRaw[i]
			if item is String:
				excludedPaths.append(item)

	var files = currentConfig.get("additional_files", [])
	_additionalFiles.clear()
	# Manual append to avoid type conversion issues
	for file in files:
		if file is Dictionary:
			_additionalFiles.append(file)

	# For binary platforms, load include patterns from export_presets.cfg
	# (exclude patterns still come from godot-valet config, same as Source)
	_includePatterns.clear()
	if _isBinaryPlatform and _projectItem != null:
		var presetFilters = _projectItem.GetExportPresetFilters(platform)
		var includeFilterStr = presetFilters.get("include_filter", "")

		# Parse comma-separated patterns
		if includeFilterStr != "":
			for p in includeFilterStr.split(","):
				var trimmed = p.strip_edges()
				if trimmed != "":
					_includePatterns.append(trimmed)

	# Apply default exclude patterns if this is first time (no config) - all platforms
	if _excludePatterns.is_empty() and currentConfig.is_empty():
		_excludePatterns = _getDefaultExcludePatterns()

	# Store initial state for discard/reset
	_initialExcludePatterns = _excludePatterns.duplicate()
	_initialIncludePatterns = _includePatterns.duplicate()
	_initialAdditionalFiles = _additionalFiles.duplicate(true)
	_initialExcludedPaths = excludedPaths.duplicate()
	_isDirty = false

	# Show dialog FIRST so layout happens
	visible = true
	move_to_front()

	# Show busy overlay while loading
	_show_busy_overlay()

	# Wait a couple frames for overlay to render before blocking tree build
	await get_tree().process_frame
	await get_tree().process_frame

	# Build appropriate UI based on platform
	if _isBinaryPlatform:
		# Build include patterns UI for binary
		_buildIncludePatternsUI()
	else:
		# Build tree for Source
		_buildProjectTree()

	# Apply tree colors AFTER card styling to ensure they're not overridden
	_applyTreeColors()

	# Apply excluded paths to tree (uncheck previously excluded items)
	_applyExcludedPathsToTree(excludedPaths)

	# Build exclude patterns UI
	_buildExcludePatternsUI()

	# Hide busy overlay now that loading is complete
	_hide_busy_overlay()

	# Build additional files UI
	_buildAdditionalFilesUI()

	# Switch to first appropriate tab
	if _isBinaryPlatform:
		_switchToTab(0)  # Include Patterns tab
	else:
		_switchToTab(0)  # Project Files tab

# Set up platform-specific UI elements
func _setupPlatformUI():
	print("_setupPlatformUI called")
	print("  _platform: ", _platform)
	print("  _isBinaryPlatform: ", _isBinaryPlatform)

	# Reset current tab to ensure clean state
	_currentTab = 0

	# First, hide ALL cards to start fresh
	if _projectTreeCard:
		_projectTreeCard.visible = false
	if _excludePatternsCard:
		_excludePatternsCard.visible = false
	if _additionalFilesCard:
		_additionalFilesCard.visible = false
	if _includePatternsCard:
		_includePatternsCard.visible = false

	if _isBinaryPlatform:
		# Hide Project Files tab (not relevant for binary exports)
		if _projectFilesTab:
			_projectFilesTab.visible = false

		# Create Include Patterns tab if not exists
		_ensureIncludePatternsUI()

		# Show Include Patterns tab (card will be shown by _switchToTab)
		if _includePatternsTab:
			_includePatternsTab.visible = true
	else:
		# Source platform - show Project Files tab
		if _projectFilesTab:
			_projectFilesTab.visible = true

		# Hide Include Patterns tab if it exists
		if _includePatternsTab:
			_includePatternsTab.visible = false

# Create Include Patterns tab and card if they don't exist
func _ensureIncludePatternsUI():
	if _includePatternsTab != null:
		return  # Already created

	print("Creating Include Patterns UI...")
	print("  _tabButtonsContainer: ", _tabButtonsContainer)
	print("  _cardContainer: ", _cardContainer)

	# Create tab button
	_includePatternsTab = Button.new()
	_includePatternsTab.text = "Include Patterns"
	_includePatternsTab.custom_minimum_size = Vector2(150, 36)
	_includePatternsTab.pressed.connect(_onTabPressed.bind(0))

	# Insert at the beginning of tab buttons
	if _tabButtonsContainer:
		_tabButtonsContainer.add_child(_includePatternsTab)
		_tabButtonsContainer.move_child(_includePatternsTab, 0)
		print("  Added tab to container")
	else:
		print("  ERROR: _tabButtonsContainer is null!")

	# Create card (similar to Exclude Patterns card)
	_includePatternsCard = PanelContainer.new()
	_includePatternsCard.set_anchors_preset(Control.PRESET_FULL_RECT)
	_includePatternsCard.visible = false

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 0)
	_includePatternsCard.add_child(content)

	# Header
	var header = PanelContainer.new()
	content.add_child(header)

	var headerMargin = MarginContainer.new()
	headerMargin.add_theme_constant_override("margin_left", 10)
	headerMargin.add_theme_constant_override("margin_top", 10)
	headerMargin.add_theme_constant_override("margin_right", 10)
	headerMargin.add_theme_constant_override("margin_bottom", 10)
	header.add_child(headerMargin)

	var headerRow = HBoxContainer.new()
	headerRow.add_theme_constant_override("separation", 8)
	headerMargin.add_child(headerRow)

	var headerLabel = Label.new()
	headerLabel.text = "Include Patterns"
	headerLabel.add_theme_font_size_override("font_size", 16)
	headerLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headerRow.add_child(headerLabel)

	_addIncludePatternButton = Button.new()
	_addIncludePatternButton.text = "+ Add Pattern"
	_addIncludePatternButton.custom_minimum_size = Vector2(150, 0)
	_addIncludePatternButton.pressed.connect(_onAddIncludePatternPressed)
	headerRow.add_child(_addIncludePatternButton)

	_includePatternsHelpButton = Button.new()
	_includePatternsHelpButton.text = "?"
	_includePatternsHelpButton.custom_minimum_size = Vector2(32, 0)
	_includePatternsHelpButton.focus_mode = Control.FOCUS_NONE
	_includePatternsHelpButton.pressed.connect(_onIncludePatternsHelpPressed)
	headerRow.add_child(_includePatternsHelpButton)

	# Content panel
	var contentPanel = PanelContainer.new()
	contentPanel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(contentPanel)

	var contentMargin = MarginContainer.new()
	contentMargin.add_theme_constant_override("margin_left", 10)
	contentMargin.add_theme_constant_override("margin_top", 10)
	contentMargin.add_theme_constant_override("margin_right", 10)
	contentMargin.add_theme_constant_override("margin_bottom", 10)
	contentPanel.add_child(contentMargin)

	var patternsVBox = VBoxContainer.new()
	patternsVBox.add_theme_constant_override("separation", 8)
	contentMargin.add_child(patternsVBox)

	var scrollContainer = ScrollContainer.new()
	scrollContainer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	patternsVBox.add_child(scrollContainer)

	_includePatternsList = VBoxContainer.new()
	_includePatternsList.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_includePatternsList.add_theme_constant_override("separation", 4)
	scrollContainer.add_child(_includePatternsList)

	# Add card to container
	if _cardContainer:
		_cardContainer.add_child(_includePatternsCard)
		print("  Added card to container")
	else:
		print("  ERROR: _cardContainer is null!")

	# Apply card styling
	_applyCardStyling()
	print("  Include Patterns UI created successfully")

# Build the include patterns list UI
func _buildIncludePatternsUI():
	if not _includePatternsList:
		return

	# Clear existing patterns
	for child in _includePatternsList.get_children():
		child.queue_free()

	# Add each pattern as a row
	for pattern in _includePatterns:
		_addIncludePatternRow(pattern)

	# Update header count
	_updateIncludeCount()

func _addIncludePatternRow(pattern: String):
	if not _includePatternsList:
		return

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var patternEdit = LineEdit.new()
	patternEdit.text = pattern
	patternEdit.placeholder_text = "e.g., *.sql, data/*, *.json"
	patternEdit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	patternEdit.editable = true
	patternEdit.text_changed.connect(_onIncludePatternTextChanged.bind(patternEdit))
	row.add_child(patternEdit)

	var removeButton = Button.new()
	removeButton.text = "Remove"
	removeButton.custom_minimum_size = Vector2(80, 0)
	removeButton.pressed.connect(_onRemoveIncludePatternPressed.bind(row))
	row.add_child(removeButton)

	_includePatternsList.add_child(row)

func _updateIncludeCount():
	# Update the header label with pattern count (if we had a label reference)
	pass

func _onAddIncludePatternPressed():
	# Add empty pattern that user can edit
	_includePatterns.append("")
	_addIncludePatternRow("")
	_isDirty = true

func _onIncludePatternTextChanged(newText: String, patternEdit: LineEdit):
	# Find which row this LineEdit belongs to by finding it in the patterns list
	var row = patternEdit.get_parent() as HBoxContainer
	if not row:
		return

	# Find the index of this row in the patterns list
	var rowIndex = row.get_index()
	if rowIndex >= 0 and rowIndex < _includePatterns.size():
		_includePatterns[rowIndex] = newText
		_isDirty = true

func _onRemoveIncludePatternPressed(row: HBoxContainer):
	# Find which pattern this row represents
	var patternEdit = row.get_child(0) as LineEdit
	if patternEdit:
		var pattern = patternEdit.text
		_includePatterns.erase(pattern)
		row.queue_free()
		_updateIncludeCount()
		_isDirty = true

func _onIncludePatternsHelpPressed():
	_showHelpDialog("Include Patterns", INCLUDE_PATTERNS_HELP_TEXT)

func _applyExcludedPathsToTree(excludedPaths: Array[String]):
	if excludedPaths.is_empty():
		return

	# Recursively uncheck all items in excluded paths
	var root = _tree.get_root()
	if root:
		for path in excludedPaths:
			var relativePath = path
			_uncheckItemByPath(root, relativePath)

func _uncheckItemByPath(item: TreeItem, targetPath: String) -> bool:
	if item == null:
		return false

	# Check if this item matches the target path
	var metadata = item.get_metadata(0)
	if metadata != null and metadata is Dictionary:
		var itemPath = metadata.get("path", "")
		# Make path relative to project
		var relativePath = itemPath.replace(_projectPath + "/", "").replace(_projectPath + "\\", "")

		if relativePath == targetPath:
			# Found it! Uncheck this item
			metadata["checked"] = false
			item.set_icon(0, _iconUnchecked)
			# Propagate uncheck state to all children (folder was unchecked, so all contents should be unchecked)
			_propagateCheckState(item, false)
			return true

	# Recurse to children
	var child = item.get_first_child()
	while child:
		if _uncheckItemByPath(child, targetPath):
			return true
		child = child.get_next()

	return false

func _getDefaultExcludePatterns() -> Array[String]:
	var defaults: Array[String] = []
	defaults.append(".git/")
	defaults.append(".godot/")
	defaults.append(".import/")
	defaults.append("exports/")
	defaults.append(".vscode/")
	defaults.append(".vs/")
	defaults.append(".idea/")
	return defaults

# Checks if a relative path matches any exclude pattern
func _matchesExcludePattern(relativePath: String, isDirectory: bool) -> bool:
	for pattern in _excludePatterns:
		if pattern.is_empty():
			continue
		if pattern.ends_with("/"):
			# Directory pattern - check if path starts with or equals pattern (without trailing /)
			var dirPattern = pattern.trim_suffix("/")
			if isDirectory:
				if relativePath == dirPattern or relativePath.begins_with(dirPattern + "/"):
					return true
			else:
				# File inside a directory that matches
				if relativePath.begins_with(dirPattern + "/"):
					return true
		elif pattern.contains("*"):
			# Wildcard pattern
			var regexPattern = "^" + pattern.replace(".", "\\.").replace("*", ".*") + "$"
			var regex = RegEx.new()
			regex.compile(regexPattern)
			# Check both the full path and just the filename
			if regex.search(relativePath):
				return true
			var fileName = relativePath.get_file()
			if regex.search(fileName):
				return true
		else:
			# Exact match
			if relativePath == pattern:
				return true
	return false

func _applyTreeColors():
	# Apply tree colors - must be called AFTER card styling to avoid being overridden
	if not _tree:
		print("ERROR: Tree is null in _applyTreeColors")
		return

	# Don't apply any custom theme - let it use the global theme

func _buildProjectTree():
	if not _tree:
		print("ERROR: Tree is null in _buildProjectTree")
		return

	_tree.clear()
	var root = _tree.create_item()

	if _projectPath.is_empty() or not DirAccess.dir_exists_absolute(_projectPath):
		print("ERROR: Invalid project path: ", _projectPath)
		return

	# Add project directory as root
	var projectName = _projectPath.get_file()
	_addDirectoryToTree(root, _projectPath, projectName)

	# Expand all by default
	_expandAllTree()
	_treeExpanded = true
	if _expandAllButton:
		_expandAllButton.text = "Collapse All"

	# Force tree to update/redraw
	_tree.queue_redraw()
	_tree.update_minimum_size()

# Rebuilds tree with current exclude patterns, preserving manual exclusions
func _rebuildTreeWithPatterns():
	if not _tree:
		return

	# Collect manually unchecked paths (NOT pattern-excluded)
	var manualExclusions: Array[String] = []
	_collectManualExclusions(_tree.get_root(), manualExclusions)

	# Rebuild tree with current patterns
	_buildProjectTree()

	# Re-apply manual exclusions
	_applyExcludedPathsToTree(manualExclusions)

# Collects paths that were manually unchecked (not pattern-excluded)
func _collectManualExclusions(item: TreeItem, exclusions: Array[String]):
	if item == null:
		return

	var metadata = item.get_metadata(0)
	if metadata != null and metadata is Dictionary:
		var isChecked = metadata.get("checked", true)
		var isPatternExcluded = metadata.get("pattern_excluded", false)
		# Only collect if manually unchecked (not pattern-excluded)
		if not isChecked and not isPatternExcluded:
			var path = metadata.get("path", "")
			var relativePath = path.replace(_projectPath + "/", "").replace(_projectPath + "\\", "")
			if not exclusions.has(relativePath):
				exclusions.append(relativePath)

	var child = item.get_first_child()
	while child:
		_collectManualExclusions(child, exclusions)
		child = child.get_next()

func _addDirectoryToTree(parentItem: TreeItem, dirPath: String, displayName: String, parentExcluded: bool = false) -> TreeItem:
	var item = _tree.create_item(parentItem)

	# Check if this directory matches an exclude pattern
	var relativePath = dirPath.replace(_projectPath + "/", "").replace(_projectPath + "\\", "")
	var isPatternExcluded = parentExcluded or _matchesExcludePattern(relativePath, true)

	# Column 0: Checkbox icon + folder name
	if isPatternExcluded:
		item.set_icon(0, _iconUnchecked)
		item.set_icon_modulate(0, Color(0.5, 0.5, 0.5, 0.5))
		item.set_custom_color(0, Color(0.5, 0.5, 0.5))
		item.set_selectable(0, false)
		item.set_metadata(0, {"path": dirPath, "checked": false, "pattern_excluded": true})
	else:
		item.set_icon(0, _iconChecked)
		item.set_metadata(0, {"path": dirPath, "checked": true})
	item.set_text(0, displayName + "/")

	# Column 1: Size
	var dirInfo = _getDirectoryInfo(dirPath)
	var sizeText = _formatSize(dirInfo["size"]) + " (" + str(dirInfo["files"]) + " files)"
	item.set_text(1, sizeText)

	# Add subdirectories and files
	var dir = DirAccess.open(dirPath)
	if dir == null:
		return item

	dir.list_dir_begin()
	var fileName = dir.get_next()

	# Collect directories and files
	var directories: Array[String] = []
	var files: Array[String] = []

	while fileName != "":
		if fileName == "." or fileName == "..":
			fileName = dir.get_next()
			continue

		if dir.current_is_dir():
			directories.append(fileName)
		else:
			files.append(fileName)

		fileName = dir.get_next()

	dir.list_dir_end()

	# Sort and add directories first
	directories.sort()
	for dirName in directories:
		var subDirPath = dirPath.path_join(dirName)
		_addDirectoryToTree(item, subDirPath, dirName, isPatternExcluded)

	# Then add files
	files.sort()
	for file in files:
		var filePath = dirPath.path_join(file)
		_addFileToTree(item, filePath, file, isPatternExcluded)

	return item

func _addFileToTree(parentItem: TreeItem, filePath: String, displayName: String, parentExcluded: bool = false):
	var item = _tree.create_item(parentItem)

	# Check if this file matches an exclude pattern
	var relativePath = filePath.replace(_projectPath + "/", "").replace(_projectPath + "\\", "")
	var isPatternExcluded = parentExcluded or _matchesExcludePattern(relativePath, false)

	# Column 0: Checkbox icon + filename
	if isPatternExcluded:
		item.set_icon(0, _iconUnchecked)
		item.set_icon_modulate(0, Color(0.5, 0.5, 0.5, 0.5))
		item.set_custom_color(0, Color(0.5, 0.5, 0.5))
		item.set_selectable(0, false)
		item.set_metadata(0, {"path": filePath, "checked": false, "pattern_excluded": true})
	else:
		item.set_icon(0, _iconChecked)
		item.set_metadata(0, {"path": filePath, "checked": true})
	item.set_text(0, displayName)

	# Column 1: Size
	var file = FileAccess.open(filePath, FileAccess.READ)
	if file:
		var fileSize = file.get_length()
		var sizeText = _formatSize(fileSize)
		item.set_text(1, sizeText)
		file.close()

func _getDirectoryInfo(dirPath: String) -> Dictionary:
	var totalSize: int = 0
	var fileCount: int = 0

	var dir = DirAccess.open(dirPath)
	if dir == null:
		return {"size": 0, "files": 0}

	dir.list_dir_begin()
	var fileName = dir.get_next()

	while fileName != "":
		if fileName != "." and fileName != "..":
			var fullPath = dirPath.path_join(fileName)

			if dir.current_is_dir():
				var subInfo = _getDirectoryInfo(fullPath)
				totalSize += subInfo["size"]
				fileCount += subInfo["files"]
			else:
				var file = FileAccess.open(fullPath, FileAccess.READ)
				if file:
					totalSize += file.get_length()
					fileCount += 1
					file.close()

		fileName = dir.get_next()

	dir.list_dir_end()

	return {"size": totalSize, "files": fileCount}

func _formatSize(bytes: int) -> String:
	if bytes < 1024:
		return str(bytes) + " B"
	elif bytes < 1024 * 1024:
		return "%.1f KB" % (bytes / 1024.0)
	elif bytes < 1024 * 1024 * 1024:
		return "%.1f MB" % (bytes / (1024.0 * 1024.0))
	else:
		return "%.2f GB" % (bytes / (1024.0 * 1024.0 * 1024.0))

func _buildExcludePatternsUI():
	if not _patternsList:
		return

	# Clear existing patterns
	for child in _patternsList.get_children():
		child.queue_free()

	# Add each pattern as a row
	for pattern in _excludePatterns:
		_addPatternRow(pattern)

	# Update header count
	_updateExcludeCount()

func _addPatternRow(pattern: String):
	if not _patternsList:
		return

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var patternEdit = LineEdit.new()
	patternEdit.text = pattern
	patternEdit.placeholder_text = "e.g., *.tmp, .git/, exports/"
	patternEdit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	patternEdit.editable = true
	patternEdit.text_changed.connect(_onPatternTextChanged.bind(patternEdit))
	row.add_child(patternEdit)

	var removeButton = Button.new()
	removeButton.text = "Remove"
	removeButton.custom_minimum_size = Vector2(80, 0)
	removeButton.pressed.connect(_onRemovePatternPressed.bind(row))
	row.add_child(removeButton)

	_patternsList.add_child(row)

func _buildAdditionalFilesUI():
	if not _filesList:
		return

	# Clear existing files
	for child in _filesList.get_children():
		child.queue_free()

	# Add each file entry as a row
	for fileEntry in _additionalFiles:
		_addAdditionalFileRow(fileEntry)

	# Update header count
	_updateAdditionalFilesCount()

func _addAdditionalFileRow(fileEntry: Dictionary):
	if not _filesList:
		return

	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	# Source row
	var sourceRow = HBoxContainer.new()
	sourceRow.add_theme_constant_override("separation", 8)

	var sourceLabel = Label.new()
	sourceLabel.text = "Source:"
	sourceLabel.custom_minimum_size = Vector2(60, 0)
	sourceRow.add_child(sourceLabel)

	var sourceEdit = LineEdit.new()
	sourceEdit.text = fileEntry.get("source", "")
	sourceEdit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sourceEdit.editable = false
	sourceRow.add_child(sourceEdit)

	var browseButton = Button.new()
	browseButton.text = "🗀"
	browseButton.custom_minimum_size = Vector2(32, 0)
	browseButton.pressed.connect(_onBrowseAdditionalFilePressed.bind(fileEntry))
	sourceRow.add_child(browseButton)

	row.add_child(sourceRow)

	# Target row
	var targetRow = HBoxContainer.new()
	targetRow.add_theme_constant_override("separation", 8)

	var targetLabel = Label.new()
	targetLabel.text = "Target:"
	targetLabel.custom_minimum_size = Vector2(60, 0)
	targetRow.add_child(targetLabel)

	var targetEdit = LineEdit.new()
	targetEdit.text = fileEntry.get("target", "")
	targetEdit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	targetEdit.text_changed.connect(_onTargetPathChanged.bind(fileEntry))
	targetRow.add_child(targetEdit)

	var removeButton = Button.new()
	removeButton.text = "X"
	removeButton.custom_minimum_size = Vector2(32, 0)
	removeButton.pressed.connect(_onRemoveAdditionalFilePressed.bind(fileEntry))
	targetRow.add_child(removeButton)

	row.add_child(targetRow)

	_filesList.add_child(row)

func _propagateCheckState(item: TreeItem, checked: bool):
	# Set all children to same state (icon-based checkboxes)
	var child = item.get_first_child()
	while child:
		var metadata = child.get_metadata(0)
		if metadata != null and metadata is Dictionary:
			metadata["checked"] = checked
			if checked:
				child.set_icon(0, _iconChecked)
			else:
				child.set_icon(0, _iconUnchecked)
		_propagateCheckState(child, checked)
		child = child.get_next()

func _onExpandAllPressed():
	_treeExpanded = !_treeExpanded

	if _treeExpanded:
		_expandAllTree()
		_expandAllButton.text = "Collapse All"
	else:
		_collapseAllTree()
		_expandAllButton.text = "Expand All"

func _expandAllTree():
	var root = _tree.get_root()
	if root:
		_expandTreeItem(root)

func _collapseAllTree():
	# Collapse to first visible level (project root folder)
	# Don't collapse the hidden root or the project folder itself
	var root = _tree.get_root()
	if root:
		var projectFolder = root.get_first_child()  # First child is the project folder
		if projectFolder:
			# Collapse all children of the project folder, but keep project folder expanded
			var child = projectFolder.get_first_child()
			while child:
				_collapseTreeItem(child)
				child = child.get_next()

func _expandTreeItem(item: TreeItem):
	item.collapsed = false
	var child = item.get_first_child()
	while child:
		_expandTreeItem(child)
		child = child.get_next()

func _collapseTreeItem(item: TreeItem):
	item.collapsed = true
	var child = item.get_first_child()
	while child:
		_collapseTreeItem(child)
		child = child.get_next()

func _onHelpPressed():
	_showHelpDialog("Project Files", PROJECT_FILES_HELP_TEXT)

func _onExcludePatternsHelpPressed():
	_showHelpDialog("Exclude Patterns", EXCLUDE_PATTERNS_HELP_TEXT)

func _onAdditionalFilesHelpPressed():
	_showHelpDialog("Additional Files", ADDITIONAL_FILES_HELP_TEXT)

func _showHelpDialog(titleText: String, content: String):
	# Create card-styled help dialog overlay
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 200

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

	# Scroll container for help content (in case it's long)
	var scrollContainer = ScrollContainer.new()
	scrollContainer.custom_minimum_size = Vector2(420, 100)
	scrollContainer.custom_maximum_size = Vector2(0, 300)  # Max height to trigger scrolling
	scrollContainer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scrollContainer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bodyVBox.add_child(scrollContainer)

	# Help content label
	var contentLabel = Label.new()
	contentLabel.text = content
	contentLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contentLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrollContainer.add_child(contentLabel)

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

func _onAddPatternPressed():
	# Add empty pattern that user can edit
	_excludePatterns.append("")
	_addPatternRow("")
	_isDirty = true

func _onPatternTextChanged(newText: String, patternEdit: LineEdit):
	# Find which row this LineEdit belongs to by finding it in the patterns list
	var row = patternEdit.get_parent() as HBoxContainer
	if not row:
		return

	# Find the index of this row in the patterns list
	var rowIndex = row.get_index()
	if rowIndex >= 0 and rowIndex < _excludePatterns.size():
		_excludePatterns[rowIndex] = newText
		_isDirty = true

func _onRemovePatternPressed(row: HBoxContainer):
	# Find which pattern this row represents
	var patternEdit = row.get_child(0) as LineEdit
	if patternEdit:
		var pattern = patternEdit.text
		_excludePatterns.erase(pattern)
		row.queue_free()
		_updateExcludeCount()
		_isDirty = true

func _onAddFilePressed():
	# Add a new empty file entry
	var newEntry = {"source": "", "target": ""}
	_additionalFiles.append(newEntry)
	_buildAdditionalFilesUI()
	_isDirty = true

func _onBrowseAdditionalFilePressed(fileEntry: Dictionary):
	# TODO: Open file/folder browser dialog
	print("Browse for additional file: ", fileEntry)

func _onTargetPathChanged(newPath: String, fileEntry: Dictionary):
	fileEntry["target"] = newPath
	_isDirty = true

func _onRemoveAdditionalFilePressed(fileEntry: Dictionary):
	_additionalFiles.erase(fileEntry)
	_buildAdditionalFilesUI()
	_isDirty = true

func _updateExcludeCount():
	# No longer showing count in header
	pass

func _updateAdditionalFilesCount():
	# No longer showing count in header
	pass

func _onSavePressed():
	if _isBinaryPlatform:
		# For binary platforms, save include/exclude patterns to export_presets.cfg
		_saveBinaryPlatformFilters()
	else:
		# For Source platform, use existing behavior
		_saveSourcePlatformFilters()

func _saveBinaryPlatformFilters():
	# Convert include patterns array to comma-separated string
	var includeFilterStr = ", ".join(_includePatterns)

	# Save include patterns to export_presets.cfg (this is what Godot uses for non-resource files)
	# Note: We don't save exclude patterns to export_presets.cfg - those stay in godot-valet config
	if _projectItem != null:
		# Get current exclude_filter from export_presets.cfg (don't overwrite it)
		var currentFilters = _projectItem.GetExportPresetFilters(_platform)
		var currentExcludeFilter = currentFilters.get("exclude_filter", "")

		var success = _projectItem.SetExportPresetFilters(_platform, includeFilterStr, currentExcludeFilter)
		if success:
			print("Saved include patterns to export_presets.cfg for ", _platform)
		else:
			print("Failed to save include patterns for ", _platform)

	# Build config dictionary (exclude patterns saved via signal, same as Source)
	var config = {
		"excluded_paths": [],  # Not used for binary (no tree)
		"exclude_patterns": _excludePatterns,  # Saved to godot-valet config
		"additional_files": _additionalFiles
	}

	# Emit signal to save exclude patterns and additional files
	settings_saved.emit(_platform, config)

	# Clear dirty state after save
	_isDirty = false
	_lastSavedConfig = config.duplicate(true)

	# Update initial state so discard will reset to this saved state
	_initialIncludePatterns = _includePatterns.duplicate()
	_initialExcludePatterns = _excludePatterns.duplicate()
	_initialAdditionalFiles = _additionalFiles.duplicate(true)

func _saveSourcePlatformFilters():
	# Collect all unchecked paths from tree
	var excludedPaths: Array[String] = []
	_collectUncheckedPaths(_tree.get_root(), excludedPaths)

	# Build config dictionary
	var config = {
		"excluded_paths": excludedPaths,
		"exclude_patterns": _excludePatterns,
		"additional_files": _additionalFiles
	}

	# Emit signal
	settings_saved.emit(_platform, config)

	# Clear dirty state after save
	_isDirty = false
	_lastSavedConfig = config.duplicate(true)

	# Update initial state so discard will reset to this saved state
	_initialExcludePatterns = _excludePatterns.duplicate()
	_initialAdditionalFiles = _additionalFiles.duplicate(true)
	_initialExcludedPaths = excludedPaths.duplicate()

	# Rebuild tree to reflect any pattern changes
	_rebuildTreeWithPatterns()

func _collectUncheckedPaths(item: TreeItem, excludedPaths: Array[String]):
	if item == null:
		return

	# Check if this item is unchecked (using metadata dict)
	var metadata = item.get_metadata(0)
	if metadata != null and metadata is Dictionary:
		var isChecked = metadata.get("checked", true)
		if not isChecked:
			var path = metadata.get("path", "")
			# Make path relative to project
			var relativePath = path.replace(_projectPath + "/", "")
			if not excludedPaths.has(relativePath):
				excludedPaths.append(relativePath)

	# Recurse to children
	var child = item.get_first_child()
	while child:
		_collectUncheckedPaths(child, excludedPaths)
		child = child.get_next()

func _onCancelPressed():
	# Renamed to Back - warn if there are unsaved changes
	if _isDirty:
		_showUnsavedChangesWarning()
	else:
		_closeDialog()

func _closeDialog():
	# Reset state to initial values if there were unsaved changes
	# (no need to rebuild UI since we're closing - next open will load fresh)
	if _isDirty:
		_excludePatterns = _initialExcludePatterns.duplicate()
		_additionalFiles = _initialAdditionalFiles.duplicate(true)

	cancelled.emit()
	visible = false
	_isDirty = false

func _showUnsavedChangesWarning():
	# Create warning dialog overlay
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 250

	# Semi-transparent background
	var dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.5)
	overlay.add_child(dimmer)

	# Center container
	var centerContainer = CenterContainer.new()
	centerContainer.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(centerContainer)

	# Warning card
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(400, 0)
	centerContainer.add_child(card)

	# Card styling
	var cardTheme = Theme.new()
	var cardStyleBox = StyleBoxFlat.new()
	cardStyleBox.bg_color = _getAdjustedBackgroundColor(-0.08)
	cardStyleBox.border_color = Color(0.8, 0.6, 0.2)  # Warning orange border
	cardStyleBox.border_width_left = 2
	cardStyleBox.border_width_top = 2
	cardStyleBox.border_width_right = 2
	cardStyleBox.border_width_bottom = 2
	cardStyleBox.corner_radius_top_left = 6
	cardStyleBox.corner_radius_top_right = 6
	cardStyleBox.corner_radius_bottom_right = 6
	cardStyleBox.corner_radius_bottom_left = 6
	cardTheme.set_stylebox("panel", "PanelContainer", cardStyleBox)
	card.theme = cardTheme

	# Card content
	var cardMargin = MarginContainer.new()
	cardMargin.add_theme_constant_override("margin_left", 20)
	cardMargin.add_theme_constant_override("margin_top", 20)
	cardMargin.add_theme_constant_override("margin_right", 20)
	cardMargin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(cardMargin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	cardMargin.add_child(vbox)

	# Warning title
	var titleLabel = Label.new()
	titleLabel.text = "Unsaved Changes"
	titleLabel.add_theme_font_size_override("font_size", 18)
	titleLabel.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	vbox.add_child(titleLabel)

	# Warning message
	var messageLabel = Label.new()
	messageLabel.text = "You have unsaved changes. Do you want to save before leaving?"
	messageLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(messageLabel)

	# Buttons
	var buttonContainer = HBoxContainer.new()
	buttonContainer.alignment = BoxContainer.ALIGNMENT_END
	buttonContainer.add_theme_constant_override("separation", 8)
	vbox.add_child(buttonContainer)

	var discardButton = Button.new()
	discardButton.text = "Discard"
	discardButton.custom_minimum_size = Vector2(90, 32)
	discardButton.pressed.connect(func():
		overlay.queue_free()
		_closeDialog()
	)
	buttonContainer.add_child(discardButton)

	var saveButton = Button.new()
	saveButton.text = "Save"
	saveButton.custom_minimum_size = Vector2(90, 32)
	saveButton.pressed.connect(func():
		overlay.queue_free()
		_onSavePressed()
		_closeDialog()
	)
	buttonContainer.add_child(saveButton)

	var cancelButton = Button.new()
	cancelButton.text = "Cancel"
	cancelButton.custom_minimum_size = Vector2(90, 32)
	cancelButton.pressed.connect(func():
		overlay.queue_free()
	)
	buttonContainer.add_child(cancelButton)

	add_child(overlay)

func _onTreeItemClicked(_mouse_position: Vector2, mouse_button_index: int):
	# Toggle checkbox when item is clicked (works on every click, even if already selected)
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return  # Only toggle on left-click

	var item = _tree.get_selected()
	if item:
		var metadata = item.get_metadata(0)
		if metadata != null and metadata is Dictionary:
			# Ignore clicks on pattern-excluded items
			if metadata.get("pattern_excluded", false):
				return

			var isChecked = metadata.get("checked", true)
			var newState = not isChecked
			metadata["checked"] = newState

			# Update icon
			if newState:
				item.set_icon(0, _iconChecked)
			else:
				item.set_icon(0, _iconUnchecked)

			# Propagate to all children
			_propagateCheckState(item, newState)

			# Mark as dirty
			_isDirty = true

func _onTabPressed(tabIndex: int):
	_currentTab = tabIndex
	_switchToTab(tabIndex)

func _switchToTab(tabIndex: int):
	# Hide all cards
	if _projectTreeCard:
		_projectTreeCard.visible = false
	if _excludePatternsCard:
		_excludePatternsCard.visible = false
	if _additionalFilesCard:
		_additionalFilesCard.visible = false
	if _includePatternsCard:
		_includePatternsCard.visible = false

	# Show selected card based on tab index and platform type
	# Tab 0: Project Files (Source) or Include Patterns (Binary)
	# Tab 1: Exclude Patterns
	# Tab 2: Additional Files
	match tabIndex:
		0:
			if _isBinaryPlatform:
				if _includePatternsCard:
					_includePatternsCard.visible = true
			else:
				if _projectTreeCard:
					_projectTreeCard.visible = true
			_updateTabButtonStates(0)
		1:
			if _excludePatternsCard:
				_excludePatternsCard.visible = true
			_updateTabButtonStates(1)
		2:
			if _additionalFilesCard:
				_additionalFilesCard.visible = true
			_updateTabButtonStates(2)

func _updateTabButtonStates(activeIndex: int):
	# Update button appearances to show which tab is active
	# For binary: [Include Patterns, Exclude Patterns, Additional Files]
	# For source: [Project Files, Exclude Patterns, Additional Files]
	var buttons: Array = []
	if _isBinaryPlatform:
		buttons = [_includePatternsTab, _excludePatternsTab, _additionalFilesTab]
	else:
		buttons = [_projectFilesTab, _excludePatternsTab, _additionalFilesTab]

	for i in range(buttons.size()):
		if buttons[i] and buttons[i].visible:
			if i == activeIndex:
				# Active tab: white border
				var activeStyle = StyleBoxFlat.new()
				activeStyle.bg_color = Color(0.2, 0.2, 0.2)
				activeStyle.border_color = Color(1, 1, 1)  # White border
				activeStyle.border_width_left = 2
				activeStyle.border_width_top = 2
				activeStyle.border_width_right = 2
				activeStyle.border_width_bottom = 2
				activeStyle.corner_radius_top_left = 4
				activeStyle.corner_radius_top_right = 4
				activeStyle.corner_radius_bottom_right = 4
				activeStyle.corner_radius_bottom_left = 4
				buttons[i].add_theme_stylebox_override("normal", activeStyle)
				buttons[i].add_theme_stylebox_override("hover", activeStyle)
				buttons[i].add_theme_stylebox_override("pressed", activeStyle)
				buttons[i].disabled = false
			else:
				# Inactive tab: default style
				buttons[i].remove_theme_stylebox_override("normal")
				buttons[i].remove_theme_stylebox_override("hover")
				buttons[i].remove_theme_stylebox_override("pressed")
				buttons[i].disabled = false

func _applyCardStyling():
	# Apply platform card styling to each card
	var projectTreeCard = get_node_or_null("%ProjectTreeCard")
	var excludePatternsCard = get_node_or_null("%ExcludePatternsCard")
	var additionalFilesCard = get_node_or_null("%AdditionalFilesCard")

	var cards = [projectTreeCard, excludePatternsCard, additionalFilesCard]

	for card in cards:
		if card:
			_styleCard(card)

	# Also style header and content panels with borders
	if projectTreeCard:
		var treeHeader = projectTreeCard.get_node_or_null("ProjectTreeContent/TreeHeader")
		var treeContent = projectTreeCard.get_node_or_null("ProjectTreeContent/TreeContentPanel")
		if treeHeader:
			_styleHeaderPanel(treeHeader)
		if treeContent:
			_styleContentPanel(treeContent)

	if excludePatternsCard:
		var patternsHeader = excludePatternsCard.get_node_or_null("PatternsContent/PatternsHeader")
		var patternsContent = excludePatternsCard.get_node_or_null("PatternsContent/PatternsContentPanel")
		if patternsHeader:
			_styleHeaderPanel(patternsHeader)
		if patternsContent:
			_styleContentPanel(patternsContent)

	if additionalFilesCard:
		var filesHeader = additionalFilesCard.get_node_or_null("FilesContent/FilesHeader")
		var filesContent = additionalFilesCard.get_node_or_null("FilesContent/FilesContentPanel")
		if filesHeader:
			_styleHeaderPanel(filesHeader)
		if filesContent:
			_styleContentPanel(filesContent)

func _styleCard(card: PanelContainer):
	# Apply styled theme like platform cards
	var cardTheme = Theme.new()
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
	cardTheme.set_stylebox("panel", "PanelContainer", styleBox)
	card.theme = cardTheme

func _styleHeaderPanel(panel: PanelContainer):
	# Header panel with bottom border only
	var headerTheme = Theme.new()
	var headerStyleBox = StyleBoxFlat.new()
	headerStyleBox.bg_color = Color(0, 0, 0, 0)  # Transparent background
	headerStyleBox.border_color = Color(0.6, 0.6, 0.6)
	headerStyleBox.border_width_left = 0
	headerStyleBox.border_width_top = 0
	headerStyleBox.border_width_right = 0
	headerStyleBox.border_width_bottom = 1
	headerTheme.set_stylebox("panel", "PanelContainer", headerStyleBox)
	panel.theme = headerTheme

func _styleContentPanel(panel: PanelContainer):
	# Content panel with transparent background
	var contentTheme = Theme.new()
	var contentStyleBox = StyleBoxFlat.new()
	contentStyleBox.bg_color = Color(0, 0, 0, 0)  # Transparent background
	contentStyleBox.border_width_left = 0
	contentStyleBox.border_width_top = 0
	contentStyleBox.border_width_right = 0
	contentStyleBox.border_width_bottom = 0
	contentTheme.set_stylebox("panel", "PanelContainer", contentStyleBox)
	panel.theme = contentTheme

func _getAdjustedBackgroundColor(amount: float) -> Color:
	var colorToSubtract = Color(amount, amount, amount, 0.0)
	var baseColor = App.GetBackgroundColor()
	return Color(
		max(baseColor.r + colorToSubtract.r, 0),
		max(baseColor.g + colorToSubtract.g, 0),
		max(baseColor.b + colorToSubtract.b, 0),
		baseColor.a
	)
