@tool
class_name PluginSyncManager
extends RefCounted

signal sync_completed(plugin_name: String, success: bool, message: String)
signal all_syncs_completed(success_count: int, fail_count: int)

var _exclude_patterns: Array = []


func SyncPlugin(plugin: Dictionary, exclude_patterns: Array) -> Dictionary:
	_exclude_patterns = exclude_patterns
	var result := {"success": false, "message": "", "files_copied": 0, "resource_files": []}

	var source_path: String = plugin.source
	var plugin_name: String = plugin.name
	var dest_path := ProjectSettings.globalize_path("res://addons").path_join(plugin_name)
	var res_prefix := "res://addons/" + plugin_name + "/"

	# Validate source exists
	if not DirAccess.dir_exists_absolute(source_path):
		result.message = "Source not found: " + source_path
		return result

	# Remove existing destination
	if DirAccess.dir_exists_absolute(dest_path):
		var remove_result := _RemoveDirectoryRecursive(dest_path)
		if not remove_result.success:
			result.message = "Failed to remove existing: " + remove_result.message
			return result

	# Copy source to destination
	var copy_result := _CopyDirectoryRecursive(source_path, dest_path, res_prefix)
	if not copy_result.success:
		result.message = "Copy failed: " + copy_result.message
		return result

	result.success = true
	result.files_copied = copy_result.files_copied
	result.resource_files = copy_result.resource_files
	result.message = "Synced %d files" % copy_result.files_copied
	return result


func SyncAllEnabled(config: PluginSyncConfig) -> Dictionary:
	var results := {"success_count": 0, "fail_count": 0, "details": [], "resource_files": []}
	var enabled_plugins := config.GetEnabledPlugins()

	for plugin in enabled_plugins:
		var result := SyncPlugin(plugin, config.exclude_patterns)
		var detail := {
			"name": plugin.name,
			"success": result.success,
			"message": result.message
		}
		results.details.append(detail)

		if result.success:
			results.success_count += 1
			results.resource_files.append_array(result.resource_files)
			sync_completed.emit(plugin.name, true, result.message)
		else:
			results.fail_count += 1
			sync_completed.emit(plugin.name, false, result.message)

	all_syncs_completed.emit(results.success_count, results.fail_count)
	return results


func _RemoveDirectoryRecursive(dir_path: String) -> Dictionary:
	var result := {"success": false, "message": ""}
	var dir := DirAccess.open(dir_path)

	if not dir:
		result.message = "Cannot open directory"
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path := dir_path.path_join(file_name)
			if dir.current_is_dir():
				var sub_result := _RemoveDirectoryRecursive(full_path)
				if not sub_result.success:
					dir.list_dir_end()
					return sub_result
			else:
				var err := dir.remove(file_name)
				if err != OK:
					result.message = "Failed to remove file: " + file_name
					dir.list_dir_end()
					return result
		file_name = dir.get_next()

	dir.list_dir_end()

	# Remove the directory itself
	var parent_path := dir_path.get_base_dir()
	var dir_name := dir_path.get_file()
	var parent_dir := DirAccess.open(parent_path)
	if parent_dir:
		var err := parent_dir.remove(dir_name)
		if err != OK:
			result.message = "Failed to remove directory: " + dir_name
			return result

	result.success = true
	return result


# Resource file extensions that need reimporting
const RESOURCE_EXTENSIONS := [".svg", ".png", ".jpg", ".jpeg", ".webp", ".tga", ".bmp",
	".wav", ".ogg", ".mp3", ".ttf", ".otf", ".woff", ".woff2",
	".obj", ".gltf", ".glb", ".fbx", ".dae"]

func _CopyDirectoryRecursive(source: String, dest: String, res_prefix: String = "") -> Dictionary:
	var result := {"success": false, "message": "", "files_copied": 0, "resource_files": []}

	# Create destination directory
	var err := DirAccess.make_dir_recursive_absolute(dest)
	if err != OK:
		result.message = "Failed to create directory: " + dest
		return result

	var dir := DirAccess.open(source)
	if not dir:
		result.message = "Cannot open source: " + source
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name != "." and file_name != "..":
			var source_path := source.path_join(file_name)
			var dest_path := dest.path_join(file_name)

			if not _ShouldExclude(file_name):
				if dir.current_is_dir():
					var sub_res_prefix := res_prefix + file_name + "/" if res_prefix else ""
					var sub_result := _CopyDirectoryRecursive(source_path, dest_path, sub_res_prefix)
					if not sub_result.success:
						dir.list_dir_end()
						return sub_result
					result.files_copied += sub_result.files_copied
					result.resource_files.append_array(sub_result.resource_files)
				else:
					var copy_err := dir.copy(source_path, dest_path)
					if copy_err != OK:
						result.message = "Failed to copy: " + file_name
						dir.list_dir_end()
						return result
					result.files_copied += 1
					# Track resource files that need reimporting
					if res_prefix and _IsResourceFile(file_name):
						result.resource_files.append(res_prefix + file_name)

		file_name = dir.get_next()

	dir.list_dir_end()
	result.success = true
	return result


func _IsResourceFile(file_name: String) -> bool:
	var lower_name := file_name.to_lower()
	for ext in RESOURCE_EXTENSIONS:
		if lower_name.ends_with(ext):
			return true
	return false


func _ShouldExclude(file_name: String) -> bool:
	for pattern in _exclude_patterns:
		if _MatchesPattern(file_name, pattern):
			return true
	return false


func _MatchesPattern(file_name: String, pattern: String) -> bool:
	# Exact match
	if file_name == pattern:
		return true

	# Wildcard pattern (e.g., "*.import")
	if pattern.begins_with("*"):
		var suffix := pattern.substr(1)
		if file_name.ends_with(suffix):
			return true

	# Wildcard pattern (e.g., "test*")
	if pattern.ends_with("*"):
		var prefix := pattern.substr(0, pattern.length() - 1)
		if file_name.begins_with(prefix):
			return true

	return false
