# gdlint:ignore-file:file-length
extends Panel

# Preload analyzer scripts
const QubeAnalyzer = preload("res://scripts/code-quality/code-analyzer.gd")
const QubeConfig = preload("res://scripts/code-quality/analysis-config.gd")
const QubeIssue = preload("res://scripts/code-quality/issue.gd")
const QubeResult = preload("res://scripts/code-quality/analysis-result.gd")
const SettingsCardBuilderScript = preload("res://scenes/code-quality-manager/ui/settings-card-builder.gd")
const SettingsManagerScript = preload("res://scenes/code-quality-manager/ui/settings-manager.gd")

const ISSUES_PER_CATEGORY := 100

# Issue type display names mapped to check_ids
const ISSUE_TYPES := {
	"all": "All Types",
	"file-length": "File Length",
	"long-function": "Long Function",
	"long-line": "Long Line",
	"todo-comment": "TODO/FIXME",
	"print-statement": "Print Statement",
	"empty-function": "Empty Function",
	"magic-number": "Magic Number",
	"commented-code": "Commented Code",
	"missing-type-hint": "Missing Type Hint",
	"missing-return-type": "Missing Return Type",
	"too-many-params": "Too Many Params",
	"deep-nesting": "Deep Nesting",
	"high-complexity": "High Complexity",
	"god-class": "God Class",
	"naming-class": "Naming: Class",
	"naming-function": "Naming: Function",
	"naming-signal": "Naming: Signal",
	"naming-const": "Naming: Constant",
	"naming-enum": "Naming: Enum",
	"unused-variable": "Unused Variable",
	"unused-parameter": "Unused Parameter"
}

# UI References - Project Card Header
@onready var _thumbTextureRect: TextureRect = %ThumbTextureRect
@onready var _projectNameLabel: Label = %ProjectNameLabel
@onready var _projectPathLabel: Label = %ProjectPathLabel
@onready var _folderButton: Button = %FolderButton
@onready var _lastScannedLabel: Label = %LastScannedLabel

# UI References - Toolbar and main UI
@onready var _scanButton: Button = %ScanButton
@onready var _exportJSONButton: Button = %ExportJSONButton
@onready var _exportHTMLButton: Button = %ExportHTMLButton
@onready var _settingsButton: Button = %SettingsButton
@onready var _severityFilter: OptionButton = %SeverityFilter
@onready var _typeFilter: OptionButton = %TypeFilter
@onready var _fileFilter: LineEdit = %FileFilter
@onready var _resultsLabel: RichTextLabel = %ResultsLabel
@onready var _settingsPanel: PanelContainer = %SettingsPanel
@onready var _resultsScroll: ScrollContainer = %ResultsScroll

# UI References - Report Card
@onready var _reportCard: PanelContainer = %ReportCard
@onready var _headerContainer: PanelContainer = %HeaderContainer
@onready var _contentContainer: PanelContainer = %ContentContainer
@onready var _headerLabel: Label = %HeaderLabel

# Busy overlay
var _busy_overlay: Control
var _busy_spinner: Label
var _busy_animation_timer: Timer
var _spinner_frames := ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
var _spinner_frame_index: int = 0

# State
var _selectedProjectItem = null
var _currentConfig: Resource = null
var _currentResult = null
var _lastScannedTimestamp: String = ""

# Filter state
var _currentSeverityFilter: String = "all"
var _currentTypeFilter: String = "all"
var _currentFileFilter: String = ""

# Claude button interaction state
var _hovered_claude_link: String = ""
var _claude_context_menu: PopupMenu
var _claude_tooltip: PanelContainer
var _grouped_issues_by_type: Dictionary = {}  # check_id -> Array of issues
var _grouped_issues_by_severity: Dictionary = {}  # severity -> Array of issues

# Claude customize dialog
var _claude_customize_popup: PanelContainer
var _claude_customize_context: RichTextLabel
var _claude_customize_command: LineEdit
var _claude_customize_instructions: TextEdit
var _claude_customize_pending_link: String = ""
var _claude_context_menu_link: String = ""

# Settings manager and controls
var _settings_manager: RefCounted
var _settings_controls: Dictionary = {}

# Track if checks changed while settings panel was open
var _checks_changed_while_settings_open: bool = false


func _ready():
	_init_config_and_settings_panel()
	_init_settings_manager()
	_setup_filters()
	_connect_signals()
	_setup_claude_context_menu()
	_setup_claude_tooltip()
	_setup_claude_customize_popup()
	_apply_initial_visibility()
	_add_results_styling()
	_setup_busy_overlay()


func _init_config_and_settings_panel() -> void:
	_currentConfig = QubeConfig.new()
	var reset_icon = load("res://scenes/code-quality-manager/assets/arrow-reset.svg")
	var card_builder = SettingsCardBuilderScript.new(reset_icon)
	card_builder.build_settings_panel(_settingsPanel, _settings_controls)


func _init_settings_manager() -> void:
	_settings_manager = SettingsManagerScript.new(_currentConfig)
	_settings_manager.controls = _settings_controls
	_settings_manager.display_refresh_needed.connect(_on_display_refresh_needed)
	_settings_manager.setting_changed.connect(_on_setting_changed)
	_settings_manager.connect_controls(_exportJSONButton, _exportHTMLButton)


func _setup_filters() -> void:
	_severityFilter.clear()
	_severityFilter.add_item("All Severities", 0)
	_severityFilter.add_item("Critical", 1)
	_severityFilter.add_item("Warnings", 2)
	_severityFilter.add_item("Info", 3)
	_populate_type_filter()


func _connect_signals() -> void:
	_resultsLabel.meta_underlined = false
	_resultsLabel.meta_clicked.connect(_on_link_clicked)
	_resultsLabel.meta_hover_started.connect(_on_meta_hover_started)
	_resultsLabel.meta_hover_ended.connect(_on_meta_hover_ended)
	_resultsLabel.gui_input.connect(_on_results_gui_input)
	_severityFilter.item_selected.connect(_on_severity_filter_changed)
	_typeFilter.item_selected.connect(_on_type_filter_changed)
	_fileFilter.text_changed.connect(_on_file_filter_changed)


func _apply_initial_visibility() -> void:
	_exportJSONButton.visible = _settings_manager.show_json_export
	_exportHTMLButton.visible = _settings_manager.show_html_export
	_exportJSONButton.disabled = true
	_exportHTMLButton.disabled = true
	_settingsPanel.visible = false


func _add_results_styling() -> void:
	var results_style := StyleBoxFlat.new()
	results_style.bg_color = Color(0, 0, 0, 0)
	_resultsLabel.add_theme_stylebox_override("normal", results_style)
	_style_report_card()
	_style_scrollbar()


