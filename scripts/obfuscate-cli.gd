extends SceneTree

# CLI entry point for headless obfuscation and export pipeline
# Usage: Godot --headless --path /path/to/godot-valet --script res://scripts/obfuscate-cli.gd -- [options]
#
# Options:
#   --config <path>           Path to obfuscation.cfg config file
#   --project-dir <path>      Source project directory (overrides config)
#   --output <path>           Output directory (overrides config)
#   --functions               Enable function obfuscation (default: true)
#   --no-functions            Disable function obfuscation
#   --variables               Enable variable obfuscation (default: true)
#   --no-variables            Disable variable obfuscation
#   --comments                Enable comment removal (default: true)
#   --no-comments             Disable comment removal
#   --constants               Enable constant/enum value inlining (default: false)
#   --no-constants            Disable constant/enum value inlining
#   --skip-addons             Skip addons/ directory during obfuscation (default: true)
#   --no-skip-addons          Include addons/ directory in obfuscation
#   --skip-dirs <dirs>        Comma-separated list of additional directories to skip
#   --validate                Run headless validation after obfuscation to count errors
#   --export <preset>         Export after obfuscation using this preset name
#   --godot-path <path>       Custom Godot binary for export (required with --export)
#   --encryption-key <path>   Path to file containing hex encryption key
#   --export-output <path>    Copy final build artifacts to this location
#   --debug                   Use --export-debug instead of --export-release
#   --help                    Show usage info

