extends Control
class_name Claude

# claude.gd
# - Generated with assistance from Claude 4 Sonnet (Anthropic) - December 2024

const CLAUDE_API_URL = "https://api.anthropic.com/v1/messages"

var _claudeManager: ClaudeManager

# Output Animations
var _typingSpeed = 0.001  # Can't go much faster.
var _isTyping = false
var _busyTween : Tween = null

# Debugging Options
# If true, skip claude and load local test file for testing output formats.
# If true, claude-testing-output.txt gets loaded on initial use.
var _isDebuggingOutput = false 
var _claudeTestResponse := "" 

func _ready():
	InitSignals()
	InitClaudeManager()
	%InputLineEdit.grab_focus()
	
func InitSignals():
	%HttpRequest.request_completed.connect(_on_http_request_completed)
	%InputLineEdit.text_submitted.connect(SubmitInput)

func InitClaudeManager():
	_claudeManager = ClaudeManager.new()
	LoadClaudeHistory()

# Iterate through full history and display
func LoadClaudeHistory():
	var fullHistory = _claudeManager.GetFullHistory()
	for entry in fullHistory:
		if entry.role == "user":
			%OutputRichTextLabel.text += "[color=#00FFFF][b]You:[/b][/color] " + entry.content + "\n\n"
		elif entry.role == "assistant":
			%OutputRichTextLabel.text += "[color=orange][b]Claude:[/b][/color] " + entry.content + "\n\n"

func AnimateClaudeBusy():
	_busyTween = create_tween()
	_busyTween.set_loops()
	_busyTween.tween_property(%ClaudeTextureRect, "self_modulate", Color(1.0, 1.0, 1.0, 0.5), 0.6)
	_busyTween.tween_property(%ClaudeTextureRect, "self_modulate", Color(1.0, 1.0, 1.0, 1.0), 0.6)

func StopAnimatingClaudeBusy():
	if _busyTween == null:
		return
		
	_busyTween.stop()
	%ClaudeTextureRect.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	
func SaveClaudeSettings(claudeApiKey : String, isStoringApiKeyLocally : bool = false, maxMessages : int = 1):
	_claudeManager.SetClaudeApiKey(claudeApiKey)
	_claudeManager.SetIsSavingKeyLocally(isStoringApiKeyLocally)
	_claudeManager.SetMaxMessages(maxMessages)
	_claudeManager.SaveClaudeSettings()
		
func SubmitInput(textInput : String):
	if textInput.strip_edges().is_empty():
		return

	AnimateClaudeBusy()
	
	var message = "[color=#00FFFF][b]You:[/b][/color] " + textInput + "\n\n"
	_claudeManager.AddUserMessage(message)
	%InputLineEdit.placeholder_text = "" # Only needed before for first input
	%InputLineEdit.clear()
	%OutputRichTextLabel.text += message
	
	if _isDebuggingOutput:
		AnimateClaudeResponse(LoadClaudeTestResponse(), Enums.ClaudeResponseType.Line)
	else:
		SendToClaude(textInput)

func OpenClaudeSettings():
	var claudeSettings = load("res://scenes/claude-settings/claude-settings.tscn").instantiate()
	add_child(claudeSettings)
	claudeSettings.connect("SaveClaudeSettings", SaveClaudeSettings)
	claudeSettings.InitClaudeSettings(_claudeManager.GetApiKey(), _claudeManager.GetIsSavingKeyLocally(), _claudeManager.GetMaxMessageCount())

func AnimateClaudeResponse(claudeResponse: String, animationType = Enums.ClaudeResponseType.Line):
	if _isTyping:
		return
	
	_isTyping = true
	
	%OutputRichTextLabel.text += "[color=orange][b]Claude:[/b][/color] "
	var responseStartPos = %OutputRichTextLabel.text.length()
	
	match animationType:
		Enums.ClaudeResponseType.Character:
			await AnimateByCharacter(claudeResponse, responseStartPos)
		Enums.ClaudeResponseType.Word:
			await AnimateByWords(claudeResponse, responseStartPos)
		Enums.ClaudeResponseType.Line:
			await AnimateByLines(claudeResponse, responseStartPos)
	
	%OutputRichTextLabel.text += "\n\n"
	_isTyping = false
	StopAnimatingClaudeBusy()
	_claudeManager.AddClaudeMessage(claudeResponse)

