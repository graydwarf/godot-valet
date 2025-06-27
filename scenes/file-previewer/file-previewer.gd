extends Control

# - Generated with assistance from Claude 4 Sonnet (Anthropic) - December 2024

# Supported file types
var supportedTextFiles = ["gd", "cs", "txt", "json", "cfg", "ini", "md", "xml", "html", "css", "js", "gdshader"]
var supportedImageFiles = ["png", "jpg", "jpeg", "bmp", "svg", "webp", "tga"]
var supportedSceneFiles = ["tscn", "scn"]
var _baseSize : Vector2
var _zoomFactor := 1.0
var _isDragging : bool = false
var _dragStartPos := Vector2.ZERO
var _imageStartPos := Vector2.ZERO
var _zoomCenter := Vector2.ZERO

func _ready():
	ClearPreview()

# Check if the path is inside a zip file
func IsZipPath(filePath: String) -> bool:
	return "::" in filePath

# Extract a file from a zip archive and return its data
func ExtractFileFromZip(zipFilePath: String, internalPath: String) -> PackedByteArray:
	var zip = ZIPReader.new()
	var error = zip.open(zipFilePath)
	if error != OK:
		return PackedByteArray()
	
	var fileData = zip.read_file(internalPath)
	zip.close()
	return fileData

# Preview a file based on its extension
func PreviewFile(filePath: String):
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
	_zoomFactor = 1.0 # Reset with each image
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
	_baseSize = texture.get_size()
	%ImageViewer.texture = texture
	UpdateImageSize()
		
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
			%TextEdit.text = "Nothing to show in this file..."
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
	
	if content == "":
		%TextEdit.text = "Nothing to show in this file..."
	else:
		%TextEdit.text = content
		
	%TextEdit.editable = false  # Read-only preview
	
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
			ShowError("Nothing to show in this file...")
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
	
	%TextEdit.text = content
	%TextEdit.editable = false

# Show info for unsupported file types
func ShowUnsupportedFile(filePath: String, extension: String):
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
	
	%TextEdit.text = info
	%TextEdit.editable = false

# Show error message
func ShowError(errorMessage: String):
	ShowTextEditor()
	%TextEdit.text = "Error: " + errorMessage
	%TextEdit.editable = false

# Set syntax highlighting based on file extension
func SetSyntaxHighlighting(extension: String):
	match extension.to_lower():
		"gd":
			var highlighter = CodeHighlighter.new()
			highlighter.symbol_color = Color.WHITE
			highlighter.member_variable_color = Color.WHITE
			
			# Keywords (func, if, var, etc.) - orange/red
			var keywordColor = "#ff6666"
			highlighter.add_keyword_color("func", Color(keywordColor))
			highlighter.add_keyword_color("var", Color(keywordColor))
			highlighter.add_keyword_color("if", Color(keywordColor))
			highlighter.add_keyword_color("else", Color(keywordColor))
			highlighter.add_keyword_color("for", Color(keywordColor))
			highlighter.add_keyword_color("while", Color(keywordColor))
			highlighter.add_keyword_color("class", Color(keywordColor))
			highlighter.add_keyword_color("extends", Color(keywordColor))
			highlighter.add_keyword_color("return", Color(keywordColor))
			highlighter.add_keyword_color("bool", Color(keywordColor))
			highlighter.add_keyword_color("Vector2", Color(keywordColor))
			
			# Built-in classes/types
			var builtInColor = "#73f87a"
			highlighter.add_keyword_color("FileAccess", Color(builtInColor))
			highlighter.add_keyword_color("DirAccess", Color(builtInColor))
			highlighter.add_keyword_color("ZIPReader", Color(builtInColor))
			highlighter.add_keyword_color("Image", Color(builtInColor))
			highlighter.add_keyword_color("ImageTexture", Color(builtInColor))
			highlighter.add_keyword_color("TreeItem", Color(builtInColor))
			highlighter.add_keyword_color("Control", Color(builtInColor))
			highlighter.add_keyword_color("Node", Color(builtInColor))
			highlighter.add_keyword_color("PackedByteArray", Color(builtInColor))

			# Function names - blue
			highlighter.function_color = Color("#8cc5ff")
			
			# Strings - green (using color regions)
			highlighter.add_color_region("\"", "\"", Color("#ffff67"))
			highlighter.add_color_region("'", "'", Color("#ffff67"))
			
			# Numbers - light blue/cyanffff40
			highlighter.number_color = Color("#66ffff")
			
			# Comments - green
			highlighter.add_color_region("#", "", Color("#66aa66"), true)
			
			%TextEdit.syntax_highlighter = highlighter
		"json":
			var highlighter = CodeHighlighter.new()
			highlighter.add_keyword_color("true", Color("#66ffff"))
			highlighter.add_keyword_color("false", Color("#66ffff"))
			highlighter.add_keyword_color("null", Color("#66ffff"))
			# Strings in JSON
			highlighter.add_color_region("\"", "\"", Color("#66ff66"))
			highlighter.number_color = Color("#66ffff")
			%TextEdit.syntax_highlighter = highlighter
		_:
			%TextEdit.syntax_highlighter = null

