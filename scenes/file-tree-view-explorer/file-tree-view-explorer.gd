extends Control

# Signals
signal file_selected(filePath: String)
signal directory_selected(dirPath: String)

var _rootItem: TreeItem
var _isProcessingSelection: bool = false
var _isProcessingExpansion: bool = false
var _currentFilePath : String = ""
var zipFileExtensions = [".zip", ".rar", ".7z", ".tar", ".gz"]
var _isNavigating : bool = false
var _currentDirectoryFiles : Array = []
var _currentFileIndex : int = -1

# Add this with your other class variables
var supportedExtensions = [
	# Godot scene files
	".tscn", ".scn", ".res",
	# Scripts
	".gd", ".cs",
	# Images
	".png", ".jpg", ".jpeg", ".bmp", ".svg", ".webp", ".tga", ".exr", ".hdr",
	# Audio
	".ogg", ".mp3", ".wav", ".aac",
	# Video
	".ogv", ".webm",
	# 3D Models
	".dae", ".gltf", ".glb", ".fbx", ".blend", ".obj",
	# Fonts
	".ttf", ".otf", ".woff", ".woff2",
	# Text/Data
	".txt", ".json", ".cfg", ".ini", ".csv", ".md", ".xml",
	# Archives (since you're supporting them)
	".zip", ".rar", ".7z", ".tar", ".gz"
]

func _ready():
	SetupTree()
	PopulateDrives()
	
	# Connect tree signals
	%FileTree.item_collapsed.connect(_on_item_collapsed)
	%FileTree.item_selected.connect(_on_item_selected)

func IsFileSupported(fileName: String) -> bool:
	var extension = "." + fileName.get_extension().to_lower()
	return extension in supportedExtensions

func GetOpenFolderIcon() -> Texture2D:
	return load("res://scenes/file-tree-view-explorer/assets/open-folder.png") as Texture2D
		
func SetupTree():
	# Configure tree properties
	%FileTree.hide_root = true
	%FileTree.allow_reselect = true
	%FileTree.select_mode = Tree.SELECT_SINGLE
		
	# Create root item
	_rootItem = %FileTree.create_item()

func PopulateDrives():
	var drives = GetAvailableDrives()
	
	for drive in drives:
		var driveItem = %FileTree.create_item(_rootItem)
		driveItem.set_text(0, drive)
		driveItem.set_metadata(0, drive)
		driveItem.set_icon(0, GetDriveIcon())
		
		# Populate the root directory of each drive immediately
		PopulateDirectory(driveItem)

func GetAvailableDrives() -> Array[String]:
	var drives: Array[String] = []
	
	# Check for drives A-Z
	for i in range(26):
		var drive_letter = char(65 + i) + ":"
		var dir = DirAccess.open(drive_letter + "/")
		if dir != null:
			drives.append(drive_letter + "/")
	
	return drives

func GetDriveIcon() -> Texture2D:
	return load("res://scenes/file-tree-view-explorer/assets/drive.png") as Texture2D

func GetFolderIcon() -> Texture2D:
	return load("res://scenes/file-tree-view-explorer/assets/folder.png") as Texture2D

func GetFileIcon() -> Texture2D:
	return load("res://scenes/file-tree-view-explorer/assets/file.png") as Texture2D

# Handle when an item is expanded
func _on_item_collapsed(item: TreeItem):
	if _isProcessingExpansion:
		return
	
	_isProcessingExpansion = true
	
	# Update folder icon based on collapsed state
	var metadata = item.get_metadata(0)
	if metadata != null:
		var path = metadata as String
		var isDirectory = IsDirectory(path)
		
		if isDirectory:
			if item.is_collapsed():
				item.set_icon(0, GetFolderIcon())  # Closed folder
			else:
				item.set_icon(0, GetOpenFolderIcon())  # Open folder
	
	# When an item is expanded (collapsed = false), check if we need to populate it
	if not item.is_collapsed():
		if not HasBeenPopulated(item):
			# Defer the population to avoid "blocked" error
			call_deferred("CleanupAndPopulate", item)
	
	_isProcessingExpansion = false

# Check if an item has already been populated with its children
func HasBeenPopulated(item: TreeItem) -> bool:
	# If it has children and the first child has metadata, it's been populated
	var firstChild = item.get_first_child()
	if firstChild and firstChild.get_metadata(0) != null:
		return true
	return false