func _init():
	var args := _parse_args(OS.get_cmdline_user_args())

	if args.get("help", false):
		_print_usage()
		call_deferred("quit", 0)
		return

	var config_path: String = args.get("config", "")
	var config := _load_config(config_path)

	var project_dir: String = args.get("project-dir", config.get("project_dir", ""))
	var output_dir: String = args.get("output", config.get("output_dir", ""))

	if project_dir.is_empty():
		printerr("Error: --project-dir is required (or set project_dir in config [paths] section)")
		call_deferred("quit", 1)
		return
	if output_dir.is_empty():
		printerr("Error: --output is required (or set output_dir in config [paths] section)")
		call_deferred("quit", 1)
		return

	project_dir = project_dir.replace("\\", "/")
	output_dir = output_dir.replace("\\", "/")

	var obfuscate_functions: bool = _resolve_flag(args, "functions", config.get("functions", true))
	var obfuscate_variables: bool = _resolve_flag(args, "variables", config.get("variables", true))
	var obfuscate_comments: bool = _resolve_flag(args, "comments", config.get("comments", true))
	var inline_constants: bool = _resolve_flag(args, "constants", config.get("constants", false))
	var inject_dead_code: bool = _resolve_flag(args, "dead-code", config.get("dead_code", false))
	var encrypt_strings: bool = _resolve_flag(args, "strings", config.get("strings", false))
	var skip_addons: bool = _resolve_flag(args, "skip-addons", config.get("skip_addons", true))

	var skip_dirs: Array[String] = [".godot", ".import"]
	if skip_addons:
		skip_dirs.append("addons")
	var extra_skip: Array[String] = _parse_csv(args.get("skip-dirs", config.get("skip_dirs", "")))
	for dir in extra_skip:
		if dir not in skip_dirs:
			skip_dirs.append(dir)
	ObfuscateHelper.SetSkipDirectories(skip_dirs)

	var func_excludes: Array[String] = config.get("function_excludes", [] as Array[String])
	var var_excludes: Array[String] = config.get("variable_excludes", [] as Array[String])
	var ext_classes: Array[String] = config.get("external_classes", [] as Array[String])
	var const_excludes: Array[String] = config.get("constant_excludes", [] as Array[String])

	ObfuscateHelper.SetFunctionExcludeList(func_excludes)
	ObfuscateHelper.SetVariableExcludeList(var_excludes)
	ObfuscateHelper.SetExternalPluginClasses(ext_classes)
	ObfuscateHelper.SetConstantExcludeList(const_excludes)

	# Export pipeline flags
	var export_preset: String = args.get("export", config.get("export_preset", ""))
	var godot_path: String = args.get("godot-path", config.get("export_godot_path", ""))
	var encryption_key_path: String = args.get("encryption-key", config.get("export_encryption_key", ""))
	var export_output: String = args.get("export-output", config.get("export_output", ""))
	var is_debug: bool = _resolve_flag(args, "debug", config.get("export_debug", false))

	if not export_preset.is_empty():
		godot_path = godot_path.replace("\\", "/")
		encryption_key_path = encryption_key_path.replace("\\", "/")
		export_output = export_output.replace("\\", "/")
		if godot_path.is_empty():
			printerr("Error: --godot-path is required when using --export")
			call_deferred("quit", 1)
			return
		if not FileAccess.file_exists(godot_path):
			printerr("Error: Godot binary not found: %s" % godot_path)
			call_deferred("quit", 1)
			return
		if not encryption_key_path.is_empty() and not FileAccess.file_exists(encryption_key_path):
			printerr("Error: Encryption key file not found: %s" % encryption_key_path)
			call_deferred("quit", 1)
			return

	print("Obfuscating: %s -> %s" % [project_dir, output_dir])
	print("  Functions: %s | Variables: %s | Comments: %s | Constants: %s | Dead Code: %s | Strings: %s" % [
		obfuscate_functions, obfuscate_variables, obfuscate_comments, inline_constants, inject_dead_code, encrypt_strings])
	print("  Skip dirs: %s" % [", ".join(skip_dirs)])
	if not export_preset.is_empty():
		print("  Export: preset=%s, debug=%s" % [export_preset, is_debug])

	var result: int = ObfuscateHelper.ObfuscateScripts(
		project_dir, output_dir,
		obfuscate_functions, obfuscate_variables, obfuscate_comments, inline_constants,
		inject_dead_code, encrypt_strings)

	if result != OK:
		printerr("Obfuscation failed with error code: %d" % result)
		call_deferred("quit", 1)
		return

	print("Obfuscation completed successfully.")

	if args.get("validate", false):
		var error_count = _validate_obfuscation(project_dir, output_dir)
		if error_count == 0:
			print("Validation PASSED: No obfuscation errors detected.")
		else:
			print("Validation: %d SCRIPT ERROR(s) detected." % error_count)

	if not export_preset.is_empty():
		var export_result := _run_export_pipeline(
			project_dir, output_dir, export_preset,
			godot_path, encryption_key_path, export_output, is_debug)
		call_deferred("quit", export_result)
		return

	call_deferred("quit", 0)

# Resolves a --flag / --no-flag pair, falling back to config default
static func _resolve_flag(args: Dictionary, flag_name: String, config_default: bool) -> bool:
	if args.has(flag_name):
		return args[flag_name]
	if args.has("no-" + flag_name):
		return false
	return config_default

# Parses CLI arguments after the -- separator
static func _parse_args(raw_args: PackedStringArray) -> Dictionary:
	var result := {}
	var i := 0
	while i < raw_args.size():
		var arg: String = raw_args[i]
		if not arg.begins_with("--"):
			i += 1
			continue

		var key := arg.substr(2)

		# Handle --key=value
		if "=" in key:
			var parts := key.split("=", true, 1)
			result[parts[0]] = parts[1]
			i += 1
			continue

		# Boolean flags: --help, --functions, --no-functions
		if key == "help" or key.begins_with("no-"):
			result[key] = true
			i += 1
			continue

		# Known boolean flags without values
		if key in ["functions", "variables", "comments", "constants", "dead-code", "strings", "skip-addons", "validate", "debug"]:
			if i + 1 < raw_args.size() and not raw_args[i + 1].begins_with("--"):
				result[key] = raw_args[i + 1].to_lower() == "true"
				i += 2
			else:
				result[key] = true
				i += 1
			continue

		# Key-value: --config path, --project-dir path, --output path
		if i + 1 < raw_args.size():
			result[key] = raw_args[i + 1]
			i += 2
		else:
			printerr("Warning: --" + key + " provided without a value")
			i += 1

	return result

