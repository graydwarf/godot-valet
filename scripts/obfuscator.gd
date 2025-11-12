extends Node
class_name ObfuscateHelper

# README - BETA BETA BETA - EARLY ACCESS - UNTESTED
#
# USE AT YOUR OWN RISK <- Read that again.
#
# This is an open source project. Review any and all code
# and ensure it does what you expect before using it. 
#
# A couple important things:
# - Do not proceed without source control (backing up)
# - Do not release without comprehensive testing.
#
# You SHOULD NOT use obfuscation without testing every nook and
# cranny of your game. Launching is not enough. Obfuscation touches
# every little thing in your project so you have to test every little
# thing to be certain nothing is broken. I do mean every little thing.
# Unit tests can be a big help in this regard if you have them. Once 
# you've refined & stabalized the obfuscation (and tested every aspect
# of your game) you should only need to test where you've made changes
# from there on out. If you make changes to the obfuscator, a full test
# pass is recommended (generally required). 
#
# This initial version is rudamtary at best. It was designed based on
# a single project which means no real testing has occured yet. I use 
# a mix of camelCase, PascalCase and kebab-case so this could be completely 
# busted for styles.
#
# You will most likely need to massage your code to work well with 
# obfuscation (renaming problematic things) as well as updating the
# obfuscator where it's lacking or maybe even wrong. Again, this feature
# is largely untested.
#
# There are other obfuscator projects out there that are way more 
# sofisticated including plug-ins for godot. 
#
# If you make improvements that others can benefit from, 
# please publish a PR. 
#

# Notes:
# Key things to keep in mind.
# - A global symbol map is used (we crawl through all the files looking for
#	all function and variable names.
# - We use that global symbol map to replace function/variable 
# 	name regardless of local/global state so every instance of a name
# 	gets replaced with the same replacement name across all files.
# 	This generally works for most things but can trip up.
# 
# Open Issues: (to name a few)
# - Just about any call made with a string to a
# 	function is at risk if duplicate names are present.
#
# - Calls to functions using string representation such 
#	as: .set("_rotationSpeed", ...) especially if that variable
#	was set with @export.
#
# - Calls to variables in other classes where the variable 
# 	is an @export AND that same variable name is defined elsewhere.

static var _inputDir : String = ""
static var _outputDir : String = ""
static var _usedNames : Dictionary = {}
static var _exportVariableNames := []
static var _obfuscateFunctions := false
static var _obfuscateVariables := false
static var _obfuscateComments := false
static var _isObfuscatingFunctions := false
static var _isObfuscatingVariables := false
static var _isObfuscatingComments := false
static var _functionExcludeList : Array[String] = []
static var _variableExcludeList : Array[String] = []
static var _enumValueExcludeList : Array[String] = []

# It's possible that you've used a reserved keyword 
# without realizing it. Godot generally warns about 
# reserved keywords but not always. Recommend updating
# your code to not use reserved keywords vs fixing here.
# An example I fixed in code which godot doesn't warn me about: 
# var values = enumType.values() # Using values as a 
# variable name which is a godot keyword. I chose to rename the
# variable to something else instead of adding it here.
const _godotReservedKeywords := [
	"_ready", "_process", "_physics_process", "_input", "_unhandled_input", "_init",
	"_enter_tree", "_exit_tree", "_notification", "_draw", "_gui_input", "_get_property_list",
	"_get", "_set", "_to_string", "_save", "_load"
]

static func ObfuscateScripts(inputDir: String, outputDir: String, isObfuscatingFunctions : bool, isObfuscatingVariables : bool, isObfuscatingComments : bool):
	_inputDir = inputDir
	_outputDir = outputDir
	_isObfuscatingFunctions = isObfuscatingFunctions
	_isObfuscatingVariables = isObfuscatingVariables
	_isObfuscatingComments = isObfuscatingComments

	if inputDir == "":
		OS.alert("Invalid input directory for obfuscation. Please specify a valid directory containing a Godot project.")
		return -1

	if outputDir == "":
		OS.alert("Invalid output directory for obfuscation. Please specify a directory outside of your project.")
		return -1

	if not DirAccess.dir_exists_absolute(_inputDir):
		printerr("Input directory does not exist: ", _inputDir)
		return -1

	if not DirAccess.dir_exists_absolute(_outputDir):
		var created := DirAccess.make_dir_recursive_absolute(_outputDir)
		if created != OK:
			printerr("Failed to create output directory: ", _outputDir)
			return -1

	var autoloads = GetAutoloadGlobalNames()
	ObfuscateDirectory(_inputDir, autoloads)
	return OK

