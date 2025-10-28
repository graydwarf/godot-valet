extends Window
class_name LicenseDialog

# Dialog for editing license text for sound files

signal LicenseSaved(soundPath: String, licenseText: String)

var _soundPath: String = ""

@onready var _licenseTextEdit: TextEdit = %LicenseTextEdit
@onready var _saveButton: Button = %SaveButton
@onready var _cancelButton: Button = %CancelButton
@onready var _fileNameLabel: Label = %FileNameLabel

func _ready():
	_saveButton.pressed.connect(_on_save_pressed)
	_cancelButton.pressed.connect(_on_cancel_pressed)
	close_requested.connect(_on_cancel_pressed)

func ShowDialog(soundPath: String):
	_soundPath = soundPath
	_fileNameLabel.text = "License for: " + soundPath.get_file()

	# Load existing license if it exists
	var licensePath = soundPath + ".license"
	if FileAccess.file_exists(licensePath):
		var file = FileAccess.open(licensePath, FileAccess.READ)
		if file:
			_licenseTextEdit.text = file.get_as_text()
			file.close()
	else:
		_licenseTextEdit.text = ""

	popup_centered(Vector2i(600, 400))
	_licenseTextEdit.grab_focus()

func _on_save_pressed():
	var licenseText = _licenseTextEdit.text
	var licensePath = _soundPath + ".license"

	# Save license file
	var file = FileAccess.open(licensePath, FileAccess.WRITE)
	if file:
		file.store_string(licenseText)
		file.close()
		LicenseSaved.emit(_soundPath, licenseText)
		hide()
	else:
		OS.alert("Failed to save license file: " + licensePath)

func _on_cancel_pressed():
	hide()
