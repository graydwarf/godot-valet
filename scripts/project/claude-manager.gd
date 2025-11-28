class_name ClaudeManager
extends RefCounted

var _claudeConfigFile = "user://claude-settings.cfg"
var _claudeHistoryFile = "user://claude-history.txt"

# Claude Settings
var _apiKey := ""
var _defaultMaxMessageCount := 20
var _maxMessageCount := _defaultMaxMessageCount
var _isSavingKeyLocally := false

# Chat History
var _fullHistory := []  # Complete conversation history for display
var _conversationHistory := []  # Current session history for API calls

func _init():
	LoadClaudeSettings()
	LoadChatHistory()

func SetClaudeApiKey(apiKey):
	_apiKey = apiKey

func SetIsSavingKeyLocally(isSavingKeyLocally : bool):
	_isSavingKeyLocally = isSavingKeyLocally

func GetIsSavingKeyLocally():
	return _isSavingKeyLocally
	
func SetMaxMessages(maxMessageCount : int):
	_maxMessageCount = maxMessageCount
	
func GetApiKey() -> String:
	return _apiKey

func HasApiKey() -> bool:
	return _apiKey != ""

# Max Message Count Management
func SetMaxMessageCount(count: int):
	if ValidateMaxMessageCount(count):
		_maxMessageCount = count
		SaveClaudeSettings()

func GetMaxMessageCount() -> int:
	return _maxMessageCount

# Chat History Management
func AddUserMessage(message: String):
	var historyEntry = {
		"role": "user",
		"content": message,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	_fullHistory.append(historyEntry)
	_conversationHistory.append({"role": "user", "content": message})
	
	TrimConversationHistory()
	SaveChatHistory()

func AddClaudeMessage(message: String):
	var historyEntry = {
		"role": "assistant", 
		"content": message,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	_fullHistory.append(historyEntry)
	_conversationHistory.append({"role": "assistant", "content": message})
	
	TrimConversationHistory()
	SaveChatHistory()

func GetFullHistory() -> Array:
	return _fullHistory

func GetConversationHistory() -> Array:
	return _conversationHistory

func ClearHistory():
	_fullHistory.clear()
	_conversationHistory.clear()
	SaveChatHistory()

# Keep only the most recent messages for API calls
func TrimConversationHistory():
	var maxMessages = _maxMessageCount * 2  # User + Assistant pairs
	if _conversationHistory.size() > maxMessages:
		_conversationHistory = _conversationHistory.slice(-maxMessages)

func LoadChatHistory():
	if !FileAccess.file_exists(_claudeHistoryFile):
		return
		
	var file = FileAccess.open(_claudeHistoryFile, FileAccess.READ)
	if file:
		var historyText = file.get_as_text()
		file.close()
		
		if historyText.strip_edges() != "":
			var json = JSON.new()
			if json.parse(historyText) == OK:
				_fullHistory = json.data
				
				# Rebuild conversation history from recent full history
				RebuildConversationHistory()

func SaveChatHistory():
	var file = FileAccess.open(_claudeHistoryFile, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_fullHistory, "\t"))
		file.close()

func RebuildConversationHistory():
	_conversationHistory.clear()
	
	# Take the most recent entries for conversation context
	var maxMessages = _maxMessageCount * 2
	var startIndex = max(0, _fullHistory.size() - maxMessages)
	
	for i in range(startIndex, _fullHistory.size()):
		var entry = _fullHistory[i]
		_conversationHistory.append({
			"role": entry.role,
			"content": entry.content
		})

func LoadClaudeSettings():
	if !FileAccess.file_exists(_claudeConfigFile):
		return
		
	var config = ConfigFile.new()
	var err = config.load(_claudeConfigFile)
	if err == OK:
		_apiKey = config.get_value("ClaudeSettings", "api_key", "")
		_isSavingKeyLocally = config.get_value("ClaudeSettings", "save_key_locally", false)
		_maxMessageCount = config.get_value("ClaudeSettings", "max_message_count", _defaultMaxMessageCount)
	else:
		OS.alert("An error occurred loading the Claude configuration file")
	
func SaveClaudeSettings():
	var config = ConfigFile.new()
	
	if FileAccess.file_exists(_claudeConfigFile):
		config.load(_claudeConfigFile)

	if _isSavingKeyLocally:
		config.set_value("ClaudeSettings", "api_key", _apiKey)
	else:
		config.set_value("ClaudeSettings", "api_key", "")
	
	config.set_value("ClaudeSettings", "max_message_count", _maxMessageCount)
	config.set_value("ClaudeSettings", "save_key_locally", _isSavingKeyLocally)
	
	var err = config.save(_claudeConfigFile)
	if err != OK:
		OS.alert("An error occurred while saving the Claude config file.")

func ValidateMaxMessageCount(value) -> bool:
	var numberValue = 0
	
	if value is String:
		if value.is_valid_int():
			numberValue = value.to_int()
		elif value.is_valid_float():
			numberValue = int(value.to_float())
		else:
			print("Warning: Max message count must be a valid number")
			return false
	elif value is int or value is float:
		numberValue = int(value)
	else:
		print("Warning: Max message count must be a valid number")
		return false
	
	if numberValue > 20:
		print("Warning: Max message count over 20 may result in high API costs")
	
	if numberValue < 1:
		print("Warning: Max message count must be at least 1")
		return false
	
	return true
