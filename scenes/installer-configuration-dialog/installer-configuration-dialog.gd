extends Control

@onready var _selectedInstallerFilePath = $MarginContainer/HBoxContainer/SelectedInstallerPathLineEdit
@onready var _selectInstallerFileDialog = $FileDialog
@onready var _installerConfigurationName = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/InstallerConfigurationName/InstallerConfigurationNameLineEdit
@onready var _windowsPathLineEdit = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/WindowsPackageHBoxContainer/WindowsPathLineEdit
@onready var _linuxPathLineEdit = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/LinuxInstallerPackageHBoxContainer/LinuxPackagePathLineEdit

var selectInstallerDialogType = "" # Windows or Linux
func _ready():
	pass

func SaveConfiguration():
	# TODO: Create a configuration file called configs/<project-name>/installer-configuration.cfg
	# TODO: Save all settings
	pass

func ValidateInstallerConfiguration():
	# TODO: 
	# Validate friendly Name
	# 	- Only allow letters, numbers, spaces, dashes, and underscores in friendly name
	# Validate paths exist and end in .zip and even go as far as reviewing what's inside the .zip
	pass
	
func _on_file_dialog_file_selected(path):
	if selectInstallerDialogType == "Windows":
		_windowsPathLineEdit.text = path
	elif selectInstallerDialogType == "Linux":
		_linuxPathLineEdit.text = path

func _on_windows_pacakge_select_button_pressed():
	selectInstallerDialogType = "Windows"
	_selectInstallerFileDialog.show()

func _on_linux_pacakge_select_button_pressed():
	selectInstallerDialogType = "Linux"
	_selectInstallerFileDialog.show()
	
func _on_save_button_pressed():
	var err = ValidateInstallerConfiguration()
	if err != OK:
		return
	
	# Save to disk
	err = SaveConfiguration()
	if err != OK:
		return

	var configurationFileName = _installerConfigurationName.text
	Signals.emit_signal("SaveInstallerConfiguration", configurationFileName)
	queue_free()


func _on_disconnect_button_pressed():
	Signals.emit_signal("SaveInstallerConfiguration", "")
