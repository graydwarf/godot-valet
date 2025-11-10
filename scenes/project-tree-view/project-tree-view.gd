extends Control

# - Generated with assistance from Claude 4 Sonnet (Anthropic) - December 2024

var _rootItem: TreeItem
var _projectRootPath: String = ""

func _ready():
	SetupTree()
	SetupContextMenu()

func SetupTree():
	%Tree.hide_root = true
	%Tree.allow_reselect = true
	%Tree.select_mode = Tree.SELECT_MULTI
	_rootItem = %Tree.create_item()
	%Tree.item_collapsed.connect(_on_item_collapsed)
	%Tree.item_mouse_selected.connect(_on_tree_item_mouse_selected)

func SetupContextMenu():
	%ContextMenu.add_item("Delete", 0)
	%ContextMenu.id_pressed.connect(_on_context_menu_item_selected)

func InitializeProjectTree(projectPath: String):
	_projectRootPath = projectPath.get_base_dir()
	await PopulateProjectTree()

func RefreshProjectTree():
	if _projectRootPath and not _projectRootPath.is_empty():
		# Save currently selected items
		var selectedPaths: Array[String] = []
		var selected = %Tree.get_next_selected(null)
		while selected:
			var path = selected.get_metadata(0)
			if path:
				selectedPaths.append(path)
			selected = %Tree.get_next_selected(selected)

		# Refresh the tree contents
		var rootItem = %Tree.get_root()
		if rootItem:
			await _RefreshExpandedFolders(rootItem)

		# Restore selections
		if not selectedPaths.is_empty():
			_RestoreSelections(rootItem, selectedPaths)

func _RefreshExpandedFolders(item: TreeItem):
	# Only process this item if it's expanded
	if not item or item.is_collapsed():
		return

	var path = item.get_metadata(0)
	var child: TreeItem

	if not path:
		# Process children of root item
		child = item.get_first_child()
		while child:
			await _RefreshExpandedFolders(child)
			child = child.get_next()
		return

	# Get current file names in this tree item
	var currentChildren: Dictionary = {}
	child = item.get_first_child()
	while child:
		var childName = child.get_text(0)
		if childName:
			currentChildren[childName] = child
		child = child.get_next()

	# Get actual file names from filesystem (only files, not directories)
	var dir = DirAccess.open(path)
	if dir:
		var actualFiles: Array[String] = []

		dir.list_dir_begin()
		var entryName = dir.get_next()
		while entryName != "":
			if not dir.current_is_dir() and not entryName.begins_with("."):
				actualFiles.append(entryName)
			entryName = dir.get_next()
		dir.list_dir_end()

		# Remove files that no longer exist in filesystem
		for childName in currentChildren:
			var childItem = currentChildren[childName]
			var childPath = childItem.get_metadata(0)
			if childPath:
				# Check if it's a file or directory
				var isFile = not DirAccess.dir_exists_absolute(childPath)
				if isFile:
					# It's a file - check if it's still in actualFiles
					if not childName in actualFiles:
						childItem.free()
				else:
					# It's a directory - check if it still exists
					if not DirAccess.dir_exists_absolute(childPath):
						childItem.free()

		# Add new files that don't exist in the tree yet
		for fileName in actualFiles:
			if not fileName in currentChildren:
				# Simply append new files at the end
				var fileItem = %Tree.create_item(item)
				fileItem.set_text(0, fileName)
				var fullPath = path.path_join(fileName)
				fileItem.set_metadata(0, fullPath)
				fileItem.set_icon(0, GetFileIcon(fileName))

	# Recursively refresh child folders that are ACTUALLY expanded (not just leaf directories)
	child = item.get_first_child()
	while child:
		# Only recurse if:
		# 1. It's a directory (has metadata that points to a directory path)
		# 2. It's explicitly expanded (not collapsed)
		# 3. It has real children (not just a dummy placeholder)
		var childPath = child.get_metadata(0)
		if childPath and DirAccess.dir_exists_absolute(childPath):
			# Check if it has real children (if it has 1 child, check it's not a dummy)
			var hasRealChildren = false
			if child.get_child_count() > 1:
				hasRealChildren = true
			elif child.get_child_count() == 1:
				var firstChild = child.get_first_child()
				# Has real children if the first child has metadata (not a dummy)
				hasRealChildren = firstChild.get_metadata(0) != null

			# Only recurse if expanded AND has been populated with real children
			if not child.is_collapsed() and hasRealChildren:
				await _RefreshExpandedFolders(child)
		child = child.get_next()

