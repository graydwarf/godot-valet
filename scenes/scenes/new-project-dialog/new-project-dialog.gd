extends Panel

@onready var _projectNameLineEdit = $NewProjectDialog/VBoxContainer/HBoxContainer/ProjectNameLineEdit

func AttemptNewProject():
	var newProjectName = _projectNameLineEdit.text.trim_prefix(" ").trim_suffix(" ")
	if newProjectName == "":
		OS.alert("Invalid project name. Cancel to close.")
		return
		
	if FileAccess.file_exists("user://" + newProjectName + ".cfg"):
		OS.alert("Project already exists!")
		return
		
	Signals.emit_signal("CreateNewProject", _projectNameLineEdit.text)
	queue_free()
	
func _on_cancel_button_pressed():
	queue_free()

func _on_save_button_pressed():
	AttemptNewProject()

