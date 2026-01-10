class_name FileTreeIcons
extends RefCounted

# File Tree Icons - Icon management for file tree view explorer
# Extracted from file-tree-view-explorer.gd to reduce file size

# Icon paths
const ICON_PATH_BASE = "res://scenes/file-tree-view-explorer/assets/fluent-icons/"

# Cached icons for performance
static var _cache: Dictionary = {}

static func GetDriveIcon() -> Texture2D:
	return _get_icon("drive.svg")

static func GetFolderIcon() -> Texture2D:
	return _get_icon("folder.svg")

static func GetOpenFolderIcon() -> Texture2D:
	return _get_icon("folder-open.svg")

static func GetFileIcon() -> Texture2D:
	return _get_icon("document.svg")

static func GetImageIcon() -> Texture2D:
	return _get_icon("image.svg")

static func GetZipIcon() -> Texture2D:
	return _get_icon("archive.svg")

static func GetScriptIcon() -> Texture2D:
	return _get_icon("code.svg")

static func GetAudioIcon() -> Texture2D:
	return _get_icon("audio.svg")

static func GetSceneIcon() -> Texture2D:
	return _get_icon("document.svg")

static func GetVideoIcon() -> Texture2D:
	return _get_icon("video.svg")

static func Get3DModelIcon() -> Texture2D:
	return _get_icon("3d-model.svg")

static func GetFontIcon() -> Texture2D:
	return _get_icon("font.svg")

static func GetTextIcon() -> Texture2D:
	return _get_icon("document.svg")

static func GetExecutableIcon() -> Texture2D:
	return _get_icon("app.svg")

# Helper to load and cache icons
static func _get_icon(icon_name: String) -> Texture2D:
	if not _cache.has(icon_name):
		_cache[icon_name] = load(ICON_PATH_BASE + icon_name) as Texture2D
	return _cache[icon_name]

# Set icon on a tree item with consistent styling
static func SetTreeItemIcon(item: TreeItem, column: int, texture: Texture2D):
	item.set_icon(column, texture)
	item.set_icon_modulate(column, Color.WHITE)

# Get appropriate icon based on file path and extension arrays
static func GetIconFromFilePath(filePath: String, extensions: Dictionary) -> Texture2D:
	var extension = "." + filePath.get_extension().to_lower()

	if extension in extensions.get("executables", []):
		return GetExecutableIcon()
	elif extension in extensions.get("images", []):
		return GetImageIcon()
	elif extension in extensions.get("zip", []):
		return GetZipIcon()
	elif extension in extensions.get("scripts", []):
		return GetScriptIcon()
	elif extension in extensions.get("audio", []):
		return GetAudioIcon()
	elif extension in extensions.get("scenes", []):
		return GetSceneIcon()
	elif extension in extensions.get("videos", []):
		return GetVideoIcon()
	elif extension in extensions.get("models", []):
		return Get3DModelIcon()
	elif extension in extensions.get("fonts", []):
		return GetFontIcon()
	elif extension in extensions.get("text", []):
		return GetTextIcon()
	else:
		return GetFileIcon()
