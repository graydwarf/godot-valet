extends Control

@onready var titleLabel: Label = %TitleLabel

# Supported file types
var supportedTextFiles = ["gd", "cs", "txt", "json", "cfg", "ini", "md", "xml", "html", "css", "js", "gdshader"]
var supportedImageFiles = ["png", "jpg", "jpeg", "bmp", "svg", "webp", "tga"]
var supportedSceneFiles = ["tscn", "scn"]

func _ready():
	ClearPreview()

# Add this function to FilePreviewer.gd
func IsZipPath(filePath: String) -> bool:
	"""Check if the path is inside a zip file"""
	return "::" in filePath

func ExtractFileFromZip(zipFilePath: String, internalPath: String) -> PackedByteArray:
	"""Extract a file from a zip archive and return its data"""
	var zip = ZIPReader.new()
	var error = zip.open(zipFilePath)
	if error != OK:
		print("Failed to open zip file: " + zipFilePath)
		return PackedByteArray()
	
	var fileData = zip.read_file(internalPath)
	zip.close()
	return fileData

# Update your PreviewFile function to handle zip paths:
func PreviewFile(filePath: String):
	"""Preview a file based on its extension"""
	var fileName = ""
	var extension = ""
	
	# Handle zip file paths
	if IsZipPath(filePath):
		var parts = filePath.split("::")
		var internalPath = parts[1]
		fileName = internalPath.get_file()
		extension = internalPath.get_extension().to_lower()
	else:
		fileName = filePath.get_file()
		extension = filePath.get_extension().to_lower()
	
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

func ResetContentScrollContainer():
	%ContentScrollContainer.scroll_horizontal = 0
	%ContentScrollContainer.scroll_vertical = 0
	
func PreviewImage(filePath: String):
	var image = Image.new()
	var error
	ResetContentScrollContainer()
	ShowImageDisplay()	
	
	if IsZipPath(filePath):
		# Extract from zip and save to temporary file
		var parts = filePath.split("::")
		var zipPath = parts[0]
		var internalPath = parts[1]
		
		var imageData = ExtractFileFromZip(zipPath, internalPath)
		if imageData.size() == 0:
			ShowError("Failed to extract image from zip: " + internalPath)
			return
		
		# Create a temporary file
		var tempFilePath = "user://temp_image_preview." + internalPath.get_extension()
		var tempFile = FileAccess.open(tempFilePath, FileAccess.WRITE)
		if tempFile == null:
			ShowError("Failed to create temporary file for image preview")
			return
		
		tempFile.store_buffer(imageData)
		tempFile.close()
		
		# Load from temporary file
		error = image.load(tempFilePath)
		
		# Clean up temporary file
		DirAccess.remove_absolute(tempFilePath)
	else:
		# Load from regular file
		error = image.load(filePath)
	
	if error != OK:
		ShowError("Failed to load image: " + filePath)
		return
	
	var texture = ImageTexture.create_from_image(image)
	%ImageViewer.texture = texture
	
	# Set to actual size - no scaling
	%ImageViewer.stretch_mode = TextureRect.STRETCH_KEEP
	%ImageViewer.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	
	# Set the size to match the image
	%ImageViewer.custom_minimum_size = Vector2(image.get_width(), image.get_height())
	
	# Show image info
	var displayPath = filePath
	if IsZipPath(filePath):
		displayPath = filePath.split("::")[1]
	
	var info = "Image: %dx%d pixels\nFormat: %s\nSize: %s" % [
		image.get_width(),
		image.get_height(),
		displayPath.get_extension().to_upper(),
		FormatFileSize(GetFileSize(filePath))
	]
	
	print(info)

func PreviewTextFile(filePath: String):
	ShowTextEditor()
	var content = ""
	
	if IsZipPath(filePath):
		# Extract from zip
		var parts = filePath.split("::")
		var zipPath = parts[0]
		var internalPath = parts[1]
		
		var fileData = ExtractFileFromZip(zipPath, internalPath)
		if fileData.size() == 0:
			ShowError("Failed to extract file from zip: " + internalPath)
			return
		
		content = fileData.get_string_from_utf8()
	else:
		# Load from regular file
		var file = FileAccess.open(filePath, FileAccess.READ)
		if file == null:
			ShowError("Failed to open file: " + filePath)
			return
		
		content = file.get_as_text()
		file.close()
	
	%TextViewer.text = content
	%TextViewer.editable = false  # Read-only preview
	
	# Set syntax highlighting based on file type
	var extension = ""
	if IsZipPath(filePath):
		extension = filePath.split("::")[1].get_extension()
	else:
		extension = filePath.get_extension()
	
	SetSyntaxHighlighting(extension)

func GetFileSize(filePath: String) -> int:
	if IsZipPath(filePath):
		var parts = filePath.split("::")
		var zipPath = parts[0]
		var internalPath = parts[1]
		
		var zip = ZIPReader.new()
		var error = zip.open(zipPath)
		if error != OK:
			return 0
		
		# Check if the file actually exists in the zip
		var files = zip.get_files()
		if not internalPath in files:
			zip.close()
			return 0
		
		var fileData = zip.read_file(internalPath)
		zip.close()
		return fileData.size()
	else:
		var file = FileAccess.open(filePath, FileAccess.READ)
		if file == null:
			return 0
		
		var fileSize = file.get_length()
		file.close()
		return fileSize

# Preview text files
func PreviewSceneFile(filePath: String):
	ShowTextEditor()
	
	var content = ""
	
	if IsZipPath(filePath):
		# Extract from zip
		var parts = filePath.split("::")
		var zipPath = parts[0]
		var internalPath = parts[1]
		
		var fileData = ExtractFileFromZip(zipPath, internalPath)
		if fileData.size() == 0:
			ShowError("Failed to extract scene file from zip: " + internalPath)
			return
		
		content = fileData.get_string_from_utf8()
	else:
		# Load from regular file
		var file = FileAccess.open(filePath, FileAccess.READ)
		if file == null:
			ShowError("Failed to open scene file: " + filePath)
			return
		
		content = file.get_as_text()
		file.close()
	
	%TextViewer.text = content
	%TextViewer.editable = false
	
	# Could add special scene file highlighting or parsing here
	print("Scene file preview: " + filePath)

func ShowUnsupportedFile(filePath: String, extension: String):
	"""Show info for unsupported file types"""
	ShowTextEditor()
	
	var fileName = ""
	if IsZipPath(filePath):
		fileName = filePath.split("::")[1].get_file()
	else:
		fileName = filePath.get_file()
	
	var fileSize = GetFileSize(filePath)
	var info = "File: %s\nExtension: %s\nSize: %s\n\nThis file type is not supported for preview." % [
		fileName,
		extension,
		FormatFileSize(fileSize)
	]
	
	if IsZipPath(filePath):
		var zipPath = filePath.split("::")[0].get_file()
		info += "\n\nThis file is inside: " + zipPath
	
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
	%TitleLabel.text = "No file selected"
	%TextViewer.text = ""
	%ImageViewer.texture = null
	ShowTextEditor()

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
