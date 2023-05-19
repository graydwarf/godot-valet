extends ColorRect

@onready var _projectNameLineEdit = $VBoxContainer/HBoxContainer/ProjectNameLineEdit

func SaveProject():
	var newProjectName = _projectNameLineEdit.text.trim_prefix(" ").trim_suffix(" ")
	if newProjectName == "":
		OS.alert("Invalid project name")
		return
		
	if FileAccess.file_exists("user://" + newProjectName + ".cfg"):
		OS.alert("Project already exists!")
		return
	
	Signals.emit_signal("ProjectRenamed", _projectNameLineEdit.text)
		
	queue_free()

func SetProjectName(projectName):
	_projectNameLineEdit.text = projectName
	
func _on_cancel_button_pressed():
	queue_free()

func _on_save_button_pressed():
	SaveProject()

