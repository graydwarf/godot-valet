extends Control
class_name AssetFinderTipsDialog

@onready var _closeButton = %CloseButton

func _ready():
	visible = false
	if _closeButton:
		_closeButton.pressed.connect(_onClosePressed)

func show_dialog():
	visible = true
	move_to_front()
	_closeButton.grab_focus()

func hide_dialog():
	visible = false

func _onClosePressed():
	hide_dialog()

# Close on Escape key
func _unhandled_input(event: InputEvent):
	if visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			hide_dialog()
			get_viewport().set_input_as_handled()
