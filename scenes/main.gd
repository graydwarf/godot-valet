extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	InitConfigurationFolders()
	var projectManager = load("res://scenes/project-manager/project-manager.tscn").instantiate()
	add_child(projectManager)

func InitConfigurationFolders():
	DirAccess.make_dir_recursive_absolute("user://" + Game.GetProjectItemFolder())
	DirAccess.make_dir_recursive_absolute("user://" + Game.GetGodotVersionItemFolder())