# Loads an INI-style config file using Godot's ConfigFile
static func _load_config(config_path: String) -> Dictionary:
	var result := {}
	if config_path.is_empty():
		return result

	var config := ConfigFile.new()
	var err := config.load(config_path)
	if err != OK:
		printerr("Warning: Could not load config file: %s (error %d)" % [config_path, err])
		return result

	result["project_dir"] = config.get_value("paths", "project_dir", "")
	result["output_dir"] = config.get_value("paths", "output_dir", "")

	result["functions"] = config.get_value("obfuscation", "functions", true)
	result["variables"] = config.get_value("obfuscation", "variables", true)
	result["comments"] = config.get_value("obfuscation", "comments", true)
	result["constants"] = config.get_value("obfuscation", "constants", false)
	result["skip_addons"] = config.get_value("obfuscation", "skip_addons", true)

	result["skip_dirs"] = str(config.get_value("obfuscation", "skip_dirs", ""))

	# Export section
	result["export_preset"] = str(config.get_value("export", "preset", ""))
	result["export_godot_path"] = str(config.get_value("export", "godot_path", ""))
	result["export_encryption_key"] = str(config.get_value("export", "encryption_key", ""))
	result["export_output"] = str(config.get_value("export", "export_output", ""))
	result["export_debug"] = config.get_value("export", "debug", false)

	result["function_excludes"] = _parse_csv(str(config.get_value("exclude", "function_names", "")))
	result["variable_excludes"] = _parse_csv(str(config.get_value("exclude", "variable_names", "")))
	result["external_classes"] = _parse_csv(str(config.get_value("exclude", "external_classes", "")))
	result["constant_excludes"] = _parse_csv(str(config.get_value("exclude", "constant_names", "")))

	return result

# Splits a comma-separated string into a typed array, trimming whitespace
static func _parse_csv(text: String) -> Array[String]:
	var result: Array[String] = []
	if text.strip_edges().is_empty():
		return result
	for item in text.split(","):
		var trimmed := item.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)
	return result

# Validates obfuscated output by overlaying onto a copy of the source project
# and launching Godot headlessly to count SCRIPT ERRORs
func _validate_obfuscation(project_dir: String, output_dir: String) -> int:
	print("Validating obfuscated output...")

	# Create a temp validation directory
	var validate_dir := output_dir.rstrip("/") + "-validate"

	# Copy source project to validation directory
	var copy_output: Array = []
	if OS.get_name() == "Windows":
		OS.execute("cmd", ["/c", "xcopy", "/E", "/I", "/Y", "/Q",
			project_dir.replace("/", "\\"), validate_dir.replace("/", "\\")], copy_output, true)
	else:
		OS.execute("cp", ["-r", project_dir, validate_dir], copy_output, true)

	# Overlay obfuscated files
	if OS.get_name() == "Windows":
		OS.execute("cmd", ["/c", "xcopy", "/E", "/Y", "/Q",
			output_dir.replace("/", "\\"), validate_dir.replace("/", "\\")], copy_output, true)
	else:
		OS.execute("cp", ["-r", output_dir + "/.", validate_dir], copy_output, true)

	# Launch Godot headlessly on the validation copy
	var godot_path := OS.get_executable_path()
	var run_output: Array = []
	OS.execute(godot_path, ["--headless", "--path", validate_dir, "--quit-after", "5"], run_output, true)

	# Count SCRIPT ERRORs in output, tracking which come from skipped directories
	var skip_dirs := ObfuscateHelper._skipDirectories
	var error_count := 0
	var skip_dir_errors := 0
	var skip_dir_names: Dictionary = {}
	for line in run_output:
		for output_line in str(line).split("\n"):
			if "SCRIPT ERROR" in output_line:
				var from_skip_dir := false
				for skip_dir in skip_dirs:
					if ("res://" + skip_dir + "/") in output_line:
						from_skip_dir = true
						skip_dir_errors += 1
						skip_dir_names[skip_dir] = skip_dir_names.get(skip_dir, 0) + 1
						break
				if not from_skip_dir:
					error_count += 1
					if error_count <= 20:
						print("  ", output_line.strip_edges())

	if error_count > 20:
		print("  ... and %d more errors" % (error_count - 20))

	if skip_dir_errors > 0:
		print("")
		print("  Note: %d error(s) from skipped directories (not counted above):" % skip_dir_errors)
		for dir_name in skip_dir_names:
			print("    %s/ — %d error(s)" % [dir_name, skip_dir_names[dir_name]])
		print("  These directories were not obfuscated but reference renamed symbols.")
		print("  Consider excluding them from your export or adding them to your obfuscation scope.")

	# Clean up validation directory
	_cleanup_dir(validate_dir)

	return error_count

