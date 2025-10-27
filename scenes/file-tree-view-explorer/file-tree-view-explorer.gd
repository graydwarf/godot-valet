extends Control

# File Tree View Explorer
# - Generated with assistance from Claude 4 Sonnet (Anthropic) - December 2024

# Signals
signal FileSelected(filePath : String)
signal DirectorySelected(dirPath : String)

var _rootItem: TreeItem
var _isProcessingSelection := false
var _isProcessingExpansion := false
var _currentFilePath := ""
var _isNavigating := false
var _currentDirectoryFiles := []
var _currentFileIndex := -1
var _allSupportedFiles := []
var _activeFilters := []
var _cachedFileList := []
var _treeViewFilters := []
var _isTreeViewFiltered := false
var _flatListBasePath: String = ""

# Supported extensions used to filter files
var _zipExtensions := [".zip", ".rar", ".7z", ".tar", ".gz"]
var _imageExtensions := [".png", ".jpg", ".jpeg", ".bmp", ".svg", ".webp", ".tga", ".exr", ".hdr"]
var _scriptExtensions := [".gd", ".cs"]
var _audioExtensions := [".ogg", ".mp3", ".wav", ".aac"]
var _sceneExtensions := [".tscn", ".scn", ".res"]
var _videoExtensions := [".ogv", ".webm", ".mp4", ".mov", ".avi", ".mkv", ".wmv", ".flv", ".m4v"]
var _3dModelExtensions := [".dae", ".gltf", ".glb", ".fbx", ".blend", ".obj"]
var _fontExtensions := [".ttf", ".otf", ".woff", ".woff2"]
var _textExtensions := [".txt", ".json", ".cfg", ".ini", ".csv", ".md", ".xml"]

# Import vars
var _filesToImport: Array[String] = []
var _importStep: int = 1  # 1 = select files, 2 = choose destination

func _ready():
	SetupTree()
	PopulateDrives()
	InitSignals()

func InitSignals():
	%FileTree.item_collapsed.connect(_on_item_collapsed)

func GetSelectedFiles() -> Array[String]:
	var selected: Array[String] = []
	
	# Get all selected items from the tree
	var selectedItems = GetAllSelectedItems()
	
	for item in selectedItems:
		if item.get_metadata(0) != null:
			var path = item.get_metadata(0) as String
			# Only include files, not directories
			if not path.is_empty() and not IsDirectory(path):
				selected.append(path)
	
	return selected

# Get all currently selected tree items
func GetAllSelectedItems() -> Array[TreeItem]:
	var items: Array[TreeItem] = []
	var root = %FileTree.get_root()
	
	if root:
		CollectSelectedItems(root, items)
	
	return items

# Recursively collect all selected items
func CollectSelectedItems(item: TreeItem, items: Array[TreeItem]):
	if item.is_selected(0):
		items.append(item)
	
	# Check children
	var child = item.get_first_child()
	while child:
		CollectSelectedItems(child, items)
		child = child.get_next()
		
# Select and highlight the first visible node in the tree
func SelectFirstNode():
	var firstChild = _rootItem.get_first_child()
	if firstChild:
		%FileTree.set_selected(firstChild, 0)
		firstChild.select(0)
		%FileTree.scroll_to_item(firstChild)
		
func IsFileSupported(fileName: String) -> bool:
	var extension = "." + fileName.get_extension().to_lower()
	
	# If tree view filtering is active, only show filtered extensions
	if _isTreeViewFiltered and not %FlatListToggleButton.button_pressed:
		return extension in _treeViewFilters
	
	# Otherwise use the full supported list
	return extension in GetAllSupportedExtensions()

func GetAllSupportedExtensions():
	var allExtensions := []
	allExtensions.append_array(_zipExtensions)
	allExtensions.append_array(_imageExtensions)
	allExtensions.append_array(_scriptExtensions)
	allExtensions.append_array(_audioExtensions)
	allExtensions.append_array(_sceneExtensions)
	allExtensions.append_array(_videoExtensions)
	allExtensions.append_array(_3dModelExtensions)
	allExtensions.append_array(_fontExtensions)
	allExtensions.append_array(_textExtensions)
	return allExtensions

func GetOpenFolderIcon() -> Texture2D:
	return load("res://scenes/file-tree-view-explorer/assets/open-folder.png") as Texture2D
		
func SetupTree():
	_rootItem = %FileTree.create_item()

func PopulateDrives():
	await ProcessWithBusyIndicator(func():
		PopulateDrivesInternal()
	)

# Internal function that does the actual drive population
func PopulateDrivesInternal():
	var drives = GetAvailableDrives()
	
	for drive in drives:
		var driveItem = %FileTree.create_item(_rootItem)
		driveItem.set_text(0, drive)
		driveItem.set_metadata(0, drive)
		driveItem.set_icon(0, GetDriveIcon())
		PopulateDirectory(driveItem)
	
	# Select the first drive
	SelectFirstNode()
	
# Find and add all drives A-Z
func GetAvailableDrives() -> Array[String]:
	var drives: Array[String] = []
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

func GetImageIcon() -> Texture2D:
	return load("res://scenes/file-tree-view-explorer/assets/image-file.png") as Texture2D

func GetZipIcon() -> Texture2D:
	return load("res://scenes/file-tree-view-explorer/assets/zip.png") as Texture2D
	