func _style_report_card() -> void:
	# Get base background color and darken slightly for card
	var base_color := Color(0.18, 0.20, 0.25)  # Default dark theme approximation
	var card_bg := base_color.darkened(0.08)

	# Style outer card panel (rounded corners, border)
	var card_theme := Theme.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = card_bg
	card_style.border_color = Color(0.6, 0.6, 0.6)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(6)
	card_theme.set_stylebox("panel", "PanelContainer", card_style)
	_reportCard.theme = card_theme

	# Style header container (transparent bg, bottom border only)
	var header_theme := Theme.new()
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0, 0, 0, 0)
	header_style.border_color = Color(0.6, 0.6, 0.6)
	header_style.border_width_bottom = 1
	header_theme.set_stylebox("panel", "PanelContainer", header_style)
	_headerContainer.theme = header_theme

	# Style content container (transparent)
	var content_theme := Theme.new()
	var content_style := StyleBoxFlat.new()
	content_style.bg_color = Color(0, 0, 0, 0)
	content_theme.set_stylebox("panel", "PanelContainer", content_style)
	_contentContainer.theme = content_theme


func _style_scrollbar() -> void:
	# Match scrollbar width to Project Manager style (20px)
	var scrollbar := _resultsScroll.get_v_scroll_bar()
	if scrollbar:
		scrollbar.custom_minimum_size.x = 20


func _setup_busy_overlay() -> void:
	# Create overlay container that covers the entire panel
	_busy_overlay = Control.new()
	_busy_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_busy_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block all mouse input
	_busy_overlay.visible = false
	_busy_overlay.z_index = 100
	add_child(_busy_overlay)
	# Move to front so it's above all siblings including OuterMargin
	move_child(_busy_overlay, -1)

	# Semi-transparent dark background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.1, 0.12, 0.15, 0.85)
	_busy_overlay.add_child(bg)

	# Center container for spinner and text
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_busy_overlay.add_child(center)

	# Panel for the loading indicator
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.17, 0.21, 0.95)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	# VBox for spinner and label
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Spinner label (static hourglass since analysis blocks the thread)
	_busy_spinner = Label.new()
	_busy_spinner.text = "⏳"
	_busy_spinner.add_theme_font_size_override("font_size", 48)
	_busy_spinner.add_theme_color_override("font_color", Color(0.4, 0.6, 0.9))
	_busy_spinner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_busy_spinner)

	# "Scanning..." label
	var label := Label.new()
	label.text = "Scanning codebase...\nThis may take a moment."
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	# Animation timer
	_busy_animation_timer = Timer.new()
	_busy_animation_timer.wait_time = 0.08
	_busy_animation_timer.timeout.connect(_on_busy_animation_tick)
	add_child(_busy_animation_timer)


func _on_busy_animation_tick() -> void:
	_spinner_frame_index = (_spinner_frame_index + 1) % _spinner_frames.size()
	_busy_spinner.text = _spinner_frames[_spinner_frame_index]


func _show_busy_overlay() -> void:
	_spinner_frame_index = 0
	_busy_spinner.text = _spinner_frames[0]
	# Ensure overlay fills the entire panel
	_busy_overlay.size = size
	_busy_overlay.position = Vector2.ZERO
	_busy_overlay.visible = true
	_busy_overlay.move_to_front()
	_busy_animation_timer.start()


func _hide_busy_overlay() -> void:
	_busy_overlay.visible = false
	_busy_animation_timer.stop()


# Called by ProjectManager to configure with selected project
func Configure(selectedProjectItem):
	_selectedProjectItem = selectedProjectItem
	_projectNameLabel.text = selectedProjectItem.GetProjectName()
	_projectPathLabel.text = selectedProjectItem.GetProjectDir()
	_loadThumbnail()
	_loadSettings()
	_loadLastScanned()


func _loadSettings():
	_currentConfig = QubeConfig.new()
	var projectDir = _selectedProjectItem.GetProjectDir()
	var configPath = projectDir.path_join(".gdqube.cfg")
	if FileAccess.file_exists(configPath):
		_currentConfig.load_project_config(projectDir)
	_settings_manager.config = _currentConfig
	_settings_manager.project_directory = projectDir
	_settings_manager.load_settings()
	_restoreFilterSelections()


func _restoreFilterSelections() -> void:
	if not _settings_manager.remember_filter_selections:
		return

	# Restore severity filter
	var saved_severity: int = _settings_manager.saved_severity_filter
	if saved_severity >= 0 and saved_severity < _severityFilter.item_count:
		_severityFilter.select(saved_severity)
		match saved_severity:
			0: _currentSeverityFilter = "all"
			1: _currentSeverityFilter = "critical"
			2: _currentSeverityFilter = "warning"
			3: _currentSeverityFilter = "info"

	# Restore type filter (find by metadata)
	var saved_type: String = _settings_manager.saved_type_filter
	for i in range(_typeFilter.item_count):
		if _typeFilter.get_item_metadata(i) == saved_type:
			_typeFilter.select(i)
			_currentTypeFilter = saved_type
			break

	# Restore file filter
	var saved_file: String = _settings_manager.saved_file_filter
	if not saved_file.is_empty():
		_fileFilter.text = saved_file
		_currentFileFilter = saved_file.to_lower()


func _on_display_refresh_needed() -> void:
	if _currentResult:
		_display_results()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key.begins_with("check_") or key == "all_checks":
		_checks_changed_while_settings_open = true


func _populate_type_filter(sev_filter: String = "all") -> void:
	_typeFilter.clear()
	var idx := 0

	_typeFilter.add_item("All Types", idx)
	_typeFilter.set_item_metadata(idx, "all")
	idx += 1

	var available_types := _get_available_types_for_severity(sev_filter)

	for check_id in ISSUE_TYPES:
		if check_id == "all":
			continue
		if sev_filter == "all" or check_id in available_types:
			_typeFilter.add_item(ISSUE_TYPES[check_id], idx)
			_typeFilter.set_item_metadata(idx, check_id)
			idx += 1


func _get_available_types_for_severity(sev_filter: String) -> Dictionary:
	var available: Dictionary = {}
	if not _currentResult:
		return available

	for issue in _currentResult.issues:
		var matches_severity := false
		match sev_filter:
			"all": matches_severity = true
			"critical": matches_severity = issue.severity == QubeIssue.Severity.CRITICAL
			"warning": matches_severity = issue.severity == QubeIssue.Severity.WARNING
			"info": matches_severity = issue.severity == QubeIssue.Severity.INFO

		if matches_severity:
			available[issue.check_id] = true

	return available


func _on_scan_button_pressed():
	_settingsPanel.visible = false
	_resultsScroll.visible = true

	_scanButton.disabled = true
	_exportJSONButton.disabled = true
	_exportHTMLButton.disabled = true
	_resultsLabel.text = "[color=#888888]Analyzing codebase...[/color]"

	# Show busy overlay before starting analysis
	_show_busy_overlay()

	# Wait two frames to ensure overlay renders before blocking analysis
	await get_tree().process_frame
	await get_tree().process_frame

	_run_analysis()


func _run_analysis():
	var projectDir = _selectedProjectItem.GetProjectDir()

	var analyzer = QubeAnalyzer.new()
	analyzer.config = _currentConfig

	_currentResult = analyzer.analyze_directory(projectDir)

	# Update and save last scanned timestamp
	_lastScannedTimestamp = Time.get_datetime_string_from_system().replace("T", " ").substr(0, 16)
	_updateLastScannedLabel()
	_saveLastScanned()

	_display_results()

	_scanButton.disabled = false
	var issueCount = _currentResult.issues.size()
	_exportJSONButton.disabled = (issueCount == 0)
	_exportHTMLButton.disabled = (issueCount == 0)

	# Hide busy overlay when done
	_hide_busy_overlay()


