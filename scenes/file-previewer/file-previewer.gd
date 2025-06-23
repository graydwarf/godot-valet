extends Control

@onready var titleLabel: Label = %TitleLabel

# Supported file types
var supportedTextFiles = ["gd", "cs", "txt", "json", "cfg", "ini", "md", "xml", "html", "css", "js", "gdshader"]
var supportedImageFiles = ["png", "jpg", "jpeg", "bmp", "svg", "webp", "tga"]
var supportedSceneFiles = ["tscn", "scn"]

func _ready():
	ClearPreview()

func PreviewFile(filePath: String):
	"""Preview a file based on its extension"""
	var fileName = filePath.get_file()
	var extension = filePath.get_extension().to_lower()
	
	titleLabel.text = fileName
	
	# Check file type and preview accordingly
	if extension in supportedImageFiles:
		PreviewImage(filePath)
	elif extension in supportedTextFiles:
		PreviewTextFile(filePath)
	elif extension in supportedSceneFiles:
		PreviewSceneFile(filePath)
	else:
		ShowUnsupportedFile(filePath, extension)

func PreviewImage(filePath: String):
	"""Preview image files"""
	ShowImageDisplay()
	
	var image = Image.new()
	var error = image.load(filePath)
	
	if error != OK:
		ShowError("Failed to load image: " + filePath)
		return
	
	var texture = ImageTexture.create_from_image(image)
	%ImageViewer.texture = texture
	
	# Set stretch mode to keep aspect ratio
	#%ImageViewer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Show image info
	var info = "Image: %dx%d pixels\nFormat: %s\nSize: %s" % [
		image.get_width(),
		image.get_height(),
		filePath.get_extension().to_upper(),
		FormatFileSize(GetFileSize(filePath))
	]
	
	# You could add an info label here if desired
	print(info)

func PreviewTextFile(filePath: String):
	"""Preview text-based files"""
	ShowTextEditor()
	
	var file = FileAccess.open(filePath, FileAccess.READ)
	if file == null:
		ShowError("Failed to open file: " + filePath)
		return
	
	var content = file.get_as_text()
	file.close()
	
	%TextViewer.text = content
	%TextViewer.editable = false  # Read-only preview
	
	# Set syntax highlighting based on file type
	SetSyntaxHighlighting(filePath.get_extension())

func PreviewSceneFile(filePath: String):
	"""Preview Godot scene files"""
	ShowTextEditor()
	
	var file = FileAccess.open(filePath, FileAccess.READ)
	if file == null:
		ShowError("Failed to open scene file: " + filePath)
		return
	
	var content = file.get_as_text()
	file.close()
	
	%TextViewer.text = content
	%TextViewer.editable = false
	
	# Could add special scene file highlighting or parsing here
	print("Scene file preview: " + filePath)

func ShowUnsupportedFile(filePath: String, extension: String):
	"""Show info for unsupported file types"""
	ShowTextEditor()
	
	var fileSize = GetFileSize(filePath)
	var info = "File: %s\nExtension: %s\nSize: %s\n\nThis file type is not supported for preview." % [
		filePath.get_file(),
		extension,
		FormatFileSize(fileSize)
	]
	
	%TextViewer.text = info
	%TextViewer.editable = false

func ShowError(errorMessage: String):
	"""Show error message"""
	ShowTextEditor()
	%TextViewer.text = "Error: " + errorMessage
	%TextViewer.editable = false

func SetSyntaxHighlighting(extension: String):
	"""Set syntax highlighting based on file extension"""
	# Note: You might need to configure syntax highlighting differently
	# depending on your Godot version and available highlighters
	match extension.to_lower():
		".gd":
			%TextViewer.syntax_highlighter = null  # Godot's default GDScript highlighter
		".cs":
			%TextViewer.syntax_highlighter = null  # C# highlighter if available
		".json":
			%TextViewer.syntax_highlighter = null  # JSON highlighter if available
		_:
			%TextViewer.syntax_highlighter = null  # No highlighting

func ShowTextEditor():
	"""Show the text editor and hide image display"""
	%TextViewer.visible = true
	%ImageViewer.visible = false

func ShowImageDisplay():
	"""Show the image display and hide text editor"""
	%TextViewer.visible = false
	%ImageViewer.visible = true

func ClearPreview():
	"""Clear the preview area"""
	%TitleLabel.text = "No file selected"
	%TextViewer.text = ""
	%ImageViewer.texture = null
	ShowTextEditor()

func GetFileSize(filePath: String) -> int:
	"""Get file size in bytes"""
	var file = FileAccess.open(filePath, FileAccess.READ)
	if file == null:
		return 0
	
	var size = file.get_length()
	file.close()
	return size

func FormatFileSize(sizeBytes: int) -> String:
	"""Format file size in human-readable format"""
	if sizeBytes < 1024:
		return str(sizeBytes) + " B"
	elif sizeBytes < 1024 * 1024:
		return "%.1f KB" % (sizeBytes / 1024.0)
	elif sizeBytes < 1024 * 1024 * 1024:
		return "%.1f MB" % (sizeBytes / (1024.0 * 1024.0))
	else:
		return "%.1f GB" % (sizeBytes / (1024.0 * 1024.0 * 1024.0))

func IsFileSupported(filePath: String) -> bool:
	"""Check if a file type is supported for preview"""
	var extension = filePath.get_extension().to_lower()
	return extension in supportedTextFiles or extension in supportedImageFiles or extension in supportedSceneFiles

func AddSupportedExtension(extension: String, fileType: String = "text"):
	"""Add support for additional file extensions"""
	match fileType:
		"text":
			if not extension in supportedTextFiles:
				supportedTextFiles.append(extension)
		"image":
			if not extension in supportedImageFiles:
				supportedImageFiles.append(extension)
		"scene":
			if not extension in supportedSceneFiles:
				supportedSceneFiles.append(extension)
