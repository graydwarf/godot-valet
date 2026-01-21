extends Control

# FluentUI icons for dynamic buttons
const ICON_ARROW_UP = preload("res://scenes/release-manager/assets/fluent-icons/arrow-up.svg")
const ICON_ARROW_DOWN = preload("res://scenes/release-manager/assets/fluent-icons/arrow-down.svg")
const ICON_DELETE = preload("res://scenes/release-manager/assets/fluent-icons/delete.svg")
const ICON_FOLDER_OPEN = preload("res://scenes/release-manager/assets/fluent-icons/folder-open.svg")

signal settings_saved(platform: String, root_path: String, path_template: Array)
signal cancelled()

@onready var _platformLabel = %PlatformLabel
@onready var _segmentsList = %SegmentsList
@onready var _previewLabel = %PreviewLabel
@onready var _rootPathLabel = %RootPathLabel
@onready var _rootPathCard = %RootPathCard
@onready var _previewCard = %PreviewCard
@onready var _pathSegmentsCard = %PathSegmentsCard
@onready var _addProjectPathButton = %AddProjectPathButton
@onready var _rootPathHeaderContainer = $BackgroundPanel/MarginContainer/VBoxContainer/RootPathCard/VBoxContainer/HeaderContainer
@onready var _rootPathContentContainer = $BackgroundPanel/MarginContainer/VBoxContainer/RootPathCard/VBoxContainer/ContentContainer
@onready var _previewHeaderContainer = $BackgroundPanel/MarginContainer/VBoxContainer/PreviewCard/VBoxContainer/HeaderContainer
@onready var _previewContentContainer = $BackgroundPanel/MarginContainer/VBoxContainer/PreviewCard/VBoxContainer/ContentContainer
@onready var _pathSegmentsHeaderContainer = $BackgroundPanel/MarginContainer/VBoxContainer/PathSegmentsCard/VBoxContainer/HeaderContainer
@onready var _pathSegmentsContentContainer = $BackgroundPanel/MarginContainer/VBoxContainer/PathSegmentsCard/VBoxContainer/ContentContainer


var _currentPlatform: String = ""
var _projectDir: String = ""  # Project directory (read-only display)
var _projectVersion: String = ""  # Stored for preview only, not editable here
var _pathSegments: Array = []  # Array of {type: "project-path|version|platform|date|custom", value: ""}
var _originalPathSegments: Array = []  # Store original for dirty checking
var _yesNoDialog: YesNoDialog = null

const SEGMENT_HEIGHT = 40
const DEFAULT_DATE_FORMAT = "{year}-{month}-{day}"

func _ready():
	# Apply card styles (wait until nodes are ready)
	if _rootPathCard != null and _rootPathHeaderContainer != null and _rootPathContentContainer != null:
		_applyCardStyle(_rootPathCard, _rootPathHeaderContainer, _rootPathContentContainer)
	if _previewCard != null and _previewHeaderContainer != null and _previewContentContainer != null:
		_applyCardStyle(_previewCard, _previewHeaderContainer, _previewContentContainer)
	if _pathSegmentsCard != null and _pathSegmentsHeaderContainer != null and _pathSegmentsContentContainer != null:
		_applyCardStyle(_pathSegmentsCard, _pathSegmentsHeaderContainer, _pathSegmentsContentContainer)

func _applyCardStyle(outerPanel: PanelContainer, headerPanel: PanelContainer, contentPanel: PanelContainer):
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

# Opens the page for a specific platform
func openForPlatform(platform: String, projectDir: String, currentTemplate: Array, projectVersion: String = "v1.0.0"):
	_currentPlatform = platform
	_projectDir = projectDir
	_pathSegments = currentTemplate.duplicate(true)
	_originalPathSegments = currentTemplate.duplicate(true)  # Store original for dirty checking
	_projectVersion = projectVersion  # Store for preview

	# Update platform display
	_platformLabel.text = "Platform: " + platform
	_rootPathLabel.text = projectDir

	# Load current template
	_rebuildSegmentsList()
	_updatePreview()

	# Show the control
	visible = true

