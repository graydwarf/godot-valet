extends ColorRect

var _selected = false
var _projectPath = "adsf"
var _godotPath = "asdf"
var _projectVersion = "asdf"
var _godotVersion = ""

func _ready():
	Signals.connect("ProjectItemClicked", ProjectItemClicked)

func SetProjectPath(value):
	_projectPath = value

func SetGodotVersion(value):
	_godotVersion = value

func SetProjectVersion(value):
	_projectVersion = value
	
func GetProjectPath():
	return _projectPath

func GetGodotPath():
	return _godotPath
	
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

func GetFormattedProjectPath():
	return _projectPath.trim_prefix(" ").trim_suffix(" ").to_lower().replace("/", "\\")
	
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
	