# Populate a directory item with its contents
func PopulateDirectory(parentItem: TreeItem):
	var path = parentItem.get_metadata(0) as String
	var dir = DirAccess.open(path)
	
	if dir == null:
		print("Failed to open directory: " + path)
		return
	
	var directories: Array[String] = []
	var files: Array[String] = []
	
	print("Scanning directory: " + path)  # Debug line
	
	# Get all directories and files
	dir.list_dir_begin()
	var nextFileName = dir.get_next()
	
	while nextFileName != "":
		print("Found: " + nextFileName + " (is_dir: " + str(dir.current_is_dir()) + ")")  # Debug line
		
		if dir.current_is_dir():
			# Skip hidden and system directories
			if not nextFileName.begins_with(".") and nextFileName != "System Volume Information":
				directories.append(nextFileName)
		else:
			if IsFileSupported(nextFileName):
				files.append(nextFileName)

		nextFileName = dir.get_next()
	
	dir.list_dir_end()
	
	print("Total directories found: " + str(directories.size()))  # Debug line
	print("Total files found: " + str(files.size()))  # Debug line
	
	# Sort directories and files
	directories.sort()
	files.sort()
	
	# Add directories first
	for dirName in directories:
		var dirItem = %FileTree.create_item(parentItem)
		if dirItem == null:
			continue
		dirItem.set_text(0, dirName)
		
		var fullPath = path + dirName + "/"
		dirItem.set_metadata(0, fullPath)
		dirItem.set_icon(0, GetFolderIcon())
		
		# Check if directory has subdirectories or files to make it expandable
		if HasContent(fullPath):
			# Set the item as having children without actually creating them
			# This shows the expand arrow
			dirItem.set_collapsed(true)
			# Create a temporary invisible child to show expand arrow
			var tempChild = %FileTree.create_item(dirItem)
			tempChild.set_text(0, "")
			tempChild.set_metadata(0, null)  # Mark as temporary with null metadata
	
	# Add files
	for fileName in files:
		var fileItem = %FileTree.create_item(parentItem)
		if fileItem == null:
			continue
		fileItem.set_text(0, fileName)
		
		var fullPath = path + fileName
		fileItem.set_metadata(0, fullPath)
		
		# Check if it's a zip file and treat it like a folder
		if IsZipFile(fullPath):
			fileItem.set_icon(0, GetZipIcon())
			
			# Check if zip has contents to make it expandable
			var zipContents = GetZipContents(fullPath)
			if zipContents.size() > 0 and (zipContents.directories.size() > 0 or zipContents.files.size() > 0):
				fileItem.set_collapsed(true)
				# Create a temporary invisible child to show expand arrow
				var tempChild = %FileTree.create_item(fileItem)
				tempChild.set_text(0, "")
				tempChild.set_metadata(0, null)  # Mark as temporary with null metadata
		else:
			fileItem.set_icon(0, GetFileIcon())

func PopulateZipDirectory(parentItem: TreeItem, zipPath: String, subPath: String = ""):
	var zip = OpenZipFile(zipPath)
	if zip == null:
		return
	
	var files = zip.get_files()
	var directories: Array[String] = []
	var zipFiles: Array[String] = []
	
	# Filter files for the current subPath
	var searchPrefix = subPath
	if searchPrefix != "" and not searchPrefix.ends_with("/"):
		searchPrefix += "/"
	
	for file in files:
		if file.begins_with(searchPrefix):
			var relativePath = file.substr(searchPrefix.length())
			
			if "/" in relativePath:
				# It's in a subdirectory
				var dirName = relativePath.split("/")[0]
				if not dirName in directories:
					directories.append(dirName)
			elif not file.ends_with("/"):
				# It's a file in current directory
				zipFiles.append(relativePath)
	
	directories.sort()
	zipFiles.sort()
	
	# Add directories
	for dirName in directories:
		var dirItem = %FileTree.create_item(parentItem)
		if dirItem == null:
			continue
		dirItem.set_text(0, dirName)
		
		# Store zip path + internal path as metadata
		var internalPath = searchPrefix + dirName
		dirItem.set_metadata(0, zipPath + "::" + internalPath)
		dirItem.set_icon(0, GetFolderIcon())
		
		# Check if this directory has contents
		var hasContents = false
		for file in files:
			if file.begins_with(internalPath + "/"):
				hasContents = true
				break
		
		if hasContents:
			dirItem.set_collapsed(true)
			var tempChild = %FileTree.create_item(dirItem)
			tempChild.set_text(0, "")
			tempChild.set_metadata(0, null)
	
	# Add files
	for fileName in zipFiles:
		var fileItem = %FileTree.create_item(parentItem)
		if fileItem == null:
			continue
		fileItem.set_text(0, fileName)
		
		# Store zip path + internal path as metadata
		var internalPath = searchPrefix + fileName
		fileItem.set_metadata(0, zipPath + "::" + internalPath)
		fileItem.set_icon(0, GetFileIcon())
	
	zip.close()
	