func GetScriptIcon() -> Texture2D:
	return load("res://scenes/file-tree-view-explorer/assets/file.png") as Texture2D

func GetAudioIcon() -> Texture2D:
	return load("res://scenes/file-tree-view-explorer/assets/file.png") as Texture2D
	
func GetSceneIcon() -> Texture2D:
	return load("res://scenes/file-tree-view-explorer/assets/file.png") as Texture2D
	
func GetVideoIcon() -> Texture2D:
	return load("res://scenes/file-tree-view-explorer/assets/file.png") as Texture2D
	
func Get3DModelIcon() -> Texture2D:
	return load("res://scenes/file-tree-view-explorer/assets/file.png") as Texture2D
	
func GetFontIcon() -> Texture2D:
	return load("res://scenes/file-tree-view-explorer/assets/file.png") as Texture2D

func GetTextIcon() -> Texture2D:
	return load("res://scenes/file-tree-view-explorer/assets/file.png") as Texture2D
		
func GetIconFromFilePath(filePath):
	var extension = "." + filePath.get_extension().to_lower()
	if extension in _imageExtensions:
		return GetImageIcon()
	elif extension in _zipExtensions:
		return GetZipIcon()
	elif extension in _scriptExtensions:
		return GetScriptIcon()
	elif extension in _audioExtensions:
		return GetAudioIcon()
	elif extension in _sceneExtensions:
		return GetSceneIcon()	
	elif extension in _videoExtensions:
		return GetVideoIcon()
	elif extension in _3dModelExtensions:
		return Get3DModelIcon()
	elif extension in _fontExtensions:
		return GetFontIcon()
	elif extension in _textExtensions:
		return GetTextIcon()
	
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
	ShowBusyIndicator()
	var path = parentItem.get_metadata(0) as String
	var dir = DirAccess.open(path)
	
	if dir == null:
		print("Failed to open directory: " + path)
		return
	
	var directories: Array[String] = []
	var files: Array[String] = []
	
	# Get all directories and files
	dir.list_dir_begin()
	var nextFileName = dir.get_next()
	while nextFileName != "":
		if dir.current_is_dir():
			# Skip hidden and system directories
			if not nextFileName.begins_with(".") and nextFileName != "System Volume Information":
				directories.append(nextFileName)
		else:
			# Always include zip files, filter other files normally
			if IsZipFile(path + nextFileName) or IsFileSupported(nextFileName):
				files.append(nextFileName)

		nextFileName = dir.get_next()
	
	dir.list_dir_end()
	
	# Sort directories and files
	directories.sort()
	files.sort()
	
	# Add directories first - but only if they have content
	for dirName in directories:
		var fullPath = path + dirName + "/"
		
		# Check if directory has content (respects filtering)
		if HasContent(fullPath):
			var dirItem = %FileTree.create_item(parentItem)
			if dirItem == null:
				continue
			dirItem.set_text(0, dirName)
			dirItem.set_metadata(0, fullPath)
			dirItem.set_icon(0, GetFolderIcon())
			
			# Set as expandable
			dirItem.set_collapsed(true)
			# Create a temporary invisible child to show expand arrow
			var tempChild = %FileTree.create_item(dirItem)
			tempChild.set_text(0, "")
			tempChild.set_metadata(0, null)  # Mark as temporary with null metadata
	
	# Add files
	for fileName in files:
		var fullPath = path + fileName
		var shouldInclude = true
		
		# For zip files, check if they contain filtered content when filtering is active
		if IsZipFile(fullPath):
			if _isTreeViewFiltered:
				shouldInclude = ZipContainsFilteredContent(fullPath)
		else:
			# For regular files, they've already passed IsFileSupported()
			shouldInclude = true
		
		if shouldInclude:
			var fileItem = %FileTree.create_item(parentItem)
			if fileItem == null:
				continue
			fileItem.set_text(0, fileName)
			fileItem.set_metadata(0, fullPath)
			fileItem.set_icon(0, GetIconFromFilePath(fullPath))
			
			# Make zip files expandable if they have contents
			if IsZipFile(fullPath):
				var zipContents = GetZipContents(fullPath)
				if zipContents.size() > 0 and (zipContents.directories.size() > 0 or zipContents.files.size() > 0):
					fileItem.set_collapsed(true)
					var tempChild = %FileTree.create_item(fileItem)
					tempChild.set_text(0, "")
					tempChild.set_metadata(0, null)
	HideBusyIndicator()
	
# Check if a zip file contains content matching current filters
func ZipContainsFilteredContent(zipPath: String) -> bool:
	var zip = OpenZipFile(zipPath)
	if zip == null:
		return false
	
	var files = zip.get_files()
	for file in files:
		if not file.ends_with("/"):
			var fileName = file.get_file()
			var extension = "." + fileName.get_extension().to_lower()
			# Check if file extension matches current filters
			if extension in _treeViewFilters:
				zip.close()
				return true
	
	zip.close()
	return false
	
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
				# It's a file in current directory - check if supported (respects filters)
				if IsFileSupported(relativePath):
					zipFiles.append(relativePath)
	
	directories.sort()
	zipFiles.sort()
	
	# Add directories - but only if they have filtered content
	for dirName in directories:
		var internalPath = searchPrefix + dirName
		
		# Check if directory has filtered content
		var hasValidContent = true
		if _isTreeViewFiltered and not %FlatListToggleButton.button_pressed:
			hasValidContent = HasZipFilteredContent(zipPath, internalPath)
		
		if hasValidContent:
			var dirItem = %FileTree.create_item(parentItem)
			if dirItem == null:
				continue
			dirItem.set_text(0, dirName)
			dirItem.set_metadata(0, zipPath + "::" + internalPath)
			dirItem.set_icon(0, GetFolderIcon())
			
			# Check if this directory has contents for expandability
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
	
	# Add files (unchanged)
	for fileName in zipFiles:
		var fileItem = %FileTree.create_item(parentItem)
		if fileItem == null:
			continue
		fileItem.set_text(0, fileName)
		
		var internalPath = searchPrefix + fileName
		fileItem.set_metadata(0, zipPath + "::" + internalPath)
		fileItem.set_icon(0, GetIconFromFilePath(internalPath))

	zip.close()