static func SetFunctionExcludeList(excludeList: Array[String]) -> void:
	_functionExcludeList = excludeList

static func SetVariableExcludeList(excludeList: Array[String]) -> void:
	_variableExcludeList = excludeList

# Extracts enum values from code and adds them to exclusion list
# Enum values should never be obfuscated as they're runtime constants
static func AddEnumValuesToExcludeList(content: String) -> void:
	var regex := RegEx.new()
	# Match: enum EnumName { ... } or enum { ... }
	regex.compile(r"enum\s+\w*\s*\{([^}]+)\}")

	for match in regex.search_all(content):
		var enum_body = match.get_string(1)

		# Extract individual enum values (handle VALUE = 5, VALUE, etc.)
		var value_regex := RegEx.new()
		# Match enum value names, optionally followed by = and a number
		value_regex.compile(r"\b(\w+)(?:\s*=\s*[^,}]+)?")

		for value_match in value_regex.search_all(enum_body):
			var enum_value_name = value_match.get_string(1)
			if enum_value_name not in _enumValueExcludeList:
				_enumValueExcludeList.append(enum_value_name)

# Generates a random name ensuring we haven't
# used the name before.
static func GenerateObfuscatedName()  -> String:
	var chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	while true:
		var obfuscatedName := ""
		for i in range(8):
			obfuscatedName += chars[randi() % chars.length()]
			
		if not _usedNames.has(obfuscatedName):
			_usedNames[obfuscatedName] = true
			return obfuscatedName
	
	return ""

static func ApplyBasicObfuscation(contentPayload : ContentPayload , globalObfuscationMap: Dictionary) -> void:
	for obfuscationKey in globalObfuscationMap.keys():
		contentPayload.SetContent(ReplacePattern(contentPayload.GetContent(), obfuscationKey, globalObfuscationMap[obfuscationKey]))

static func ReplacePattern(content: String, obfuscationKey: String, globalObfuscationMap: Dictionary) -> String:
	var pattern := RegEx.new()
	pattern.compile("\\b" + obfuscationKey + "\\b")

	var matches := pattern.search_all(content)
	if matches.is_empty():
		return content

	var result := ""
	var lastIndex := 0

	for match in matches:
		if _exportVariableNames.find(obfuscationKey) > -1:
			continue
			
		var start := match.get_start()
		var end := match.get_end()
		var replacement = GetObfuscationReplacement(content, obfuscationKey, globalObfuscationMap, start, end)
		result += content.substr(lastIndex, start - lastIndex)
		result += replacement
		lastIndex = end

	result += content.substr(lastIndex)
	return result

static func GetObfuscationReplacement(content: String, symbol: String, globalObfuscationMap: Dictionary, start: int, end: int) -> String:
	var before := content.substr(max(start - 20, 0), start - max(start - 20, 0))
	# var after := content.substr(end, 10)

	var prevChar := ""
	if start > 0:
		prevChar = content.substr(start - 1, 1)
		
	var nextChar := content.substr(end, 1)

	# Saving for future consideration.
	#if symbolMap.kind == "type":
		#if before.match(":\\s*$") or before.match("as\\s+$"):
			#return symbol  # Don't replace in type context
		#else:
			#return symbol  # Unknown context, skip for safety
			
	if _isObfuscatingFunctions && globalObfuscationMap.kind == "function":
		if FindFunctionSymbol(before, prevChar, nextChar, content, end):
			return globalObfuscationMap.replacement
		else:
			return symbol
	elif _isObfuscatingVariables && globalObfuscationMap.kind == "variable":
		# Check if we are obfuscating inside an @export declaration
		if before.contains("@export var"):
			_exportVariableNames.append(symbol)
			return symbol
			
		return globalObfuscationMap.replacement

	return symbol