# Show the text editor and hide image display
func ShowTextEditor():
	%ImageToolbar.visible = false
	%TextToolbar.visible = true
	%TextViewer.visible = true
	%ImageContainer.visible = false

# Show the image display and hide text editor
func ShowImageDisplay():
	%ImageToolbar.visible = true
	%TextToolbar.visible = false
	%TextViewer.visible = false
	%ImageContainer.visible = true

func ClearPreview():
	%TextEdit.text = ""
	%ImageViewer.texture = null
	ShowTextEditor()

# Format file size in human-readable format
func FormatFileSize(sizeBytes: int) -> String:
	if sizeBytes < 1024:
		return str(sizeBytes) + " B"
	elif sizeBytes < 1024 * 1024:
		return "%.1f KB" % (sizeBytes / 1024.0)
	elif sizeBytes < 1024 * 1024 * 1024:
		return "%.1f MB" % (sizeBytes / (1024.0 * 1024.0))
	else:
		return "%.1f GB" % (sizeBytes / (1024.0 * 1024.0 * 1024.0))

# Check if a file type is supported for preview
func IsFileSupported(filePath: String) -> bool:
	var extension = filePath.get_extension().to_lower()
	return extension in supportedTextFiles or extension in supportedImageFiles or extension in supportedSceneFiles

# Add support for additional file extensions
# TODO:
func AddSupportedExtension(extension: String, fileType: String = "text"):
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

func UpdateImageSize():
	var newSize = _baseSize * _zoomFactor
	%ImageViewer.custom_minimum_size = newSize
	%ImageViewer.size = newSize
	
	# Center the image when it's smaller than the container
	var containerSize = %ImageContainer.size  # Your clipping Control node
	if newSize.x < containerSize.x:
		%ImageViewer.position.x = (containerSize.x - newSize.x) * 0.5
	if newSize.y < containerSize.y:
		%ImageViewer.position.y = (containerSize.y - newSize.y) * 0.5

func ZoomIn():
	_zoomFactor = min(_zoomFactor * 1.2, 50.0)
	UpdateImageSize()

func ZoomOut():
	_zoomFactor = max(_zoomFactor / 1.2, 0.1)
	UpdateImageSize()
	
var zoom_center: Vector2  # Point to zoom into

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_isDragging = true
				_dragStartPos = event.position
				_imageStartPos = %ImageViewer.position
			else:
				_isDragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_center = event.position  # Zoom into mouse position
			ZoomIn()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_center = event.position  # Zoom out from mouse position
			ZoomOut()
	elif event is InputEventMouseMotion and _isDragging:
		var delta = event.position - _dragStartPos
		%ImageViewer.position = _imageStartPos + delta

func UpdateImageSizeWithCenter(old_zoom: float):
	var old_size = _baseSize * old_zoom
	var new_size = _baseSize * _zoomFactor
	
	# Calculate the point in the image we're zooming into
	var image_point = zoom_center - %ImageViewer.position
	
	# Calculate the ratio of the zoom change
	var zoom_ratio = _zoomFactor / old_zoom
	
	# Adjust position so the zoom_center point stays in the same place
	var new_image_point = image_point * zoom_ratio
	%ImageViewer.position = zoom_center - new_image_point
	
	# Update the image size
	%ImageViewer.custom_minimum_size = new_size
	%ImageViewer.size = new_size

# For zoom functions without a specific center (like reset), use container center
func ResetZoom():
	zoom_center = %ClippingContainer.size * 0.5  # Center of container
	var old_zoom = _zoomFactor
	_zoomFactor = 1.0
	UpdateImageSizeWithCenter(old_zoom)

# Optional: Constrain panning to keep image visible
func ConstrainImagePosition():
	var container_size = %ImageContainer.size
	var image_size = %ImageViewer.size
	
	# Don't let image move too far off screen
	%ImageViewer.position.x = clamp(%ImageViewer.position.x, 
		container_size.x - image_size.x, 0)
	%ImageViewer.position.y = clamp(%ImageViewer.position.y, 
		container_size.y - image_size.y, 0)