func HasContent(path: String) -> bool:
	"""Check if a directory has any content (subdirectories or supported files)"""
	var dir = DirAccess.open(path)
	if dir == null:
		return false
	
	dir.list_dir_begin()
	var nextFileName = dir.get_next()
	
	while nextFileName != "":
		# Return true if we find any directory (not hidden/system) or any supported file
		if dir.current_is_dir():
			if not nextFileName.begins_with(".") and nextFileName != "System Volume Information":
				dir.list_dir_end()
				return true
		else:
			# Found a file - check if it's supported
			if IsFileSupported(nextFileName):
				dir.list_dir_end()
				return true
		nextFileName = dir.get_next()
	
	dir.list_dir_end()
	return false

# Handle when an item is selected
func _on_item_selected():
	# Prevent recursive calls
	if _isProcessingSelection:
		return
	
	_isProcessingSelection = true
	
	var selected = %FileTree.get_selected()
	if selected:
		if selected.get_metadata(0) == null:
			_isProcessingSelection = false
			return
			
		_currentFilePath = selected.get_metadata(0) as String
		
		# Rebuild file list for navigation (but not when we're already navigating)
		if not _isNavigating:
			BuildCurrentDirectoryFileList()
		
		# Just emit the selection signal
		SelectedPathChanged(_currentFilePath)
	
	_isProcessingSelection = false

# Called when the selected path changes
func SelectedPathChanged(path: String):
	# Check if it's inside a zip file
	if "::" in path:
		var parts = path.split("::")
		var zipPath = parts[0]
		var internalPath = parts[1]
		file_selected.emit(path)  # Emit the full path including zip reference
	elif IsZipFile(path):
		directory_selected.emit(path)  # Treat zip files as directories
	else:
		# Check if it's a file or directory
		var dir = DirAccess.open(path)
		if dir != null:
			directory_selected.emit(path)
		else:
			file_selected.emit(path)

func GetSelectedPath() -> String:
	"""Get the currently selected path"""
	var selected = %FileTree.get_selected()
	if selected:
		return selected.get_metadata(0) as String
	return ""

# Clean up temporary children and populate with real content when expanding
func CleanupAndPopulate(item: TreeItem):
	# Remove any temporary children (those with null metadata)
	var child = item.get_first_child()
	var childrenToRemove = []
	
	while child:
		if child.get_metadata(0) == null:
			childrenToRemove.append(child)
		child = child.get_next()
	
	# Remove temporary children
	for childToRemove in childrenToRemove:
		childToRemove.free()
	
	# Check if this is a zip file or zip subdirectory
	var path = item.get_metadata(0) as String
	if "::" in path:
		# It's inside a zip file
		var parts = path.split("::")
		var zipPath = parts[0]
		var internalPath = parts[1] if parts.size() > 1 else ""
		print("CleanupAndPopulate zip: " + zipPath + " internal: " + internalPath)
		PopulateZipDirectory(item, zipPath, internalPath)
	elif IsZipFile(path):
		# It's a zip file itself
		print("CleanupAndPopulate zip file: " + path)
		PopulateZipDirectory(item, path)
	else:
		# Regular directory
		print("CleanupAndPopulate directory: " + path)
		PopulateDirectory(item)

# Override the collapse handling to properly manage lazy loading

# Expand the tree to show a specific path
func ExpandToPath(targetPath: String):
	var parts = targetPath.split("/")
	var currentItem = _rootItem
	var currentPath = ""
	
	for part in parts:
		if part == "":
			continue
			
		currentPath += part + "/"
		
		# Find the child item with this path
		var child = currentItem.get_first_child()
		while child:
			if child.get_metadata(0) == currentPath:
				# Expand this item if it's not already
				if child.is_collapsed():
					child.set_collapsed(false)
					if not HasBeenPopulated(child):
						CleanupAndPopulate(child)
				currentItem = child
				break
			child = child.get_next()