func _on_severity_filter_changed(index: int) -> void:
	match index:
		0: _currentSeverityFilter = "all"
		1: _currentSeverityFilter = "critical"
		2: _currentSeverityFilter = "warning"
		3: _currentSeverityFilter = "info"

	if _currentResult:
		var prev_type := _currentTypeFilter
		_populate_type_filter(_currentSeverityFilter)

		var restored := false
		for i in range(_typeFilter.item_count):
			if _typeFilter.get_item_metadata(i) == prev_type:
				_typeFilter.select(i)
				_currentTypeFilter = prev_type
				restored = true
				break

		if not restored:
			_typeFilter.select(0)
			_currentTypeFilter = "all"

		_display_results()

	_save_filter_selections()


func _on_type_filter_changed(index: int) -> void:
	_currentTypeFilter = _typeFilter.get_item_metadata(index)
	if _currentResult:
		_display_results()
	_save_filter_selections()


func _on_file_filter_changed(new_text: String) -> void:
	_currentFileFilter = new_text.to_lower()
	if _currentResult:
		_display_results()
	_save_filter_selections()


func _save_filter_selections() -> void:
	if _settings_manager:
		_settings_manager.save_filter_selections(
			_severityFilter.selected,
			_currentTypeFilter,
			_fileFilter.text
		)


func _on_settings_button_pressed() -> void:
	var was_visible := _settingsPanel.visible
	_settingsPanel.visible = not _settingsPanel.visible
	_resultsScroll.visible = not _settingsPanel.visible

	# If closing settings and checks changed, re-run analysis
	if was_visible and _checks_changed_while_settings_open:
		_checks_changed_while_settings_open = false
		if _currentResult:
			call_deferred("_run_analysis")


# === CLAUDE CODE INTEGRATION ===

func _setup_claude_context_menu() -> void:
	_claude_context_menu = PopupMenu.new()
	_claude_context_menu.add_item("Plan Fix (default)", 0)
	_claude_context_menu.add_item("Fix Immediately", 1)
	_claude_context_menu.add_separator()
	_claude_context_menu.add_item("Customize...", 2)
	_claude_context_menu.id_pressed.connect(_on_claude_context_menu_selected)
	add_child(_claude_context_menu)


func _setup_claude_tooltip() -> void:
	var label := Label.new()
	label.text = "Click: Plan mode | Shift+Click: Fix now | Right-click: Options"
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

	_claude_tooltip = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.13, 0.16, 0.95)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	_claude_tooltip.add_theme_stylebox_override("panel", style)
	_claude_tooltip.add_child(label)
	_claude_tooltip.visible = false
	_claude_tooltip.z_index = 100
	add_child(_claude_tooltip)


func _setup_claude_customize_popup() -> void:
	_claude_customize_popup = _create_popup_container()
	var vbox := _create_popup_vbox()
	_claude_customize_popup.add_child(vbox)

	_add_popup_title(vbox)
	_add_popup_context_section(vbox)
	_add_popup_command_section(vbox)
	_add_popup_instructions_section(vbox)
	_add_popup_buttons(vbox)

	add_child(_claude_customize_popup)


func _create_popup_container() -> PanelContainer:
	var popup := PanelContainer.new()
	popup.custom_minimum_size = Vector2(550, 500)
	popup.visible = false
	popup.z_index = 200
	popup.top_level = true

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.13, 0.16, 0.98)
	style.border_color = Color(0.3, 0.35, 0.45, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	popup.add_theme_stylebox_override("panel", style)
	return popup


func _create_popup_vbox() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	return vbox


func _add_popup_title(vbox: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "Customize Claude Launch"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	vbox.add_child(sep)


func _create_section_label(label_text: String) -> Label:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	return label


func _add_popup_context_section(vbox: VBoxContainer) -> void:
	vbox.add_child(_create_section_label("Issue Context:"))

	_claude_customize_context = RichTextLabel.new()
	_claude_customize_context.bbcode_enabled = true
	_claude_customize_context.fit_content = false
	_claude_customize_context.scroll_active = true
	_claude_customize_context.custom_minimum_size = Vector2(0, 100)
	_claude_customize_context.add_theme_font_size_override("normal_font_size", 11)
	_claude_customize_context.add_theme_color_override("default_color", Color(0.7, 0.75, 0.8))

	var context_style := StyleBoxFlat.new()
	context_style.bg_color = Color(0.09, 0.11, 0.14, 1.0)
	context_style.set_corner_radius_all(4)
	context_style.set_content_margin_all(8)
	_claude_customize_context.add_theme_stylebox_override("normal", context_style)
	vbox.add_child(_claude_customize_context)


func _add_popup_command_section(vbox: VBoxContainer) -> void:
	vbox.add_child(_create_section_label("Launch Command:"))

	_claude_customize_command = LineEdit.new()
	_claude_customize_command.placeholder_text = "claude --permission-mode plan"
	_claude_customize_command.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_claude_customize_command)


func _add_popup_instructions_section(vbox: VBoxContainer) -> void:
	vbox.add_child(_create_section_label("Custom Instructions:"))

	_claude_customize_instructions = TextEdit.new()
	_claude_customize_instructions.placeholder_text = "Additional instructions for Claude..."
	_claude_customize_instructions.add_theme_font_size_override("font_size", 12)
	_claude_customize_instructions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_claude_customize_instructions.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(_claude_customize_instructions)


func _add_popup_buttons(vbox: VBoxContainer) -> void:
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_END
	btn_container.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_container)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 32)
	cancel_btn.pressed.connect(_on_claude_customize_cancel)
	btn_container.add_child(cancel_btn)

	var launch_btn := Button.new()
	launch_btn.text = "Launch"
	launch_btn.custom_minimum_size = Vector2(80, 32)
	launch_btn.pressed.connect(_on_claude_customize_launch)
	btn_container.add_child(launch_btn)


func _show_claude_customize_popup() -> void:
	_claude_customize_command.text = _settings_manager.claude_code_command
	_claude_customize_instructions.text = _settings_manager.claude_custom_instructions

	var context_text := ""

	if _claude_customize_pending_link.begins_with("claude://"):
		var encoded_data: String = _claude_customize_pending_link.substr(9)
		var decoded_data: String = encoded_data.uri_decode()
		var parts := decoded_data.split("|")
		if parts.size() >= 5:
			context_text = "[b]Single Issue[/b]\n"
			context_text += "[color=#8899aa]File:[/color] %s\n" % parts[0]
			context_text += "[color=#8899aa]Line:[/color] %s\n" % parts[1]
			context_text += "[color=#8899aa]Type:[/color] %s\n" % parts[2]
			context_text += "[color=#8899aa]Severity:[/color] %s\n" % parts[3]
			context_text += "[color=#8899aa]Message:[/color] %s" % parts[4]

	elif _claude_customize_pending_link.begins_with("claude-type://"):
		var type_key: String = _claude_customize_pending_link.substr(14).uri_decode()
		if _grouped_issues_by_type.has(type_key):
			var issues: Array = _grouped_issues_by_type[type_key]
			context_text = "[b]Batch: %d issues of type '%s'[/b]\n\n" % [issues.size(), type_key]
			for i in range(mini(issues.size(), 5)):
				var issue = issues[i]
				context_text += "[color=#6688aa]%d.[/color] %s:%d - %s\n" % [i + 1, issue.file_path, issue.line, issue.message]
			if issues.size() > 5:
				context_text += "[color=#666677]... and %d more[/color]" % (issues.size() - 5)

	elif _claude_customize_pending_link.begins_with("claude-severity://"):
		var severity_key: String = _claude_customize_pending_link.substr(18)
		if _grouped_issues_by_severity.has(severity_key):
			var issues: Array = _grouped_issues_by_severity[severity_key]
			context_text = "[b]Batch: %d %s issues[/b]\n\n" % [issues.size(), severity_key]
			for i in range(mini(issues.size(), 5)):
				var issue = issues[i]
				context_text += "[color=#6688aa]%d.[/color] %s:%d - %s\n" % [i + 1, issue.file_path, issue.line, issue.message]
			if issues.size() > 5:
				context_text += "[color=#666677]... and %d more[/color]" % (issues.size() - 5)

	_claude_customize_context.clear()
	_claude_customize_context.append_text(context_text)

	var screen_size := DisplayServer.screen_get_size()
	var popup_size := _claude_customize_popup.custom_minimum_size
	_claude_customize_popup.global_position = Vector2(
		(screen_size.x - popup_size.x) / 2,
		(screen_size.y - popup_size.y) / 2
	)
	_claude_customize_popup.visible = true