# Runs the full export pipeline: copy project → overlay obfuscated files → export
# Returns 0 on success, 2 on export error
func _run_export_pipeline(project_dir: String, output_dir: String, preset: String,
		godot_path: String, encryption_key_path: String, export_output: String, is_debug: bool) -> int:
	var build_dir := output_dir.rstrip("/") + "-build"
	print("")
	print("=== Export Pipeline ===")
	print("  Build dir: %s" % build_dir)

	# Step 1: Copy full source project to build dir
	print("  Copying project to build directory...")
	var copy_output: Array = []
	if OS.get_name() == "Windows":
		OS.execute("cmd", ["/c", "xcopy", "/E", "/I", "/Y", "/Q",
			project_dir.replace("/", "\\"), build_dir.replace("/", "\\")], copy_output, true)
	else:
		OS.execute("cp", ["-r", project_dir, build_dir], copy_output, true)

	if not DirAccess.dir_exists_absolute(build_dir):
		printerr("Error: Failed to copy project to build directory")
		return 2

	# Step 2: Overlay obfuscated files on top
	print("  Overlaying obfuscated files...")
	copy_output.clear()
	if OS.get_name() == "Windows":
		OS.execute("cmd", ["/c", "xcopy", "/E", "/Y", "/Q",
			output_dir.replace("/", "\\"), build_dir.replace("/", "\\")], copy_output, true)
	else:
		OS.execute("cp", ["-r", output_dir + "/.", build_dir], copy_output, true)

	# Step 3: Read encryption key if provided
	var encryption_key := ""
	if not encryption_key_path.is_empty():
		var key_file := FileAccess.open(encryption_key_path, FileAccess.READ)
		if key_file == null:
			printerr("Error: Cannot read encryption key file: %s" % encryption_key_path)
			_cleanup_dir(build_dir)
			return 2
		encryption_key = key_file.get_as_text().strip_edges()
		key_file.close()
		if encryption_key.is_empty():
			printerr("Error: Encryption key file is empty")
			_cleanup_dir(build_dir)
			return 2
		print("  Encryption key loaded (%d chars)" % encryption_key.length())

	# Step 4: Determine expected output path from export_presets.cfg
	var preset_export_path := _get_preset_export_path(build_dir, preset)
	var export_flag := "--export-debug" if is_debug else "--export-release"

	# Build the absolute export output path
	var export_target_path := ""
	if not preset_export_path.is_empty():
		# preset_export_path is relative like "exports/Suganote.exe"
		export_target_path = build_dir.path_join(preset_export_path)
		# Ensure exports subdirectory exists
		var export_subdir := export_target_path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(export_subdir)
		print("  Export target: %s" % export_target_path)
	else:
		print("  Warning: Could not determine export path from preset config")
		# Fall back to a default path
		export_target_path = build_dir.path_join("exports/export.exe")
		DirAccess.make_dir_recursive_absolute(export_target_path.get_base_dir())

	# Step 5: Run Godot export
	print("  Running Godot export (%s)..." % export_flag)
	var run_output: Array = []
	var export_args: PackedStringArray = ["--headless", "--path", build_dir, export_flag, preset, export_target_path]

	var exit_code: int
	if not encryption_key.is_empty() and OS.get_name() == "Windows":
		# Pass encryption key via environment variable using cmd wrapper
		var cmd_parts := "set GODOT_SCRIPT_ENCRYPTION_KEY=%s&& \"%s\"" % [encryption_key, godot_path]
		for arg in export_args:
			cmd_parts += " \"%s\"" % arg
		exit_code = OS.execute("cmd", ["/c", cmd_parts], run_output, true)
	elif not encryption_key.is_empty():
		# Unix: use env command
		var env_args: PackedStringArray = ["GODOT_SCRIPT_ENCRYPTION_KEY=" + encryption_key, godot_path]
		env_args.append_array(export_args)
		exit_code = OS.execute("env", env_args, run_output, true)
	else:
		exit_code = OS.execute(godot_path, export_args, run_output, true)

	# Print export output for diagnostics
	for line in run_output:
		for output_line in str(line).split("\n"):
			var trimmed := output_line.strip_edges()
			if not trimmed.is_empty():
				print("    [export] %s" % trimmed)

	# Step 6: Verify export succeeded
	if not FileAccess.file_exists(export_target_path):
		printerr("Error: Export completed but output file not found: %s" % export_target_path)
		printerr("  Godot exit code: %d" % exit_code)
		_cleanup_dir(build_dir)
		return 2

	var file_size := FileAccess.get_file_as_bytes(export_target_path).size()
	print("  Export succeeded: %s (%s)" % [export_target_path.get_file(), _format_size(file_size)])

	# Step 7: Check for .pck file alongside the exe
	var pck_path := export_target_path.get_basename() + ".pck"
	if FileAccess.file_exists(pck_path):
		var pck_size := FileAccess.get_file_as_bytes(pck_path).size()
		print("  PCK file: %s (%s)" % [pck_path.get_file(), _format_size(pck_size)])

	# Step 8: Copy all artifacts from export directory to export-output location
	if not export_output.is_empty():
		var output_base_dir := export_output.get_base_dir()
		var export_source_dir := export_target_path.get_base_dir()
		print("  Copying all artifacts from: %s" % export_source_dir)
		print("  To: %s" % output_base_dir)
		DirAccess.make_dir_recursive_absolute(output_base_dir)

		# Copy all files from the export directory (exe, pck, dlls, etc.)
		var source_dir := DirAccess.open(export_source_dir)
		if source_dir == null:
			printerr("Error: Cannot open export source directory: %s" % export_source_dir)
			_cleanup_dir(build_dir)
			return 2

		source_dir.list_dir_begin()
		var file_name := source_dir.get_next()
		var copied_count := 0
		while file_name != "":
			if not source_dir.current_is_dir():
				var src := export_source_dir.path_join(file_name)
				var dest := output_base_dir.path_join(file_name)
				var copy_err := DirAccess.copy_absolute(src, dest)
				if copy_err != OK:
					printerr("Error: Failed to copy %s (error %d)" % [file_name, copy_err])
				else:
					var size := FileAccess.get_file_as_bytes(src).size()
					print("  Copied: %s (%s)" % [file_name, _format_size(size)])
					copied_count += 1
			file_name = source_dir.get_next()
		source_dir.list_dir_end()

		print("  %d artifact(s) copied successfully." % copied_count)

	# Step 9: Clean up build directory
	_cleanup_dir(build_dir)
	print("  Build directory cleaned up.")
	print("=== Export Pipeline Complete ===")
	return 0