# Handle when an item is selected
func ItemSelected(selected):
	# Prevent recursive calls
	if _isProcessingSelection:
		return
	
	_isProcessingSelection = true
	
	#var selected = %FileTree.get_selected()
	if selected:
		if selected.get_metadata(0) == null:
			_isProcessingSelection = false
			return
			
		_currentFilePath = selected.get_metadata(0) as String
		
		# Rebuild file list for navigation (but not when we're already navigating)
		if not _isNavigating:
			#BuildCurrentDirectoryFileList(selected)
			pass
		
		# Just emit the selection signal
		SelectedPathChanged(_currentFilePath)
	
	_isProcessingSelection = false

# Called when the selected path changes
func SelectedPathChanged(path: String):
	# Check if it's inside a zip file
	if "::" in path:
		FileSelected.emit(path)  # Emit the full path including zip reference
	elif IsZipFile(path):
		DirectorySelected.emit(path)  # Treat zip files as directories
	else:
		# Check if it's a file or directory
		var dir = DirAccess.open(path)
		if dir != null:
			DirectorySelected.emit(path)
		else:
			FileSelected.emit(path)

# Get the currently selected path
func GetSelectedPath() -> String:
	var selected = %FileTree.get_selected()
	if selected:
		return selected.get_metadata(0) as String
	return ""

# Clean up temporary children and populate with real content when expanding
func CleanupAndPopulate(item: TreeItem):
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
		PopulateZipDirectory(item, zipPath, internalPath)
	elif IsZipFile(path):
		# It's a zip file itself
		PopulateZipDirectory(item, path)
	else:
		# Regular directory
		PopulateDirectory(item)

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

# Check if a file is a zip archive
func IsZipFile(filePath: String) -> bool:
	var extension = filePath.get_extension().to_lower()
	return ("." + extension) in _zipExtensions

func IsImageFile(filePath : String) -> bool:
	var extension = filePath.get_extension().to_lower()
	return ("." + extension) in _imageExtensions

# Open a zip file and return a ZIPReader
func OpenZipFile(zipPath: String) -> ZIPReader:
	var zip = ZIPReader.new()
	var error = zip.open(zipPath)
	if error != OK:
		return null
		
	return zip

# Get contents of zip file organized by directories and files
func GetZipContents(zipPath: String) -> Dictionary:
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
	
func OpenCurrentFilePathInWindowsExplorer():
	FileHelper.OpenFilePathInWindowsExplorer(_currentFilePath)

# Build a list of all visible supported files in the tree
func BuildCurrentDirectoryFileList(selected : TreeItem = null):
	_currentDirectoryFiles.clear()
	
	if selected == null:
		selected = %FileTree.get_selected()
		
	if not selected:
		_currentFileIndex = -1
		return
	
	# Build list of all visible files in the tree
	BuildVisibleFileList(_rootItem)
	_currentDirectoryFiles.sort()
	
	# Find current file index
	var selectedPath = selected.get_metadata(0) as String
	_currentFileIndex = _currentDirectoryFiles.find(selectedPath)

# Recursively build list of all visible files in the tree
func BuildVisibleFileList(parentItem: TreeItem):
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

# Check if a path is a directory
func IsDirectory(path: String) -> bool:
	if "::" in path:
		# For zip files, check if it's a directory path inside the zip
		var parts = path.split("::")
		var zipPath = parts[0]
		var internalPath = parts[1]
		return IsZipDirectory(zipPath, internalPath)
	else:
		var dir = DirAccess.open(path)
		return dir != null

# Build file list for files inside a zip directory
func BuildZipDirectoryFileList(zipPath: String, internalDir: String):
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

# Navigate to the next supported file in the current directory
func NavigateToNextFile():
	if _currentDirectoryFiles.is_empty():
		BuildCurrentDirectoryFileList()
	
	if _currentDirectoryFiles.is_empty():
		return
	
	_currentFileIndex += 1
	if _currentFileIndex >= _currentDirectoryFiles.size():
		_currentFileIndex = 0  # Wrap to beginning
	
	NavigateToFileAtIndex(_currentFileIndex)

# Navigate to the previous supported file in the current directory
func NavigateToPreviousFile():
	if _currentDirectoryFiles.is_empty():
		BuildCurrentDirectoryFileList()
	
	if _currentDirectoryFiles.is_empty():
		return
	
	_currentFileIndex -= 1
	if _currentFileIndex < 0:
		_currentFileIndex = _currentDirectoryFiles.size() - 1  # Wrap to end
	
	NavigateToFileAtIndex(_currentFileIndex)

