extends SceneTree

# CLI entry point for headless obfuscation
# Usage: Godot --headless --path /path/to/godot-valet --script res://scripts/obfuscate-cli.gd -- [options]
#
# Options:
#   --config <path>        Path to obfuscation.cfg config file
#   --project-dir <path>   Source project directory (overrides config)
#   --output <path>        Output directory (overrides config)
#   --functions            Enable function obfuscation (default: true)
#   --no-functions         Disable function obfuscation
#   --variables            Enable variable obfuscation (default: true)
#   --no-variables         Disable variable obfuscation
#   --comments             Enable comment removal (default: true)
#   --no-comments          Disable comment removal
#   --constants            Enable constant/enum value inlining (default: false)
#   --no-constants         Disable constant/enum value inlining
#   --skip-addons          Skip addons/ directory during obfuscation (default: true)
#   --no-skip-addons       Include addons/ directory in obfuscation
#   --validate             Run headless validation after obfuscation to count errors
#   --help                 Show usage info

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
	var skip_addons: bool = _resolve_flag(args, "skip-addons", config.get("skip_addons", true))

	if skip_addons:
		ObfuscateHelper.SetSkipDirectories(["addons", ".godot", ".import"] as Array[String])

	var func_excludes: Array[String] = config.get("function_excludes", [] as Array[String])
	var var_excludes: Array[String] = config.get("variable_excludes", [] as Array[String])
	var ext_classes: Array[String] = config.get("external_classes", [] as Array[String])
	var const_excludes: Array[String] = config.get("constant_excludes", [] as Array[String])

	ObfuscateHelper.SetFunctionExcludeList(func_excludes)
	ObfuscateHelper.SetVariableExcludeList(var_excludes)
	ObfuscateHelper.SetExternalPluginClasses(ext_classes)
	ObfuscateHelper.SetConstantExcludeList(const_excludes)

	print("Obfuscating: %s -> %s" % [project_dir, output_dir])
	print("  Functions: %s | Variables: %s | Comments: %s | Constants: %s | Skip Addons: %s" % [
		obfuscate_functions, obfuscate_variables, obfuscate_comments, inline_constants, skip_addons])

	var result: int = ObfuscateHelper.ObfuscateScripts(
		project_dir, output_dir,
		obfuscate_functions, obfuscate_variables, obfuscate_comments, inline_constants)

	if result == OK:
		print("Obfuscation completed successfully.")
		if args.get("validate", false):
			var error_count = _validate_obfuscation(project_dir, output_dir)
			if error_count == 0:
				print("Validation PASSED: No obfuscation errors detected.")
			else:
				print("Validation: %d SCRIPT ERROR(s) detected." % error_count)
		call_deferred("quit", 0)
	else:
		printerr("Obfuscation failed with error code: %d" % result)
		call_deferred("quit", 1)

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
		if key in ["functions", "variables", "comments", "constants", "skip-addons", "validate"]:
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

	# Count SCRIPT ERRORs in output
	var error_count := 0
	for line in run_output:
		for output_line in str(line).split("\n"):
			if "SCRIPT ERROR" in output_line:
				error_count += 1
				if error_count <= 20:
					print("  ", output_line.strip_edges())

	if error_count > 20:
		print("  ... and %d more errors" % (error_count - 20))

	# Clean up validation directory
	if OS.get_name() == "Windows":
		OS.execute("cmd", ["/c", "rmdir", "/S", "/Q", validate_dir.replace("/", "\\")], [], true)
	else:
		OS.execute("rm", ["-rf", validate_dir], [], true)

	return error_count

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
	print("  --validate             After obfuscation, run headless validation to count errors")
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
	print("")
	print("  [exclude]")
	print("  function_names = func1,func2")
	print("  variable_names = var1,var2")
	print("  external_classes = SQLite,SupabaseClient")
	print("  constant_names = MY_CONST,SOME_VALUE")