func _on_claude_customize_cancel() -> void:
	_claude_customize_popup.visible = false
	_claude_customize_pending_link = ""


func _on_claude_customize_launch() -> void:
	_claude_customize_popup.visible = false

	if _claude_customize_pending_link.is_empty():
		return

	var custom_command := _claude_customize_command.text.strip_edges()
	var custom_instructions := _claude_customize_instructions.text

	if _claude_customize_pending_link.begins_with("claude://"):
		var encoded_data: String = _claude_customize_pending_link.substr(9)
		var decoded_data: String = encoded_data.uri_decode()
		var parts := decoded_data.split("|")

		if parts.size() >= 5:
			var issue_data := {
				"file_path": parts[0],
				"line": int(parts[1]),
				"check_id": parts[2],
				"severity": parts[3],
				"message": parts[4]
			}
			_launch_claude_code_custom(issue_data, custom_command, custom_instructions)

	elif _claude_customize_pending_link.begins_with("claude-type://"):
		var type_key: String = _claude_customize_pending_link.substr(14).uri_decode()
		if _grouped_issues_by_type.has(type_key):
			_launch_claude_code_batch_custom(_grouped_issues_by_type[type_key], custom_command, custom_instructions)

	elif _claude_customize_pending_link.begins_with("claude-severity://"):
		var severity_key: String = _claude_customize_pending_link.substr(18)
		if _grouped_issues_by_severity.has(severity_key):
			_launch_claude_code_batch_custom(_grouped_issues_by_severity[severity_key], custom_command, custom_instructions)

	_claude_customize_pending_link = ""


func _on_meta_hover_started(meta: Variant) -> void:
	var link := str(meta)
	if link.begins_with("claude://") or link.begins_with("claude-type://") or link.begins_with("claude-severity://"):
		_hovered_claude_link = link
		_show_claude_tooltip()


func _on_meta_hover_ended(_meta: Variant) -> void:
	_hovered_claude_link = ""
	_hide_claude_tooltip()


func _show_claude_tooltip() -> void:
	if not _claude_tooltip or not _settings_manager.claude_code_enabled:
		return
	var mouse_pos := get_global_mouse_position()
	_claude_tooltip.global_position = mouse_pos + Vector2(15, -30)
	_claude_tooltip.visible = true


func _hide_claude_tooltip() -> void:
	if _claude_tooltip:
		_claude_tooltip.visible = false


func _on_results_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _hovered_claude_link != "" and _settings_manager.claude_code_enabled:
				_hide_claude_tooltip()
				_claude_context_menu_link = _hovered_claude_link
				_claude_context_menu.position = DisplayServer.mouse_get_position() + Vector2i(16, -8)
				_claude_context_menu.popup()
				get_viewport().set_input_as_handled()


func _on_claude_context_menu_selected(id: int) -> void:
	if _claude_context_menu_link == "":
		return

	if id == 2:
		_claude_customize_pending_link = _claude_context_menu_link
		_show_claude_customize_popup()
		return

	var use_plan_mode := (id == 0)

	if _claude_context_menu_link.begins_with("claude://"):
		var encoded_data: String = _claude_context_menu_link.substr(9)
		var decoded_data: String = encoded_data.uri_decode()
		var parts := decoded_data.split("|")

		if parts.size() >= 5:
			var issue_data := {
				"file_path": parts[0],
				"line": int(parts[1]),
				"check_id": parts[2],
				"severity": parts[3],
				"message": parts[4]
			}
			_launch_claude_code(issue_data, use_plan_mode)
		return

	if _claude_context_menu_link.begins_with("claude-type://"):
		var type_key: String = _claude_context_menu_link.substr(14).uri_decode()
		if _grouped_issues_by_type.has(type_key):
			_launch_claude_code_batch(_grouped_issues_by_type[type_key], use_plan_mode)
		return

	if _claude_context_menu_link.begins_with("claude-severity://"):
		var severity_key: String = _claude_context_menu_link.substr(18)
		if _grouped_issues_by_severity.has(severity_key):
			_launch_claude_code_batch(_grouped_issues_by_severity[severity_key], use_plan_mode)


# === RESULTS DISPLAY ===

func _display_results() -> void:
	if not _currentResult:
		return

	_grouped_issues_by_type.clear()
	_grouped_issues_by_severity.clear()

	# Update header label with summary
	_headerLabel.text = _build_header_text()

	# Build body content
	var filtered := _filter_issues(_currentResult.issues.duplicate())
	var bbcode := _build_active_filters_text(filtered.size())

	var grouped := _group_issues_by_severity(filtered)

	_grouped_issues_by_severity = {
		"critical": grouped.critical,
		"warning": grouped.warning,
		"info": grouped.info
	}

	bbcode += _format_severity_section(grouped.critical, "CRITICAL", "🔴", "#ff6b6b", "critical")
	bbcode += _format_severity_section(grouped.warning, "WARNINGS", "🟡", "#ffd93d", "warning")
	bbcode += _format_severity_section(grouped.info, "INFO", "🔵", "#6bcb77", "info")

	if filtered.size() == 0:
		bbcode += "[color=#888888]No issues matching current filters[/color]"

	if _settings_manager.show_ignored_issues:
		bbcode += _format_ignored_section()

	_resultsLabel.text = bbcode


func _build_header_text() -> String:
	var parts: Array[String] = [
		"Code Quality Report",
		"Files: %d" % _currentResult.files_analyzed,
		"Lines: %d" % _currentResult.total_lines,
		"Time: %dms" % _currentResult.analysis_time_ms
	]

	if _settings_manager.show_total_issues:
		parts.append("Issues: %d" % _currentResult.issues.size())
	if _settings_manager.show_debt:
		parts.append("Debt: %d" % _currentResult.get_total_debt_score())

	return "  -  ".join(parts)


