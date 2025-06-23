extends Control

# Signals
signal file_selected(filePath: String)
signal directory_selected(dirPath: String)

var _rootItem: TreeItem

# Dictionary to store expanded paths to maintain state
var expanded_paths: Dictionary = {}

func _ready():
	SetupTree()
	PopulateDrives()
	
	# Connect tree signals
	%FileTree.item_collapsed.connect(_on_item_collapsed)
	%FileTree.item_selected.connect(_on_item_selected)

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
	return load("res://scenes/file-explorer/assets/drive.png") as Texture2D

func GetFolderIcon() -> Texture2D:
	return load("res://scenes/file-explorer/assets/folder.png") as Texture2D

func GetFileIcon() -> Texture2D:
	return load("res://scenes/file-explorer/assets/file.png") as Texture2D

# Handle when an item is expanded
func _on_item_collapsed(item: TreeItem):
	# When an item is expanded (collapsed = false), check if we need to populate it
	if not item.is_collapsed():
		if not HasBeenPopulated(item):
			# Defer the population to avoid "blocked" error
			call_deferred("CleanupAndPopulate", item)

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
			files.append(nextFileName)
			# Debug for specific file types
			if nextFileName.to_lower().ends_with(".mkv"):
				print("Found .mkv file: " + nextFileName)
		
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
		fileItem.set_icon(0, GetFileIcon())

func HasContent(path: String) -> bool:
	"""Check if a directory has any content (subdirectories or files)"""
	var dir = DirAccess.open(path)
	if dir == null:
		return false
	
	dir.list_dir_begin()
	var nextFileName = dir.get_next()
	
	while nextFileName != "":
		# Return true if we find any directory (not hidden/system) or any file
		if dir.current_is_dir():
			if not nextFileName.begins_with(".") and nextFileName != "System Volume Information":
				dir.list_dir_end()
				return true
		else:
			# Found a file
			dir.list_dir_end()
			return true
		nextFileName = dir.get_next()
	
	dir.list_dir_end()
	return false

# Handle when an item is selected
func _on_item_selected():
	var selected = %FileTree.get_selected()
	if selected:
		if selected.get_metadata(0) == null:
			return
			
		var path = selected.get_metadata(0) as String
		print("Selected: " + path)
		
		# Check if it's a directory and auto-expand it if not already populated
		var dir = DirAccess.open(path)
		if dir != null and not HasBeenPopulated(selected):
			# Auto-expand directories when selected
			selected.set_collapsed(false)
			call_deferred("CleanupAndPopulate", selected)
		
		# Emit a signal or call a function with the selected path
		SelectedPathChanged(path)

func SelectedPathChanged(path: String):
	"""Called when the selected path changes - customize this for your needs"""
	print("Path selected: " + path)
	
	# Check if it's a file or directory
	var dir = DirAccess.open(path)
	if dir != null:
		print("Selected a directory")
		directory_selected.emit(path)
	else:
		print("Selected a file")
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
	
	# Now populate with real content
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
