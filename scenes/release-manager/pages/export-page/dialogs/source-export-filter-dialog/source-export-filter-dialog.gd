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

# Cards
@onready var _projectTreeCard = %ProjectTreeCard
@onready var _excludePatternsCard = %ExcludePatternsCard
@onready var _additionalFilesCard = %AdditionalFilesCard

# State
var _platform: String = ""
var _projectPath: String = ""
var _excludePatterns: Array[String] = []
var _additionalFiles: Array[Dictionary] = []  # [{source: "", target: ""}]
var _treeExpanded: bool = false
var _currentTab: int = 0  # 0=Project Files, 1=Exclude Patterns, 2=Additional Files

# Checkbox icons
var _iconChecked: Texture2D
var _iconUnchecked: Texture2D

const PROJECT_FILES_HELP_TEXT = """Use the checkboxes to include or exclude files and folders from the Source export.

- Click a folder to toggle all its contents
- Checked items will be included in the export
- Unchecked items will be excluded

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

# Open dialog for a specific platform with current settings
func openForPlatform(platform: String, projectPath: String, currentConfig: Dictionary):
	_platform = platform
	_projectPath = projectPath

	# Update UI
	_platformLabel.text = "Platform: " + platform

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

	# Load excluded paths (same workaround for GDScript bug)
	var excludedPathsRaw = currentConfig.get("excluded_paths", [])
	var excludedPaths: Array[String] = []
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

	# Apply default exclude patterns if this is first time (no config)
	if _excludePatterns.is_empty() and currentConfig.is_empty():
		_excludePatterns = _getDefaultExcludePatterns()

	# Show dialog FIRST so layout happens
	visible = true
	move_to_front()

	# Wait a frame for layout to update
	await get_tree().process_frame

	# NOW build tree after it's properly sized
	_buildProjectTree()

	# Apply tree colors AFTER card styling to ensure they're not overridden
	_applyTreeColors()

	# Apply excluded paths to tree (uncheck previously excluded items)
	_applyExcludedPathsToTree(excludedPaths)

	# Build exclude patterns UI
	_buildExcludePatternsUI()

	# Build additional files UI
	_buildAdditionalFilesUI()

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

func _addDirectoryToTree(parentItem: TreeItem, dirPath: String, displayName: String) -> TreeItem:
	var item = _tree.create_item(parentItem)

	# Column 0: Checkbox icon + folder name
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
		_addDirectoryToTree(item, subDirPath, dirName)

	# Then add files
	files.sort()
	for file in files:
		var filePath = dirPath.path_join(file)
		_addFileToTree(item, filePath, file)

	return item

func _addFileToTree(parentItem: TreeItem, filePath: String, displayName: String):
	var item = _tree.create_item(parentItem)

	# Column 0: Checkbox icon + filename
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

func _onAddPatternPressed():
	# Add empty pattern that user can edit
	_excludePatterns.append("")
	_addPatternRow("")

func _onPatternTextChanged(newText: String, patternEdit: LineEdit):
	# Find which row this LineEdit belongs to by finding it in the patterns list
	var row = patternEdit.get_parent() as HBoxContainer
	if not row:
		return

	# Find the index of this row in the patterns list
	var rowIndex = row.get_index()
	if rowIndex >= 0 and rowIndex < _excludePatterns.size():
		_excludePatterns[rowIndex] = newText

func _onRemovePatternPressed(row: HBoxContainer):
	# Find which pattern this row represents
	var patternEdit = row.get_child(0) as LineEdit
	if patternEdit:
		var pattern = patternEdit.text
		_excludePatterns.erase(pattern)
		row.queue_free()
		_updateExcludeCount()

func _onAddFilePressed():
	# Add a new empty file entry
	var newEntry = {"source": "", "target": ""}
	_additionalFiles.append(newEntry)
	_buildAdditionalFilesUI()

func _onBrowseAdditionalFilePressed(fileEntry: Dictionary):
	# TODO: Open file/folder browser dialog
	print("Browse for additional file: ", fileEntry)

func _onTargetPathChanged(newPath: String, fileEntry: Dictionary):
	fileEntry["target"] = newPath

func _onRemoveAdditionalFilePressed(fileEntry: Dictionary):
	_additionalFiles.erase(fileEntry)
	_buildAdditionalFilesUI()

func _updateExcludeCount():
	# No longer showing count in header
	pass

func _updateAdditionalFilesCount():
	# No longer showing count in header
	pass

func _onSavePressed():
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

	# Hide dialog
	visible = false

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
	cancelled.emit()
	visible = false

func _onTreeItemClicked(_mouse_position: Vector2, mouse_button_index: int):
	# Toggle checkbox when item is clicked (works on every click, even if already selected)
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return  # Only toggle on left-click

	var item = _tree.get_selected()
	if item:
		var metadata = item.get_metadata(0)
		if metadata != null and metadata is Dictionary:
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

	# Show selected card
	match tabIndex:
		0:
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
	var buttons = [_projectFilesTab, _excludePatternsTab, _additionalFilesTab]

	for i in range(buttons.size()):
		if buttons[i]:
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