# Navigate to a specific file by index
func NavigateToFileAtIndex(index: int):
	if index < 0 or index >= _currentDirectoryFiles.size():
		return
	
	var targetPath = _currentDirectoryFiles[index]
	_isNavigating = true
	
	# Ensure the path to the target file is expanded
	ExpandPathToFile(targetPath)
	
	# Find and select the tree item
	SelectTreeItemByPath(targetPath)
	
	_isNavigating = false

# Expand the tree path to make a file visible
func ExpandPathToFile(filePath: String):
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

# Find and select a tree item by its path
func SelectTreeItemByPath(targetPath: String):
	var item = FindTreeItemByPath(_rootItem, targetPath)
	if item:
		%FileTree.set_selected(item, 0)
		item.select(0)
		# Ensure the item is visible
		%FileTree.scroll_to_item(item)

# Recursively find a tree item by its path
func FindTreeItemByPath(parentItem: TreeItem, targetPath: String) -> TreeItem:
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

# Send a key event to the Tree control via the input system
func SendKeyEventToTree(keycode: Key):
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

func ToggleFlatList():
	ShowBusyIndicator()
	await get_tree().create_timer(0.2).timeout
	
	if %FlatListToggleButton.button_pressed:
		%PreviousButton.disabled = true
		%NextButton.disabled = true
		ShowFlatListForCurrentSelection()
	else:
		_flatListBasePath = ""
		%PreviousButton.disabled = false
		%NextButton.disabled = false
		ShowTreeView()

# Internal function for flat list creation
func _show_flat_list_internal():
	var basePath = GetCurrentBasePath()
	if basePath.is_empty():
		ShowFlatList()
		return
	
	# Clear the tree
	%FileTree.clear()
	_rootItem = %FileTree.create_item()
	
	# Build list of supported files in selected path
	_allSupportedFiles.clear()
	
	if "::" in basePath:
		var parts = basePath.split("::")
		var zipPath = parts[0]
		var internalPath = parts[1] if parts.size() > 1 else ""
		ScanZipDirectoryRecursively(zipPath, internalPath)
	else:
		ScanDirectoryRecursively(basePath)
	
	_allSupportedFiles.sort()
	
	# Cache the full list for filtering
	_cachedFileList = _allSupportedFiles.duplicate()
	
	# Populate the tree with flat list
	PopulateFlatList()
	
# Get the base path for scanning based on current selection
func GetCurrentBasePath() -> String:
	var selected = %FileTree.get_selected()
	if not selected or selected.get_metadata(0) == null:
		# Nothing selected, default to first drive
		var drives = GetAvailableDrives()
		return drives[0] if drives.size() > 0 else ""
	
	var selectedPath = selected.get_metadata(0) as String
	
	# Check if selected item is a directory
	if "::" in selectedPath:
		# Inside zip file
		var parts = selectedPath.split("::")
		var zipPath = parts[0]
		var internalPath = parts[1]
		
		# Check if it's a directory inside the zip
		if IsZipDirectory(zipPath, internalPath):
			return selectedPath  # Use the zip directory path
		else:
			# It's a file, use its parent directory
			var parentPath = internalPath.get_base_dir()
			return zipPath + "::" + parentPath
	else:
		# Regular file system
		var dir = DirAccess.open(selectedPath)
		if dir != null:
			# It's a directory
			return selectedPath
		else:
			# It's a file, use its parent directory
			return selectedPath.get_base_dir() + "/"

# Check if a path inside a zip is a directory
func IsZipDirectory(zipPath: String, internalPath: String) -> bool:
	var zip = ZIPReader.new()
	var error = zip.open(zipPath)
	if error != OK:
		return false
	
	var files = zip.get_files()
	var targetPath = internalPath
	if not targetPath.ends_with("/"):
		targetPath += "/"
	
	# Check if this path exists as a directory in the zip
	for file in files:
		if file == targetPath or file.begins_with(targetPath):
			zip.close()
			return true
	
	zip.close()
	return false

# Recursively scan a zip directory for supported files
func ScanZipDirectoryRecursively(zipPath: String, basePath: String = ""):
	var zip = ZIPReader.new()
	var error = zip.open(zipPath)
	if error != OK:
		return
	
	var files = zip.get_files()
	var searchPrefix = basePath
	if searchPrefix != "" and not searchPrefix.ends_with("/"):
		searchPrefix += "/"
	
	for file in files:
		if file.begins_with(searchPrefix) and not file.ends_with("/"):
			var fileName = file.get_file()
			if IsFileSupported(fileName):
				var fullPath = zipPath + "::" + file
				_allSupportedFiles.append(fullPath)
	
	zip.close()

# Populate the tree with the flat list of files
func PopulateFlatList():
	for filePath in _allSupportedFiles:
		# Skip zip files in flat list view
		if IsZipFile(filePath):
			continue
			
		var fileItem = %FileTree.create_item(_rootItem)
		if fileItem == null:
			continue
		
		var displayName = GetDisplayNameForFlatList(filePath)
		fileItem.set_text(0, displayName)
		fileItem.set_metadata(0, filePath)
		
		# Use proper icon based on file type
		fileItem.set_icon(0, GetIconFromFilePath(filePath))
		fileItem.set_tooltip_text(0, filePath)

