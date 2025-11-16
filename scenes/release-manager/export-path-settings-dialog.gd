extends Window

signal settings_saved(platform: String, path_template: Array)

@onready var _platformLabel = %PlatformLabel
@onready var _segmentsList = %SegmentsList
@onready var _previewLabel = %PreviewLabel
@onready var _rootPathLabel = %RootPathLabel

var _currentPlatform: String = ""
var _rootExportPath: String = ""
var _pathSegments: Array = []  # Array of {type: "version|platform|custom", value: ""}

const SEGMENT_HEIGHT = 40

func _ready():
	pass

# Opens the dialog for a specific platform
func openForPlatform(platform: String, rootPath: String, currentTemplate: Array):
	_currentPlatform = platform
	_rootExportPath = rootPath
	_pathSegments = currentTemplate.duplicate(true)

	# Update title
	_platformLabel.text = "Platform: " + platform
	_rootPathLabel.text = "Root Path: " + rootPath

	# Load current template
	_rebuildSegmentsList()
	_updatePreview()

	# Show as modal dialog
	popup_centered()
	grab_focus()

	# Make it modal
	transient = true
	exclusive = true

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
	var segmentLabel = Label.new()
	segmentLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	match segment["type"]:
		"version":
			segmentLabel.text = "{version}"
		"platform":
			segmentLabel.text = "{platform}"
		"date":
			segmentLabel.text = "{date}"
		"custom":
			segmentLabel.text = segment.get("value", "custom-folder")

	row.add_child(segmentLabel)

	# Up button
	var upButton = Button.new()
	upButton.text = "↑"
	upButton.custom_minimum_size.x = 40
	upButton.disabled = (index == 0)
	upButton.pressed.connect(_onMoveUpPressed.bind(index))
	row.add_child(upButton)

	# Down button
	var downButton = Button.new()
	downButton.text = "↓"
	downButton.custom_minimum_size.x = 40
	downButton.disabled = (index == _pathSegments.size() - 1)
	downButton.pressed.connect(_onMoveDownPressed.bind(index))
	row.add_child(downButton)

	# Delete button
	var deleteButton = Button.new()
	deleteButton.text = "×"
	deleteButton.custom_minimum_size.x = 40
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
	_pathSegments.append({"type": "date"})
	_rebuildSegmentsList()
	_updatePreview()

func _onAddCustomPressed():
	# Show input dialog for custom folder name
	var input = _getCustomFolderInput()
	if input != "":
		_pathSegments.append({"type": "custom", "value": input})
		_rebuildSegmentsList()
		_updatePreview()

func _getCustomFolderInput() -> String:
	# For now, just use a default name - we can add a proper dialog later
	return "custom-folder"

func _updatePreview():
	var previewPath = _rootExportPath

	for segment in _pathSegments:
		match segment["type"]:
			"version":
				previewPath = previewPath.path_join("v0.12.2")  # Example version
			"platform":
				previewPath = previewPath.path_join(_currentPlatform)
			"date":
				previewPath = previewPath.path_join("2025-01-16")  # Example date
			"custom":
				previewPath = previewPath.path_join(segment.get("value", "custom"))

	_previewLabel.text = "Preview: " + previewPath

func _onSavePressed():
	# Emit signal with path template
	settings_saved.emit(_currentPlatform, _pathSegments)
	hide()

func _onCancelPressed():
	hide()

func _onCloseRequested():
	hide()
