# Code Quality Manager - Settings Manager
# Adapted from GDScript Linter for standalone app usage
# Uses hybrid persistence: App singleton for global settings, per-project .gdqube.cfg for analysis limits
extends RefCounted
## Handles loading and saving settings from App singleton and per-project config

signal setting_changed(key: String, value: Variant)
signal display_refresh_needed

const SettingsLimitsHandler = preload("res://scenes/code-quality-manager/ui/settings-limits-handler.gd")

const CLAUDE_CODE_DEFAULT_COMMAND := "claude --permission-mode plan"

# Project directory for per-project config
var project_directory: String = ""

# Settings state - Display (global via App singleton)
var show_total_issues: bool = true
var show_debt: bool = true
var show_json_export: bool = false
var show_html_export: bool = true
var show_ignored_issues: bool = true
var show_full_path: bool = false

# Settings state - Scanning (per-project)
var respect_gdignore: bool = true
var scan_addons: bool = false
var remember_filter_selections: bool = false

# Persisted filter selections (only used when remember_filter_selections is true)
var saved_severity_filter: int = 0  # Index in dropdown
var saved_type_filter: String = "all"  # check_id or "all"
var saved_file_filter: String = ""

# Settings state - Code Checks (per-project, all enabled by default)
var check_naming_conventions: bool = true
var check_long_lines: bool = true
var check_todo_comments: bool = true
var check_print_statements: bool = true
var check_magic_numbers: bool = true
var check_commented_code: bool = true
var check_missing_types: bool = true
var check_function_length: bool = true
var check_parameters: bool = true
var check_nesting: bool = true
var check_cyclomatic_complexity: bool = true
var check_empty_functions: bool = true
var check_missing_return_type: bool = true
var check_file_length: bool = true
var check_god_class: bool = true
var check_unused_variables: bool = true
var check_unused_parameters: bool = true

# Settings state - Claude Code (global via App singleton)
var claude_code_enabled: bool:
	get: return App.GetClaudeCodeButtonEnabled()
var claude_code_command: String:
	get: return App.GetClaudeCodeLaunchCommand()
var claude_custom_instructions: String:
	get: return App.GetClaudeCodeCustomInstructions()

# All check control keys for Enable All / Disable All
var _check_control_keys: Array[String] = [
	"check_naming_conventions", "check_long_lines", "check_todo_comments",
	"check_print_statements", "check_magic_numbers", "check_commented_code",
	"check_missing_types", "check_function_length", "check_parameters",
	"check_nesting", "check_cyclomatic_complexity", "check_empty_functions",
	"check_missing_return_type", "check_file_length", "check_god_class",
	"check_unused_variables", "check_unused_parameters"
]

# References
var config: Resource  # QubeConfig
var controls: Dictionary = {}
var _limits_handler


func _init(p_config: Resource) -> void:
	config = p_config


# Configure with project directory for per-project settings
func configure(p_project_directory: String) -> void:
	project_directory = p_project_directory


# Load all settings from App singleton and per-project config
func load_settings() -> void:
	_load_global_settings()
	_load_project_settings()
	_apply_to_ui()


func _load_global_settings() -> void:
	# Display settings from App singleton (or use defaults)
	show_total_issues = App.GetCodeQualityCardCollapseState("display/show_issues", false)  # Using card state storage for simplicity
	show_debt = App.GetCodeQualityCardCollapseState("display/show_debt", false)
	show_json_export = App.GetCodeQualityCardCollapseState("display/show_json_export", true)
	show_html_export = App.GetCodeQualityCardCollapseState("display/show_html_export", false)
	show_ignored_issues = App.GetCodeQualityCardCollapseState("display/show_ignored", false)
	show_full_path = App.GetCodeQualityCardCollapseState("display/show_full_path", true)  # Default false (inverted)
	# Note: show_* are inverted because we're using collapse state (true = hidden)
	show_total_issues = not show_total_issues
	show_debt = not show_debt
	show_json_export = not show_json_export
	show_html_export = not show_html_export
	show_ignored_issues = not show_ignored_issues
	show_full_path = not show_full_path


