extends Control

# - Generated with assistance from Claude 4 Sonnet (Anthropic) - December 2024

# Supported file types
var supportedTextFiles = ["gd", "cs", "txt", "json", "cfg", "ini", "md", "xml", "html", "css", "js", "gdshader"]
var supportedImageFiles = ["png", "jpg", "jpeg", "bmp", "svg", "webp", "tga"]
var supportedSceneFiles = ["tscn", "scn"]
var supportedArchiveFiles = ["zip"]
var supportedVideoFiles = ["ogv", "webm", "mp4", "mov", "avi", "mkv", "wmv", "flv", "m4v"]
var supportedAudioFiles = ["wav", "ogg", "mp3"]

# Image display modes
enum ImageDisplayMode {
	FIT_TO_SCREEN,
	ACTUAL_SIZE,
	STRETCH,
	TILE
}

var _currentDisplayMode := ImageDisplayMode.FIT_TO_SCREEN
var _baseSize : Vector2
var _zoomFactor := 1.0
var _isPanning : bool = false
var _panStartPos := Vector2.ZERO
var _scrollStartPos := Vector2.ZERO

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
	var extension = ""

	# Handle zip file paths
	if IsZipPath(filePath):
		var parts = filePath.split("::")
		var internalPath = parts[1]
		extension = internalPath.get_extension().to_lower()
	else:
		extension = filePath.get_extension().to_lower()
	
	# Check file type and preview accordingly
	if extension in supportedArchiveFiles:
		PreviewZipFile(filePath)
	elif extension in supportedVideoFiles:
		PreviewVideoFile(filePath)
	elif extension in supportedImageFiles:
		PreviewImage(filePath)
	elif extension in supportedAudioFiles:
		PreviewAudioFile(filePath)
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
	%ImageViewerDirect.texture = texture
	%ImageViewer.texture = texture
	ApplyImageDisplayMode(_currentDisplayMode)

	# Show image info
func PreviewZipFile(filePath: String):
	ShowTextEditor()

	# Extract actual zip file path if this is a path inside a zip
	var actualZipPath = filePath
	if IsZipPath(filePath):
		actualZipPath = filePath.split("::")[0]

	# Check if file exists
	if not FileAccess.file_exists(actualZipPath):
		ShowError("Zip file not found: " + actualZipPath)
		return

	var zip = ZIPReader.new()
	var error = zip.open(actualZipPath)

	if error != OK:
		ShowError("Failed to open zip file: " + actualZipPath + "\nError code: " + str(error))
		return

	# Get file list
	var files = zip.get_files()
	var fileCount = files.size()

	if fileCount == 0:
		%TextEdit.text = "Empty archive: " + actualZipPath.get_file()
		%TextEdit.editable = false
		zip.close()
		return

	# Calculate total uncompressed size
	var totalSize = 0
	for file in files:
		var fileData = zip.read_file(file)
		totalSize += fileData.size()

	zip.close()

	# Get zip file size on disk
	var zipFileSize = GetFileSize(actualZipPath)

	# Build display info
	var info = "Archive: %s\n" % actualZipPath.get_file()
	info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
	info += "File Count: %d\n" % fileCount
	info += "Archive Size: %s\n" % FormatFileSize(zipFileSize)
	info += "Uncompressed Size: %s\n" % FormatFileSize(totalSize)

	if zipFileSize > 0 and totalSize > 0:
		var compressionRatio = (1.0 - (float(zipFileSize) / float(totalSize))) * 100.0
		info += "Compression: %.1f%%\n" % compressionRatio

	info += "Path: %s\n" % actualZipPath

	info += "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
	info += "Contents:\n"
	info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"

	# List files (limit to first 100 to avoid performance issues)
	var maxFiles = min(files.size(), 100)
	for i in range(maxFiles):
		info += "  • " + files[i] + "\n"

	if files.size() > 100:
		info += "\n  ... and %d more files\n" % (files.size() - 100)

	%TextEdit.text = info
	%TextEdit.editable = false

