extends Panel

signal settings_applied(filter_extensions: Dictionary)
signal settings_canceled()

# Default filter extensions
const DEFAULT_EXTENSIONS = {
	"all": [],  # Empty = all files
	"images": [".png", ".jpg", ".jpeg", ".bmp", ".svg", ".webp", ".tga", ".exr", ".hdr"],
	"sounds": [".ogg", ".mp3", ".wav", ".aac"],
	"text": [".txt", ".json", ".cfg", ".ini", ".csv", ".md", ".xml"],
	"videos": [".ogv", ".webm", ".mp4", ".mov", ".avi", ".mkv", ".wmv", ".flv", ".m4v"],
	"models": [".dae", ".gltf", ".glb", ".fbx", ".blend", ".obj"],
	"fonts": [".ttf", ".otf", ".woff", ".woff2"],
	"executables": [".exe", ".dll", ".so", ".dylib", ".bin", ".msi", ".app"],
	"zip": [".zip", ".rar", ".7z", ".tar", ".gz"]
}

@onready var _imagesLineEdit: LineEdit = %ImagesLineEdit
@onready var _soundsLineEdit: LineEdit = %SoundsLineEdit
@onready var _textLineEdit: LineEdit = %TextLineEdit
@onready var _videosLineEdit: LineEdit = %VideosLineEdit
@onready var _modelsLineEdit: LineEdit = %ModelsLineEdit
@onready var _fontsLineEdit: LineEdit = %FontsLineEdit
@onready var _executablesLineEdit: LineEdit = %ExecutablesLineEdit
@onready var _zipLineEdit: LineEdit = %ZipLineEdit

@onready var _resetButton: Button = %ResetButton
@onready var _closeButton: Button = %CloseButton
@onready var _saveButton: Button = %SaveButton

var _currentExtensions: Dictionary = {}

func _ready():
	_resetButton.pressed.connect(_on_reset_button_pressed)
	_closeButton.pressed.connect(_on_close_button_pressed)
	_saveButton.pressed.connect(_on_save_button_pressed)

# Load current extension configuration
func load_extensions(extensions: Dictionary):
	_currentExtensions = extensions.duplicate()

	# Populate line edits with current values
	_imagesLineEdit.text = _extensions_to_string(_currentExtensions.get("images", DEFAULT_EXTENSIONS.images))
	_soundsLineEdit.text = _extensions_to_string(_currentExtensions.get("sounds", DEFAULT_EXTENSIONS.sounds))
	_textLineEdit.text = _extensions_to_string(_currentExtensions.get("text", DEFAULT_EXTENSIONS.text))
	_videosLineEdit.text = _extensions_to_string(_currentExtensions.get("videos", DEFAULT_EXTENSIONS.videos))
	_modelsLineEdit.text = _extensions_to_string(_currentExtensions.get("models", DEFAULT_EXTENSIONS.models))
	_fontsLineEdit.text = _extensions_to_string(_currentExtensions.get("fonts", DEFAULT_EXTENSIONS.fonts))
	_executablesLineEdit.text = _extensions_to_string(_currentExtensions.get("executables", DEFAULT_EXTENSIONS.executables))
	_zipLineEdit.text = _extensions_to_string(_currentExtensions.get("zip", DEFAULT_EXTENSIONS.zip))

# Convert extensions array to comma-delimited string
func _extensions_to_string(extensions: Array) -> String:
	if extensions.is_empty():
		return ""
	return ", ".join(extensions)

# Convert comma-delimited string to extensions array
func _string_to_extensions(text: String) -> Array:
	if text.strip_edges().is_empty():
		return []

	var parts = text.split(",")
	var extensions = []
	for part in parts:
		var ext = part.strip_edges()
		if not ext.is_empty():
			# Ensure extension starts with dot
			if not ext.begins_with("."):
				ext = "." + ext
			extensions.append(ext)
	return extensions

func _on_reset_button_pressed():
	# Reset to default values
	_imagesLineEdit.text = _extensions_to_string(DEFAULT_EXTENSIONS.images)
	_soundsLineEdit.text = _extensions_to_string(DEFAULT_EXTENSIONS.sounds)
	_textLineEdit.text = _extensions_to_string(DEFAULT_EXTENSIONS.text)
	_videosLineEdit.text = _extensions_to_string(DEFAULT_EXTENSIONS.videos)
	_modelsLineEdit.text = _extensions_to_string(DEFAULT_EXTENSIONS.models)
	_fontsLineEdit.text = _extensions_to_string(DEFAULT_EXTENSIONS.fonts)
	_executablesLineEdit.text = _extensions_to_string(DEFAULT_EXTENSIONS.executables)
	_zipLineEdit.text = _extensions_to_string(DEFAULT_EXTENSIONS.zip)

func _on_close_button_pressed():
	# Emit signal to close panel without saving
	# Parent will handle visibility and reparenting
	settings_canceled.emit()

func _on_save_button_pressed():
	# Gather all values from line edits
	var new_extensions = {
		"images": _string_to_extensions(_imagesLineEdit.text),
		"sounds": _string_to_extensions(_soundsLineEdit.text),
		"text": _string_to_extensions(_textLineEdit.text),
		"videos": _string_to_extensions(_videosLineEdit.text),
		"models": _string_to_extensions(_modelsLineEdit.text),
		"fonts": _string_to_extensions(_fontsLineEdit.text),
		"executables": _string_to_extensions(_executablesLineEdit.text),
		"zip": _string_to_extensions(_zipLineEdit.text)
	}

	# Emit signal with new configuration
	settings_applied.emit(new_extensions)

	# Don't close panel - just save

func show_panel():
	visible = true
	move_to_front()
