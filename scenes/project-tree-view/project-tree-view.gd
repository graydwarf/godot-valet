extends Control

# - Generated with assistance from Claude 4 Sonnet (Anthropic) - December 2024

var _rootItem: TreeItem
var _projectRootPath: String = ""

func _ready():
	SetupTree()

func SetupTree():
	%Tree.hide_root = true
	%Tree.allow_reselect = true
	%Tree.select_mode = Tree.SELECT_SINGLE
	_rootItem = %Tree.create_item()
	%Tree.item_collapsed.connect(_on_item_collapsed)

func InitializeProjectTree(projectPath: String):
	_projectRootPath = projectPath.get_base_dir()
	PopulateProjectTree()

func PopulateProjectTree():
	%Tree.clear()
	_rootItem = %Tree.create_item()
	
	# Add project root
	var rootItem = %Tree.create_item(_rootItem)
	rootItem.set_text(0, "Project Root")
	rootItem.set_metadata(0, _projectRootPath)
	rootItem.set_icon(0, GetFolderIcon())
	
	# Populate with project directories
	PopulateDirectory(rootItem, _projectRootPath)
	rootItem.set_collapsed(false)

func PopulateDirectory(parentItem: TreeItem, dirPath: String):
	var dir = DirAccess.open(dirPath)
	if dir == null:
		return
	
	var directories: Array[String] = []
	
	dir.list_dir_begin()
	var fileName = dir.get_next()
	
	while fileName != "":
		if dir.current_is_dir():
			if not fileName.begins_with(".") and fileName != "addons":
				directories.append(fileName)
		fileName = dir.get_next()
	
	dir.list_dir_end()
	directories.sort()
		
	# Add a delay and process in smaller batches
	for i in range(directories.size()):
		var dirName = directories[i]
		
		# Process a frame every few items to avoid blocking
		if i % 5 == 0:
			await get_tree().process_frame
		
		var dirItem = %Tree.create_item(parentItem)
		if dirItem == null:
			print("ERROR: Failed to create tree item for: ", dirName)
			continue
			
		dirItem.set_text(0, dirName)
		
		var fullPath = dirPath + "/" + dirName
		dirItem.set_metadata(0, fullPath)
		dirItem.set_icon(0, GetFolderIcon())
		
		if HasSubdirectories(fullPath):
			dirItem.set_collapsed(true)
			var tempChild = %Tree.create_item(dirItem)
			if tempChild:
				tempChild.set_text(0, "")
				tempChild.set_metadata(0, null)

func GetSelectedDestination() -> String:
	var selected = %Tree.get_selected()
	if selected and selected.get_metadata(0) != null:
		return selected.get_metadata(0) as String
	return ""

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

func _on_item_collapsed(item: TreeItem):
	if not item.is_collapsed() and item.get_child_count() == 1:
		var child = item.get_first_child()
		if child.get_metadata(0) == null:
			child.free()
			var path = item.get_metadata(0) as String
			PopulateDirectory(item, path)