func _rebuildSegmentsList():
	# Clear existing segments
	for child in _segmentsList.get_children():
		child.queue_free()

	# Create segment rows
	for i in range(_pathSegments.size()):
		var segment = _pathSegments[i]
		_createSegmentRow(i, segment)

	# Update Add Project Path button state (only one allowed)
	_updateAddProjectPathButtonState()

# Checks if a project-path segment already exists
func _hasProjectPathSegment() -> bool:
	for segment in _pathSegments:
		if segment.get("type", "") == "project-path":
			return true
	return false

# Updates the Add Project Path button enabled/disabled state
func _updateAddProjectPathButtonState():
	if _addProjectPathButton != null:
		_addProjectPathButton.disabled = _hasProjectPathSegment()

func _createSegmentRow(index: int, segment: Dictionary):
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = SEGMENT_HEIGHT

	# Index label
	var indexLabel = Label.new()
	indexLabel.text = str(index + 1) + "."
	indexLabel.custom_minimum_size.x = 30
	row.add_child(indexLabel)

	# Segment type/value display
	var contentControl: Control

	match segment["type"]:
		"project-path":
			var label = Label.new()
			label.text = "{project-path}"
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			contentControl = label
		"version":
			var label = Label.new()
			label.text = "{version}"
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			contentControl = label
		"platform":
			var label = Label.new()
			label.text = "{platform}"
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			contentControl = label
		"date":
			var lineEdit = LineEdit.new()
			lineEdit.text = segment.get("value", DEFAULT_DATE_FORMAT)
			lineEdit.placeholder_text = "e.g., {year}-{month}-{day}"
			lineEdit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lineEdit.text_changed.connect(_onDateSegmentChanged.bind(index))
			contentControl = lineEdit
		"custom":
			var lineEdit = LineEdit.new()
			lineEdit.text = segment.get("value", "custom-folder")
			lineEdit.placeholder_text = "Folder name (supports tokens)"
			lineEdit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lineEdit.text_changed.connect(_onCustomSegmentChanged.bind(index))
			contentControl = lineEdit

	row.add_child(contentControl)

	var isProjectPath = segment.get("type", "") == "project-path"
	var hasProjectPathAtZero = _pathSegments.size() > 0 and _pathSegments[0].get("type", "") == "project-path"

	# Up button (hidden for project-path since it must stay at index 0)
	# Also disabled for index 1 if project-path is at index 0 (can't swap with it)
	var upButton = Button.new()
	upButton.icon = ICON_ARROW_UP
	upButton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upButton.custom_minimum_size.x = 32
	upButton.disabled = (index == 0) or (index == 1 and hasProjectPathAtZero)
	upButton.pressed.connect(_onMoveUpPressed.bind(index))
	upButton.visible = not isProjectPath
	row.add_child(upButton)

	# Down button (hidden for project-path since it must stay at index 0)
	var downButton = Button.new()
	downButton.icon = ICON_ARROW_DOWN
	downButton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	downButton.custom_minimum_size.x = 32
	downButton.disabled = (index == _pathSegments.size() - 1)
	downButton.pressed.connect(_onMoveDownPressed.bind(index))
	downButton.visible = not isProjectPath
	row.add_child(downButton)

	# Delete button
	var deleteButton = Button.new()
	deleteButton.icon = ICON_DELETE
	deleteButton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deleteButton.custom_minimum_size.x = 32
	deleteButton.pressed.connect(_onDeletePressed.bind(index))
	row.add_child(deleteButton)

	_segmentsList.add_child(row)

