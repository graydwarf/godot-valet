extends Control
class_name ClaudeSettings

signal SaveClaudeSettings

func InitClaudeSettings(claudeApiKey : String = "", isSavingKeyLocally : bool = false, maxMessageCount := 1):
	%ApiKeyLineEdit.text = claudeApiKey
	%SaveLocallyCheckBox.button_pressed = isSavingKeyLocally
	%SendContextAmountLineEdit.text = str(maxMessageCount)

# Check if it's a valid number
func IsMaxMessageCountValid(value) -> bool:
	var numberValue = 0
	
	if value.is_valid_int():
		numberValue = value.to_int()
	elif value.is_valid_float():
		OS.alert("Invalid integer.")
		return false
	else:
		OS.alert("Invalid integer.")
		return false

	# Check if too low
	if numberValue < 1:
		OS.alert("Warning: Max message count must be at least 1")
		return false
		
	# Check if over 20 just to make sure someone doesn't get crazy without realizing.
	if numberValue > 20:
		OS.alert("Note: The higher the 'Max Messages', the higher the API cost per transaction.")
	
	return true
	
func _on_back_button_pressed() -> void:
	var maxMessages = %SendContextAmountLineEdit.text
	if IsMaxMessageCountValid(maxMessages):
		emit_signal("SaveClaudeSettings", %ApiKeyLineEdit.text, %SaveLocallyCheckBox.button_pressed, maxMessages.to_int())
		queue_free()
