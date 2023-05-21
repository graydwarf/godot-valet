extends Panel

@onready var _projectNameLineEdit = $NewProjectDialog/VBoxContainer/HBoxContainer/ProjectNameLineEdit
@onready var _godotVersionLineEdit = $NewProjectDialog/VBoxContainer/GodotVersionHBoxContainer/GodotVersionLineEdit
@onready var _projectPathLineEdit = $NewProjectDialog/VBoxContainer/ProjectPathHBoxContainer2/ProjectPathLineEdit

func CreateNewProject():
	var newProjectName = _projectNameLineEdit.text.trim_prefix(" ").trim_suffix(" ")
	if newProjectName == "":
		OS.alert("Invalid project name. Cancel to close.")
		return
		
	if FileAccess.file_exists("user://" + newProjectName + ".cfg"):
		OS.alert("Project already exists!")
		return
		
	CreateNewSettingsFile(newProjectName)
	queue_free()

func CreateNewSettingsFile(projectName):
	var config = ConfigFile.new()

	config.set_value("ProjectSettings", "project_name", _projectNameLineEdit.text)
	config.set_value("ProjectSettings", "godot_version", _godotVersionLineEdit.text)
	config.set_value("ProjectSettings", "project_path", _projectPathLineEdit.text)
#	config.set_value("ProjectSettings", "project_version", _projectVersionLineEdit.text)

	# Save the config file.
	var err = config.save("user://" + projectName + ".cfg")

	if err != OK:
		OS.alert("An error occurred while saving the config file.")
		
func _on_cancel_button_pressed():
	queue_free()

func _on_save_button_pressed():
	CreateNewProject()