static func FindFunctionSymbol(before, prevChar, nextChar, content: String, end: int):
	var regex := RegEx.new()

	# Match function declaration: "func MyFunction("
	regex.compile('^(static\\s+)?func\\s*$')
	if regex.search(before):
		return true

	# Match function call: "MyFunction(" or ".MyFunction("
	if nextChar == "(" or (prevChar == "." and nextChar == "("):
		return true

	# Match callable reference passed as argument: "function)" or "obj.function)" or "Class.StaticMethod)"
	# Examples: sort_custom(my_sort), signal.connect(my_function), sort_custom(CommonHelper.SortAscending)
	if nextChar == ")" or nextChar == ",":
		return true

	# Match Callable methods: "MyFunction.bind(", "MyFunction.unbind(", etc.
	if nextChar == ".":
		# Look ahead to see what comes after the dot
		var after_dot = content.substr(end + 1, 10)
		if after_dot.begins_with("bind(") or after_dot.begins_with("unbind(") or \
		   after_dot.begins_with("call(") or after_dot.begins_with("callv("):
			return true

	# Detect has_method() and all call() variants (string-based reflection - should NOT obfuscate)
	regex.compile('.*\\.(?:has_method|call(?:_deferred|_thread_safe|v)?)\\s*\\(\\s*\\"')
	return !!regex.search(before)
	
static func ObfuscateDirectory(path: String, autoloads : Array) -> void:
	var fileFilters := ["gd"]
	var filteredFiles := FileHelper.GetFilesRecursive(path, fileFilters)
	var globalObfuscationMap := BuildGlobalObfuscationMap(filteredFiles)
	ObfuscateAllFiles(filteredFiles, globalObfuscationMap, autoloads)

# Pass 1: Build global obfuscation map
static func BuildGlobalObfuscationMap(allFiles) -> Dictionary:
	var obfuscationMap : Dictionary = {}

	# Clear enum exclude list to avoid stale values from previous runs
	_enumValueExcludeList.clear()

	# First pass: Extract ALL enum values from ALL files before building symbol map
	# This ensures enum values are in the exclude list before any variables/functions are processed
	for fullPath in allFiles:
		var content := FileAccess.get_file_as_string(fullPath)
		AddEnumValuesToExcludeList(content)

	# Second pass: Build symbol map (functions and variables)
	for fullPath in allFiles:
		var content := FileAccess.get_file_as_string(fullPath)
		BuildSymbolMap(content, obfuscationMap)

		for symbolName in obfuscationMap.keys():
			var kind = obfuscationMap[symbolName].get("kind")
			var replacement = GenerateObfuscatedName()

			obfuscationMap[symbolName] = {
				"kind": kind,
				"replacement": replacement
			}

	return obfuscationMap
				
static func PreserveStringLiterals(contentPayload : ContentPayload) -> void:
	var stringRegex := RegEx.new()
	stringRegex.compile(r'"([^"\\]|\\.)*"')
	var stringMatches := stringRegex.search_all(contentPayload.GetContent())

	var preservedStrings := {}

	# IMPORTANT NOTE: This replaces all string literals with
	# a temporary token so we don't obfuscate them.
	var index := 0
	for match in stringMatches:
		var key = "__STRING_TOKEN_" + str(index) + "__"
		preservedStrings[key] = match.get_string()
		contentPayload.SetContent(contentPayload.GetContent().replace(match.get_string(), key))
		index += 1

	contentPayload.SetPreservedStrings(preservedStrings)
	
# Put preserved strings back in
static func RestoreStringLiterals(contentPayload : ContentPayload) -> void:
	for key in contentPayload.GetPreservedStrings().keys():
		contentPayload.SetContent(contentPayload.GetContent().replace(key, contentPayload.GetPreservedStrings()[key]))

# Put special preserved strings back in
static func RestoreSpecialStrings(contentPayload : ContentPayload) -> void:
	for key in contentPayload.GetPreservedSpecialStrings().keys():
		contentPayload.SetContent(contentPayload.GetContent().replace(key, contentPayload.GetPreservedSpecialStrings()[key]))

# Note: Supports has_method and all call() variants.
static func PreserveSpecialStrings(contentPayload : ContentPayload) -> void:
	var stringRegex := RegEx.new()
	stringRegex.compile(r'(?:has_method|call(?:_deferred|_thread_safe|v)?)\s*\(\s*"([^"\\]*)"\s*')
	var stringMatches := stringRegex.search_all(contentPayload.GetContent())

	var preservedStrings := {}

	# IMPORTANT NOTE: This replaces all string literals with
	# a temporary token so we don't obfuscate them.
	var index := 0
	for match in stringMatches:
		var key = "__SPECIAL_STRING_TOKEN_" + str(index) + "__"
		preservedStrings[key] = match.get_string()
		contentPayload.SetContent(contentPayload.GetContent().replace(match.get_string(), key))
		index += 1
	
	contentPayload.SetPreservedSpecialStrings(preservedStrings)
	
