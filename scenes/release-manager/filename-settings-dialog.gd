extends Control

signal settings_saved(filename_type: String, filename_template: Array, is_synced: bool)
signal cancelled()

@onready var _titleLabel = %TitleLabel
@onready var _segmentsList = %SegmentsList
@onready var _previewLabel = %PreviewLabel
@onready var _segmentsCard = %SegmentsCard
@onready var _previewCard = %PreviewCard
@onready var _segmentsHeaderContainer = $MarginContainer/VBoxContainer/SegmentsCard/VBoxContainer/HeaderContainer
@onready var _segmentsContentContainer = $MarginContainer/VBoxContainer/SegmentsCard/VBoxContainer/ContentContainer
@onready var _previewHeaderContainer = $MarginContainer/VBoxContainer/PreviewCard/VBoxContainer/HeaderContainer
@onready var _previewContentContainer = $MarginContainer/VBoxContainer/PreviewCard/VBoxContainer/ContentContainer

var _filenameType: String = ""  # "export" or "archive"
var _currentPlatform: String = ""
var _filenameSegments: Array = []  # The archive's custom segments (always preserved)
var _exportFilenameTemplate: Array = []  # Export template for syncing preview
var _projectName: String = ""
var _projectVersion: String = ""
var _extension: String = ""
var _syncCheckbox: CheckBox = null
var _isSynced: bool = false

const SEGMENT_HEIGHT = 40

func _ready():
	_applyPanelBackground()
	# Apply card styles
	if _segmentsCard != null and _segmentsHeaderContainer != null and _segmentsContentContainer != null:
		_applyCardStyle(_segmentsCard, _segmentsHeaderContainer, _segmentsContentContainer)
	if _previewCard != null and _previewHeaderContainer != null and _previewContentContainer != null:
		_applyCardStyle(_previewCard, _previewHeaderContainer, _previewContentContainer)

func _applyPanelBackground():
	var styleBox = StyleBoxFlat.new()
	styleBox.bg_color = App.GetBackgroundColor()
	add_theme_stylebox_override("panel", styleBox)

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

func openForFilename(filenameType: String, platform: String, currentTemplate: Array, projectName: String, projectVersion: String, extension: String, exportTemplate: Array = [], isSynced: bool = false):
	_filenameType = filenameType
	_currentPlatform = platform
	_filenameSegments = currentTemplate.duplicate(true)  # Archive's custom segments
	_exportFilenameTemplate = exportTemplate.duplicate(true)
	_projectName = projectName
	_projectVersion = projectVersion
	_extension = extension
	# Only archive type can sync, and only for non-Source platforms
	_isSynced = isSynced if (filenameType == "archive" and platform != "Source") else false

	# Set title based on type
	if filenameType == "export":
		_titleLabel.text = "Export File Name Configuration"
	else:
		_titleLabel.text = "Archive File Name Configuration"

	# Initialize segments if empty
	if _filenameSegments.is_empty():
		_filenameSegments = [{"type": "project"}]

	# Setup sync checkbox for archive type only
	_setupSyncCheckbox()

	_rebuildSegmentsList()
	_updatePreview()
	_updateSegmentsCardState()

	visible = true

func _setupSyncCheckbox():
	# Create sync checkbox if it doesn't exist
	if _syncCheckbox == null:
		var headerMargin = _previewHeaderContainer.get_node("HeaderMargin")
		if headerMargin:
			# Convert the existing Label to an HBoxContainer with Label + Checkbox
			var existingLabel = headerMargin.get_node_or_null("HeaderLabel")
			if existingLabel:
				# Create HBox to hold label and checkbox
				var hbox = HBoxContainer.new()
				hbox.name = "HeaderHBox"
				hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

				# Move existing label into hbox
				headerMargin.remove_child(existingLabel)
				hbox.add_child(existingLabel)

				# Add spacer
				var spacer = Control.new()
				spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hbox.add_child(spacer)

				# Add checkbox
				_syncCheckbox = CheckBox.new()
				_syncCheckbox.text = "Sync With Export File Name"
				_syncCheckbox.toggled.connect(_onSyncToggled)
				hbox.add_child(_syncCheckbox)

				headerMargin.add_child(hbox)

	# Show/hide checkbox based on type (only for archive, and only for non-Source platforms)
	if _syncCheckbox:
		_syncCheckbox.visible = (_filenameType == "archive" and _currentPlatform != "Source")
		_syncCheckbox.set_pressed_no_signal(_isSynced)

func _onSyncToggled(toggled: bool):
	_isSynced = toggled
	# Don't change the segments - just update preview and disable state
	_updatePreview()
	_updateSegmentsCardState()

