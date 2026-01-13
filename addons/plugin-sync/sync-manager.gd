@tool
class_name PluginSyncManager
extends RefCounted

signal sync_completed(plugin_name: String, success: bool, message: String)
signal all_syncs_completed(success_count: int, fail_count: int)

var _exclude_patterns: Array = []
var _last_sync_time: int = 0
const SYNC_COOLDOWN_MS: int = 2000  # Minimum time between syncs to let Godot finish reimporting


# Returns seconds remaining in cooldown, or 0 if ready to sync
func GetCooldownRemaining() -> float:
	if _last_sync_time == 0:
		return 0.0
	var elapsed := Time.get_ticks_msec() - _last_sync_time
	var remaining := SYNC_COOLDOWN_MS - elapsed
	return max(0.0, remaining / 1000.0)


func SyncPlugin(plugin: Dictionary, exclude_patterns: Array, skip_cooldown: bool = false) -> Dictionary:
	_exclude_patterns = exclude_patterns
	var result := {"success": false, "message": "", "files_copied": 0, "resource_files": [], "skipped": false}

	# Check cooldown to prevent rapid syncs that confuse Godot's reimport system
	if not skip_cooldown:
		var current_time := Time.get_ticks_msec()
		var time_since_last := current_time - _last_sync_time
		if _last_sync_time > 0 and time_since_last < SYNC_COOLDOWN_MS:
			var wait_time := (SYNC_COOLDOWN_MS - time_since_last) / 1000.0
			result.message = "Cooldown: wait %.1f seconds" % wait_time
			result.skipped = true
			return result

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
	var results := {"success_count": 0, "fail_count": 0, "skipped_count": 0, "details": [], "resource_files": []}

	# Check cooldown at batch level
	var current_time := Time.get_ticks_msec()
	var time_since_last := current_time - _last_sync_time
	if _last_sync_time > 0 and time_since_last < SYNC_COOLDOWN_MS:
		var wait_time := (SYNC_COOLDOWN_MS - time_since_last) / 1000.0
		results.skipped_count = config.GetEnabledPlugins().size()
		results.details.append({"name": "all", "success": false, "message": "Cooldown: wait %.1f seconds" % wait_time, "skipped": true})
		return results

	var enabled_plugins := config.GetEnabledPlugins()

	for plugin in enabled_plugins:
		var result := SyncPlugin(plugin, config.exclude_patterns, true)  # Skip per-plugin cooldown
		var detail := {
			"name": plugin.name,
			"success": result.success,
			"message": result.message,
			"skipped": result.get("skipped", false)
		}
		results.details.append(detail)

		if result.get("skipped", false):
			results.skipped_count += 1
			sync_completed.emit(plugin.name, false, result.message)
		elif result.success:
			results.success_count += 1
			results.resource_files.append_array(result.resource_files)
			sync_completed.emit(plugin.name, true, result.message)
		else:
			results.fail_count += 1
			sync_completed.emit(plugin.name, false, result.message)

	all_syncs_completed.emit(results.success_count, results.fail_count)
	_last_sync_time = Time.get_ticks_msec()  # Update cooldown after batch completes
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


# Resource file extensions that need reimporting (UIDs stored in .import files, not .uid files)
const RESOURCE_EXTENSIONS := [".svg", ".png", ".jpg", ".jpeg", ".webp", ".tga", ".bmp",
	".wav", ".ogg", ".mp3", ".ttf", ".otf", ".woff", ".woff2",
	".obj", ".gltf", ".glb", ".fbx", ".dae"]

# Scene/resource files that may contain ext_resource UID references
const SCENE_EXTENSIONS := [".tscn", ".tres"]

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
					# Copy file (with UID stripping for scene files)
					var copy_err: Error
					if _IsSceneFile(file_name):
						copy_err = _CopyAndProcessSceneFile(source_path, dest_path)
					else:
						copy_err = dir.copy(source_path, dest_path)
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


func _IsSceneFile(file_name: String) -> bool:
	var lower_name := file_name.to_lower()
	for ext in SCENE_EXTENSIONS:
		if lower_name.ends_with(ext):
			return true
	return false


# Copy a scene/resource file while stripping UIDs for imported assets
func _CopyAndProcessSceneFile(source_path: String, dest_path: String) -> Error:
	var file := FileAccess.open(source_path, FileAccess.READ)
	if not file:
		return ERR_FILE_CANT_OPEN

	var content := file.get_as_text()
	file.close()
	file = null  # Explicitly release

	var processed_content := _StripImportedAssetUIDs(content)

	var out_file := FileAccess.open(dest_path, FileAccess.WRITE)
	if not out_file:
		return ERR_FILE_CANT_WRITE

	out_file.store_string(processed_content)
	out_file.flush()  # Ensure written to disk
	out_file.close()
	out_file = null  # Explicitly release
	return OK


# Strip uid="uid://xxx" from ext_resource lines that reference imported assets.
# Imported assets (.png, .svg, etc.) have UIDs in .import files which aren't synced,
# so these UID references would cause mismatch warnings in the destination project.
func _StripImportedAssetUIDs(content: String) -> String:
	var lines := content.split("\n")
	var result_lines := PackedStringArray()

	for line in lines:
		if line.begins_with("[ext_resource") and _LineReferencesImportedAsset(line):
			line = _RemoveUIDFromLine(line)
		result_lines.append(line)

	return "\n".join(result_lines)


# Check if an ext_resource line references an imported asset type
func _LineReferencesImportedAsset(line: String) -> bool:
	var path_start := line.find('path="')
	if path_start == -1:
		return false

	var path_content_start := path_start + 6  # len('path="')
	var path_end := line.find('"', path_content_start)
	if path_end == -1:
		return false

	var resource_path := line.substr(path_content_start, path_end - path_content_start)
	var lower_path := resource_path.to_lower()

	for ext in RESOURCE_EXTENSIONS:
		if lower_path.ends_with(ext):
			return true
	return false


# Remove uid="uid://..." from a line
func _RemoveUIDFromLine(line: String) -> String:
	var uid_start := line.find('uid="uid://')
	if uid_start == -1:
		return line

	var uid_content_start := uid_start + 5  # len('uid="')
	var uid_end := line.find('"', uid_content_start)
	if uid_end == -1:
		return line

	var before := line.substr(0, uid_start)
	var after := line.substr(uid_end + 1)

	# Clean up extra space
	if after.begins_with(" "):
		after = after.substr(1)

	return before + after