func PreviewVideoFile(filePath: String):
	ShowTextEditor()

	# Extract actual file path if this is inside a zip
	var actualFilePath = filePath
	if IsZipPath(filePath):
		actualFilePath = filePath.split("::")[1]

	var extension = actualFilePath.get_extension().to_lower()
	var fileSize = GetFileSize(filePath)

	# Build display info
	var info = "Video: %s\n" % actualFilePath.get_file()
	info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
	info += "Format: .%s\n" % extension.to_upper()
	info += "Size: %s\n" % FormatFileSize(fileSize)
	info += "Path: %s\n\n" % filePath
	info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"

	# Add format-specific info
	if extension in ["ogv", "webm"]:
		info += "✓  Playback Supported\n\n"
		info += "This format can be played in Godot using\n"
		info += "the VideoStreamPlayer node.\n"
	else:
		info += "⚠️  Playback Not Supported\n\n"
		info += "Godot only supports .OGV and .WEBM video playback.\n"
		info += "This file can be viewed in external players like\n"
		info += "VLC, Windows Media Player, or QuickTime.\n"

	%TextEdit.text = info
	%TextEdit.editable = false

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

# Preview audio files with sound player
func PreviewAudioFile(filePath: String):
	ShowSoundPlayer()

	# Load single audio file into sound player
	if has_node("%SoundPlayerGrid"):
		var soundPaths: Array[String] = [filePath]
		%SoundPlayerGrid.LoadSounds(soundPaths)

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
# Partial implementation. Just playing around with the idea
# We should problably add a toggle button for this and 
# a UI to customize but why? Questionable to even have
# it for the file previewer.
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
	if has_node("%SoundPlayerContainer"):
		%SoundPlayerContainer.visible = false

# Show the image display and hide text editor
func ShowImageDisplay():
	%ImageToolbar.visible = true
	%TextToolbar.visible = false
	%TextViewer.visible = false
	%ImageContainer.visible = true
	if has_node("%SoundPlayerContainer"):
		%SoundPlayerContainer.visible = false

# Show the sound player and hide other views
func ShowSoundPlayer():
	%ImageToolbar.visible = false
	%TextToolbar.visible = false
	%TextViewer.visible = false
	%ImageContainer.visible = false
	if has_node("%SoundPlayerContainer"):
		%SoundPlayerContainer.visible = true

func ClearPreview():
	%TextEdit.text = ""
	%ImageViewer.texture = null
	%ImageViewerDirect.texture = null
	if has_node("%SoundPlayerGrid"):
		%SoundPlayerGrid.ClearPlayers()
	ShowTextEditor()