func _load_project_settings() -> void:
	if project_directory.is_empty():
		return

	var config_path := project_directory.path_join(".gdqube.cfg")
	if not FileAccess.file_exists(config_path):
		return

	var cfg := ConfigFile.new()
	var err := cfg.load(config_path)
	if err != OK:
		return

	# Load scanning settings
	respect_gdignore = cfg.get_value("scanning", "respect_gdignore", true)
	config.respect_gdignore = respect_gdignore
	scan_addons = cfg.get_value("scanning", "scan_addons", false)
	config.include_addons = scan_addons
	remember_filter_selections = cfg.get_value("scanning", "remember_filters", false)

	# Load saved filter selections
	saved_severity_filter = cfg.get_value("filters", "severity", 0)
	saved_type_filter = cfg.get_value("filters", "type", "all")
	saved_file_filter = cfg.get_value("filters", "file", "")

	# Load analysis limits
	config.line_limit_soft = cfg.get_value("limits", "file_lines_warn", 200)
	config.line_limit_hard = cfg.get_value("limits", "file_lines_critical", 300)
	config.function_line_limit = cfg.get_value("limits", "function_lines", 30)
	config.function_line_critical = cfg.get_value("limits", "function_lines_crit", 60)
	config.cyclomatic_warning = cfg.get_value("limits", "complexity_warn", 10)
	config.cyclomatic_critical = cfg.get_value("limits", "complexity_crit", 15)
	config.max_parameters = cfg.get_value("limits", "max_params", 4)
	config.max_nesting = cfg.get_value("limits", "max_nesting", 3)
	config.god_class_functions = cfg.get_value("limits", "god_class_funcs", 20)
	config.god_class_signals = cfg.get_value("limits", "god_class_signals", 10)

	# Load code checks settings
	_load_check_settings(cfg)


func _load_check_settings(cfg: ConfigFile) -> void:
	var check_mappings := {
		"naming_conventions": "check_naming_conventions",
		"long_lines": "check_long_lines",
		"todo_comments": "check_todo_comments",
		"print_statements": "check_print_statements",
		"magic_numbers": "check_magic_numbers",
		"commented_code": "check_commented_code",
		"missing_types": "check_missing_types",
		"function_length": "check_function_length",
		"parameters": "check_parameters",
		"nesting": "check_nesting",
		"cyclomatic_complexity": "check_cyclomatic_complexity",
		"empty_functions": "check_empty_functions",
		"missing_return_type": "check_missing_return_type",
		"file_length": "check_file_length",
		"god_class": "check_god_class",
		"unused_variables": "check_unused_variables",
		"unused_parameters": "check_unused_parameters",
	}

	for key_suffix: String in check_mappings:
		var prop_name: String = check_mappings[key_suffix]
		var value: bool = cfg.get_value("checks", key_suffix, true)
		set(prop_name, value)
		if config.get(prop_name) != null:
			config.set(prop_name, value)


# Apply current settings to UI controls
func _apply_to_ui() -> void:
	if controls.is_empty():
		return

	# Boolean controls (CheckBox/CheckButton)
	var bool_mappings := {
		# Display options
		"show_issues_check": func(): return show_total_issues,
		"show_debt_check": func(): return show_debt,
		"show_json_export_check": func(): return show_json_export,
		"show_html_export_check": func(): return show_html_export,
		"show_ignored_check": func(): return show_ignored_issues,
		"show_full_path_check": func(): return show_full_path,
		# Scanning options
		"respect_gdignore_check": func(): return respect_gdignore,
		"scan_addons_check": func(): return scan_addons,
		"remember_filters_check": func(): return remember_filter_selections,
		# Code checks - Naming
		"check_naming_conventions": func(): return check_naming_conventions,
		# Code checks - Style
		"check_long_lines": func(): return check_long_lines,
		"check_todo_comments": func(): return check_todo_comments,
		"check_print_statements": func(): return check_print_statements,
		"check_magic_numbers": func(): return check_magic_numbers,
		"check_commented_code": func(): return check_commented_code,
		"check_missing_types": func(): return check_missing_types,
		# Code checks - Functions
		"check_function_length": func(): return check_function_length,
		"check_parameters": func(): return check_parameters,
		"check_nesting": func(): return check_nesting,
		"check_cyclomatic_complexity": func(): return check_cyclomatic_complexity,
		"check_empty_functions": func(): return check_empty_functions,
		"check_missing_return_type": func(): return check_missing_return_type,
		# Code checks - Structure
		"check_file_length": func(): return check_file_length,
		"check_god_class": func(): return check_god_class,
		"check_unused_variables": func(): return check_unused_variables,
		"check_unused_parameters": func(): return check_unused_parameters,
		# Claude Code
		"claude_enabled_check": func(): return claude_code_enabled,
	}

	for control_key in bool_mappings:
		if controls.has(control_key):
			controls[control_key].button_pressed = bool_mappings[control_key].call()

	# Numeric controls (SpinBox)
	var spin_mappings := {
		"max_lines_soft_spin": func(): return config.line_limit_soft,
		"max_lines_hard_spin": func(): return config.line_limit_hard,
		"max_func_lines_spin": func(): return config.function_line_limit,
		"max_complexity_spin": func(): return config.cyclomatic_warning,
		"func_lines_crit_spin": func(): return config.function_line_critical,
		"max_complexity_crit_spin": func(): return config.cyclomatic_critical,
		"max_params_spin": func(): return config.max_parameters,
		"max_nesting_spin": func(): return config.max_nesting,
		"god_class_funcs_spin": func(): return config.god_class_functions,
		"god_class_signals_spin": func(): return config.god_class_signals,
	}

	for control_key in spin_mappings:
		if controls.has(control_key):
			controls[control_key].value = spin_mappings[control_key].call()

	# Text controls (LineEdit/TextEdit)
	var text_mappings := {
		"claude_command_edit": func(): return claude_code_command,
		"claude_instructions_edit": func(): return claude_custom_instructions,
	}

	for control_key in text_mappings:
		if controls.has(control_key):
			controls[control_key].text = text_mappings[control_key].call()