func IsZipFile(filePath: String) -> bool:
	"""Check if a file is a zip archive"""
	var extension = filePath.get_extension().to_lower()
	return ("." + extension) in zipFileExtensions

func OpenZipFile(zipPath: String) -> ZIPReader:
	"""Open a zip file and return a ZIPReader"""
	var zip = ZIPReader.new()
	var error = zip.open(zipPath)
	if error != OK:
		print("Failed to open zip file: " + zipPath)
		return null
	return zip

func GetZipContents(zipPath: String) -> Dictionary:
	"""Get contents of zip file organized by directories and files"""
	var zip = OpenZipFile(zipPath)
	if zip == null:
		return {}
	
	var contents = {"directories": [], "files": []}
	var files = zip.get_files()
	var directories = {}
	
	for file in files:
		if file.ends_with("/"):
			# It's a directory
			var dirName = file.trim_suffix("/")
			if not "/" in dirName:  # Root level directory
				contents.directories.append(dirName)
		else:
			# It's a file
			if not "/" in file:  # Root level file
				contents.files.append(file)
			else:
				# File in subdirectory - track the directory
				var dirName = file.split("/")[0]
				directories[dirName] = true
	
	# Add directories that contain files but weren't explicitly listed
	for dir in directories.keys():
		if not dir in contents.directories:
			contents.directories.append(dir)
	
	zip.close()
	return contents

func GetZipIcon() -> Texture2D:
	return load("res://scenes/file-tree-view-explorer/assets/zip.png") as Texture2D
	
func OpenCurrentFilePathInWindowsExplorer():
	FileHelper.OpenFilePathInWindowsExplorer(_currentFilePath)

func BuildCurrentDirectoryFileList():
	"""Build a list of all visible supported files in the tree"""
	_currentDirectoryFiles.clear()
	
	var selected = %FileTree.get_selected()
	if not selected:
		_currentFileIndex = -1
		return
	
	# Build list of all visible files in the tree
	BuildVisibleFileList(_rootItem)
	_currentDirectoryFiles.sort()
	
	# Find current file index
	var selectedPath = selected.get_metadata(0) as String
	_currentFileIndex = _currentDirectoryFiles.find(selectedPath)

func BuildVisibleFileList(parentItem: TreeItem):
	"""Recursively build list of all visible files in the tree"""
	var child = parentItem.get_first_child()
	while child:
		var metadata = child.get_metadata(0)
		if metadata != null:
			var childPath = metadata as String
			
			# Check if it's a file (not a directory)
			if not IsDirectory(childPath):
				_currentDirectoryFiles.append(childPath)
			
			# If the item is expanded, check its children
			if not child.is_collapsed():
				BuildVisibleFileList(child)
		
		child = child.get_next()

func IsDirectory(path: String) -> bool:
	"""Check if a path is a directory"""
	if "::" in path:
		# For zip files, we need to check if it's a directory path
		return false  # For now, assume zip entries are files
	else:
		var dir = DirAccess.open(path)
		return dir != null

func BuildZipDirectoryFileList(zipPath: String, internalDir: String):
	"""Build file list for files inside a zip directory"""
	var zip = ZIPReader.new()
	var error = zip.open(zipPath)
	if error != OK:
		_currentDirectoryFiles.clear()
		_currentFileIndex = -1
		return
	
	var files = zip.get_files()
	_currentDirectoryFiles.clear()
	
	var searchPrefix = internalDir
	if searchPrefix != "" and not searchPrefix.ends_with("/"):
		searchPrefix += "/"
	
	for file in files:
		if file.begins_with(searchPrefix) and not file.ends_with("/"):
			var relativePath = file.substr(searchPrefix.length())
			# Only files in this directory (not subdirectories)
			if not "/" in relativePath:
				var fileName = relativePath.get_file()
				if IsFileSupported(fileName):
					_currentDirectoryFiles.append(zipPath + "::" + file)
	
	zip.close()
	_currentDirectoryFiles.sort()
	
	# Find current file index
	var selected = %FileTree.get_selected()
	if selected:
		var selectedPath = selected.get_metadata(0) as String
		_currentFileIndex = _currentDirectoryFiles.find(selectedPath)