# Parses export_presets.cfg to find the export_path for a given preset name
static func _get_preset_export_path(project_dir: String, preset_name: String) -> String:
	var presets_path := project_dir.path_join("export_presets.cfg")
	if not FileAccess.file_exists(presets_path):
		printerr("Warning: export_presets.cfg not found in: %s" % project_dir)
		return ""

	var config := ConfigFile.new()
	var err := config.load(presets_path)
	if err != OK:
		printerr("Warning: Failed to load export_presets.cfg (error %d)" % err)
		return ""

	# Iterate through preset sections to find matching name
	var i := 0
	while true:
		var section := "preset.%d" % i
		if not config.has_section(section):
			break
		var name: String = config.get_value(section, "name", "")
		if name == preset_name:
			return config.get_value(section, "export_path", "")
		i += 1

	printerr("Warning: Preset '%s' not found in export_presets.cfg" % preset_name)
	return ""

# Removes a directory recursively
func _cleanup_dir(dir_path: String) -> void:
	if OS.get_name() == "Windows":
		OS.execute("cmd", ["/c", "rmdir", "/S", "/Q", dir_path.replace("/", "\\")], [], true)
	else:
		OS.execute("rm", ["-rf", dir_path], [], true)

# Formats byte size into human-readable string
static func _format_size(bytes: int) -> String:
	if bytes < 1024:
		return "%d B" % bytes
	elif bytes < 1024 * 1024:
		return "%.1f KB" % (bytes / 1024.0)
	elif bytes < 1024 * 1024 * 1024:
		return "%.1f MB" % (bytes / (1024.0 * 1024.0))
	else:
		return "%.2f GB" % (bytes / (1024.0 * 1024.0 * 1024.0))