func _build_active_filters_text(count: int) -> String:
	var active: Array[String] = []
	if _currentSeverityFilter != "all":
		active.append(_currentSeverityFilter.capitalize())
	if _currentTypeFilter != "all":
		active.append(ISSUE_TYPES.get(_currentTypeFilter, _currentTypeFilter))
	if _currentFileFilter != "":
		active.append("\"%s\"" % _currentFileFilter)
	if active.size() > 0:
		return "[color=#888888]Filters: %s (%d matches)[/color]\n\n" % [", ".join(active), count]
	return ""


func _group_issues_by_severity(issues: Array) -> Dictionary:
	var grouped := {"critical": [], "warning": [], "info": []}
	for issue in issues:
		match issue.severity:
			QubeIssue.Severity.CRITICAL: grouped.critical.append(issue)
			QubeIssue.Severity.WARNING: grouped.warning.append(issue)
			QubeIssue.Severity.INFO: grouped.info.append(issue)
	return grouped


func _format_severity_section(issues: Array, label: String, emoji: String, color: String, severity_key: String) -> String:
	if issues.size() == 0:
		return ""
	var bbcode := "[color=%s][b]%s %s (%d)[/b][/color]" % [color, emoji, label, issues.size()]

	if _settings_manager.claude_code_enabled:
		bbcode += " [url=claude-severity://%s][img=20x20]res://scenes/code-quality-manager/assets/claude.png[/img][/url]" % severity_key

	bbcode += "\n"
	bbcode += _format_issues_by_type(issues, color, severity_key)
	return bbcode + "\n"


func _format_issues_by_type(issues: Array, color: String, severity_key: String) -> String:
	var bbcode := ""

	var by_type: Dictionary = {}
	for issue in issues:
		var check_id: String = issue.check_id
		if not by_type.has(check_id):
			by_type[check_id] = []
		by_type[check_id].append(issue)

	for check_id in by_type:
		var type_key := "%s|%s" % [severity_key, check_id]
		_grouped_issues_by_type[type_key] = by_type[check_id]

	var type_keys := by_type.keys()
	type_keys.sort_custom(func(a, b): return by_type[a].size() > by_type[b].size())

	var is_first_type := true
	for check_id in type_keys:
		var type_issues: Array = by_type[check_id]
		var type_name: String = ISSUE_TYPES.get(check_id, check_id)

		if not is_first_type:
			bbcode += "\n"
		is_first_type = false

		bbcode += "  [color=#aaaaaa]── %s (%d)[/color]" % [type_name, type_issues.size()]

		if _settings_manager.claude_code_enabled:
			var type_key := "%s|%s" % [severity_key, check_id]
			bbcode += " [url=claude-type://%s][img=16x16]res://scenes/code-quality-manager/assets/claude.png[/img][/url]" % type_key.uri_encode()

		bbcode += " [color=#aaaaaa]──[/color]\n"

		var shown := 0
		for issue in type_issues:
			if shown >= ISSUES_PER_CATEGORY:
				bbcode += "  [color=#888888]  ... and %d more[/color]\n" % (type_issues.size() - shown)
				break
			bbcode += _format_issue(issue, color)
			shown += 1

	return bbcode


func _format_issue(issue, color: String) -> String:
	var display_path: String = _getDisplayPath(issue.file_path)

	var line := "    [color=%s]%s:%d[/color] %s" % [
		color, display_path, issue.line, issue.message
	]

	if _settings_manager.claude_code_enabled:
		var severity_str: String = "unknown"
		match issue.severity:
			QubeIssue.Severity.CRITICAL: severity_str = "critical"
			QubeIssue.Severity.WARNING: severity_str = "warning"
			QubeIssue.Severity.INFO: severity_str = "info"

		var claude_data := "%s|%d|%s|%s|%s" % [
			issue.file_path, issue.line, issue.check_id, severity_str,
			issue.message.replace("|", "-")
		]
		line += " [url=claude://%s][img=20x20]res://scenes/code-quality-manager/assets/claude.png[/img][/url]" % claude_data.uri_encode()

	return line + "\n"


func _format_ignored_section() -> String:
	if not _currentResult or _currentResult.ignored_issues.size() == 0:
		return ""

	var ignored: Array = _currentResult.ignored_issues.filter(_matches_severity_and_file)

	if ignored.size() == 0:
		return ""

	var by_type: Dictionary = {}
	for issue in ignored:
		var check_id: String = issue.check_id
		if not by_type.has(check_id):
			by_type[check_id] = []
		by_type[check_id].append(issue)

	var bbcode := "\n[color=#666666][b]── Ignored (%d) ──[/b][/color]\n" % ignored.size()

	var type_keys := by_type.keys()
	type_keys.sort_custom(func(a, b): return by_type[a].size() > by_type[b].size())

	for check_id in type_keys:
		var type_issues: Array = by_type[check_id]
		var type_name: String = ISSUE_TYPES.get(check_id, check_id)

		if type_issues.size() <= 3:
			var refs: Array[String] = []
			for issue in type_issues:
				var display_path: String = _getDisplayPath(issue.file_path)
				refs.append("%s:%d" % [display_path, issue.line])
			bbcode += "  [color=#555555]%s: %s[/color]\n" % [type_name.to_lower(), ", ".join(refs)]
		else:
			bbcode += "  [color=#555555]%s (%d):[/color]\n" % [type_name.to_lower(), type_issues.size()]
			var shown := 0
			for issue in type_issues:
				if shown >= ISSUES_PER_CATEGORY:
					bbcode += "    [color=#444444]... and %d more[/color]\n" % (type_issues.size() - shown)
					break
				var display_path: String = _getDisplayPath(issue.file_path)
				bbcode += "    [color=#555555]%s:%d[/color] %s\n" % [
					display_path, issue.line, issue.message
				]
				shown += 1

	return bbcode


# Get display path respecting show_full_path setting
func _getDisplayPath(absolute_path: String) -> String:
	var res_path: String = _toResPath(absolute_path)
	if _settings_manager.show_full_path:
		return res_path
	return res_path.get_file()


# === FILTER HELPERS ===

func _matches_severity(issue) -> bool:
	if _currentSeverityFilter == "all":
		return true
	match _currentSeverityFilter:
		"critical": return issue.severity == QubeIssue.Severity.CRITICAL
		"warning": return issue.severity == QubeIssue.Severity.WARNING
		"info": return issue.severity == QubeIssue.Severity.INFO
	return false


func _matches_type(issue) -> bool:
	return _currentTypeFilter == "all" or issue.check_id == _currentTypeFilter


func _matches_file(issue) -> bool:
	return _currentFileFilter == "" or _currentFileFilter in issue.file_path.to_lower()


func _matches_current_filters(issue) -> bool:
	return _matches_severity(issue) and _matches_type(issue) and _matches_file(issue)


func _matches_severity_and_file(issue) -> bool:
	return _matches_severity(issue) and _matches_file(issue)


func _filter_issues(issues: Array) -> Array:
	return issues.filter(_matches_current_filters)


# === LINK HANDLERS ===

func _on_link_clicked(meta: Variant) -> void:
	var location := str(meta)

	if location.begins_with("claude://"):
		_handle_claude_single_link(location)
	elif location.begins_with("claude-type://"):
		_handle_claude_type_link(location)
	elif location.begins_with("claude-severity://"):
		_handle_claude_severity_link(location)


