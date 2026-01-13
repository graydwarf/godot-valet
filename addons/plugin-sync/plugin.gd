@tool
extends EditorPlugin

const SyncMenuScript := preload("res://addons/plugin-sync/ui/sync-menu.gd")
const ConfigManagerScript := preload("res://addons/plugin-sync/config-manager.gd")
const SyncManagerScript := preload("res://addons/plugin-sync/sync-manager.gd")

var _toolbar_button: MenuButton
var _sync_menu: PopupMenu
var _config: PluginSyncConfig
var _sync_manager: PluginSyncManager
var _cooldown_timer: Timer


func _enter_tree() -> void:
	_sync_manager = SyncManagerScript.new()

	_toolbar_button = MenuButton.new()
	_toolbar_button.text = "Sync Plugins"
	_toolbar_button.tooltip_text = "Synchronize addon plugins from source repositories"
	_toolbar_button.flat = false

	_sync_menu = _toolbar_button.get_popup()
	_sync_menu.set_script(SyncMenuScript)

	_sync_menu.sync_all_requested.connect(_on_sync_all_requested)
	_sync_menu.sync_plugin_requested.connect(_on_sync_plugin_requested)
	_sync_menu.open_config_requested.connect(_on_open_config_requested)

	# Create cooldown timer
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	_cooldown_timer.timeout.connect(_on_cooldown_finished)
	add_child(_cooldown_timer)

	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, _toolbar_button)

	_RefreshConfig()


func _exit_tree() -> void:
	if _cooldown_timer:
		_cooldown_timer.queue_free()
		_cooldown_timer = null
	if _toolbar_button:
		remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, _toolbar_button)
		_toolbar_button.queue_free()
		_toolbar_button = null


func _StartCooldown() -> void:
	var cooldown_sec := _sync_manager.SYNC_COOLDOWN_MS / 1000.0
	_toolbar_button.disabled = true
	_toolbar_button.text = "Sync Plugins (%.0fs)" % cooldown_sec
	_cooldown_timer.start(cooldown_sec)


func _on_cooldown_finished() -> void:
	_toolbar_button.disabled = false
	_toolbar_button.text = "Sync Plugins"


func _RefreshConfig() -> void:
	_config = ConfigManagerScript.LoadFromProject()

	if _config.IsValid():
		_sync_menu.BuildMenu(_config)
	else:
		_sync_menu.BuildNoConfigMenu()
		if _config.load_error != "":
			push_warning("[Plugin Sync] " + _config.load_error)


func _on_sync_all_requested() -> void:
	if not _config or not _config.IsValid():
		_ShowNotification("No valid config found", true)
		return

	var enabled := _config.GetEnabledPlugins()
	if enabled.size() == 0:
		_ShowNotification("No enabled plugins to sync", true)
		return

	print("[Plugin Sync] Syncing %d plugins..." % enabled.size())

	var results := _sync_manager.SyncAllEnabled(_config)

	# Refresh filesystem - scan() will trigger reimports for modified files
	EditorInterface.get_resource_filesystem().scan()

	# Show notification
	if results.fail_count == 0:
		_ShowNotification("Synced %d plugins successfully" % results.success_count, false)
	else:
		_ShowNotification("Synced %d/%d (check console for errors)" % [results.success_count, results.success_count + results.fail_count], true)

	# Log details
	for detail in results.details:
		if detail.success:
			print("[Plugin Sync] %s: %s" % [detail.name, detail.message])
		else:
			push_error("[Plugin Sync] %s: %s" % [detail.name, detail.message])

	_StartCooldown()


func _on_sync_plugin_requested(plugin_name: String) -> void:
	if not _config or not _config.IsValid():
		_ShowNotification("No valid config found", true)
		return

	var plugin := _config.GetPluginByName(plugin_name)
	if plugin.is_empty():
		_ShowNotification("Plugin not found: " + plugin_name, true)
		return

	print("[Plugin Sync] Syncing %s..." % plugin_name)

	var result := _sync_manager.SyncPlugin(plugin, _config.exclude_patterns)

	# Refresh filesystem - scan() will trigger reimports for modified files
	EditorInterface.get_resource_filesystem().scan()

	if result.success:
		_ShowNotification("Synced " + plugin_name, false)
		print("[Plugin Sync] %s: %s" % [plugin_name, result.message])
		_StartCooldown()
	else:
		_ShowNotification("Failed: " + plugin_name, true)
		push_error("[Plugin Sync] %s: %s" % [plugin_name, result.message])


func _on_open_config_requested() -> void:
	var config_path := ProjectSettings.globalize_path("res://plugin-sync.json")

	if FileAccess.file_exists(config_path):
		OS.shell_open(config_path)
	else:
		# Show where to create it
		var project_path := ProjectSettings.globalize_path("res://")
		push_warning("[Plugin Sync] Config not found. Create 'plugin-sync.json' in: " + project_path)
		OS.shell_open(project_path)


func _ShowNotification(message: String, is_error: bool) -> void:
	# Use EditorToaster for notifications (Godot 4.x)
	if is_error:
		push_error("[Plugin Sync] " + message)
	else:
		print("[Plugin Sync] " + message)

	# Show toast notification in editor
	var toast_type := 0 if not is_error else 1  # 0 = info, 1 = warning
	if EditorInterface.has_method("get_editor_toaster"):
		# Godot 4.3+ has toaster
		pass
	# Fallback: Use a temporary label (works in all versions)
	_ShowTemporaryNotification(message, is_error)


func _ShowTemporaryNotification(message: String, is_error: bool) -> void:
	# Create a temporary notification panel
	var panel := PanelContainer.new()
	var label := Label.new()
	label.text = message

	if is_error:
		label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	else:
		label.add_theme_color_override("font_color", Color(0.4, 1, 0.4))

	panel.add_child(label)

	# Add to editor UI
	var editor_base := EditorInterface.get_base_control()
	editor_base.add_child(panel)

	# Position at bottom center
	await editor_base.get_tree().process_frame
	panel.position = Vector2(
		(editor_base.size.x - panel.size.x) / 2,
		editor_base.size.y - panel.size.y - 50
	)

	# Fade out and remove after 3 seconds
	var tween := editor_base.create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(panel, "modulate:a", 0.0, 1.0)
	tween.tween_callback(panel.queue_free)
