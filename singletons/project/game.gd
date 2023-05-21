extends Node

var _defaultColor = Color(0.34, 0.17, 0.19)
var _projectItemFolder = "project-items"
var _godotVersionItemFolder = "godot-version-items"

func _ready():
	pass # Replace with function body.

func GetProjectItemFolder():
	return _projectItemFolder

func GetGodotVersionItemFolder():
	return _godotVersionItemFolder
	
func GetDefaultBackgroundColor():
	return _defaultColor
