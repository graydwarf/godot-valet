extends ColorRect
@onready var _projectNameLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/ProjectNameLabel
@onready var _godotVersionLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/GodotVersionLabel
@onready var _projectPathLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer/ProjectPathLabel
@onready var _projectVersionLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer3/ProjectVersionLabel

var _selected = false
var _id = ""

func _ready():
	Signals.connect("ProjectItemSelected", ProjectItemSelected)

func SetProjectVersion(value):
	_projectVersionLabel.text = value
	
func SetProjectPath(value):
	_projectPathLabel.text = value
	
func SetProjectName(value):
	_projectNameLabel.text = value

func SetGodotVersion(value):
	_godotVersionLabel.text = value

func GetProjectVersion():
	return _projectVersionLabel.text
	
func GetProjectPath():
	return _projectPathLabel.text
	
func GetGodotVersion():
	return _godotVersionLabel.text

func GetProjectName():
	return _projectNameLabel.text
	
func SetId(value):
	_id = value

func GetId():
	return _id
	
func ProjectItemSelected(projectItem, _isSelected):
	if projectItem == self:
		return
	
	UnselectProjectItem()

func RestoreDefaultColor():
	color = Color(0.0, 0.0, 0.0, 0.5)

func ShowHoverColor():
	color = Color(0.0, 0.0, 0.0, 0.3)

func ShowSelectedColor():
	color = Color(0.0, 0.0, 0.5, 0.2)

func GetFormattedProjectPath():
	return GetProjectPath().trim_prefix(" ").trim_suffix(" ").to_lower().replace("/", "\\")

func SelectProjectItem():
	ShowSelectedColor()
	_selected = true

func UnselectProjectItem():
	RestoreDefaultColor()
	_selected = false
	
func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _selected:
			_selected = false
			Signals.emit_signal("ProjectItemSelected", self, _selected)
		else:
			_selected = true
			Signals.emit_signal("ProjectItemSelected", self, _selected)

func _on_mouse_entered():
	if _selected:
		return
	
	ShowHoverColor()

func _on_mouse_exited():
	if _selected:
		return
	
	RestoreDefaultColor()
	