# Count all visible files in the tree
func CountAllVisibleFiles(parentItem: TreeItem) -> int:
	var count = 0
	var child = parentItem.get_first_child()
	
	while child:
		if child.get_metadata(0) != null:
			var childPath = child.get_metadata(0) as String
			if not IsDirectory(childPath):
				count += 1
			else:
				# If directory is expanded, count its children too
				if not child.is_collapsed():
					count += CountAllVisibleFiles(child)
		child = child.get_next()
	
	return count

# Get display name for flat list items
func GetDisplayNameForFlatList(filePath: String) -> String:
	if "::" in filePath:
		# Zip file - show internal path
		var parts = filePath.split("::")
		return parts[1]
	else:
		# Regular file - show relative path or just filename
		return filePath.get_file()  # Just filename
		# return filePath  # Full path if you prefer
	
# Return to normal tree view
func ShowTreeView():
	%FileTree.clear()
	_rootItem = %FileTree.create_item()
	
	# Check if we need to reapply filters
	if not _activeFilters.is_empty():
		# Preserve filter state and reapply
		_isTreeViewFiltered = true
		var combinedExtensions := []
		for filterName in _activeFilters:
			match filterName:
				"images":
					combinedExtensions.append_array(_imageExtensions)
				"scripts":
					combinedExtensions.append_array(_scriptExtensions)
				"audio":
					combinedExtensions.append_array(_audioExtensions)
				"scenes":
					combinedExtensions.append_array(_sceneExtensions)
				"videos":
					combinedExtensions.append_array(_videoExtensions)
		_treeViewFilters = combinedExtensions
	else:
		_isTreeViewFiltered = false
		_treeViewFilters.clear()
	
	PopulateDrives()
	
# Show all supported files in a flat list
func ShowFlatList():
	# Clear the tree
	%FileTree.clear()
	_rootItem = %FileTree.create_item()
	
	# Build list of all supported files
	_allSupportedFiles.clear()
	var drives = GetAvailableDrives()
	
	for drive in drives:
		ScanDirectoryRecursively(drive)
	
	# Sort the files
	_allSupportedFiles.sort()
	
	# Cache the full list
	_cachedFileList = _allSupportedFiles.duplicate()
	
	# Apply active filters if any
	if not _activeFilters.is_empty():
		var combinedExtensions := []
		for filterName in _activeFilters:
			match filterName:
				"images":
					combinedExtensions.append_array(_imageExtensions)
				"scripts":
					combinedExtensions.append_array(_scriptExtensions)
				"audio":
					combinedExtensions.append_array(_audioExtensions)
				"scenes":
					combinedExtensions.append_array(_sceneExtensions)
				"videos":
					combinedExtensions.append_array(_videoExtensions)
		
		# Filter the list
		var filteredFiles := []
		for filePath in _allSupportedFiles:
			var extension = "." + filePath.get_extension().to_lower()
			if extension in combinedExtensions:
				filteredFiles.append(filePath)
		
		_allSupportedFiles = filteredFiles
	
	# Populate the tree with (possibly filtered) flat list
	PopulateFlatList()

# Recursively scan directory for all supported files
func ScanDirectoryRecursively(dirPath: String):
	var dir = DirAccess.open(dirPath)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var fileName = dir.get_next()
	
	while fileName != "":
		if dir.current_is_dir():
			if not fileName.begins_with(".") and fileName != "System Volume Information":
				var subDirPath = dirPath + fileName + "/"
				ScanDirectoryRecursively(subDirPath)
		else:
			if IsFileSupported(fileName):
				var fullPath = dirPath + fileName
				
				# Handle zip files specially - scan their contents
				if IsZipFile(fullPath):
					ScanZipFileRecursively(fullPath)
				else:
					_allSupportedFiles.append(fullPath)
		
		fileName = dir.get_next()
	
	dir.list_dir_end()

# Update ScanZipFileRecursively to respect filters
func ScanZipFileRecursively(zipPath: String):
	var zip = ZIPReader.new()
	var error = zip.open(zipPath)
	if error != OK:
		return
	
	var files = zip.get_files()
	for file in files:
		if not file.ends_with("/"):  # It's a file, not a directory
			var fileName = file.get_file()
			# Check if file is supported (this will respect active filters)
			if IsFileSupported(fileName):
				var fullPath = zipPath + "::" + file
				_allSupportedFiles.append(fullPath)
	
	zip.close()

func GetFlatListModeStatus() -> bool:
	return %FlatListToggleButton.button_pressed

# Get the number of files in the flat list
func GetFlatListCount() -> int:
	return _allSupportedFiles.size()

# Search through the flat list
func SearchFlatList(query: String) -> Array[String]:
	var results: Array[String] = []
	var lowerQuery = query.to_lower()
	
	for filePath in _allSupportedFiles:
		var fileName = filePath.get_file().to_lower()
		if fileName.contains(lowerQuery):
			results.append(filePath)
	
	return results

# Filter flat list by file extensions
func FilterFlatListByExtension(extensions : Array) -> Array:
	var filtered : Array = []
	
	for filePath in _allSupportedFiles:
		var extension = "." + filePath.get_extension().to_lower()
		if extension in extensions:
			filtered.append(filePath)
	
	return filtered

