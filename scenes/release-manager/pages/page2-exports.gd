extends WizardPageBase

@onready var _windowsCheckBox = %WindowsCheckBox
@onready var _linuxCheckBox = %LinuxCheckBox
@onready var _webCheckBox = %WebCheckBox
@onready var _sourceCheckBox = %SourceCheckBox

func _loadPageData():
	if _selectedProjectItem == null:
		return

	_windowsCheckBox.button_pressed = _selectedProjectItem.GetWindowsChecked()
	_linuxCheckBox.button_pressed = _selectedProjectItem.GetLinuxChecked()
	_webCheckBox.button_pressed = _selectedProjectItem.GetWebChecked()
	_sourceCheckBox.button_pressed = _selectedProjectItem.GetSourceChecked()

func validate() -> bool:
	# Warn if no platforms selected, but allow proceeding
	var anySelected = _windowsCheckBox.button_pressed || \
					  _linuxCheckBox.button_pressed || \
					  _webCheckBox.button_pressed || \
					  _sourceCheckBox.button_pressed
	return anySelected

func save():
	if _selectedProjectItem == null:
		return

	_selectedProjectItem.SetWindowsChecked(_windowsCheckBox.button_pressed)
	_selectedProjectItem.SetLinuxChecked(_linuxCheckBox.button_pressed)
	_selectedProjectItem.SetWebChecked(_webCheckBox.button_pressed)
	_selectedProjectItem.SetSourceChecked(_sourceCheckBox.button_pressed)
	_selectedProjectItem.SaveProjectItem()