func PreviewDirectory(dirPath: String):
	ShowTextEditor()

	var info := ""  # Declare at function scope to avoid confusing redeclarations

	# Check if this is actually an archive file
	var extension = dirPath.get_extension().to_lower()
	if extension == "zip":
		PreviewZipFile(dirPath)
		return
	elif extension in ["7z", "rar", "tar", "gz", "bz2", "xz"]:
		# Unsupported archive formats
		info = "Archive: %s\n" % dirPath.get_file()
		info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
		info += "Format: .%s\n" % extension.to_upper()
		info += "Size: %s\n" % FormatFileSize(GetFileSize(dirPath))
		info += "Path: %s\n\n" % dirPath
		info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
		info += "⚠️  Archive preview not supported\n\n"
		info += "Godot only supports .ZIP file inspection.\n"
		info += "To view contents, please extract this archive\n"
		info += "using an external tool like 7-Zip or WinRAR.\n"
		%TextEdit.text = info
		%TextEdit.editable = false
		return

	# Handle zip paths differently
	if IsZipPath(dirPath):
		var parts = dirPath.split("::")
		var zipPath = parts[0]
		var internalPath = parts[1]

		# Show zip folder contents
		var zip = ZIPReader.new()
		var error = zip.open(zipPath)
		if error != OK:
			ShowError("Failed to open zip file: " + zipPath)
			return

		var files = zip.get_files()
		var folderFiles = []
		var folderPrefix = internalPath
		if not folderPrefix.ends_with("/"):
			folderPrefix += "/"

		# Find files in this folder
		for file in files:
			if file.begins_with(folderPrefix):
				var relativePath = file.substr(folderPrefix.length())
				# Only show immediate children (not nested)
				if "/" not in relativePath or relativePath.ends_with("/"):
					folderFiles.append(file)

		zip.close()

		info = "Folder: %s\n" % internalPath
		info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
		info += "Item Count: %d\n" % folderFiles.size()
		info += "Location: Inside %s\n" % zipPath.get_file()
		info += "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
		info += "Contents:\n"
		info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"

		for file in folderFiles:
			var fileNameInFolder = file.substr(folderPrefix.length())
			info += "  • " + fileNameInFolder + "\n"

		%TextEdit.text = info
		%TextEdit.editable = false
		return

	# Regular directory
	if not DirAccess.dir_exists_absolute(dirPath):
		ShowError("Directory does not exist: " + dirPath)
		return

	var dir = DirAccess.open(dirPath)
	if dir == null:
		ShowError("Cannot access directory: " + dirPath)
		return

	# Count files and folders
	var fileCount = 0
	var folderCount = 0
	var totalSize = 0
	var fileList = []

	dir.list_dir_begin()
	var fileName = dir.get_next()
	while fileName != "":
		if fileName != "." and fileName != "..":
			var fullPath = dirPath + "/" + fileName
			if dir.current_is_dir():
				folderCount += 1
				fileList.append("📁 " + fileName)
			else:
				fileCount += 1
				var fileSize = GetFileSize(fullPath)
				totalSize += fileSize
				fileList.append("📄 " + fileName)
		fileName = dir.get_next()
	dir.list_dir_end()

	# Build display info
	info = "Folder: %s\n" % dirPath.get_file()
	info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
	info += "Folders: %d\n" % folderCount
	info += "Files: %d\n" % fileCount
	info += "Total Size: %s\n" % FormatFileSize(totalSize)
	info += "Path: %s\n" % dirPath
	info += "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
	info += "Contents:\n"
	info += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"

	# List contents
	for item in fileList:
		info += "  " + item + "\n"

	%TextEdit.text = info
	%TextEdit.editable = false

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
	return extension in supportedTextFiles or extension in supportedImageFiles or extension in supportedSceneFiles or extension in supportedArchiveFiles or extension in supportedVideoFiles

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
		"archive":
			if not extension in supportedArchiveFiles:
				supportedArchiveFiles.append(extension)
		"video":
			if not extension in supportedVideoFiles:
				supportedVideoFiles.append(extension)

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

