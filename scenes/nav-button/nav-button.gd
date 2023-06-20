extends Button
#
# Note: This nav-button is used to dynamically create the 
# godot launch buttons (v3.5.x) on the Project Management form.
#
var _customVar1

func SetCustomVar1(value):
	_customVar1 = value

func GetCustomVar1():
	return _customVar1
