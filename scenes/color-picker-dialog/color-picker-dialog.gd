extends Control

@onready var _colorPicker = $MarginContainer/VBoxContainer/ColorPicker
var _selectedColor

func SetDefaultColor(value):
	_colorPicker.color = value
	
func _on_save_button_pressed():
	App.SetBackgroundColor(_selectedColor)
	App.SaveSolutionSettings()
	queue_free()

func _on_color_picker_color_changed(color):
	_selectedColor = color
	Signals.emit_signal("BackgroundColorTemporarilyChanged", color)

func _on_cancel_button_pressed():
	Signals.emit_signal("BackgroundColorChanged", App.GetBackgroundColor())
	queue_free()
