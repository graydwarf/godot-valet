extends Panel

@onready var _licenseTextEdit = $CenterContainer/Panel/VBoxContainer/ScrollContainer/MarginContainer2/CardsVBox/LicensesCard/VBoxContainer/LicenseTextEdit

func _ready():
	LoadLicenseText()
	LoadTheme()

func LoadTheme():
	theme = load(App.GetThemePath())

func LoadLicenseText():
	var licensePath = "res://scenes/file-tree-view-explorer/assets/fluent-icons/FLUENT_UI_LICENSE.txt"
	var file = FileAccess.open(licensePath, FileAccess.READ)

	if file:
		var licenseText = file.get_as_text()
		file.close()

		var fullText = """Godot Valet uses icons from Microsoft's Fluent UI System Icons library.

====================================================================

"""
		fullText += licenseText

		_licenseTextEdit.text = fullText
	else:
		_licenseTextEdit.text = "Error: Unable to load license file at " + licensePath

func _on_close_button_pressed():
	queue_free()

func _on_discord_button_pressed():
	OS.shell_open("https://discord.gg/9GnrTKXGfq")

func _on_github_button_pressed():
	OS.shell_open("https://github.com/graydwarf/godot-valet")

func _on_more_tools_button_pressed():
	OS.shell_open("https://poplava.itch.io")

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		queue_free()
		get_viewport().set_input_as_handled()