func _onMoveUpPressed(index: int):
	if index > 0:
		# Don't allow moving into position 0 if there's a project-path there
		if index == 1 and _pathSegments[0].get("type", "") == "project-path":
			return
		var temp = _pathSegments[index]
		_pathSegments[index] = _pathSegments[index - 1]
		_pathSegments[index - 1] = temp
		_rebuildSegmentsList()
		_updatePreview()

func _onMoveDownPressed(index: int):
	if index < _pathSegments.size() - 1:
		# Don't allow moving project-path down from position 0
		if index == 0 and _pathSegments[0].get("type", "") == "project-path":
			return
		var temp = _pathSegments[index]
		_pathSegments[index] = _pathSegments[index + 1]
		_pathSegments[index + 1] = temp
		_rebuildSegmentsList()
		_updatePreview()

func _onDeletePressed(index: int):
	_pathSegments.remove_at(index)
	_rebuildSegmentsList()
	_updatePreview()

func _onAddProjectPathPressed():
	# Project-path must always be first, so insert at index 0
	_pathSegments.insert(0, {"type": "project-path"})
	_rebuildSegmentsList()
	_updatePreview()

func _onAddVersionPressed():
	_pathSegments.append({"type": "version"})
	_rebuildSegmentsList()
	_updatePreview()

func _onAddPlatformPressed():
	_pathSegments.append({"type": "platform"})
	_rebuildSegmentsList()
	_updatePreview()

func _onAddDatePressed():
	_pathSegments.append({"type": "date", "value": DEFAULT_DATE_FORMAT})
	_rebuildSegmentsList()
	_updatePreview()

func _onAddCustomPressed():
	_pathSegments.append({"type": "custom", "value": "custom-folder"})
	_rebuildSegmentsList()
	_updatePreview()

func _onDateSegmentChanged(newText: String, index: int):
	if index >= 0 and index < _pathSegments.size():
		_pathSegments[index]["value"] = newText
		_updatePreview()

func _onCustomSegmentChanged(newText: String, index: int):
	if index >= 0 and index < _pathSegments.size():
		# Trim leading/trailing slashes from custom paths
		var trimmedText = newText.strip_edges()
		trimmedText = trimmedText.trim_prefix("/").trim_prefix("\\")
		trimmedText = trimmedText.trim_suffix("/").trim_suffix("\\")

		# Block parent directory references to prevent recursive loops
		if ".." in trimmedText:
			# Remove all .. segments to prevent path traversal
			var parts = trimmedText.replace("\\", "/").split("/")
			var safeParts: Array[String] = []
			for part in parts:
				if part != ".." and part != "." and not part.is_empty():
					safeParts.append(part)
			trimmedText = "/".join(safeParts)
			if trimmedText.is_empty():
				trimmedText = "custom-folder"

		_pathSegments[index]["value"] = trimmedText
		_updatePreview()

func _updatePreview():
	var previewPath = ""

	for segment in _pathSegments:
		match segment["type"]:
			"project-path":
				var projectPath = _projectDir if _projectDir != "" else "C:/project"
				if previewPath.is_empty():
					previewPath = projectPath
				else:
					previewPath = previewPath.path_join(projectPath)
			"version":
				var version = _projectVersion if _projectVersion != "" else "v1.0.0"
				if previewPath.is_empty():
					previewPath = version
				else:
					previewPath = previewPath.path_join(version)
			"platform":
				if previewPath.is_empty():
					previewPath = _currentPlatform
				else:
					previewPath = previewPath.path_join(_currentPlatform)
			"date":
				var dateFormat = segment.get("value", DEFAULT_DATE_FORMAT)
				var processedDate = _processDatetimeTokens(dateFormat)
				if previewPath.is_empty():
					previewPath = processedDate
				else:
					previewPath = previewPath.path_join(processedDate)
			"custom":
				var customValue = segment.get("value", "custom")
				var processedCustom = _processDatetimeTokens(customValue)
				# Custom paths can contain slashes for nested folders
				# Normalize to forward slashes first, then join
				processedCustom = processedCustom.replace("\\", "/")
				if previewPath.is_empty():
					previewPath = processedCustom
				elif "/" in processedCustom:
					# If it contains slashes, append directly
					previewPath = previewPath + "/" + processedCustom
				else:
					previewPath = previewPath.path_join(processedCustom)

	# Fallback if no segments
	if previewPath.is_empty():
		previewPath = "No path segments defined"

	# Use forward slashes (cross-platform compatible)
	if _previewLabel != null:
		_previewLabel.text = previewPath

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

