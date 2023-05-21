extends ColorRect

@onready var _godotVersionNameLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer2/GodotVersionNameLabel
@onready var _godotPathLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer/GodotPathLabel
var _godotVersion = ""
var _godotPath = ""

func GetGodotVersion():
	return _godotVersion

func GetGodotPath():
	return _godotPath

func SetGodotVersion(value):
	_godotVersion = value
	_godotVersionNameLabel.text = value

func SetGodotPath(value):
	_godotPath = value
	_godotPathLable.text = value

