extends Panel
class_name ProjectCard

@onready var _thumbTextureRect = %ThumbTextureRect
@onready var _projectNameLabel = %ProjectNameLabel
@onready var _godotVersionLabel = %GodotVersionLabel
@onready var _versionLeftLabel = %VersionLeftLabel
@onready var _versionRightLabel = %VersionRightLabel
@onready var _projectPathLabel = %ProjectPathLabel
@onready var _folderIcon = %FolderIcon
@onready var _publishedDateLabel = %PublishedDateLabel

var _selectedProjectItem = null

func _ready():
	_applySelectedTheme()
	_setupProjectPathLink()

func _setupProjectPathLink():
	# Make project path clickable
	_projectPathLabel.mouse_filter = Control.MOUSE_FILTER_STOP
	_projectPathLabel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_projectPathLabel.gui_input.connect(_onProjectPathClicked)

	# Make folder icon clickable too
	_folderIcon.gui_input.connect(_onProjectPathClicked)

func _onProjectPathClicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _selectedProjectItem != null:
			var projectPath = _selectedProjectItem.GetProjectPath()
			OS.shell_open(projectPath)

# Called by wizard to update card with project info
func configure(projectItem):
	_selectedProjectItem = projectItem
	_updateDisplay()

func _updateDisplay():
	if _selectedProjectItem == null:
		return

	_projectNameLabel.text = _selectedProjectItem.GetProjectName()
	_godotVersionLabel.text = _selectedProjectItem.GetGodotVersion()

	var version = _selectedProjectItem.GetProjectVersion()
	if version.is_empty():
		version = "v0.0.1"  # Default if no version set
	_updateVersionDisplay(version, version)

	_projectPathLabel.text = _selectedProjectItem.GetProjectPath()

	# Format published date
	var publishedDate = _selectedProjectItem.GetPublishedDate()

	if publishedDate.is_empty():
		_publishedDateLabel.text = "Published: Never"
	else:
		_publishedDateLabel.text = "Published: " + Date.GetCurrentDateAsString(publishedDate)

	# Load thumbnail
	_loadThumbnail()

func update_version_comparison(old_version: String, new_version: String):
	_updateVersionDisplay(old_version, new_version)

func _updateVersionDisplay(old_version: String, new_version: String):
	# Always show arrow format: "v0.0.1 → v0.0.2"
	_versionLeftLabel.text = old_version + " → "
	_versionRightLabel.text = new_version

func _loadThumbnail():
	var thumbnailPath = _selectedProjectItem.GetThumbnailPath()
	if thumbnailPath == "":
		return

	# Check if this is a Godot resource path (res://)
	if thumbnailPath.begins_with("res://"):
		var texture = load(thumbnailPath)
		if texture:
			_thumbTextureRect.texture = texture
	else:
		# Load from filesystem
		var image = Image.new()
		var error = image.load(thumbnailPath)
		if error == OK:
			var texture = ImageTexture.create_from_image(image)
			_thumbTextureRect.texture = texture

# Show brief "Saved" indicator (not implemented in this simple version)
# Could add a flash effect or label if needed
func show_saved_indicator():
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
