extends ColorRect

@onready var _deleteConfirmationDialog = $DeleteConfirmationDialog
@onready var _godotVersionItemContainer = $VBoxContainer/HBoxContainer/MarginContainer/ScrollContainer/GodotVersionItemContainer
var _selectedGodotVersionItem

func _ready():
	InitSignals()
	color = App.GetBackgroundColor()
	LoadGodotVersionItems()
	
func InitSignals():
	Signals.connect("GodotVersionItemClicked", GodotVersionItemClicked)
	Signals.connect("NewGodotVersionAdded", NewGodotVersionAdded)
	Signals.connect("MoveVersionItemUp", MoveVersionItemUp)
	Signals.connect("SaveGodotVersionSettingsFile", SaveGodotVersionSettingsFile)
	
func MoveVersionItemUp(godotVersionItem):
	var idx = godotVersionItem.get_index()

	if idx > 0:
		_godotVersionItemContainer.move_child(godotVersionItem, idx - 1)
		_godotVersionItemContainer.move_child(_godotVersionItemContainer.get_child(idx), idx)

	SaveAllGodotVersions()
	Signals.emit_signal("LoadOpenGodotButtons")

func SaveAllGodotVersions():
	var newGodotVersionAdded = false
	for godotVersionItem in _godotVersionItemContainer.get_children():
		SaveGodotVersionSettingsFile(godotVersionItem.GetGodotVersionId(), godotVersionItem.GetGodotVersion(), godotVersionItem.GetGodotPath(), godotVersionItem.get_index(), newGodotVersionAdded)

func SaveGodotVersionSettingsFile(id, godotVersion, filePath, sortOrder = -1, newGodotVersionAdded = false):
	var config = ConfigFile.new()

	config.set_value("GodotVersionSettings", "godot_version", godotVersion)
	config.set_value("GodotVersionSettings", "godot_path", filePath)
	config.set_value("GodotVersionSettings", "sort_order", sortOrder)
	
	# New or are we saving?
	if id == "":
		id = Common.GetId()
		
	# Save the config file.
	var err = config.save("user://" + App.GetGodotVersionItemFolder() +"/" + id + ".cfg")
	if err != OK:
		OS.alert("An error occurred while saving the config file.")
		return
	
	if newGodotVersionAdded:
		NewGodotVersionAdded()
	
func GodotVersionItemClicked(godotVersionItem):
	_selectedGodotVersionItem = godotVersionItem
	
func ClearVersionItems():
	for child in _godotVersionItemContainer.get_children():
		child.queue_free()
		
func NewGodotVersionAdded():
	ClearVersionItems()
	LoadGodotVersionItems()

func RemoveSelectedVersionItem():
	if !is_instance_valid(_selectedGodotVersionItem):
		return
	
	if IsGodotVersionInUse():
		$DeleteUsedVersionConfirmationDialog.show()
	else:
		$DeleteConfirmationDialog.show()

func IsGodotVersionInUse():
	var allResourceFiles = FileHelper.GetFilesFromPath("user://" + App.GetProjectItemFolder())
	for resourceFile in allResourceFiles:
		if !resourceFile.ends_with(".cfg"):
			continue

		var projectId = resourceFile.trim_suffix(".cfg")
		var config = ConfigFile.new()
		var err = config.load("user://" + App.GetProjectItemFolder() + "/" + projectId + ".cfg")
		if err == OK:
			var godotVersionId = config.get_value("ProjectSettings", "godot_version_id", "")
			if godotVersionId == _selectedGodotVersionItem.GetGodotVersionId():
				return true

	# No existing projects are using this Godot Version
	return false
			
func DeleteGodotVersionConfiguration():
	pass

func DeleteGodotVersion():
	_godotVersionItemContainer.remove_child(_selectedGodotVersionItem)
	DirAccess.remove_absolute("user://" + App.GetGodotVersionItemFolder() + "/" + _selectedGodotVersionItem.GetGodotVersionId() + ".cfg")
	_selectedGodotVersionItem = null
	Signals.emit_signal("GodotVersionsChanged")

func DisplayDeleteProjectConfirmationDialog():
	_deleteConfirmationDialog.show()
	
func EditSelectedGodotVersion():
	if !is_instance_valid(_selectedGodotVersionItem):
		return
		
	var editGodotVersionDialog = load("res://scenes/create-godot-version-dialog/create-godot-version-dialog.tscn").instantiate()
	add_child(editGodotVersionDialog)
	editGodotVersionDialog.SetGodotVersionId(_selectedGodotVersionItem.GetGodotVersionId())
	editGodotVersionDialog.SetGodotVersion(_selectedGodotVersionItem.GetGodotVersion())
	editGodotVersionDialog.SetGodotPath(_selectedGodotVersionItem.GetGodotPath())
	
func LoadGodotVersionItems():
	var allResourceFiles = FileHelper.GetFilesFromPath("user://" + App.GetGodotVersionItemFolder())
	for resourceFile in allResourceFiles:
		if !resourceFile.ends_with(".cfg"):
			continue

		var fileName = resourceFile.trim_suffix(".cfg")
		
		var godotVersionItem = load("res://scenes/godot-version-item/godot-version-item.tscn").instantiate()
		_godotVersionItemContainer.add_child(godotVersionItem)
		
		var config = ConfigFile.new()
		var err = config.load("user://" + App.GetGodotVersionItemFolder() + "/" + fileName + ".cfg")
		if err == OK:
			godotVersionItem.SetGodotVersion(config.get_value("GodotVersionSettings", "godot_version", ""))
			godotVersionItem.SetGodotPath(config.get_value("GodotVersionSettings", "godot_path", ""))
			var sortOrder = config.get_value("GodotVersionSettings", "sort_order", -1)
			godotVersionItem.SetSortOrder(sortOrder)
			godotVersionItem.SetGodotVersionId(fileName)
	call_deferred("SortGodotVersionItems")

func SortGodotVersionItems():
	var children = _godotVersionItemContainer.get_children()
	children.sort_custom(SortGodotVersionItemNodes)

	while _godotVersionItemContainer.get_child_count() > 0:
		_godotVersionItemContainer.remove_child(_godotVersionItemContainer.get_child(0))

	for child in children:
		_godotVersionItemContainer.add_child(child)

func SortGodotVersionItemNodes(node1, node2):
	var node1SortOrder = int(node1._sortOrder)
	var node2SortOrder = int(node2._sortOrder)
	if node1SortOrder == -1:
		return true
	elif node2SortOrder == -1:
		return false
	elif node1SortOrder < node2SortOrder:
		return true
	elif node1SortOrder > node2SortOrder:
		return false
	else:
		return false

func OpenNewGodotVersionDialog():
	var newGodotVersionDialog = load("res://scenes/create-godot-version-dialog/create-godot-version-dialog.tscn").instantiate()
	add_child(newGodotVersionDialog)
	
func _on_new_project_button_pressed():
	OpenNewGodotVersionDialog()

func _on_close_button_pressed():
	Signals.emit_signal("GodotVersionManagerClosing")
	queue_free()

func _on_edit_button_pressed():
	EditSelectedGodotVersion()

func _on_remove_button_pressed():
	RemoveSelectedVersionItem()

func _on_confirmation_dialog_confirmed():
	DeleteGodotVersion()

func _on_delete_used_version_confirmation_dialog_confirmed():
	DeleteGodotVersion()
