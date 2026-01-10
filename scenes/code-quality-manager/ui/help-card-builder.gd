# Code Quality Manager - Help Card UI Builder
# Adapted from GDScript Linter for standalone app usage
extends RefCounted
## Creates the Help section card with ignore rules and Claude shortcuts


# Create Help card (returns content to be added to a collapsible card)
func create_card_content(container: VBoxContainer) -> void:
	_add_ignore_rules_section(container)
	_add_separator(container)
	_add_shortcuts_section(container)
	_add_separator(container)
	_add_license_section(container)


func _add_separator(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.35, 0.4, 0.5))
	parent.add_child(sep)


func _add_section_header(parent: VBoxContainer, title: String, description: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	parent.add_child(hbox)

	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.8, 0.82, 0.85))
	hbox.add_child(header)

	var desc := Label.new()
	desc.text = " -   " + description
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.55, 0.57, 0.6))
	hbox.add_child(desc)


func _add_ignore_rules_section(parent: VBoxContainer) -> void:
	_add_section_header(parent, "Ignore Rules", "Suppress warnings for intentional code patterns")

	# Summary table
	_add_ignore_table(parent)

	# Examples for each directive
	_add_thin_separator(parent)
	_add_ignore_example(parent, "gdlint:ignore-file",
		"# gdlint:ignore-file\n# gdlint:ignore-file:file-length,long-function")

	_add_thin_separator(parent)
	_add_ignore_example(parent, "gdlint:ignore-below",
		"# gdlint:ignore-below\n# gdlint:ignore-below:magic-number")

	_add_thin_separator(parent)
	_add_ignore_example(parent, "gdlint:ignore-function",
		"# gdlint:ignore-function\nfunc _debug(): ...\n\n# gdlint:ignore-function:print-statement\nfunc _log(): ...")

	_add_thin_separator(parent)
	_add_ignore_example(parent, "gdlint:ignore-block-start/end",
		"# gdlint:ignore-block-start:magic-number\nvar x = 42\nvar y = 100\n# gdlint:ignore-block-end")

	_add_thin_separator(parent)
	_add_ignore_example(parent, "gdlint:ignore-next-line",
		"# gdlint:ignore-next-line\nvar magic = 42")

	_add_thin_separator(parent)
	_add_ignore_example(parent, "gdlint:ignore-line",
		"var magic = 42  # gdlint:ignore-line\nvar x = 100  # gdlint:ignore-line:magic-number")

	_add_thin_separator(parent)
	_add_ignore_example(parent, "Pinned Exceptions (=value)",
		"# gdlint:ignore-function:long-function=35\nfunc complex(): ...  # Warns if exceeds 35 lines")


func _add_ignore_table(parent: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 2)
	parent.add_child(grid)

	var directives := [
		["gdlint:ignore-file", "Entire file"],
		["gdlint:ignore-below", "Line to EOF"],
		["gdlint:ignore-function", "Entire function"],
		["gdlint:ignore-block-start/end", "Code block"],
		["gdlint:ignore-next-line", "Next line"],
		["gdlint:ignore-line", "Same line"],
	]

	for entry in directives:
		var directive_label := Label.new()
		directive_label.text = entry[0]
		directive_label.add_theme_font_size_override("font_size", 12)
		directive_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.6))
		grid.add_child(directive_label)

		var scope_label := Label.new()
		scope_label.text = entry[1]
		scope_label.add_theme_font_size_override("font_size", 12)
		scope_label.add_theme_color_override("font_color", Color(0.55, 0.57, 0.6))
		grid.add_child(scope_label)


func _add_ignore_example(parent: VBoxContainer, directive: String, code: String) -> void:
	# Directive name as mini-header
	var header := Label.new()
	header.text = directive
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.7, 0.8, 0.6))
	parent.add_child(header)

	# Code example
	var code_label := Label.new()
	code_label.text = code
	code_label.add_theme_font_size_override("font_size", 11)
	code_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	parent.add_child(code_label)


func _add_thin_separator(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	sep.add_theme_color_override("separator", Color(0.25, 0.28, 0.32, 0.4))
	parent.add_child(sep)


func _add_shortcuts_section(parent: VBoxContainer) -> void:
	_add_section_header(parent, "Claude Code Shortcuts", "When Claude Code integration is enabled")

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)

	var shortcuts := [
		["Click", "Plan mode (safe, reviews first)"],
		["Shift+Click", "Immediate mode (fixes directly)"],
		["Right-click", "Context menu with options"]
	]

	for shortcut in shortcuts:
		var key_label := Label.new()
		key_label.text = shortcut[0]
		key_label.add_theme_font_size_override("font_size", 12)
		key_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.6))
		grid.add_child(key_label)

		var desc_label := Label.new()
		desc_label.text = shortcut[1]
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.55, 0.57, 0.6))
		grid.add_child(desc_label)


func _add_license_section(parent: VBoxContainer) -> void:
	var license_lbl := Label.new()
	license_lbl.text = "MIT License - Copyright (c) 2025 Poplava"
	license_lbl.add_theme_font_size_override("font_size", 11)
	license_lbl.add_theme_color_override("font_color", Color(0.45, 0.47, 0.5))
	parent.add_child(license_lbl)