# Show flat list filtered by file extensions
func ShowFilteredFlatListByType(extensions : Array):
	if not %FlatListToggleButton.button_pressed:
		return
	
	# Use cached list if available to avoid re-scanning
	var filesToShow : Array = []
	var sourceList = _allSupportedFiles if not _allSupportedFiles.is_empty() else _cachedFileList
	
	for filePath in sourceList:
		var extension = "." + filePath.get_extension().to_lower()
		if extension in extensions:
			filesToShow.append(filePath)
	
	# Clear and repopulate tree
	%FileTree.clear()
	_rootItem = %FileTree.create_item()
	
	for filePath in filesToShow:
		var fileItem = %FileTree.create_item(_rootItem)
		if fileItem == null:
			continue
		
		var displayName = GetDisplayNameForFlatList(filePath)
		fileItem.set_text(0, displayName)
		fileItem.set_metadata(0, filePath)
		fileItem.set_icon(0, GetIconFromFilePath(filePath))
		fileItem.set_tooltip_text(0, filePath)

func ShowOnlyScripts():
	ShowFilteredFlatListByType(_scriptExtensions)

func ShowOnlyAudio():
	ShowFilteredFlatListByType(_audioExtensions)

func ShowOnlyScenes():
	ShowFilteredFlatListByType(_sceneExtensions)

# Refresh the currently selected folder in tree view
func RefreshSelectedTreeFolder():
	var selected = %FileTree.get_selected()
	if not selected or selected.get_metadata(0) == null:
		return
	
	var selectedPath = selected.get_metadata(0) as String
	
	# Check if it's a directory
	var isDirectory = false
	if "::" in selectedPath:
		# Zip file path - check if it's a directory
		var parts = selectedPath.split("::")
		isDirectory = IsZipDirectory(parts[0], parts[1])
	else:
		var dir = DirAccess.open(selectedPath)
		isDirectory = (dir != null)
	
	if isDirectory and HasBeenPopulated(selected):
		# Clear children and repopulate
		var child = selected.get_first_child()
		while child:
			var nextChild = child.get_next()
			child.free()
			child = nextChild
		
		# Repopulate the directory
		if "::" in selectedPath:
			var parts = selectedPath.split("::")
			PopulateZipDirectory(selected, parts[0], parts[1])
		else:
			PopulateDirectory(selected)

# Toggle a filter on/off
func ToggleFilter(filterName : String, enabled : bool):
	ShowBusyIndicator()
	await get_tree().create_timer(0.2).timeout
	
	if enabled:
		if not filterName in _activeFilters:
			_activeFilters.append(filterName)
	else:
		_activeFilters.erase(filterName)
	
	ApplyActiveFilters()

func RefreshCurrentView():
	if %FlatListToggleButton.button_pressed:
		_activeFilters.clear()
		_treeViewFilters.clear()
		_isTreeViewFiltered = false
		ShowFlatListForCurrentSelection()
	else:
		# Clear filters and refresh tree view
		_activeFilters.clear()
		_treeViewFilters.clear()
		_isTreeViewFiltered = false
		RefreshTreeViewWithFilters()
		
# Apply all currently active filters
func ApplyActiveFilters():
	if _activeFilters.is_empty():
		_treeViewFilters.clear()
		_isTreeViewFiltered = false
		RefreshCurrentView()
		return
	
	# Combine all active filter extensions
	var combinedExtensions := []
	
	for filterName in _activeFilters:
		match filterName:
			"images":
				combinedExtensions.append_array(_imageExtensions)
			"scripts":
				combinedExtensions.append_array(_scriptExtensions)
			"audio":
				combinedExtensions.append_array(_audioExtensions)
			"scenes":
				combinedExtensions.append_array(_sceneExtensions)
			"videos":
				combinedExtensions.append_array(_videoExtensions)

	if %FlatListToggleButton.button_pressed:
		ShowFilteredFlatListByType(combinedExtensions)
	else:
		# Apply filtering to tree view
		_treeViewFilters = combinedExtensions
		_isTreeViewFiltered = true
		RefreshTreeViewWithFilters()
	
	HideBusyIndicator()

func RefreshTreeViewWithFilters():
	await ProcessWithBusyIndicator(func():
		_refresh_tree_view_with_filters_internal()
	)

# Internal function for tree view filtering
func _refresh_tree_view_with_filters_internal():
	# Save the current expanded state and selection
	var expandedPaths = GetExpandedPaths(_rootItem)
	var currentSelection = GetSelectedPath()
	
	# Clear and rebuild the entire tree with filters
	%FileTree.clear()
	_rootItem = %FileTree.create_item()
	PopulateDrives()
	
	# Restore expanded state
	RestoreExpandedPaths(expandedPaths)
	
	# Try to restore selection
	if not currentSelection.is_empty():
		var item = FindTreeItemByPath(_rootItem, currentSelection)
		if item:
			%FileTree.set_selected(item, 0)
			item.select(0)
			%FileTree.scroll_to_item(item)
		else:
			SelectFirstNode()
	else:
		SelectFirstNode()

# Recursively collect all expanded folder paths
func GetExpandedPaths(parentItem: TreeItem) -> Array[String]:
	var expandedPaths: Array[String] = []
	var child = parentItem.get_first_child()
	
	while child:
		var metadata = child.get_metadata(0)
		if metadata != null:
			var childPath = metadata as String
			
			# If this item is expanded and is a directory, save its path
			if not child.is_collapsed() and IsDirectory(childPath):
				expandedPaths.append(childPath)
				
				# Recursively get expanded paths from children
				var childExpanded = GetExpandedPaths(child)
				expandedPaths.append_array(childExpanded)
		
		child = child.get_next()
	
	return expandedPaths

