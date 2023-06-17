extends Panel

func _ready():
	InitSignals()
	LoadTheme()
	LoadBackgroundColor(App.GetBackgroundColor())

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

func _on_close_button_pressed():
	App.SaveSolutionSettings()
	Signals.emit_signal("BackgroundColorChanged", App.GetBackgroundColor())
	queue_free()

# Reminder: Uses custom ColorPickerDialog
func _on_change_background_color_button_pressed():
	var colorPickerDialog = load("res://scenes/color-picker-dialog/color-picker-dialog.tscn").instantiate()
	add_child(colorPickerDialog)
	colorPickerDialog.position = Vector2(400, 50)
	colorPickerDialog.SetDefaultColor(App.GetBackgroundColor())

