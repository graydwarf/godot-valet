extends Panel

@onready var _licenseTextEdit = $CenterContainer/Panel/VBoxContainer/ScrollContainer/MarginContainer2/CardsVBox/LicensesCard/VBoxContainer/LicenseTextEdit

const FLUENT_UI_LICENSE = """MIT License

Copyright (c) 2020 Microsoft Corporation

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE."""

func _ready():
	LoadLicenseText()
	LoadTheme()

func LoadTheme():
	theme = load(App.GetThemePath())

func LoadLicenseText():
	var fullText = """Godot Valet uses icons from Microsoft's Fluent UI System Icons library.

====================================================================

"""
	fullText += FLUENT_UI_LICENSE
	_licenseTextEdit.text = fullText

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
