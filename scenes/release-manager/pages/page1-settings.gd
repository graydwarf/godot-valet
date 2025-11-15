extends WizardPageBase

signal version_changed(old_version: String, new_version: String)

@onready var _projectVersionLineEdit = %ProjectVersionLineEdit
@onready var _godotVersionLabel = %GodotVersionLabel
@onready var _exportPathLineEdit = %ExportPathLineEdit
@onready var _exportFileNameLineEdit = %ExportFileNameLineEdit

var _folderDialog: FileDialog = null
var _currentVersion: String = ""  # Store current version for comparison

func _ready():
	# Connect to version input changes to notify card
	_projectVersionLineEdit.text_changed.connect(_onVersionChanged)

func _loadPageData():
	if _selectedProjectItem == null:
		return

	_currentVersion = _selectedProjectItem.GetProjectVersion()
	_projectVersionLineEdit.text = _currentVersion
	_godotVersionLabel.text = _selectedProjectItem.GetGodotVersion()
	_exportPathLineEdit.text = _selectedProjectItem.GetExportPath()
	_exportFileNameLineEdit.text = _selectedProjectItem.GetExportFileName()

func _onVersionChanged(newText: String):
	# Notify card of version change
	version_changed.emit(_currentVersion, newText)

func validate() -> bool:
	# Export path cannot equal project path
	if _selectedProjectItem != null:
		var projectPath = _selectedProjectItem.GetProjectPath()
		if _exportPathLineEdit.text == projectPath:
			return false

	return true

func save():
	if _selectedProjectItem == null:
		return

	_selectedProjectItem.SetProjectVersion(_projectVersionLineEdit.text)
	_selectedProjectItem.SetExportPath(_exportPathLineEdit.text)
	_selectedProjectItem.SetExportFileName(_exportFileNameLineEdit.text)
	_selectedProjectItem.SaveProjectItem()

func _on_select_export_path_pressed():
	# If export path is empty, default to project path
	var initialPath = _exportPathLineEdit.text
	if initialPath.is_empty() and _selectedProjectItem != null:
		initialPath = _selectedProjectItem.GetProjectPath()
	_openFolderDialog(initialPath)

func _openFolderDialog(currentPath: String):
	if _folderDialog == null:
		_folderDialog = FileDialog.new()
		_folderDialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_folderDialog.access = FileDialog.ACCESS_FILESYSTEM
		_folderDialog.show_hidden_files = true
		_folderDialog.title = "Select Folder"
		_folderDialog.ok_button_text = "Select"
		_folderDialog.dir_selected.connect(_onFolderSelected)
		add_child(_folderDialog)

	# Set initial directory if path exists
	if currentPath != "" and DirAccess.dir_exists_absolute(currentPath):
		_folderDialog.current_dir = currentPath

	_folderDialog.popup_centered(Vector2i(800, 600))

func _onFolderSelected(path: String):
	_exportPathLineEdit.text = path
