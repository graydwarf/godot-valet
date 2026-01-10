# Code Quality Manager - Collapsible Card Component
# Adapted from GDScript Linter for standalone app usage
extends VBoxContainer
## A card that can be collapsed/expanded with persistent state
## Structure: Header panel (always visible) + Body panel (shown when expanded)

signal toggled(is_collapsed: bool)

var title: String = ""
var setting_key: String = ""
var collapsed: bool = true:
	set(value):
		collapsed = value
		_update_collapsed_state()

var _header_panel: PanelContainer
var _body_panel: PanelContainer
var _content_container: VBoxContainer
var _icon_label: Label


func _init(p_title: String = "", p_setting_key: String = "") -> void:
	title = p_title
	setting_key = p_setting_key


func _ready() -> void:
	_load_collapsed_state()


# Returns the content container for adding child controls (lazy initialization)
func get_content_container() -> VBoxContainer:
	if _content_container == null:
		_setup_card()
	return _content_container


func _setup_card() -> void:
	add_theme_constant_override("separation", 0)

	# Header panel (always visible, clickable)
	_header_panel = PanelContainer.new()
	_header_panel.name = "HeaderPanel"
	_header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_header_panel.gui_input.connect(_on_header_gui_input)
	add_child(_header_panel)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 6)
	_header_panel.add_child(header_hbox)

	# Expand/collapse icon (using Unicode arrows instead of editor theme icons)
	_icon_label = Label.new()
	_icon_label.add_theme_font_size_override("font_size", 14)
	_icon_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.75))
	_icon_label.custom_minimum_size = Vector2(16, 16)
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_hbox.add_child(_icon_label)

	# Title label
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_label)

	# Body panel (shown when expanded)
	_body_panel = PanelContainer.new()
	_body_panel.name = "BodyPanel"
	_body_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_body_panel)

	# Content container inside body
	_content_container = VBoxContainer.new()
	_content_container.name = "ContentContainer"
	_content_container.add_theme_constant_override("separation", 8)
	_body_panel.add_child(_content_container)

	_update_styles()
	_update_collapsed_state()


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			collapsed = not collapsed
			_save_collapsed_state()
			toggled.emit(collapsed)
			accept_event()


func _update_collapsed_state() -> void:
	if _icon_label:
		_icon_label.text = "▶" if collapsed else "▼"
	if _body_panel:
		_body_panel.visible = not collapsed
	_update_styles()


func _update_styles() -> void:
	if not _header_panel:
		return

	# Header style - rounded top corners, bottom border only when expanded
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.145, 0.169, 0.204, 1.0)  # #252B34
	header_style.border_color = Color(0.3, 0.35, 0.45, 0.5)
	header_style.set_border_width_all(1)
	header_style.set_content_margin_all(12)

	if collapsed:
		# Collapsed: all corners rounded
		header_style.set_corner_radius_all(6)
	else:
		# Expanded: only top corners rounded, bottom has separator line
		header_style.corner_radius_top_left = 6
		header_style.corner_radius_top_right = 6
		header_style.corner_radius_bottom_left = 0
		header_style.corner_radius_bottom_right = 0
		header_style.border_width_bottom = 1

	_header_panel.add_theme_stylebox_override("panel", header_style)

	if _body_panel:
		# Body style - rounded bottom corners, no top corners
		var body_style := StyleBoxFlat.new()
		body_style.bg_color = Color(0.145, 0.169, 0.204, 1.0)  # #252B34
		body_style.border_color = Color(0.3, 0.35, 0.45, 0.5)
		body_style.set_border_width_all(1)
		body_style.border_width_top = 0  # No top border (header has bottom)
		body_style.corner_radius_top_left = 0
		body_style.corner_radius_top_right = 0
		body_style.corner_radius_bottom_left = 6
		body_style.corner_radius_bottom_right = 6
		body_style.set_content_margin_all(12)
		_body_panel.add_theme_stylebox_override("panel", body_style)


func _load_collapsed_state() -> void:
	if setting_key.is_empty():
		return
	# Use App singleton for global settings storage
	collapsed = App.GetCodeQualityCardCollapseState(setting_key, true)


func _save_collapsed_state() -> void:
	if setting_key.is_empty():
		return
	# Use App singleton for global settings storage
	App.SetCodeQualityCardCollapseState(setting_key, collapsed)