# Connect all UI control signals
func connect_controls(export_btn: Button, html_export_btn: Button) -> void:
	# Display options
	if controls.has("show_issues_check"):
		controls.show_issues_check.toggled.connect(_on_show_issues_toggled)
	if controls.has("show_debt_check"):
		controls.show_debt_check.toggled.connect(_on_show_debt_toggled)
	if controls.has("show_json_export_check"):
		controls.show_json_export_check.toggled.connect(func(pressed): _on_show_json_export_toggled(pressed, export_btn))
	if controls.has("show_html_export_check"):
		controls.show_html_export_check.toggled.connect(func(pressed): _on_show_html_export_toggled(pressed, html_export_btn))
	if controls.has("show_ignored_check"):
		controls.show_ignored_check.toggled.connect(_on_show_ignored_toggled)
	if controls.has("show_full_path_check"):
		controls.show_full_path_check.toggled.connect(_on_show_full_path_toggled)

	# Scanning options
	if controls.has("respect_gdignore_check"):
		controls.respect_gdignore_check.toggled.connect(_on_respect_gdignore_toggled)
	if controls.has("scan_addons_check"):
		controls.scan_addons_check.toggled.connect(_on_scan_addons_toggled)
	if controls.has("remember_filters_check"):
		controls.remember_filters_check.toggled.connect(_on_remember_filters_toggled)

	# Code checks - Enable All / Disable All buttons
	if controls.has("enable_all_checks_btn"):
		controls.enable_all_checks_btn.pressed.connect(_on_enable_all_checks)
	if controls.has("disable_all_checks_btn"):
		controls.disable_all_checks_btn.pressed.connect(_on_disable_all_checks)

	# Code checks - Individual toggles
	_connect_check_signals()

	# Analysis limits (delegated to handler)
	_limits_handler = SettingsLimitsHandler.new(config, controls, save_project_setting)
	_limits_handler.connect_controls()

	# Claude Code settings
	if controls.has("claude_enabled_check"):
		controls.claude_enabled_check.toggled.connect(_on_claude_enabled_toggled)
	if controls.has("claude_command_edit"):
		controls.claude_command_edit.text_changed.connect(_on_claude_command_changed)
	if controls.has("claude_instructions_edit"):
		controls.claude_instructions_edit.text_changed.connect(_on_claude_instructions_changed)
	if controls.has("claude_reset_button"):
		controls.claude_reset_button.pressed.connect(_on_claude_command_reset_pressed)
	if controls.has("claude_instructions_reset_button"):
		controls.claude_instructions_reset_button.pressed.connect(_on_claude_instructions_reset_pressed)


# Save a per-project setting to .gdqube.cfg
func save_project_setting(key: String, value: Variant) -> void:
	if project_directory.is_empty():
		return

	var config_path := project_directory.path_join(".gdqube.cfg")
	var cfg := ConfigFile.new()

	if FileAccess.file_exists(config_path):
		cfg.load(config_path)

	# Parse key like "code_quality/limits/file_lines_warn" into section/key
	var parts := key.split("/")
	if parts.size() >= 3:
		var section := parts[1]  # e.g., "limits"
		var setting_key := parts[2]  # e.g., "file_lines_warn"
		cfg.set_value(section, setting_key, value)

	cfg.save(config_path)
	setting_changed.emit(key, value)


# ========== Display Options Handlers (Global via App) ==========

func _on_show_issues_toggled(pressed: bool) -> void:
	show_total_issues = pressed
	App.SetCodeQualityCardCollapseState("display/show_issues", not pressed)
	display_refresh_needed.emit()


func _on_show_debt_toggled(pressed: bool) -> void:
	show_debt = pressed
	App.SetCodeQualityCardCollapseState("display/show_debt", not pressed)
	display_refresh_needed.emit()


func _on_show_json_export_toggled(pressed: bool, export_btn: Button) -> void:
	show_json_export = pressed
	App.SetCodeQualityCardCollapseState("display/show_json_export", not pressed)
	export_btn.visible = pressed


