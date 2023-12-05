extends Control

func CloseDialog():
	queue_free()
	
func SaveChanges():
	var sourceFilterLines = GetLinesFromRichTextLabel()
	Signals.emit_signal("SaveSourceFilterChanges", sourceFilterLines)
	CloseDialog()

func AddSourceFilters(listOfSourceFilters):
	for filter in listOfSourceFilters:
		%TextEdit.text += filter + "\n"
	
func GetLinesFromRichTextLabel():
	var allowEmpty = false
	return %TextEdit.text.split("\n", allowEmpty)

func _on_cancel_button_pressed() -> void:
	CloseDialog()

func _on_save_button_pressed() -> void:
	SaveChanges()