func _handle_claude_single_link(location: String) -> void:
	var encoded_data: String = location.substr(9)
	var decoded_data: String = encoded_data.uri_decode()
	var parts := decoded_data.split("|")

	if parts.size() >= 5:
		var issue_data := {
			"file_path": parts[0],
			"line": int(parts[1]),
			"check_id": parts[2],
			"severity": parts[3],
			"message": parts[4]
		}
		var use_plan_mode := not Input.is_key_pressed(KEY_SHIFT)
		_launch_claude_code(issue_data, use_plan_mode)
	else:
		push_warning("Invalid Claude link format: %s" % location)


func _handle_claude_type_link(location: String) -> void:
	var type_key: String = location.substr(14).uri_decode()
	if _grouped_issues_by_type.has(type_key):
		var issues: Array = _grouped_issues_by_type[type_key]
		var use_plan_mode := not Input.is_key_pressed(KEY_SHIFT)
		_launch_claude_code_batch(issues, use_plan_mode)
	else:
		push_warning("No issues found for type key: %s" % type_key)


func _handle_claude_severity_link(location: String) -> void:
	var severity_key: String = location.substr(18)
	if _grouped_issues_by_severity.has(severity_key):
		var issues: Array = _grouped_issues_by_severity[severity_key]
		var use_plan_mode := not Input.is_key_pressed(KEY_SHIFT)
		_launch_claude_code_batch(issues, use_plan_mode)
	else:
		push_warning("No issues found for severity: %s" % severity_key)


# === CLAUDE LAUNCH FUNCTIONS ===

func _launch_claude_code(issue: Dictionary, use_plan_mode: bool) -> void:
	var project_path: String = _selectedProjectItem.GetProjectDir()

	var prompt := "Code quality issue to fix:\n\n"
	prompt += "File: %s\n" % _toResPath(issue.file_path)
	prompt += "Line: %d\n" % issue.line
	prompt += "Type: %s\n" % issue.check_id
	prompt += "Severity: %s\n" % issue.severity
	prompt += "Message: %s\n\n" % issue.message

	if use_plan_mode:
		prompt += "Analyze this issue and suggest a fix."
	else:
		prompt += "Fix this issue now."

	if not _settings_manager.claude_custom_instructions.strip_edges().is_empty():
		prompt += "\n\n" + _settings_manager.claude_custom_instructions

	var escaped_prompt := prompt.replace("'", "''")

	var command: String
	if use_plan_mode:
		command = _settings_manager.claude_code_command
	else:
		command = _settings_manager.claude_code_command.replace("--permission-mode plan", "").strip_edges()
		if command.is_empty():
			command = "claude"

	var args: PackedStringArray = [
		"-d", project_path,
		"powershell", "-NoProfile", "-NoExit",
		"-Command", "%s '%s'" % [command, escaped_prompt]
	]
	OS.create_process("wt", args)


func _launch_claude_code_batch(issues: Array, use_plan_mode: bool) -> void:
	if issues.is_empty():
		return

	var project_path: String = _selectedProjectItem.GetProjectDir()

	var prompt := "Code quality issues to fix (%d total):\n\n" % issues.size()

	for i in range(issues.size()):
		var issue = issues[i]
		var severity_str: String = "unknown"
		match issue.severity:
			QubeIssue.Severity.CRITICAL: severity_str = "critical"
			QubeIssue.Severity.WARNING: severity_str = "warning"
			QubeIssue.Severity.INFO: severity_str = "info"

		prompt += "%d. %s:%d\n" % [i + 1, _toResPath(issue.file_path), issue.line]
		prompt += "   Type: %s | Severity: %s\n" % [issue.check_id, severity_str]
		prompt += "   %s\n\n" % issue.message

	if use_plan_mode:
		prompt += "Analyze these issues and suggest fixes for each."
	else:
		prompt += "Fix all these issues now."

	if not _settings_manager.claude_custom_instructions.strip_edges().is_empty():
		prompt += "\n\n" + _settings_manager.claude_custom_instructions

	var escaped_prompt := prompt.replace("'", "''")

	var command: String
	if use_plan_mode:
		command = _settings_manager.claude_code_command
	else:
		command = _settings_manager.claude_code_command.replace("--permission-mode plan", "").strip_edges()
		if command.is_empty():
			command = "claude"

	var args: PackedStringArray = [
		"-d", project_path,
		"powershell", "-NoProfile", "-NoExit",
		"-Command", "%s '%s'" % [command, escaped_prompt]
	]
	OS.create_process("wt", args)


func _launch_claude_code_custom(issue: Dictionary, custom_command: String, custom_instructions: String) -> void:
	var project_path: String = _selectedProjectItem.GetProjectDir()

	var prompt := "Code quality issue to fix:\n\n"
	prompt += "File: %s\n" % _toResPath(issue.file_path)
	prompt += "Line: %d\n" % issue.line
	prompt += "Type: %s\n" % issue.check_id
	prompt += "Severity: %s\n" % issue.severity
	prompt += "Message: %s\n\n" % issue.message
	prompt += "Fix this issue."

	if not custom_instructions.strip_edges().is_empty():
		prompt += "\n\n" + custom_instructions

	var escaped_prompt := prompt.replace("'", "''")

	var command := custom_command if not custom_command.is_empty() else "claude"

	var args: PackedStringArray = [
		"-d", project_path,
		"powershell", "-NoProfile", "-NoExit",
		"-Command", "%s '%s'" % [command, escaped_prompt]
	]
	OS.create_process("wt", args)


func _launch_claude_code_batch_custom(issues: Array, custom_command: String, custom_instructions: String) -> void:
	if issues.is_empty():
		return

	var project_path: String = _selectedProjectItem.GetProjectDir()

	var prompt := "Code quality issues to fix (%d total):\n\n" % issues.size()

	for i in range(issues.size()):
		var issue = issues[i]
		var severity_str: String = "unknown"
		match issue.severity:
			QubeIssue.Severity.CRITICAL: severity_str = "critical"
			QubeIssue.Severity.WARNING: severity_str = "warning"
			QubeIssue.Severity.INFO: severity_str = "info"

		prompt += "%d. %s:%d\n" % [i + 1, _toResPath(issue.file_path), issue.line]
		prompt += "   Type: %s | Severity: %s\n" % [issue.check_id, severity_str]
		prompt += "   %s\n\n" % issue.message

	prompt += "Fix all these issues."

	if not custom_instructions.strip_edges().is_empty():
		prompt += "\n\n" + custom_instructions

	var escaped_prompt := prompt.replace("'", "''")

	var command := custom_command if not custom_command.is_empty() else "claude"

	var args: PackedStringArray = [
		"-d", project_path,
		"powershell", "-NoProfile", "-NoExit",
		"-Command", "%s '%s'" % [command, escaped_prompt]
	]
	OS.create_process("wt", args)


# === UTILITY FUNCTIONS ===

# Convert absolute path to res:// path relative to project directory
func _toResPath(absolutePath: String) -> String:
	if _selectedProjectItem == null:
		return absolutePath
	var projectDir = _selectedProjectItem.GetProjectDir()
	var normalizedPath = absolutePath.replace("\\", "/")
	var normalizedProject = projectDir.replace("\\", "/")
	if normalizedPath.begins_with(normalizedProject):
		var relativePath = normalizedPath.substr(normalizedProject.length())
		if relativePath.begins_with("/"):
			relativePath = relativePath.substr(1)
		return "res://" + relativePath
	return absolutePath