func _updateSegmentsCardState():
	# Disable segments card when synced
	if _segmentsCard:
		_segmentsContentContainer.modulate = Color(1, 1, 1, 0.5) if _isSynced else Color(1, 1, 1, 1)
		# Disable all children in content container
		_setControlsDisabled(_segmentsContentContainer, _isSynced)

func _setControlsDisabled(node: Node, disabled: bool):
	if node is Button:
		node.disabled = disabled
	elif node is LineEdit:
		node.editable = not disabled
	for child in node.get_children():
		_setControlsDisabled(child, disabled)

func _rebuildSegmentsList():
	# Clear existing segments
	for child in _segmentsList.get_children():
		child.queue_free()

	# Create segment rows
	for i in range(_filenameSegments.size()):
		var segment = _filenameSegments[i]
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
		"project":
			var label = Label.new()
			label.text = "{project}"
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
		"custom":
			var lineEdit = LineEdit.new()
			lineEdit.text = segment.get("value", "custom")
			lineEdit.placeholder_text = "Custom text"
			lineEdit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lineEdit.text_changed.connect(_onCustomSegmentChanged.bind(index))
			contentControl = lineEdit

	row.add_child(contentControl)

	# Up button
	var upButton = Button.new()
	upButton.text = "^"
	upButton.custom_minimum_size.x = 40
	upButton.disabled = (index == 0)
	upButton.pressed.connect(_onMoveUpPressed.bind(index))
	row.add_child(upButton)

	# Down button
	var downButton = Button.new()
	downButton.text = "v"
	downButton.custom_minimum_size.x = 40
	downButton.disabled = (index == _filenameSegments.size() - 1)
	downButton.pressed.connect(_onMoveDownPressed.bind(index))
	row.add_child(downButton)

	# Delete button
	var deleteButton = Button.new()
	deleteButton.text = "x"
	deleteButton.custom_minimum_size.x = 40
	deleteButton.pressed.connect(_onDeletePressed.bind(index))
	row.add_child(deleteButton)

	_segmentsList.add_child(row)

func _updatePreview():
	# When synced, use export template for preview; otherwise use archive segments
	var templateToUse = _exportFilenameTemplate if _isSynced else _filenameSegments
	var filename = _buildFilenameFromTemplate(templateToUse)
	var fullText = filename + _extension
	_previewLabel.text = fullText
	_previewLabel.tooltip_text = fullText

func _buildFilenameFromTemplate(template: Array) -> String:
	var parts: Array[String] = []

	for segment in template:
		match segment["type"]:
			"project":
				if not _projectName.is_empty():
					parts.append(_projectName)
				else:
					parts.append("project")
			"version":
				parts.append(_projectVersion)
			"platform":
				parts.append(_currentPlatform.to_lower().replace(" ", "-"))
			"custom":
				var customValue = segment.get("value", "")
				if not customValue.is_empty():
					parts.append(customValue)

	if parts.is_empty():
		return "export"

	return "-".join(parts)

func _onMoveUpPressed(index: int):
	if index > 0:
		var temp = _filenameSegments[index]
		_filenameSegments[index] = _filenameSegments[index - 1]
		_filenameSegments[index - 1] = temp
		_rebuildSegmentsList()
		_updatePreview()

func _onMoveDownPressed(index: int):
	if index < _filenameSegments.size() - 1:
		var temp = _filenameSegments[index]
		_filenameSegments[index] = _filenameSegments[index + 1]
		_filenameSegments[index + 1] = temp
		_rebuildSegmentsList()
		_updatePreview()

func _onDeletePressed(index: int):
	_filenameSegments.remove_at(index)
	_rebuildSegmentsList()
	_updatePreview()

func _onCustomSegmentChanged(newText: String, index: int):
	if index >= 0 and index < _filenameSegments.size():
		_filenameSegments[index]["value"] = newText
		_updatePreview()

func _onAddProjectPressed():
	_filenameSegments.append({"type": "project"})
	_rebuildSegmentsList()
	_updatePreview()

func _onAddVersionPressed():
	_filenameSegments.append({"type": "version"})
	_rebuildSegmentsList()
	_updatePreview()

func _onAddPlatformPressed():
	_filenameSegments.append({"type": "platform"})
	_rebuildSegmentsList()
	_updatePreview()

func _onAddCustomPressed():
	_filenameSegments.append({"type": "custom", "value": "custom"})
	_rebuildSegmentsList()
	_updatePreview()

func _onSavePressed():
	settings_saved.emit(_filenameType, _filenameSegments, _isSynced)
	visible = false

func _onCancelPressed():
	cancelled.emit()
	visible = false