func _print_usage() -> void:
	print("Godot Valet Obfuscator CLI")
	print("")
	print("Usage:")
	print("  Godot --headless --path <godot-valet-dir> --script res://scripts/obfuscate-cli.gd -- [options]")
	print("")
	print("Options:")
	print("  --config <path>        Path to obfuscation.cfg config file")
	print("  --project-dir <path>   Source project directory")
	print("  --output <path>        Output directory for obfuscated files")
	print("  --functions            Enable function name obfuscation (default)")
	print("  --no-functions         Disable function name obfuscation")
	print("  --variables            Enable variable name obfuscation (default)")
	print("  --no-variables         Disable variable name obfuscation")
	print("  --comments             Enable comment removal (default)")
	print("  --no-comments          Disable comment removal")
	print("  --constants            Enable constant/enum inlining")
	print("  --no-constants         Disable constant/enum inlining (default)")
	print("  --skip-addons          Skip addons/ directory (default)")
	print("  --no-skip-addons       Include addons/ directory in obfuscation")
	print("  --skip-dirs <dirs>     Comma-separated additional directories to skip (e.g. tests,build)")
	print("  --validate             After obfuscation, run headless validation to count errors")
	print("")
	print("Export pipeline (triggers full build after obfuscation):")
	print("  --export <preset>         Export preset name (e.g. 'Windows Desktop')")
	print("  --godot-path <path>       Path to Godot binary for export (required with --export)")
	print("  --encryption-key <path>   Path to file containing hex encryption key")
	print("  --export-output <path>    Copy final artifacts (exe+pck) to this path")
	print("  --debug                   Use --export-debug instead of --export-release")
	print("")
	print("  --help                 Show this help message")
	print("")
	print("Config file format (INI):")
	print("  [paths]")
	print("  project_dir = /path/to/project")
	print("  output_dir = /path/to/output")
	print("")
	print("  [obfuscation]")
	print("  functions = true")
	print("  variables = true")
	print("  comments = true")
	print("  constants = false")
	print("  skip_dirs = tests,build")
	print("")
	print("  [exclude]")
	print("  function_names = func1,func2")
	print("  variable_names = var1,var2")
	print("  external_classes = SQLite,SupabaseClient")
	print("  constant_names = MY_CONST,SOME_VALUE")
	print("")
	print("  [export]")
	print("  preset = Windows Desktop")
	print("  godot_path = C:/path/to/custom/godot.exe")
	print("  encryption_key = C:/path/to/encryption.key")
	print("  export_output = C:/path/to/final/output.exe")
	print("  debug = false")