func _on_show_html_export_toggled(pressed: bool, html_export_btn: Button) -> void:
	show_html_export = pressed
	App.SetCodeQualityCardCollapseState("display/show_html_export", not pressed)
	html_export_btn.visible = pressed


func _on_show_ignored_toggled(pressed: bool) -> void:
	show_ignored_issues = pressed
	App.SetCodeQualityCardCollapseState("display/show_ignored", not pressed)
	display_refresh_needed.emit()


func _on_show_full_path_toggled(pressed: bool) -> void:
	show_full_path = pressed
	App.SetCodeQualityCardCollapseState("display/show_full_path", not pressed)
	display_refresh_needed.emit()


func _on_respect_gdignore_toggled(pressed: bool) -> void:
	respect_gdignore = pressed
	config.respect_gdignore = pressed
	save_project_setting("code_quality/scanning/respect_gdignore", pressed)


func _on_scan_addons_toggled(pressed: bool) -> void:
	scan_addons = pressed
	config.include_addons = pressed
	save_project_setting("code_quality/scanning/scan_addons", pressed)


func _on_remember_filters_toggled(pressed: bool) -> void:
	remember_filter_selections = pressed
	save_project_setting("code_quality/scanning/remember_filters", pressed)


# Save filter selections (called by code-quality-manager.gd when filters change)
func save_filter_selections(severity_index: int, type_id: String, file_text: String) -> void:
	if not remember_filter_selections:
		return
	saved_severity_filter = severity_index
	saved_type_filter = type_id
	saved_file_filter = file_text
	save_project_setting("code_quality/filters/severity", severity_index)
	save_project_setting("code_quality/filters/type", type_id)
	save_project_setting("code_quality/filters/file", file_text)


# ========== Claude Code Handlers (Global via App) ==========

func _on_claude_enabled_toggled(pressed: bool) -> void:
	App.SetClaudeCodeButtonEnabled(pressed)
	display_refresh_needed.emit()


func _on_claude_command_changed(new_text: String) -> void:
	App.SetClaudeCodeLaunchCommand(new_text)


func _on_claude_instructions_changed() -> void:
	if controls.has("claude_instructions_edit"):
		App.SetClaudeCodeCustomInstructions(controls.claude_instructions_edit.text)


func _on_claude_command_reset_pressed() -> void:
	if controls.has("claude_command_edit"):
		controls.claude_command_edit.text = CLAUDE_CODE_DEFAULT_COMMAND
	App.SetClaudeCodeLaunchCommand(CLAUDE_CODE_DEFAULT_COMMAND)


func _on_claude_instructions_reset_pressed() -> void:
	var default_instructions: String = App.GetDefaultClaudeCodeInstructions()
	if controls.has("claude_instructions_edit"):
		controls.claude_instructions_edit.text = default_instructions
	App.SetClaudeCodeCustomInstructions(default_instructions)


# ========== Code Checks Handlers (Per-Project) ==========

func _connect_check_signals() -> void:
	var check_mappings := {
		"check_naming_conventions": "naming_conventions",
		"check_long_lines": "long_lines",
		"check_todo_comments": "todo_comments",
		"check_print_statements": "print_statements",
		"check_magic_numbers": "magic_numbers",
		"check_commented_code": "commented_code",
		"check_missing_types": "missing_types",
		"check_function_length": "function_length",
		"check_parameters": "parameters",
		"check_nesting": "nesting",
		"check_cyclomatic_complexity": "cyclomatic_complexity",
		"check_empty_functions": "empty_functions",
		"check_missing_return_type": "missing_return_type",
		"check_file_length": "file_length",
		"check_god_class": "god_class",
		"check_unused_variables": "unused_variables",
		"check_unused_parameters": "unused_parameters",
	}

	for control_key in check_mappings:
		if controls.has(control_key):
			var setting_suffix: String = check_mappings[control_key]
			controls[control_key].toggled.connect(
				func(pressed): _on_check_toggled(control_key, setting_suffix, pressed)
			)


func _on_check_toggled(control_key: String, setting_suffix: String, pressed: bool) -> void:
	set(control_key, pressed)
	if config.get(control_key) != null:
		config.set(control_key, pressed)
	save_project_setting("code_quality/checks/" + setting_suffix, pressed)
	setting_changed.emit("check_" + setting_suffix, pressed)


func _on_enable_all_checks() -> void:
	_set_all_checks(true)


func _on_disable_all_checks() -> void:
	_set_all_checks(false)


func _set_all_checks(enabled: bool) -> void:
	for control_key in _check_control_keys:
		if controls.has(control_key):
			controls[control_key].button_pressed = enabled
	setting_changed.emit("all_checks", enabled)
