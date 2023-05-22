extends ColorRect

@onready var _godotVersionNameLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer2/GodotVersionNameLabel
@onready var _godotPathLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer/GodotPathLabel
var _godotVersion = ""
var _godotPath = ""
var _selected = false
var _godotVersionId = ""

func _ready():
	Signals.connect("GodotVersionItemClicked", GodotVersionItemClicked)

func GetGodotVersionId():
	return _godotVersionId

func SetGodotVersionId(value):
	_godotVersionId = value
	
func GetGodotVersion():
	return _godotVersion

func GetGodotPath():
	return _godotPath

func SetGodotVersion(value):
	_godotVersion = value
	_godotVersionNameLabel.text = value

func SetGodotPath(value):
	_godotPath = value
	_godotPathLabel.text = value

func GodotVersionItemClicked(godorVersionItem):
	if godorVersionItem == self:
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
		Signals.emit_signal("GodotVersionItemClicked", self)
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