# Character-by-character output
func AnimateByCharacter(claudeResponse: String, startPos: int):
	for i in range(claudeResponse.length()):
		%OutputRichTextLabel.text = %OutputRichTextLabel.text.substr(0, startPos) + claudeResponse.substr(0, i + 1)
		await get_tree().create_timer(_typingSpeed).timeout

# Word-by-word output
func AnimateByWords(claudeResponse: String, startPos: int):
	var words = claudeResponse.split(" ")
	var currentText = ""
	
	for i in range(words.size()):
		currentText += words[i]
		if i < words.size() - 1:
			currentText += " "
		
		%OutputRichTextLabel.text = %OutputRichTextLabel.text.substr(0, startPos) + currentText
		await get_tree().create_timer(_typingSpeed * 3).timeout

# Line-by-line output
func AnimateByLines(claudeResponse: String, startPos: int):
	var lines = claudeResponse.split("\n")
	var currentText = ""
	
	for lineIndex in range(lines.size()):
		var line = lines[lineIndex]
		
		# Add the entire line at once
		currentText += line
		
		# Add newline after each line (except the last)
		if lineIndex < lines.size() - 1:
			currentText += "\n"
		
		# Update display with all lines so far
		%OutputRichTextLabel.text = %OutputRichTextLabel.text.substr(0, startPos) + currentText
		
		# Wait before showing next line
		await get_tree().create_timer(_typingSpeed * 10).timeout  # Longer pause between lines

func AddUserMessage(userMessage: String):
	%OutputRichTextLabel.text += userMessage + "\n\n"

func LoadClaudeTestResponse() -> String:
	if _claudeTestResponse == "":
		var filePath = "res://scenes/claude/assets/claude-testing-output.txt"
		
		if FileAccess.file_exists(filePath):
			var file = FileAccess.open(filePath, FileAccess.READ)
			if file:
				_claudeTestResponse = file.get_as_text()
				file.close()
			else:
				OS.alert("Failed to open claude test response file")
		else:
			OS.alert("Claude test response file not found at: ", filePath)
	
	return _claudeTestResponse

func TestClaudeResponse():
	var testResponse = LoadClaudeTestResponse()
	AnimateClaudeResponse(testResponse, Enums.ClaudeResponseType.Character)

func ClearConversationHistory():
	_claudeManager.ClearHistory()
	%OutputRichTextLabel.text = ""

func TrimConversationHistory():
	_claudeManager.TrimConversationHistory()

# Add user message to history
func SendToClaude(textInput: String):
	_claudeManager.GetConversationHistory().append({
		"role": "user",
		"content": textInput
	})
	
	var headers = [
		"Content-Type: application/json",
		"x-api-key: " + _claudeManager.GetApiKey(),
		"anthropic-version: 2023-06-01"
	]
	
	var body = {
		"model": "claude-3-5-sonnet-20241022",
		"max_tokens": 1024,
		"messages": _claudeManager.GetConversationHistory()
	}
	
	var jsonBody = JSON.stringify(body)
	%HttpRequest.request(CLAUDE_API_URL, headers, HTTPClient.METHOD_POST, jsonBody)

func _on_http_request_completed(_result: int, responseCode: int, _headers: PackedStringArray, body: PackedByteArray):
	if responseCode == 200:
		var json = JSON.new()
		var parseResult = json.parse(body.get_string_from_utf8())
		if parseResult == OK:
			var responseData = json.get_data()
			var claudeResponse = responseData.content[0].text
			
			# Add Claude's response to history
			_claudeManager.GetConversationHistory().append({
				"role": "assistant",
				"content": claudeResponse
			})
			
			AnimateClaudeResponse(claudeResponse, Enums.ClaudeResponseType.Line)
		else:
			%OutputRichTextLabel.text += "Error parsing response\n\n"
			StopAnimatingClaudeBusy()
	else:
		%OutputRichTextLabel.text += "API Error: " + str(responseCode) + "\n\n"
		if str(responseCode) == "401":
			%OutputRichTextLabel.text += "Did you configure the Claude API Key in settings (bottom right)?"
			
		StopAnimatingClaudeBusy()
	
func _on_texture_button_pressed() -> void:
	OpenClaudeSettings()

func _on_close_texture_button_pressed() -> void:
	queue_free()
