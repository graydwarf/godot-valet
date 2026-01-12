@tool
class_name PluginSyncMenu
extends PopupMenu

signal sync_all_requested
signal sync_plugin_requested(plugin_name: String)
signal open_config_requested

const ID_SYNC_ALL := 0
const ID_SEPARATOR_1 := 1
const ID_PLUGIN_BASE := 100
const ID_SEPARATOR_2 := 1000
const ID_OPEN_CONFIG := 1001

var _plugin_names: Array = []


func BuildMenu(config: PluginSyncConfig) -> void:
	clear()
	_plugin_names.clear()

	var enabled_count := config.GetEnabledPlugins().size()

	# Sync All option
	add_item("Sync All Enabled (%d)" % enabled_count, ID_SYNC_ALL)
	set_item_disabled(get_item_index(ID_SYNC_ALL), enabled_count == 0)

	add_separator("", ID_SEPARATOR_1)

	# Individual plugins
	var source_validity := config.ValidateSourcePaths()
	var index := 0
	for plugin in config.plugins:
		var item_id := ID_PLUGIN_BASE + index
		var label: String = plugin.name
		if not plugin.enabled:
			label += " (disabled)"

		add_item(label, item_id)
		_plugin_names.append(plugin.name)

		# Set tooltip with description and source
		var tooltip: String = plugin.source
		if plugin.description != "":
			tooltip = plugin.description + "\n" + tooltip
		set_item_tooltip(get_item_index(item_id), tooltip)

		# Mark invalid sources
		if not source_validity.get(plugin.name, false):
			set_item_icon(get_item_index(item_id), get_theme_icon("StatusWarning", "EditorIcons"))

		index += 1

	add_separator("", ID_SEPARATOR_2)

	# Open config option
	add_item("Open Config...", ID_OPEN_CONFIG)


func BuildNoConfigMenu() -> void:
	clear()
	_plugin_names.clear()

	add_item("Config not found", -1)
	set_item_disabled(0, true)
	add_separator()
	add_item("See README for setup", -1)
	set_item_disabled(2, true)


func _ready() -> void:
	id_pressed.connect(_on_id_pressed)


func _on_id_pressed(id: int) -> void:
	if id == ID_SYNC_ALL:
		sync_all_requested.emit()
	elif id == ID_OPEN_CONFIG:
		open_config_requested.emit()
	elif id >= ID_PLUGIN_BASE and id < ID_SEPARATOR_2:
		var plugin_index := id - ID_PLUGIN_BASE
		if plugin_index < _plugin_names.size():
			sync_plugin_requested.emit(_plugin_names[plugin_index])
