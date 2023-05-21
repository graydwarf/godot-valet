extends ColorRect

var _selected = false
func _ready():
	Signals.connect("ProjectItemClicked", ProjectItemClicked)

func ProjectItemClicked(projectItem):
	if projectItem == self:
		return
	
	RestoreDefaultColor()
	_selected = false
	
func RestoreDefaultColor():
	color = Color(0.0, 0.0, 0.0, 0.5)

func ShowHoverColor():
	color = Color(0.0, 0.0, 0.0, 0.3)

func ShowSelectedColor():
	color = Color(0.0, 0.0, 0.5, 0.2)
		
func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Signals.emit_signal("ProjectItemClicked", self)
		ShowSelectedColor()
		_selected = true

func _on_mouse_entered():
	if _selected:
		return
	
	ShowHoverColor()

func _on_mouse_exited():
	if _selected:
		return
	
	RestoreDefaultColor()
	