# Restore the expanded state of folders
func RestoreExpandedPaths(expandedPaths: Array[String]):
	for path in expandedPaths:
		var item = FindTreeItemByPath(_rootItem, path)
		if item:
			# Expand the item
			item.set_collapsed(false)
			
			# Make sure it's populated
			if not HasBeenPopulated(item):
				# Temporarily disable processing to avoid recursion
				var wasProcessing = _isProcessingExpansion
				_isProcessingExpansion = true
				CleanupAndPopulate(item)
				_isProcessingExpansion = wasProcessing
			
			# Update folder icon to open state
			item.set_icon(0, GetOpenFolderIcon())

# Check if a directory has any content (subdirectories or supported files)
func HasContent(path: String) -> bool:
	var dir = DirAccess.open(path)
	if dir == null:
		return false
	
	dir.list_dir_begin()
	var nextFileName = dir.get_next()
	
	while nextFileName != "":
		if dir.current_is_dir():
			if not nextFileName.begins_with(".") and nextFileName != "System Volume Information":
				var subPath = path + nextFileName + "/"
				# If filtering is active, check if subdirectory has filtered content
				if _isTreeViewFiltered and not %FlatListToggleButton.button_pressed:
					if HasFilteredContent(subPath):
						dir.list_dir_end()
						return true
				else:
					dir.list_dir_end()
					return true
		else:
			# Found a file - check if it's supported (respects filters)
			if IsFileSupported(nextFileName):
				dir.list_dir_end()
				return true
		nextFileName = dir.get_next()
	
	dir.list_dir_end()
	return false

# Check if a zip directory has content matching current filters
func HasZipFilteredContent(zipPath: String, basePath: String) -> bool:
	var zip = OpenZipFile(zipPath)
	if zip == null:
		return false
	
	var files = zip.get_files()
	var searchPrefix = basePath
	if not searchPrefix.ends_with("/"):
		searchPrefix += "/"
	
	# Check for files in this directory that match the filter
	for file in files:
		if file.begins_with(searchPrefix) and not file.ends_with("/"):
			var fileName = file.get_file()
			var extension = "." + fileName.get_extension().to_lower()
			if extension in _treeViewFilters:
				zip.close()
				return true
	
	# Check subdirectories recursively
	var subdirectories: Array[String] = []
	for file in files:
		if file.begins_with(searchPrefix):
			var relativePath = file.substr(searchPrefix.length())
			if "/" in relativePath:
				var dirName = relativePath.split("/")[0]
				if not dirName in subdirectories:
					subdirectories.append(dirName)
	
	# Recursively check subdirectories
	for subDir in subdirectories:
		var subPath = searchPrefix + subDir
		if HasZipFilteredContent(zipPath, subPath):
			zip.close()
			return true
	
	zip.close()
	return false

# Check if a directory has content matching current filters"""
func HasFilteredContent(path: String) -> bool:
	var dir = DirAccess.open(path)
	if dir == null:
		return false
	
	dir.list_dir_begin()
	var nextFileName = dir.get_next()
	
	while nextFileName != "":
		if dir.current_is_dir():
			if not nextFileName.begins_with(".") and nextFileName != "System Volume Information":
				var subPath = path + nextFileName + "/"
				if HasFilteredContent(subPath):
					dir.list_dir_end()
					return true
		else:
			# Check if file matches filter
			var extension = "." + nextFileName.get_extension().to_lower()
			if extension in _treeViewFilters:
				dir.list_dir_end()
				return true
		nextFileName = dir.get_next()
	
	dir.list_dir_end()
	return false

# Add visual indicator for filtered tree view
func UpdateFilterIndicator():
	var filterLabel = get_node("%FilterStatusLabel")  # Add this label to your UI
	if filterLabel:
		if _isTreeViewFiltered:
			var filterText = "Filtered: " + str(_activeFilters)
			filterLabel.text = filterText
			filterLabel.visible = true
		else:
			filterLabel.visible = false

# Show and start the spinning busy indicator
func ShowBusyIndicator():
	%BusyIndicator.visible = true

# Hide and stop the busy indicator  
func HideBusyIndicator():
	%BusyIndicator.visible = false

# Show flat list for currently selected directory/drive
func ShowFlatListForCurrentSelection():
	if _flatListBasePath == "":
		_flatListBasePath = GetCurrentBasePath()
		
	ShowBusyIndicator()
	call_deferred("DoFlatListWork")

# Do the actual work after UI has updated
func DoFlatListWork():
	var basePath = _flatListBasePath  # Use stored path instead of GetCurrentBasePath()
	if basePath.is_empty():
		ShowFlatList()
		HideBusyIndicator()
		return
	
	%FileTree.clear()
	_rootItem = %FileTree.create_item()
	_allSupportedFiles.clear()
	
	if "::" in basePath:
		var parts = basePath.split("::")
		var zipPath = parts[0]
		var internalPath = parts[1] if parts.size() > 1 else ""
		ScanZipDirectoryRecursively(zipPath, internalPath)
	else:
		ScanDirectoryRecursively(basePath)
	
	_allSupportedFiles.sort()
	_cachedFileList = _allSupportedFiles.duplicate()
	
	# Apply active filters if any
	if not _activeFilters.is_empty():
		var combinedExtensions := []
		for filterName in _activeFilters:
			match filterName:
				"images":
					combinedExtensions.append_array(_imageExtensions)
				"scripts":
					combinedExtensions.append_array(_scriptExtensions)
				"audio":
					combinedExtensions.append_array(_audioExtensions)
				"scenes":
					combinedExtensions.append_array(_sceneExtensions)
				"videos":
					combinedExtensions.append_array(_videoExtensions)
		
		# Filter the list
		var filteredFiles := []
		for filePath in _allSupportedFiles:
			var extension = "." + filePath.get_extension().to_lower()
			if extension in combinedExtensions:
				filteredFiles.append(filePath)
		
		_allSupportedFiles = filteredFiles
	
	PopulateFlatList()
	HideBusyIndicator()