func _loadThumbnail():
	if _selectedProjectItem == null:
		return
	var thumbnailPath = _selectedProjectItem.GetThumbnailPath()
	if thumbnailPath == "":
		return

	if thumbnailPath.begins_with("res://"):
		var texture = load(thumbnailPath)
		if texture:
			_thumbTextureRect.texture = texture
	else:
		var image = Image.new()
		var error = image.load(thumbnailPath)
		if error == OK:
			var texture = ImageTexture.create_from_image(image)
			_thumbTextureRect.texture = texture


func _loadLastScanned():
	var projectDir = _selectedProjectItem.GetProjectDir()
	var configPath = projectDir + "/.gdqube_state.json"

	if FileAccess.file_exists(configPath):
		var file = FileAccess.open(configPath, FileAccess.READ)
		if file:
			var json = JSON.new()
			var error = json.parse(file.get_as_text())
			file.close()
			if error == OK and json.data is Dictionary:
				_lastScannedTimestamp = json.data.get("last_scanned", "")

	_updateLastScannedLabel()


func _saveLastScanned():
	var projectDir = _selectedProjectItem.GetProjectDir()
	var configPath = projectDir + "/.gdqube_state.json"

	var data = {
		"last_scanned": _lastScannedTimestamp
	}

	var file = FileAccess.open(configPath, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func _updateLastScannedLabel():
	if _lastScannedTimestamp.is_empty():
		_lastScannedLabel.text = "Last Scanned: Never"
	else:
		_lastScannedLabel.text = "Last Scanned: " + _lastScannedTimestamp


# === EXPORT FUNCTIONS ===

func _on_export_json_pressed():
	if _currentResult == null:
		return

	var projectDir = _selectedProjectItem.GetProjectDir()
	var exportPath = projectDir + "/code_quality_report.json"

	var data = {
		"project": _selectedProjectItem.GetProjectName(),
		"path": projectDir,
		"timestamp": Time.get_datetime_string_from_system(),
		"summary": {
			"total_issues": _currentResult.issues.size(),
			"critical": _currentResult.issues.filter(func(i): return i.severity == QubeIssue.Severity.CRITICAL).size(),
			"warning": _currentResult.issues.filter(func(i): return i.severity == QubeIssue.Severity.WARNING).size(),
			"info": _currentResult.issues.filter(func(i): return i.severity == QubeIssue.Severity.INFO).size()
		},
		"issues": []
	}

	for issue in _currentResult.issues:
		var severity_str := "unknown"
		match issue.severity:
			QubeIssue.Severity.CRITICAL: severity_str = "critical"
			QubeIssue.Severity.WARNING: severity_str = "warning"
			QubeIssue.Severity.INFO: severity_str = "info"
		data["issues"].append({
			"file": issue.file_path,
			"line": issue.line,
			"severity": severity_str,
			"type": issue.check_id,
			"message": issue.message
		})

	var file = FileAccess.open(exportPath, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		OS.shell_show_in_file_manager(exportPath)
	else:
		push_error("Could not write JSON file: " + exportPath)


func _on_export_html_pressed():
	if _currentResult == null:
		return

	var projectDir = _selectedProjectItem.GetProjectDir()
	var exportPath = projectDir + "/code_quality_report.html"

	var html = _generateHTMLReport()

	var file = FileAccess.open(exportPath, FileAccess.WRITE)
	if file:
		file.store_string(html)
		file.close()
		OS.shell_open(exportPath)
	else:
		push_error("Could not write HTML file: " + exportPath)


func _generateHTMLReport() -> String:
	var critical: Array = _currentResult.issues.filter(func(i): return i.severity == QubeIssue.Severity.CRITICAL)
	var warnings: Array = _currentResult.issues.filter(func(i): return i.severity == QubeIssue.Severity.WARNING)
	var info: Array = _currentResult.issues.filter(func(i): return i.severity == QubeIssue.Severity.INFO)

	var types_by_severity: Dictionary = {
		"all": {},
		"critical": {},
		"warning": {},
		"info": {}
	}
	for issue in _currentResult.issues:
		types_by_severity["all"][issue.check_id] = true
	for issue in critical:
		types_by_severity["critical"][issue.check_id] = true
	for issue in warnings:
		types_by_severity["warning"][issue.check_id] = true
	for issue in info:
		types_by_severity["info"][issue.check_id] = true

	var type_names_json := "{"
	var first := true
	for check_id in types_by_severity["all"].keys():
		if not first:
			type_names_json += ","
		first = false
		var display_name: String = ISSUE_TYPES.get(check_id, check_id)
		type_names_json += "\"%s\":\"%s\"" % [check_id, display_name]
	type_names_json += "}"

	var severity_types_json := "{"
	for sev in ["all", "critical", "warning", "info"]:
		if sev != "all":
			severity_types_json += ","
		var types_arr: Array = types_by_severity[sev].keys()
		types_arr.sort()
		severity_types_json += "\"%s\":%s" % [sev, JSON.stringify(types_arr)]
	severity_types_json += "}"

	var html := """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Code Quality Report</title>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #1a1a2e; color: #eee; padding: 20px; line-height: 1.6; }
.container { max-width: 1200px; margin: 0 auto; }
h1 { color: #00d4ff; margin-bottom: 10px; }
h2 { color: #888; font-size: 1.2em; margin: 20px 0 10px; border-bottom: 1px solid #333; padding-bottom: 5px; }
.header { text-align: center; margin-bottom: 30px; }
.subtitle { color: #888; font-size: 0.9em; }
.filters { background: #16213e; border-radius: 8px; padding: 15px; margin-bottom: 20px; display: flex; flex-wrap: wrap; gap: 15px; align-items: center; }
.filters label { color: #aaa; font-size: 0.95em; font-weight: bold; }
.filters select, .filters input { background: #0f3460; border: 1px solid #333; color: #eee; padding: 8px 12px; border-radius: 4px; font-size: 0.9em; }
.filters input { min-width: 400px; }
.filters select:focus, .filters input:focus { outline: none; border-color: #00d4ff; }
.filter-count { color: #00d4ff; font-weight: bold; margin-left: auto; }
.summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px; margin-bottom: 30px; }
.stat-card { background: #16213e; border-radius: 8px; padding: 15px; text-align: center; }
.stat-card .value { font-size: 2em; font-weight: bold; }
.stat-card .label { color: #888; font-size: 0.85em; }
.stat-card.critical .value { color: #ff6b6b; }
.stat-card.warning .value { color: #ffd93d; }
.stat-card.info .value { color: #6bcb77; }
.issues-section { margin-bottom: 30px; }
.section-header { display: flex; align-items: center; gap: 10px; margin-bottom: 15px; }
.section-header .icon { font-size: 1.5em; }
.section-header.critical { color: #ff6b6b; }
.section-header.warning { color: #ffd93d; }
.section-header.info { color: #6bcb77; }
.section-header .count { font-size: 0.8em; color: #888; }
.issue { background: #16213e; border-radius: 6px; padding: 12px 15px; margin-bottom: 8px; display: grid; grid-template-columns: minmax(280px, 350px) 1fr auto; gap: 15px; align-items: center; }
.issue.hidden { display: none; }
.issue .location { font-family: 'Consolas', 'Monaco', monospace; font-size: 0.85em; color: #00d4ff; word-break: break-all; }
.issue .message { color: #ccc; }
.issue .check-id { font-size: 0.75em; background: #0f3460; padding: 2px 8px; border-radius: 4px; color: #888; white-space: nowrap; }
.footer { text-align: center; margin-top: 40px; padding-top: 20px; border-top: 1px solid #333; color: #666; font-size: 0.85em; }
.footer a { color: #00d4ff; text-decoration: none; }
.no-results { text-align: center; color: #666; padding: 40px; }
</style>
</head>
<body>
<div class="container">
<div class="header">
<h1>Code Quality Report</h1>
<p class="subtitle">%s</p>
</div>

<div class="summary">
<div class="stat-card"><div class="value">%d</div><div class="label">Files Analyzed</div></div>
<div class="stat-card"><div class="value">%d</div><div class="label">Lines of Code</div></div>
<div class="stat-card critical"><div class="value">%d</div><div class="label">Critical Issues</div></div>
<div class="stat-card warning"><div class="value">%d</div><div class="label">Warnings</div></div>
<div class="stat-card info"><div class="value">%d</div><div class="label">Info</div></div>
<div class="stat-card"><div class="value">%d</div><div class="label">Debt Score</div></div>
</div>

<div class="filters">
<label>Severity:</label>
<select id="severityFilter" onchange="onSeverityChange()">
<option value="all">All Severities</option>
<option value="critical">Critical</option>
<option value="warning">Warning</option>
<option value="info">Info</option>
</select>
<label>Type:</label>
<select id="typeFilter" onchange="applyFilters()">
<option value="all">All Types</option>
</select>
<label>File:</label>
<input type="text" id="fileFilter" placeholder="Filter by filename..." oninput="applyFilters()">
<span class="filter-count" id="filterCount"></span>
</div>

<div id="issuesContainer">
""" % [_selectedProjectItem.GetProjectName(), _currentResult.files_analyzed, _currentResult.total_lines, critical.size(), warnings.size(), info.size(), _currentResult.get_total_debt_score()]

	if critical.size() > 0:
		html += "<div class=\"issues-section\" data-severity=\"critical\"><div class=\"section-header critical\"><span class=\"icon\">🔴</span><h2>Critical Issues (<span class=\"count\">%d</span>)</h2></div>\n" % critical.size()
		for issue in critical:
			html += _formatHTMLIssue(issue, "critical")
		html += "</div>\n"

	if warnings.size() > 0:
		html += "<div class=\"issues-section\" data-severity=\"warning\"><div class=\"section-header warning\"><span class=\"icon\">🟡</span><h2>Warnings (<span class=\"count\">%d</span>)</h2></div>\n" % warnings.size()
		for issue in warnings:
			html += _formatHTMLIssue(issue, "warning")
		html += "</div>\n"

	if info.size() > 0:
		html += "<div class=\"issues-section\" data-severity=\"info\"><div class=\"section-header info\"><span class=\"icon\">🔵</span><h2>Info (<span class=\"count\">%d</span>)</h2></div>\n" % info.size()
		for issue in info:
			html += _formatHTMLIssue(issue, "info")
		html += "</div>\n"

	html += """</div>
<div id="noResults" class="no-results" style="display:none;">No issues match the current filters</div>

<div class="footer">
<p>Generated by <a href="https://github.com/graydwarf/godot-gdscript-linter">GDScript Linter</a> in %dms</p>
</div>
</div>

<script>
const TYPE_NAMES = %s;
const SEVERITY_TYPES = %s;

function populateTypeFilter(severity) {
	const typeFilter = document.getElementById('typeFilter');
	const prevValue = typeFilter.value;

	typeFilter.innerHTML = '<option value="all">All Types</option>';

	const types = SEVERITY_TYPES[severity] || [];
	types.forEach(checkId => {
		const option = document.createElement('option');
		option.value = checkId;
		option.textContent = TYPE_NAMES[checkId] || checkId;
		typeFilter.appendChild(option);
	});

	const options = Array.from(typeFilter.options);
	const found = options.find(opt => opt.value === prevValue);
	if (found) {
		typeFilter.value = prevValue;
	} else {
		typeFilter.value = 'all';
	}
}

function onSeverityChange() {
	const severity = document.getElementById('severityFilter').value;
	populateTypeFilter(severity);
	applyFilters();
}

function applyFilters() {
	const severity = document.getElementById('severityFilter').value;
	const type = document.getElementById('typeFilter').value;
	const file = document.getElementById('fileFilter').value.toLowerCase();

	const issues = document.querySelectorAll('.issue');
	let visibleCount = 0;

	issues.forEach(issue => {
		const issueSeverity = issue.dataset.severity;
		const issueType = issue.dataset.type;
		const issueFile = issue.dataset.file.toLowerCase();

		const matchSeverity = severity === 'all' || issueSeverity === severity;
		const matchType = type === 'all' || issueType === type;
		const matchFile = file === '' || issueFile.includes(file);

		if (matchSeverity && matchType && matchFile) {
			issue.classList.remove('hidden');
			visibleCount++;
		} else {
			issue.classList.add('hidden');
		}
	});

	document.querySelectorAll('.issues-section').forEach(section => {
		const visibleInSection = section.querySelectorAll('.issue:not(.hidden)').length;
		section.querySelector('.count').textContent = visibleInSection;
		section.style.display = visibleInSection > 0 ? 'block' : 'none';
	});

	document.getElementById('noResults').style.display = visibleCount === 0 ? 'block' : 'none';

	const total = issues.length;
	document.getElementById('filterCount').textContent = visibleCount === total ? '' : visibleCount + ' / ' + total + ' shown';
}

populateTypeFilter('all');
applyFilters();
</script>
</body>
</html>
""" % [_currentResult.analysis_time_ms, type_names_json, severity_types_json]

	return html


func _formatHTMLIssue(issue, severity: String) -> String:
	var escaped_message: String = issue.message.replace("<", "&lt;").replace(">", "&gt;")
	var res_path: String = _toResPath(issue.file_path)

	return "<div class=\"issue\" data-severity=\"%s\" data-type=\"%s\" data-file=\"%s\"><span class=\"location\">%s:%d</span><span class=\"message\">%s</span><span class=\"check-id\">%s</span></div>\n" % [severity, issue.check_id, res_path, res_path, issue.line, escaped_message, issue.check_id]


# === BUTTON HANDLERS ===

func _on_back_button_pressed():
	# If settings panel is visible, hide it instead of going back
	if _settingsPanel.visible:
		_settingsPanel.visible = false
		_resultsScroll.visible = true
		# Re-run analysis if checks changed while settings were open
		if _checks_changed_while_settings_open:
			_checks_changed_while_settings_open = false
			if _currentResult:
				call_deferred("_run_analysis")
		return
	queue_free()


func _on_folder_button_pressed():
	if _selectedProjectItem != null:
		var projectDir = _selectedProjectItem.GetProjectDir()
		OS.shell_open(projectDir)
