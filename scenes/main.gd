extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	InitConfigurationFolders()
	var projectManager = load("res://scenes/project-manager/project-manager.tscn").instantiate()
	add_child(projectManager)

func InitConfigurationFolders():
	DirAccess.make_dir_recursive_absolute("user://" + Game.GetProjectItemFolder())
	DirAccess.make_dir_recursive_absolute("user://" + Game.GetGodotVersionItemFolder())

func _notification(notificationType):
	if notificationType == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

func _on_window_close():
	pass
	get_tree().quit()
	
