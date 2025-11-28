extends Control

# FluentUI icons for dynamic buttons
const ICON_ARROW_UP = preload("res://scenes/release-manager/assets/fluent-icons/arrow-up.svg")
const ICON_ARROW_DOWN = preload("res://scenes/release-manager/assets/fluent-icons/arrow-down.svg")
const ICON_DELETE = preload("res://scenes/release-manager/assets/fluent-icons/delete.svg")

signal settings_saved(platform: String, root_path: String, path_template: Array)
signal cancelled()

@onready var _platformLabel = %PlatformLabel
@onready var _segmentsList = %SegmentsList
@onready var _previewLabel = %PreviewLabel
@onready var _rootPathLabel = %RootPathLabel
@onready var _rootPathCard = %RootPathCard
@onready var _previewCard = %PreviewCard
@onready var _pathSegmentsCard = %PathSegmentsCard
@onready var _rootPathHeaderContainer = $BackgroundPanel/MarginContainer/VBoxContainer/RootPathCard/VBoxContainer/HeaderContainer
@onready var _rootPathContentContainer = $BackgroundPanel/MarginContainer/VBoxContainer/RootPathCard/VBoxContainer/ContentContainer
@onready var _previewHeaderContainer = $BackgroundPanel/MarginContainer/VBoxContainer/PreviewCard/VBoxContainer/HeaderContainer
@onready var _previewContentContainer = $BackgroundPanel/MarginContainer/VBoxContainer/PreviewCard/VBoxContainer/ContentContainer
@onready var _pathSegmentsHeaderContainer = $BackgroundPanel/MarginContainer/VBoxContainer/PathSegmentsCard/VBoxContainer/HeaderContainer
@onready var _pathSegmentsContentContainer = $BackgroundPanel/MarginContainer/VBoxContainer/PathSegmentsCard/VBoxContainer/ContentContainer


var _currentPlatform: String = ""
var _rootExportPath: String = ""
var _projectVersion: String = ""  # Stored for preview only, not editable here
var _pathSegments: Array = []  # Array of {type: "version|platform|date|custom", value: ""}
var _folderDialog: FileDialog = null

const SEGMENT_HEIGHT = 40
const DEFAULT_DATE_FORMAT = "{year}-{month}-{day}"

func _ready():
	# Create folder selection dialog
	_folderDialog = FileDialog.new()
	_folderDialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_folderDialog.access = FileDialog.ACCESS_FILESYSTEM
	_folderDialog.dir_selected.connect(_onFolderSelected)
	add_child(_folderDialog)

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
func openForPlatform(platform: String, rootPath: String, currentTemplate: Array, projectVersion: String = "v1.0.0"):
	_currentPlatform = platform
	_rootExportPath = rootPath
	_pathSegments = currentTemplate.duplicate(true)
	_projectVersion = projectVersion  # Store for preview

	# Update platform display
	_platformLabel.text = "Platform: " + platform
	_rootPathLabel.text = rootPath

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

	# Up button
	var upButton = Button.new()
	upButton.icon = ICON_ARROW_UP
	upButton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upButton.custom_minimum_size.x = 32
	upButton.disabled = (index == 0)
	upButton.pressed.connect(_onMoveUpPressed.bind(index))
	row.add_child(upButton)

	# Down button
	var downButton = Button.new()
	downButton.icon = ICON_ARROW_DOWN
	downButton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	downButton.custom_minimum_size.x = 32
	downButton.disabled = (index == _pathSegments.size() - 1)
	downButton.pressed.connect(_onMoveDownPressed.bind(index))
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
		var temp = _pathSegments[index]
		_pathSegments[index] = _pathSegments[index - 1]
		_pathSegments[index - 1] = temp
		_rebuildSegmentsList()
		_updatePreview()

func _onMoveDownPressed(index: int):
	if index < _pathSegments.size() - 1:
		var temp = _pathSegments[index]
		_pathSegments[index] = _pathSegments[index + 1]
		_pathSegments[index + 1] = temp
		_rebuildSegmentsList()
		_updatePreview()

func _onDeletePressed(index: int):
	_pathSegments.remove_at(index)
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
	var previewPath = _rootExportPath

	for segment in _pathSegments:
		match segment["type"]:
			"version":
				var version = _projectVersion if _projectVersion != "" else "v1.0.0"
				previewPath = previewPath.path_join(version)
			"platform":
				previewPath = previewPath.path_join(_currentPlatform)
			"date":
				var dateFormat = segment.get("value", DEFAULT_DATE_FORMAT)
				var processedDate = _processDatetimeTokens(dateFormat)
				previewPath = previewPath.path_join(processedDate)
			"custom":
				var customValue = segment.get("value", "custom")
				var processedCustom = _processDatetimeTokens(customValue)
				# Custom paths can contain slashes for nested folders
				# Normalize to forward slashes first, then join
				processedCustom = processedCustom.replace("\\", "/")
				# If it contains slashes, append directly; otherwise use path_join
				if "/" in processedCustom:
					previewPath = previewPath + "/" + processedCustom
				else:
					previewPath = previewPath.path_join(processedCustom)

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

func _onSelectFolderPressed():
	if _folderDialog:
		# Set initial path to current root path if it exists
		if _rootExportPath != "" and DirAccess.dir_exists_absolute(_rootExportPath):
			_folderDialog.current_dir = _rootExportPath
		_folderDialog.popup_centered_ratio(0.6)

func _onFolderSelected(dir: String):
	_rootExportPath = dir
	_rootPathLabel.text = dir
	_updatePreview()

func _onSavePressed():
	# Emit signal with root path and path template (stay on page)
	settings_saved.emit(_currentPlatform, _rootExportPath, _pathSegments)

func _onSaveClosePressed():
	# Emit signal with root path and path template, then close
	settings_saved.emit(_currentPlatform, _rootExportPath, _pathSegments)
	visible = false

func _onBackPressed():
	cancelled.emit()
	visible = false