func ApplyImageDisplayMode(mode: ImageDisplayMode):
	_currentDisplayMode = mode

	# Update button states
	match mode:
		ImageDisplayMode.FIT_TO_SCREEN:
			%FitToScreenButton.button_pressed = true
		ImageDisplayMode.ACTUAL_SIZE:
			%ActualSizeButton.button_pressed = true
		ImageDisplayMode.STRETCH:
			%StretchButton.button_pressed = true
		ImageDisplayMode.TILE:
			%TileButton.button_pressed = true

	# Apply the display mode
	match mode:
		ImageDisplayMode.FIT_TO_SCREEN:
			# Use direct viewer (no scrolling), fit to screen while keeping aspect ratio
			%ImageScrollContainer.visible = false
			%ImageViewerDirect.visible = true
			%ImageViewerDirect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			%ImageViewerDirect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			%ImageViewer.custom_minimum_size = Vector2.ZERO  # Clear zoom size

		ImageDisplayMode.ACTUAL_SIZE:
			# Use scroll container, show at actual size (1:1 pixels) pinned to top-left
			%ImageScrollContainer.visible = true
			%ImageViewerDirect.visible = false
			# Use EXPAND_IGNORE_SIZE so TextureRect respects custom_minimum_size
			# Use STRETCH_SCALE so texture scales to fill the rect
			%ImageViewer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			%ImageViewer.stretch_mode = TextureRect.STRETCH_SCALE
			# Sync texture from direct viewer if needed
			if %ImageViewerDirect.texture != null:
				%ImageViewer.texture = %ImageViewerDirect.texture
			# Reset zoom to 1:1 and set initial size
			_zoomFactor = 1.0
			if _baseSize != Vector2.ZERO:
				%ImageViewer.custom_minimum_size = _baseSize

		ImageDisplayMode.STRETCH:
			# Use direct viewer (no scrolling), stretch to fill the entire area
			%ImageScrollContainer.visible = false
			%ImageViewerDirect.visible = true
			%ImageViewerDirect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			%ImageViewerDirect.stretch_mode = TextureRect.STRETCH_SCALE
			%ImageViewer.custom_minimum_size = Vector2.ZERO  # Clear zoom size

		ImageDisplayMode.TILE:
			# Use direct viewer (no scrolling), tile the image
			%ImageScrollContainer.visible = false
			%ImageViewerDirect.visible = true
			%ImageViewerDirect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			%ImageViewerDirect.stretch_mode = TextureRect.STRETCH_TILE
			%ImageViewer.custom_minimum_size = Vector2.ZERO  # Clear zoom size

func ZoomIn():
	_zoomFactor = min(_zoomFactor * 1.2, 50.0)
	UpdateImageSize()

func ZoomOut():
	_zoomFactor = max(_zoomFactor / 1.2, 0.1)
	UpdateImageSize()
	
var zoom_center: Vector2  # Point to zoom into

func _gui_input(event):
	# Handle middle-mouse panning
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_isPanning = true
				_panStartPos = event.position
				_scrollStartPos = Vector2(%ImageScrollContainer.scroll_horizontal, %ImageScrollContainer.scroll_vertical)
			else:
				_isPanning = false
			accept_event()  # Prevent event propagation
		# Handle Ctrl+wheel for zooming - auto-switch to 1:1 mode if not already
		elif event.ctrl_pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			# If not in 1:1 mode, switch to it first
			if not %ImageScrollContainer.visible:
				ApplyImageDisplayMode(ImageDisplayMode.ACTUAL_SIZE)

			# Now apply zoom
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoomFactor = min(_zoomFactor * 1.2, 10.0)
			else:
				_zoomFactor = max(_zoomFactor / 1.2, 0.1)

			# Update image size based on zoom
			var new_size = _baseSize * _zoomFactor
			%ImageViewer.custom_minimum_size = new_size
			accept_event()  # Prevent normal scrolling when zooming

	elif event is InputEventMouseMotion and _isPanning:
		# Pan by updating scroll container position
		var delta = event.position - _panStartPos
		%ImageScrollContainer.scroll_horizontal = int(_scrollStartPos.x - delta.x)
		%ImageScrollContainer.scroll_vertical = int(_scrollStartPos.y - delta.y)
		accept_event()  # Prevent event propagation

func UpdateImageSizeWithCenter(old_zoom: float):
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

# Toolbar button handlers
func _on_fit_to_screen_button_pressed():
	ApplyImageDisplayMode(ImageDisplayMode.FIT_TO_SCREEN)

func _on_actual_size_button_pressed():
	ApplyImageDisplayMode(ImageDisplayMode.ACTUAL_SIZE)

func _on_stretch_button_pressed():
	ApplyImageDisplayMode(ImageDisplayMode.STRETCH)

func _on_tile_button_pressed():
	ApplyImageDisplayMode(ImageDisplayMode.TILE)