# Pass #2: Obfuscate all files with global map
static func ObfuscateAllFiles(allFiles : Array, globalObfuscationMap : Dictionary, autoloads : Array):
	for fullPath in allFiles:
		var fileContents := FileAccess.get_file_as_string(fullPath)
		var contentPayload := ContentPayload.new()
		contentPayload.SetContent(fileContents)
		PreserveSpecialStrings(contentPayload)
		PreserveStringLiterals(contentPayload)
		
		# We need these strings to be replaced as function names
		RestoreSpecialStrings(contentPayload)

		# Reset export var tracking per file. Anytime
		# we come across and @export var, we need to ignore
		# all other matches in the same file.
		_exportVariableNames.clear()
		
		# Obfuscate Functions and Variables
		ApplyBasicObfuscation(contentPayload, globalObfuscationMap)
		
		RestoreStringLiterals(contentPayload)
		
		# Removes all comments from the project
		if _isObfuscatingComments:
			RemoveCommentsFromCode(contentPayload)
		
		# Future obfuscations that are in development:
		# ObfuscateSignals(contentPayload, autoloads)
		# Minify(contentPayload)
		
		var relativePath = fullPath.replace(_inputDir, "")
		var outputPath = _outputDir + relativePath
		var outputDir = outputPath.get_base_dir()
		DirAccess.make_dir_recursive_absolute(outputDir)

		var file := FileAccess.open(outputPath, FileAccess.WRITE)
		if file:
			file.store_string(contentPayload.GetContent())
			file.close()
		else:
			printerr("Failed to open file for writing: ", outputPath)
	
static func RemoveCommentsFromCode(contentPayload: ContentPayload) -> void:
	var result := ""
	var in_string := false
	var current_string_char := ""
	var lines := contentPayload.GetContent().split("\n")
	
	for line in lines:
		var new_line := ""
		var i := 0
		while i < line.length():
			var char := line[i]
			
			if not in_string and (char == '"' or char == "'"):
				in_string = true
				current_string_char = char
			elif in_string and char == current_string_char:
				in_string = false
			
			if not in_string and char == "#":
				break  # Stop at comment start if not in string
			
			new_line += char
			i += 1
		
		result += new_line.rstrip("") + "\n"
	
	contentPayload.SetContent(result)

# TODO: 
# Need to handle globals (which look just like locals). Wondering
# if I can detect globals in project file and then match any
# <globalName>.connect or <globalName>.emit_signal.
# May take multiple passes
static func ObfuscateSignals(contentPayload: ContentPayload, autoloads : Array) -> void:
	pass

static func GetAutoloadGlobalNames() -> Array:
	var globals := []
	var config := ConfigFile.new()
	var err := config.load(_inputDir + "\\project.godot")
	if err != OK:
		OS.alert("Failed to load globals from project.godot. Did you rename it?")
		return []
	
	if config.has_section("autoload"):
		for global_name in config.get_section_keys("autoload"):
			globals.append(global_name)
	
	return globals

# TODO: This one is a challenge. So many things require preserving
# white-space. I think it will be insanely busy.
# This is a very simple tokenizer-style minifier. 
# It may not work correctly for complex syntax like
# multiline strings, comments inside strings, etc. 
# Use with caution or refine as needed.
static func Minify(contentPayload: ContentPayload) -> void:
	return
	#var lines = contentPayload.GetContent().split("\n")
	#var result := ""
	#var lastLine = ""
#
	#for line in lines:
		#var trimmed = line.strip_edges()
		#if trimmed.begins_with("#") or trimmed == "":
			#continue
#
		#trimmed = CollapseOperatorWhitespace(trimmed)
#
		## Force newline after inline match clause
		#if "match " in trimmed and ":" in trimmed:
			#var match_split := RegExMatchReplace(trimmed, r"(match\s+[^\:]+:)", "$1\n")
			#for split_line in match_split.split("\n"):
				#if lastLine != "":
					#result += "\n" + split_line
				#else:
					#result += split_line
				#lastLine = split_line
			#continue
