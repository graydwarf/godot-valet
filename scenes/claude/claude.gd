extends Control
class_name Claude

# At the top of your script
const CLAUDE_API_KEY = ""  # Replace with your actual key
const CLAUDE_API_URL = "https://api.anthropic.com/v1/messages"

func _ready():
	# Connect the HTTP request completion signal
	%HttpRequest.request_completed.connect(_on_http_request_completed)

	# Connect your LineEdit's text_submitted signal
	%InputLineEdit.text_submitted.connect(SubmitInput)

func SubmitInput(a):
	var textInput = %InputLineEdit.text
	if textInput.strip_edges().is_empty():
		return

	# Clear input and show user message
	%InputLineEdit.clear()
	%OutputTextEdit.text += "You: " + textInput + "\n\n"

	# Send to Claude API
	SendToClaude(textInput)

func SendToClaude(textInput: String):
	var headers = [
		"Content-Type: application/json",
		"x-api-key: " + CLAUDE_API_KEY,
		"anthropic-version: 2023-06-01"
	]
	
	var body = {
		"model": "claude-3-5-sonnet-20241022",  # Updated model name
		"max_tokens": 1024,
		"messages": [
			{
				"role": "user",
				"content": textInput
			}
		]
	}
	var json_body = JSON.stringify(body)
	%HttpRequest.request(CLAUDE_API_URL, headers, HTTPClient.METHOD_POST, json_body)

func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())

		if parse_result == OK:
			var response_data = json.get_data()
			var claude_response = response_data.content[0].text
			%OutputTextEdit.text += "Claude: " + claude_response + "\n\n"
		else:
			%OutputTextEdit.text += "Error parsing response\n\n"
	else:
		%OutputTextEdit.text += "API Error: " + str(response_code) + "\n\n"
		
func _on_input_line_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			SubmitInput("a")