# Execute an operation with busy indicator and proper UI updates
func ProcessWithBusyIndicator(callable_operation: Callable):
	ShowBusyIndicator()
	await get_tree().process_frame
	callable_operation.call()
	await get_tree().process_frame
	HideBusyIndicator()
	
func SelectPreviousItem():
	var selected = %FileTree.get_selected()
	if not selected:
		return
	
	var prev = selected.get_prev()
	if prev:
		%FileTree.set_selected(prev, 0)
		prev.select(0)
		%FileTree.scroll_to_item(prev)
			
# Simple flat list navigation - just go to next sibling
func SelectNextItem():
	%FileTree.grab_focus()

	var selected = %FileTree.get_selected()
	if not selected:
		# Nothing selected - select first item
		var firstItem = _rootItem.get_first_child()
		if firstItem:
			%FileTree.set_selected(firstItem, 0)
			firstItem.select(0)
			%FileTree.scroll_to_item(firstItem)
		return

	var next = selected.get_next()
	if next:
		%FileTree.set_selected(next, 0)
		next.select(0)
		%FileTree.scroll_to_item(next)

# Add this new function for tree mode navigation
func SelectNextTreeItem():
	%FileTree.grab_focus()
	var selected = %FileTree.get_selected()
	if not selected:
		var firstItem = _rootItem.get_first_child()
		if firstItem:
			%FileTree.set_selected(firstItem, 0)
			firstItem.select(0)
			%FileTree.scroll_to_item(firstItem)
		return
	
	var next = GetNextVisibleTreeItem(selected)
	if next:
		%FileTree.set_selected(next, 0)
		next.select(0)
		%FileTree.scroll_to_item(next)

# Get next visible item in tree order (drills down into children, then siblings, then back up)
func GetNextVisibleTreeItem(item: TreeItem) -> TreeItem:
	# Check children first if expanded
	if not item.is_collapsed() and item.get_first_child():
		return item.get_first_child()
	
	# Check next sibling
	if item.get_next():
		return item.get_next()
	
	# Go up to parent and check its next sibling
	var parent = item.get_parent()
	while parent and parent != _rootItem:
		if parent.get_next():
			return parent.get_next()
		parent = parent.get_parent()
	
	return null

# Get previous visible item in tree order
func GetPreviousVisibleTreeItem(item: TreeItem) -> TreeItem:
	# Check previous sibling
	var prev = item.get_prev()
	if prev:
		# Go to the last expanded descendant of the previous sibling
		while not prev.is_collapsed() and prev.get_first_child():
			var lastChild = prev.get_first_child()
			while lastChild.get_next():
				lastChild = lastChild.get_next()
			prev = lastChild
		return prev
	
	# Go to parent
	var parent = item.get_parent()
	if parent and parent != _rootItem:
		return parent
	
	return null
	
func _input(event):
	if event is InputEventKey and event.pressed:
		if %FileTree.has_focus():
			match event.keycode:
				KEY_DOWN:
					if %FlatListToggleButton.button_pressed:
						SelectNextItem()  # Simple sibling navigation for flat list
					else:
						SelectNextTreeItem()  # Tree-aware navigation
					get_viewport().set_input_as_handled()
				KEY_UP:
					if %FlatListToggleButton.button_pressed:
						SelectPreviousItem()  # Simple sibling navigation for flat list
					else:
						SelectPreviousTreeItem()  # Tree-aware navigation
					get_viewport().set_input_as_handled()
				KEY_RIGHT:
					if %FlatListToggleButton.button_pressed:
						get_viewport().set_input_as_handled()
				KEY_LEFT:
					if %FlatListToggleButton.button_pressed:
						get_viewport().set_input_as_handled()

func SelectPreviousTreeItem():
	var selected = %FileTree.get_selected()
	if not selected:
		return
	
	var prev = GetPreviousVisibleTreeItem(selected)
	if prev:
		%FileTree.set_selected(prev, 0)
		prev.select(0)
		%FileTree.scroll_to_item(prev)

# Update button handlers
func _on_down_button_pressed() -> void:
	%FileTree.grab_focus()
	if %FlatListToggleButton.button_pressed:
		SelectNextItem()
	else:
		SelectNextTreeItem()

# Update button handlers
func _on_up_button_pressed() -> void:
	%FileTree.grab_focus()
	SelectPreviousItem()
	
func _on_file_tree_multi_selected(item: TreeItem, _column: int, selected: bool) -> void:
	if selected:
		ItemSelected(item) # Replace with function body.

func _on_flat_list_button_pressed() -> void:
	ToggleFlatList()

func _on_filter_by_images_toggle_button_pressed() -> void:
	if %FilterByImagesToggleButton.button_pressed:
		ToggleFilter("images", true)
	else:
		ToggleFilter("images", false)