#
		#if lastLine != "":
			#if lastLine.ends_with("):") or lastLine.ends_with(":"):
				#result += " " + trimmed
			#elif trimmed.begins_with("extends") or trimmed.begins_with("class_name") or trimmed.begins_with("func") or trimmed.begins_with("static func"):
				#result += "\n" + trimmed
			#elif trimmed.begins_with("if ") or trimmed.begins_with("for ") or trimmed.begins_with("while ") or trimmed.begins_with("match "):
				#result += "\n" + trimmed
			#elif " static func" in trimmed:
				#result += "\n" + trimmed
			#else:
				#result += ";" + trimmed
		#else:
			#result += trimmed
#
		#lastLine = trimmed
#
	#contentPayload.SetContent(result)


static func CollapseOperatorWhitespace(line: String) -> String:
	var replacements = [
		[r"\s*:=\s*", ":="],
		[r"\s*=\s*", "="],
		[r"\s*:\s*", ":"],
		[r"\s*,\s*", ","],
		[r"\s*\(\s*", "("],
		[r"\s*\)\s*", ")"],
		[r"\s*\[\s*", "["],
		[r"\s*\]\s*", "]"],
		[r"\s*\+\s*", "+"],
		[r"\s*-\s*", "-"],
		[r"\s*/\s*", "/"],
		[r"\s*\*\s*", "*"]
	]
	
	for pattern in replacements:
		line = RegExMatchReplace(line, pattern[0], pattern[1])
		
	return line

static func RegExMatchReplace(text: String, pattern: String, replacement: String) -> String:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex.sub(text, replacement, true)
	
static func BuildSymbolMap(content : String, symbolMap : Dictionary) -> void:
	# Note: AddEnumValuesToExcludeList() is now called in BuildGlobalObfuscationMap()
	# before this function, ensuring all enum values are excluded before building the symbol map
	AddFunctionsToSymbolMap(content, symbolMap)
	AddVariablesToSymbolMap(content, symbolMap)
	
static func AddFunctionsToSymbolMap(content: String, symbolMap) -> void:
	# Function declarations (including static)
	var regex := RegEx.new()
	regex.compile(r"(?:static\s+)?func\s+(\w+)\s*\(")
	for match in regex.search_all(content):
		var symbolName = match.get_string(1)

		# Don't add dupe symbolNames
		if symbolMap.has(symbolName):
			continue

		# Ignore godot built-in functions
		if symbolName in _godotReservedKeywords:
			continue

		# Skip user-excluded functions
		if symbolName in _functionExcludeList:
			continue

		# Skip enum values (in case an enum value name matches a function name)
		if symbolName in _enumValueExcludeList:
			continue

		# Add to symbol map - will be obfuscated (including user-defined private functions)
		symbolMap[symbolName] = { "kind": "function" }

	# Saving for future consideration
	# Type references
	#regex = RegEx.new()
	#regex.compile(r"(?::|as)\s+(\w+)")
	#for match in regex.search_all(content):
		#var symbolName = match.get_string(1)
		#if symbolName in _godotReservedKeywords:
			#continue
		#if not map.has(symbolName):
			#map[symbolName] = { "kind": "type" }

static func AddVariablesToSymbolMap(content : String, symbolMap : Dictionary):
	var lines := content.split("\n")
	var filterdExportVariables = []
	for line in lines:
		line = line.strip_edges()
		var regex := RegEx.new()
		regex.compile(r"\bvar\s+(\w+)")
		var match = regex.search(line)
		if match:
			var symbolName = match.get_string(1)
			if symbolMap.has(symbolName):
				continue

			# Skip user-excluded variables
			if symbolName in _variableExcludeList:
				continue

			# Skip enum values
			if symbolName in _enumValueExcludeList:
				continue

			symbolMap[symbolName] = { "kind": "variable" }

# Example of how you might test locally if needed.
static func GetTestContent() -> String:
	return """
	func Run():
		pass

	func _internal():
		pass

	func GetCurrentTipId():
		pass
		
	func Whatever():
		if TipManager.GetCurrentTipId() == 5:
			pass
		
	func GravSkimmer(param: int) -> void:
		pass

	var _gravSkimmer : GravSkimmer = null
	"""