func _onCopyProjectPathPressed():
	if _projectDir.is_empty():
		return
	DisplayServer.clipboard_set(_projectDir)

func _onOpenProjectFolderPressed():
	if _projectDir.is_empty():
		return

	if DirAccess.dir_exists_absolute(_projectDir):
		OS.shell_open(_projectDir)

func _onCopyPathPressed():
	var previewPath = _previewLabel.text if _previewLabel != null else ""
	if previewPath.is_empty() or previewPath == "No path segments defined":
		return

	DisplayServer.clipboard_set(previewPath)

func _onOpenPreviewFolderPressed():
	var previewPath = _previewLabel.text if _previewLabel != null else ""
	if previewPath.is_empty() or previewPath == "No path segments defined":
		_flashPreviewRed()
		return

	if DirAccess.dir_exists_absolute(previewPath):
		OS.shell_open(previewPath)
	else:
		_flashPreviewRed()

func _flashPreviewRed():
	if _previewLabel == null:
		return

	# Flash the preview label red briefly
	var originalColor = _previewLabel.get_theme_color("default_color", "RichTextLabel")
	_previewLabel.add_theme_color_override("default_color", Color(1.0, 0.3, 0.3))

	await get_tree().create_timer(0.3).timeout

	# Restore original color
	_previewLabel.remove_theme_color_override("default_color")

func _onSavePressed():
	# Emit signal with project dir and path template (stay on page)
	settings_saved.emit(_currentPlatform, _projectDir, _pathSegments)
	# Update original to match saved state (so _hasUnsavedChanges() returns false)
	_originalPathSegments = _pathSegments.duplicate(true)

func _onSaveClosePressed():
	# Emit signal with project dir and path template, then close
	settings_saved.emit(_currentPlatform, _projectDir, _pathSegments)
	# No need to update _originalPathSegments since we're closing
	visible = false

func _onBackPressed():
	if _hasUnsavedChanges():
		_showUnsavedChangesDialog()
	else:
		cancelled.emit()
		visible = false

# Checks if the path segments have been modified
func _hasUnsavedChanges() -> bool:
	if _pathSegments.size() != _originalPathSegments.size():
		return true

	for i in range(_pathSegments.size()):
		var current = _pathSegments[i]
		var original = _originalPathSegments[i]

		if current.get("type", "") != original.get("type", ""):
			return true
		if current.get("value", "") != original.get("value", ""):
			return true

	return false

# Shows the unsaved changes confirmation dialog
func _showUnsavedChangesDialog():
	if _yesNoDialog == null:
		_yesNoDialog = load("res://scenes/common/yes-no-dialog.tscn").instantiate()
		add_child(_yesNoDialog)

	_yesNoDialog.confirmed.connect(_onUnsavedChangesChoice, CONNECT_ONE_SHOT)
	_yesNoDialog.show_dialog_with_buttons(
		"You have unsaved changes.\n\nDo you want to save before leaving?",
		["Save", "Don't Save", "Cancel"]
	)

# Handles the user's choice in the unsaved changes dialog
func _onUnsavedChangesChoice(choice: String):
	match choice:
		"Save":
			settings_saved.emit(_currentPlatform, _projectDir, _pathSegments)
			visible = false
		"Don't Save":
			cancelled.emit()
			visible = false
		"Cancel":
			pass  # Do nothing, stay on the dialog