func SaveExpandedState() -> Array[String]:
	var expandedPaths: Array[String] = []
	var rootItem = %Tree.get_root()
	if rootItem:
		_CollectExpandedPaths(rootItem, expandedPaths)
	return expandedPaths

func _CollectExpandedPaths(item: TreeItem, paths: Array[String]):
	if item and not item.is_collapsed():
		var path = item.get_metadata(0)
		if path:
			paths.append(path)

	var child = item.get_first_child()
	while child:
		_CollectExpandedPaths(child, paths)
		child = child.get_next()

func _RestoreSelections(item: TreeItem, paths: Array[String]):
	if not item:
		return

	var path = item.get_metadata(0)
	if path and path in paths:
		item.select(0)

	var child = item.get_first_child()
	while child:
		_RestoreSelections(child, paths)
		child = child.get_next()

func RestoreExpandedState(expandedPaths: Array[String]):
	if expandedPaths.is_empty():
		return

	var rootItem = %Tree.get_root()
	if rootItem:
		await _RestoreExpandedPaths(rootItem, expandedPaths)

func _RestoreExpandedPaths(item: TreeItem, paths: Array[String]):
	var path = item.get_metadata(0)
	var child: TreeItem

	if path and path in paths:
		item.set_collapsed(false)

		# If this item has lazy-loaded children (dummy child), populate it now
		if item.get_child_count() == 1:
			child = item.get_first_child()
			if child and child.get_metadata(0) == null:
				child.free()
				await PopulateDirectory(item, path)

	child = item.get_first_child()
	while child:
		await _RestoreExpandedPaths(child, paths)
		child = child.get_next()

func PopulateProjectTree():
	%Tree.clear()
	_rootItem = %Tree.create_item()

	# Add project root
	var rootItem = %Tree.create_item(_rootItem)
	rootItem.set_text(0, "res://")
	rootItem.set_metadata(0, _projectRootPath)
	rootItem.set_icon(0, GetFolderIcon())

	# Populate with project directories (recursively to show all files)
	await PopulateDirectory(rootItem, _projectRootPath, true)

	# Check if rootItem is still valid after awaits
	if is_instance_valid(rootItem):
		rootItem.set_collapsed(false)

func PopulateDirectory(parentItem: TreeItem, dirPath: String, recursive: bool = false):
	var dir = DirAccess.open(dirPath)
	if dir == null:
		return

	var directories: Array[String] = []
	var files: Array[String] = []

	dir.list_dir_begin()
	var entryName = dir.get_next()

	while entryName != "":
		if dir.current_is_dir():
			if not entryName.begins_with(".") and entryName != "addons":
				directories.append(entryName)
		else:
			if not entryName.begins_with("."):
				files.append(entryName)
		entryName = dir.get_next()

	dir.list_dir_end()
	directories.sort()
	files.sort()

	# Add directories first
	for i in range(directories.size()):
		var dirName = directories[i]

		# Process a frame every few items to avoid blocking
		if i % 5 == 0:
			await get_tree().process_frame
			# Check if parent item is still valid after await
			if not is_instance_valid(parentItem):
				return

		var dirItem = %Tree.create_item(parentItem)
		if dirItem == null:
			print("ERROR: Failed to create tree item for: ", dirName)
			continue

		dirItem.set_text(0, dirName)

		var fullPath = dirPath + "/" + dirName
		dirItem.set_metadata(0, fullPath)
		dirItem.set_icon(0, GetFolderIcon())

		if recursive:
			# Recursively populate this subdirectory immediately (collapsed but populated)
			dirItem.set_collapsed(true)
			await PopulateDirectory(dirItem, fullPath, true)
		elif HasSubdirectories(fullPath):
			# Use lazy loading with dummy child
			dirItem.set_collapsed(true)
			var tempChild = %Tree.create_item(dirItem)
			if tempChild:
				tempChild.set_text(0, "")
				tempChild.set_metadata(0, null)

	# Add files
	for j in range(files.size()):
		var fileName = files[j]

		if j % 5 == 0:
			await get_tree().process_frame
			# Check if parent item is still valid after await
			if not is_instance_valid(parentItem):
				return

		var fileItem = %Tree.create_item(parentItem)
		if fileItem == null:
			continue

		fileItem.set_text(0, fileName)

		var fileFullPath = dirPath + "/" + fileName
		fileItem.set_metadata(0, fileFullPath)
		fileItem.set_icon(0, GetFileIcon(fileName))

