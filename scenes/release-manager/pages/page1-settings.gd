extends WizardPageBase

signal version_changed(old_version: String, new_version: String)

@onready var _projectVersionLineEdit = %ProjectVersionLineEdit
@onready var _godotVersionLabel = %GodotVersionLabel
@onready var _exportFileNameLineEdit = %ExportFileNameLineEdit

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
	_exportFileNameLineEdit.text = _selectedProjectItem.GetExportFileName()

func _onVersionChanged(newText: String):
	# Notify card of version change
	version_changed.emit(_currentVersion, newText)

func validate() -> bool:
	return true

func save():
	if _selectedProjectItem == null:
		return

	_selectedProjectItem.SetProjectVersion(_projectVersionLineEdit.text)
	_selectedProjectItem.SetExportFileName(_exportFileNameLineEdit.text)
	_selectedProjectItem.SaveProjectItem()