func NavigateToNextFile():
	"""Navigate to the next supported file in the current directory"""
	if _currentDirectoryFiles.is_empty():
		BuildCurrentDirectoryFileList()
	
	if _currentDirectoryFiles.is_empty():
		print("No supported files in current directory")
		return
	
	_currentFileIndex += 1
	if _currentFileIndex >= _currentDirectoryFiles.size():
		_currentFileIndex = 0  # Wrap to beginning
	
	NavigateToFileAtIndex(_currentFileIndex)

func NavigateToPreviousFile():
	"""Navigate to the previous supported file in the current directory"""
	if _currentDirectoryFiles.is_empty():
		BuildCurrentDirectoryFileList()
	
	if _currentDirectoryFiles.is_empty():
		print("No supported files in current directory")
		return
	
	_currentFileIndex -= 1
	if _currentFileIndex < 0:
		_currentFileIndex = _currentDirectoryFiles.size() - 1  # Wrap to end
	
	NavigateToFileAtIndex(_currentFileIndex)

func NavigateToFileAtIndex(index: int):
	"""Navigate to a specific file by index"""
	if index < 0 or index >= _currentDirectoryFiles.size():
		return
	
	var targetPath = _currentDirectoryFiles[index]
	_isNavigating = true
	
	# Ensure the path to the target file is expanded
	ExpandPathToFile(targetPath)
	
	# Find and select the tree item
	SelectTreeItemByPath(targetPath)
	
	_isNavigating = false

func ExpandPathToFile(filePath: String):
	"""Expand the tree path to make a file visible"""
	if "::" in filePath:
		# Handle zip file paths
		var parts = filePath.split("::")
		var zipPath = parts[0]
		var internalPath = parts[1]
		
		# First expand to the zip file
		ExpandToPath(zipPath)
		
		# Then expand within the zip if needed
		var dirs = internalPath.get_base_dir().split("/")
		var currentZipPath = zipPath
		for dir in dirs:
			if dir != "":
				currentZipPath += "::" + dir
				# Find and expand this zip directory item
				var item = FindTreeItemByPath(_rootItem, currentZipPath)
				if item and item.is_collapsed():
					item.set_collapsed(false)
					if not HasBeenPopulated(item):
						CleanupAndPopulate(item)
	else:
		# Regular file path
		var dirPath = filePath.get_base_dir()
		ExpandToPath(dirPath)

func SelectTreeItemByPath(targetPath: String):
	"""Find and select a tree item by its path"""
	var item = FindTreeItemByPath(_rootItem, targetPath)
	if item:
		%FileTree.set_selected(item, 0)
		item.select(0)
		# Ensure the item is visible
		%FileTree.scroll_to_item(item)

# Recursively find a tree item by its path
func FindTreeItemByPath(parentItem: TreeItem, targetPath: String) -> TreeItem:
	"""Recursively find a tree item by its path"""
	var child = parentItem.get_first_child()
	while child:
		var metadata = child.get_metadata(0)
		if metadata != null:
			var childPath = metadata as String
			if childPath == targetPath:
				return child
		
		# Check children recursively
		var found = FindTreeItemByPath(child, targetPath)
		if found:
			return found
		
		child = child.get_next()
	
	return null
	
func _on_open_file_explorer_button_pressed() -> void:
	OpenCurrentFilePathInWindowsExplorer()

func _on_previous_button_pressed() -> void:
	SendKeyEventToTree(KEY_LEFT)

func _on_next_button_pressed() -> void:
	SendKeyEventToTree(KEY_RIGHT)

func SendKeyEventToTree(keycode: Key):
	"""Send a key event to the Tree control via the input system"""
	# Make sure the tree has focus
	%FileTree.grab_focus()
	
	# Create and inject the key event
	var event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	
	# Send press event
	Input.parse_input_event(event)
	
	# Send release event
	var release_event = InputEventKey.new()
	release_event.keycode = keycode
	release_event.pressed = false
	Input.parse_input_event(release_event)

func _on_up_button_pressed() -> void:
	SendKeyEventToTree(KEY_UP)

func _on_down_button_pressed() -> void:
	SendKeyEventToTree(KEY_DOWN)
