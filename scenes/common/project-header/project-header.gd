extends Panel
class_name ProjectHeader

# Configuration exports - set in editor when instancing
@export var show_godot_version: bool = true
@export var show_current_version: bool = true
@export var show_last_linter_scan: bool = true
@export var show_last_published: bool = true
@export var show_date_labels: bool = false
@export var apply_theme: bool = true  # Can disable for parent to control theming

# Signals
signal folder_button_pressed(path: String)
signal copy_path_pressed(path: String)

@onready var _thumbTextureRect = %ThumbTextureRect
@onready var _projectNameLabel = %ProjectNameLabel
@onready var _godotVersionLabel = %GodotVersionLabel
@onready var _godotVersionContainer = %GodotVersionContainer
@onready var _projectPathLabel = %ProjectPathLabel
@onready var _copyPathButton = %CopyPathButton
@onready var _folderButton = %FolderButton
@onready var _metadataRow = %MetadataRow
@onready var _currentVersionLabel = %CurrentVersionLabel
@onready var _lastLinterScanLabel = %LastLinterScanLabel
@onready var _lastPublishedLabel = %LastPublishedLabel
@onready var _dateLabelsRow = %DateLabelsRow
@onready var _createdDateLabel = %CreatedDateLabel
@onready var _editedDateLabel = %EditedDateLabel

var _selectedProjectItem = null

func _ready():
	if apply_theme:
		_applySelectedTheme()
	_setupButtons()
	_applyConfiguration()

func _applyConfiguration():
	# Apply export configuration
	if _godotVersionContainer:
		_godotVersionContainer.visible = show_godot_version
	if _currentVersionLabel:
		_currentVersionLabel.visible = show_current_version
	if _lastLinterScanLabel:
		_lastLinterScanLabel.visible = show_last_linter_scan
	if _lastPublishedLabel:
		_lastPublishedLabel.visible = show_last_published
	if _dateLabelsRow:
		_dateLabelsRow.visible = show_date_labels
	# Hide entire metadata row if all fields are hidden
	if _metadataRow:
		_metadataRow.visible = show_current_version or show_last_linter_scan or show_last_published

func _setupButtons():
	# Connect copy and folder buttons
	_copyPathButton.pressed.connect(_onCopyPathButtonPressed)
	_folderButton.pressed.connect(_onFolderButtonPressed)

func _onCopyPathButtonPressed():
	var projectPath = _projectPathLabel.text
	DisplayServer.clipboard_set(projectPath)
	copy_path_pressed.emit(projectPath)

func _onFolderButtonPressed():
	var projectPath = _projectPathLabel.text
	if projectPath.is_empty():
		return
	# Get directory from path (handles both with or without project.godot)
	var projectDir = projectPath
	if projectPath.ends_with("project.godot"):
		projectDir = projectPath.get_base_dir()
	OS.shell_open(projectDir)
	folder_button_pressed.emit(projectDir)

# Configure header with project item data
func configure(projectItem):
	_selectedProjectItem = projectItem
	_updateDisplay()

# Set individual properties (for cases where no project item is available)
func set_project_name(project_name: String):
	_projectNameLabel.text = project_name

func set_path(path: String):
	_projectPathLabel.text = path

func set_godot_version(version: String):
	_godotVersionLabel.text = version

func set_icon(texture: Texture2D):
	_thumbTextureRect.texture = texture

func get_icon_texture() -> Texture2D:
	return _thumbTextureRect.texture

func set_icon_from_path(path: String):
	if path.is_empty():
		return

	# Check if this is a Godot resource path (res://)
	if path.begins_with("res://"):
		var texture = load(path)
		if texture:
			_thumbTextureRect.texture = texture
	else:
		# Load from filesystem
		var image = Image.new()
		var error = image.load(path)
		if error == OK:
			var texture = ImageTexture.create_from_image(image)
			_thumbTextureRect.texture = texture

func _updateDisplay():
	if _selectedProjectItem == null:
		return

	_projectNameLabel.text = _selectedProjectItem.GetProjectName()
	_godotVersionLabel.text = _selectedProjectItem.GetGodotVersion()
	_projectPathLabel.text = _selectedProjectItem.GetProjectPath()

	# Set metadata fields
	var version = _selectedProjectItem.GetProjectVersion()
	if version.is_empty():
		version = "--"
	set_current_version(version)

	# Set published date if available
	var published_date = _selectedProjectItem.GetPublishedDate()
	if published_date.is_empty():
		set_last_published("--")
	else:
		set_last_published(Date.GetCurrentDateAsString(published_date))

	# Load thumbnail
	set_icon_from_path(_selectedProjectItem.GetThumbnailPath())

# Set metadata field values
func set_current_version(version: String):
	if _currentVersionLabel:
		_currentVersionLabel.text = "Current Version: " + version

func set_last_linter_scan(scan_date: String):
	if _lastLinterScanLabel:
		_lastLinterScanLabel.text = "Last Linter Scan: " + scan_date

func set_last_published(published_date: String):
	if _lastPublishedLabel:
		_lastPublishedLabel.text = "Last Published: " + published_date

func set_created_date(date_str: String):
	if _createdDateLabel:
		_createdDateLabel.text = "Created: " + date_str

func set_edited_date(date_str: String):
	if _editedDateLabel:
		_editedDateLabel.text = "Edited: " + date_str

# Show brief "Saved" indicator
func show_saved_indicator():
	# Could add a flash effect or label if needed
	pass

func _applySelectedTheme():
	var customTheme = Theme.new()
	var styleBox = StyleBoxFlat.new()

	# Match selected project item styling
	styleBox.bg_color = _adjustBackgroundColor(0.32)
	styleBox.border_color = Color(0.6, 0.6, 0.6)
	styleBox.border_width_left = 3
	styleBox.border_width_top = 3
	styleBox.border_width_right = 3
	styleBox.border_width_bottom = 3
	styleBox.border_blend = true
	styleBox.corner_radius_top_left = 6
	styleBox.corner_radius_top_right = 6
	styleBox.corner_radius_bottom_right = 6
	styleBox.corner_radius_bottom_left = 6

	customTheme.set_stylebox("panel", "Panel", styleBox)
	theme = customTheme

func _adjustBackgroundColor(amount):
	var colorToSubtract = Color(amount, amount, amount, 0.0)
	var baseColor = App.GetBackgroundColor()

	var newColor = Color(
		max(baseColor.r + colorToSubtract.r, 0),
		max(baseColor.g + colorToSubtract.g, 0),
		max(baseColor.b + colorToSubtract.b, 0),
		max(baseColor.a + colorToSubtract.a, 0)
	)

	return newColor
