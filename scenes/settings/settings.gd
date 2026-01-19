extends Panel

const CLAUDE_CONFIG_FILE = "user://claude-settings.cfg"

func _ready():
	InitSignals()
	LoadTheme()
	LoadBackgroundColor(App.GetBackgroundColor())
	LoadClaudeCodeCommand()
	LoadClaudeCodeButtonEnabled()
	LoadClaudeApiChatButtonEnabled()
	LoadClaudeApiChatSettings()
	LoadClaudeMonitorCommand()
	LoadClaudeMonitorButtonEnabled()

func InitSignals():
	Signals.connect("BackgroundColorTemporarilyChanged", BackgroundColorTemporarilyChanged)
	
func BackgroundColorTemporarilyChanged(color = null):
	if color == null:
		color = App.GetBackgroundColor()
	
	LoadBackgroundColor(color)
	
func LoadBackgroundColor(color = null):
	var style_box = theme.get_stylebox("panel", "Panel") as StyleBoxFlat

	if style_box:
		style_box.bg_color = color
	
func LoadTheme():
	theme = load(App.GetThemePath())
	
func OpenGodotVersionManager():
	var godotVersionManager = load("res://scenes/godot-version-manager/godot-version-manager.tscn").instantiate()
	add_child(godotVersionManager)

func _on_open_godot_version_manager_button_pressed():
	OpenGodotVersionManager()

func LoadClaudeCodeCommand():
	%ClaudeCodeLineEdit.text = App.GetClaudeCodeLaunchCommand()

func LoadClaudeCodeButtonEnabled():
	%ClaudeCodeEnabledCheckBox.button_pressed = App.GetClaudeCodeButtonEnabled()

func LoadClaudeApiChatButtonEnabled():
	%ClaudeApiChatEnabledCheckBox.button_pressed = App.GetClaudeApiChatButtonEnabled()

func SaveClaudeCodeCommand():
	var command = %ClaudeCodeLineEdit.text.strip_edges()
	if command.is_empty():
		command = App.GetDefaultClaudeCodeLaunchCommand()
	App.SetClaudeCodeLaunchCommand(command)

func _on_reset_button_pressed():
	%ClaudeCodeLineEdit.text = App.GetDefaultClaudeCodeLaunchCommand()

func _on_claude_code_enabled_check_box_toggled(toggled_on: bool):
	App.SetClaudeCodeButtonEnabled(toggled_on)
	Signals.emit_signal("ClaudeCodeButtonEnabledChanged", toggled_on)

func _on_claude_api_chat_enabled_check_box_toggled(toggled_on: bool):
	App.SetClaudeApiChatButtonEnabled(toggled_on)
	Signals.emit_signal("ClaudeApiChatButtonEnabledChanged", toggled_on)

func LoadClaudeApiChatSettings():
	if not FileAccess.file_exists(CLAUDE_CONFIG_FILE):
		return

	var config = ConfigFile.new()
	var err = config.load(CLAUDE_CONFIG_FILE)
	if err == OK:
		%ClaudeApiKeyLineEdit.text = config.get_value("ClaudeSettings", "api_key", "")
		%ClaudeApiSaveLocallyCheckBox.button_pressed = config.get_value("ClaudeSettings", "save_key_locally", false)
		%ClaudeApiMaxMessagesLineEdit.text = str(config.get_value("ClaudeSettings", "max_message_count", 20))

func SaveClaudeApiChatSettings():
	var config = ConfigFile.new()

	if FileAccess.file_exists(CLAUDE_CONFIG_FILE):
		config.load(CLAUDE_CONFIG_FILE)

	var save_locally = %ClaudeApiSaveLocallyCheckBox.button_pressed
	if save_locally:
		config.set_value("ClaudeSettings", "api_key", %ClaudeApiKeyLineEdit.text)
	else:
		config.set_value("ClaudeSettings", "api_key", "")

	config.set_value("ClaudeSettings", "save_key_locally", save_locally)

	var max_messages = %ClaudeApiMaxMessagesLineEdit.text
	if max_messages.is_valid_int():
		var max_val = max_messages.to_int()
		if max_val >= 1:
			config.set_value("ClaudeSettings", "max_message_count", max_val)

	config.save(CLAUDE_CONFIG_FILE)

func LoadClaudeMonitorCommand():
	%ClaudeMonitorLineEdit.text = App.GetClaudeMonitorLaunchCommand()

func LoadClaudeMonitorButtonEnabled():
	%ClaudeMonitorEnabledCheckBox.button_pressed = App.GetClaudeMonitorButtonEnabled()

func SaveClaudeMonitorCommand():
	var command = %ClaudeMonitorLineEdit.text.strip_edges()
	if command.is_empty():
		command = App.GetDefaultClaudeMonitorLaunchCommand()
	App.SetClaudeMonitorLaunchCommand(command)

func _on_claude_monitor_reset_button_pressed():
	%ClaudeMonitorLineEdit.text = App.GetDefaultClaudeMonitorLaunchCommand()

func _on_claude_monitor_enabled_check_box_toggled(toggled_on: bool):
	App.SetClaudeMonitorButtonEnabled(toggled_on)
	Signals.emit_signal("ClaudeMonitorButtonEnabledChanged", toggled_on)

func _on_claude_monitor_github_button_pressed():
	OS.shell_open("https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor")

func _on_close_button_pressed():
	SaveClaudeCodeCommand()
	SaveClaudeApiChatSettings()
	SaveClaudeMonitorCommand()
	App.SaveSolutionSettings()
	Signals.emit_signal("BackgroundColorChanged", App.GetBackgroundColor())
	queue_free()

# Reminder: Uses custom ColorPickerDialog
func _on_change_background_color_button_pressed():
	var colorPickerDialog = load("res://scenes/color-picker-dialog/color-picker-dialog.tscn").instantiate()
	add_child(colorPickerDialog)
	colorPickerDialog.position = Vector2(400, 50)
	colorPickerDialog.SetDefaultColor(App.GetBackgroundColor())
