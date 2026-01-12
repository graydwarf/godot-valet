@tool
class_name PluginSyncConfig
extends RefCounted

const CONFIG_FILE_NAME := "plugin-sync.json"
const DEFAULT_EXCLUDE_PATTERNS := [".git", "*.import", "*.uid"]

var version: String = "1.0"
var exclude_patterns: Array = DEFAULT_EXCLUDE_PATTERNS.duplicate()
var plugins: Array = []
var config_path: String = ""
var load_error: String = ""


static func LoadFromProject() -> PluginSyncConfig:
	var config := PluginSyncConfig.new()
	config.config_path = ProjectSettings.globalize_path("res://").path_join(CONFIG_FILE_NAME)

	if not FileAccess.file_exists(config.config_path):
		config.load_error = "Config file not found: " + CONFIG_FILE_NAME
		return config

	var file := FileAccess.open(config.config_path, FileAccess.READ)
	if not file:
		config.load_error = "Failed to open config file"
		return config

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		config.load_error = "JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()]
		return config

	var data: Dictionary = json.data
	if not data is Dictionary:
		config.load_error = "Config must be a JSON object"
		return config

	config._ParseData(data)
	return config


func _ParseData(data: Dictionary) -> void:
	version = data.get("version", "1.0")

	if data.has("exclude_patterns") and data.exclude_patterns is Array:
		exclude_patterns = data.exclude_patterns.duplicate()

	if not data.has("plugins") or not data.plugins is Array:
		load_error = "Config missing 'plugins' array"
		return

	for plugin_data in data.plugins:
		var plugin := _ParsePluginEntry(plugin_data)
		if plugin.has("error"):
			load_error = plugin.error
			return
		plugins.append(plugin)


func _ParsePluginEntry(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return {"error": "Plugin entry must be an object"}

	if not data.has("name") or data.name == "":
		return {"error": "Plugin entry missing 'name'"}

	if not data.has("source") or data.source == "":
		return {"error": "Plugin '%s' missing 'source'" % data.name}

	return {
		"name": data.name,
		"source": data.source,
		"enabled": data.get("enabled", true),
		"description": data.get("description", "")
	}


func IsValid() -> bool:
	return load_error == "" and plugins.size() > 0


func GetEnabledPlugins() -> Array:
	var enabled := []
	for plugin in plugins:
		if plugin.enabled:
			enabled.append(plugin)
	return enabled


func GetPluginByName(plugin_name: String) -> Dictionary:
	for plugin in plugins:
		if plugin.name == plugin_name:
			return plugin
	return {}


func ValidateSourcePaths() -> Dictionary:
	var results := {}
	for plugin in plugins:
		var source_path: String = plugin.source
		results[plugin.name] = DirAccess.dir_exists_absolute(source_path)
	return results