func GetSelectedDestination() -> String:
	var selected = %Tree.get_selected()
	if selected and selected.get_metadata(0) != null:
		return selected.get_metadata(0) as String
	return ""

func GetSelectedFiles() -> Array[String]:
	# Returns selected files (not folders) from the project tree
	var files: Array[String] = []
	var selected = %Tree.get_next_selected(null)
	while selected:
		var path = selected.get_metadata(0)
		if path and FileAccess.file_exists(path):
			files.append(path)
		selected = %Tree.get_next_selected(selected)
	return files

func HasSubdirectories(path: String) -> bool:
	var dir = DirAccess.open(path)
	if dir == null:
		return false
	
	dir.list_dir_begin()
	var fileName = dir.get_next()
	
	while fileName != "":
		if dir.current_is_dir() and not fileName.begins_with("."):
			dir.list_dir_end()
			return true
		fileName = dir.get_next()
	
	dir.list_dir_end()
	return false

func GetFolderIcon() -> Texture2D:
	return load("res://scenes/file-tree-view-explorer/assets/folder.png") as Texture2D

func GetFileIcon(fileName: String) -> Texture2D:
	var extension = fileName.get_extension().to_lower()
	match extension:
		"png", "jpg", "jpeg", "bmp", "svg", "webp":
			return load("res://scenes/file-tree-view-explorer/assets/image-file.png") as Texture2D
		"zip", "rar", "7z", "tar", "gz":
			return load("res://scenes/file-tree-view-explorer/assets/zip.png") as Texture2D
		_:
			return load("res://scenes/file-tree-view-explorer/assets/file.png") as Texture2D

func _on_item_collapsed(item: TreeItem):
	if not item.is_collapsed() and item.get_child_count() == 1:
		var child = item.get_first_child()
		if child.get_metadata(0) == null:
			child.free()
			var path = item.get_metadata(0) as String
			await PopulateDirectory(item, path)

# Handle right-click on tree items
func _on_tree_item_mouse_selected(_mouse_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		var selected = %Tree.get_selected()
		if selected:
			var path = selected.get_metadata(0)
			if path != null:
				# Show context menu at mouse position
				var global_pos = get_viewport().get_mouse_position()
				%ContextMenu.position = Vector2i(global_pos)
				%ContextMenu.popup()

# Handle context menu item selection
func _on_context_menu_item_selected(id: int) -> void:
	match id:
		0:  # Delete
			await _handle_delete_selected()

# Handle delete with confirmation dialog
func _handle_delete_selected() -> void:
	# Get all selected items
	var selected_paths: Array[String] = []
	var selected_item = %Tree.get_next_selected(null)

	while selected_item:
		var path = selected_item.get_metadata(0)
		if path:
			selected_paths.append(path)
		selected_item = %Tree.get_next_selected(selected_item)

	if selected_paths.is_empty():
		return

	# Count files and folders
	var file_count = 0
	var folder_count = 0
	for path in selected_paths:
		if FileAccess.file_exists(path):
			file_count += 1
		elif DirAccess.dir_exists_absolute(path):
			folder_count += 1

	# Build confirmation message
	var message = "Are you sure you want to delete "
	if file_count > 0 and folder_count > 0:
		message += "%d file(s) and %d folder(s)?" % [file_count, folder_count]
	elif file_count > 0:
		if file_count == 1:
			message += "1 file?"
		else:
			message += "%d files?" % file_count
	else:
		if folder_count == 1:
			message += "1 folder?"
		else:
			message += "%d folders?" % folder_count

	# Show confirmation dialog
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = message
	dialog.title = "Confirm Delete"
	dialog.ok_button_text = "Yes"
	dialog.cancel_button_text = "Cancel"

	add_child(dialog)

	var confirmed = [false]
	var closed = [false]

	dialog.confirmed.connect(func():
		confirmed[0] = true
		closed[0] = true
	)
	dialog.canceled.connect(func():
		confirmed[0] = false
		closed[0] = true
	)

	dialog.popup_centered()

	# Wait for dialog to close
	while not closed[0]:
		await get_tree().process_frame

	dialog.queue_free()

	# If confirmed, delete the files/folders
	if confirmed[0]:
		for path in selected_paths:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
			elif DirAccess.dir_exists_absolute(path):
				_delete_directory_recursive(path)

		# Refresh the tree
		await RefreshProjectTree()

# Recursively delete a directory and all its contents
func _delete_directory_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = path.path_join(file_name)
			if dir.current_is_dir():
				_delete_directory_recursive(full_path)
			else:
				DirAccess.remove_absolute(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
		DirAccess.remove_absolute(path)
