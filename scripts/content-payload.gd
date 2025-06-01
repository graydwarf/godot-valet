extends Node
class_name ContentPayload

var _content
var _preservedStrings
var _preservedSpecialStrings

func SetContent(v):
	_content = v

func SetPreservedStrings(v):
	_preservedStrings = v

func SetPreservedSpecialStrings(v):
	_preservedSpecialStrings = v
	
func GetContent() -> String:
	return _content

func GetPreservedStrings():
	return _preservedStrings

func GetPreservedSpecialStrings():
	return _preservedSpecialStrings
