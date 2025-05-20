extends Node
class_name ObfuscateHelper

static var _inputDir : String = ""
static var _outputDir : String = ""
static var _usedNames : Dictionary = {}
static var _exportVariableNames := []

# It's possible that you've used a reserved keyword without realizing.
# godot generally warns about using reserved keywords but it's easy to miss.
# Recommend updating your code to not use reserved keywords vs fixing in here.
# My example which godot doesn't warn me about: var values = enumType.values()
# I chose to rename the variable to something else.
const _godotReservedKeywords := [
	"_ready", "_process", "_physics_process", "_input", "_unhandled_input", "_init",
	"_enter_tree", "_exit_tree", "_notification", "_draw", "_gui_input", "_get_property_list",
	"_get", "_set", "_to_string", "_save", "_load"
]

static func ObfuscateScripts(inputDir: String, outputDir: String) -> void:
	_inputDir = inputDir
	_outputDir = outputDir

	if inputDir == "":
		OS.alert("Invalid input directory for obfuscation. Please specify a valid directory containing a Godot project.")
		return

	if outputDir == "":
		OS.alert("Invalid output directory for obfuscation. Please specify a directory outside of your project.")
		return

	if not DirAccess.dir_exists_absolute(_inputDir):
		printerr("Input directory does not exist: ", _inputDir)
		return

	if not DirAccess.dir_exists_absolute(_outputDir):
		var created := DirAccess.make_dir_recursive_absolute(_outputDir)
		if created != OK:
			printerr("Failed to create output directory: ", _outputDir)
			return

	ObfuscateDirectory(_inputDir)

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

static func ApplySymbolObfuscation(contentPayload : ContentPayload , symbolMap: Dictionary) -> void:
	for symbol in symbolMap.keys():
		contentPayload.SetContent(ReplaceSymbol(contentPayload.GetContent(), symbol, symbolMap[symbol]))

static func ReplaceSymbol(content: String, symbol: String, symbolMap: Dictionary) -> String:
	var pattern := RegEx.new()
	pattern.compile("\\b" + symbol + "\\b")

	var matches := pattern.search_all(content)
	if matches.is_empty():
		return content

	var result := ""
	var lastIndex := 0

	for match in matches:
		if _exportVariableNames.find(symbol) > -1:
			continue
			
		var start := match.get_start()
		var end := match.get_end()
		var replacement = GetSymbolReplacement(content, symbol, symbolMap, start, end)
		result += content.substr(lastIndex, start - lastIndex)
		result += replacement
		lastIndex = end

	result += content.substr(lastIndex)
	return result

static func GetSymbolReplacement(content: String, symbol: String, symbolMap: Dictionary, start: int, end: int) -> String:
	var before := content.substr(max(start - 20, 0), start - max(start - 20, 0))
	# var after := content.substr(end, 10)
	
	var prevChar := ""
	if start > 0:
		prevChar = content.substr(start - 1, 1)
		
	var nextChar := content.substr(end, 1)

	#if symbolMap.kind == "type":
		#if before.match(":\\s*$") or before.match("as\\s+$"):
			#return symbol  # Don't replace in type context
		#else:
			#return symbol  # Unknown context, skip for safety
	if symbolMap.kind == "function":
		if FindFunctionSymbol(before, prevChar, nextChar):
			return symbolMap.replacement
		else:
			return symbol
	elif symbolMap.kind == "variable":
		# Check if we are obfuscating inside an @export declaration
		if before.contains("@export var"):
			_exportVariableNames.append(symbol)
			return symbol
			
		return symbolMap.replacement

	return symbol

static func FindFunctionSymbol(before, prevChar, nextChar):
	var regex := RegEx.new()
	
	regex.compile('^(static\\s+)?func\\s*$')
	if regex.search(before):
		return true

	if nextChar == "(" or (prevChar == "." and nextChar == "("):
		return true

	if prevChar != "." and nextChar == ")":
		return true
	
	regex.compile('.*\\.has_method\\(\\"')
	return !!regex.search(before)
	
static func ObfuscateDirectory(path: String) -> void:
	var fileFilters := ["gd"]
	var filteredFiles := FileHelper.GetFilesRecursive(path, fileFilters)
	var symbolMap := BuildGlobalSymbolMap(filteredFiles)
	ObfuscateAllFiles(filteredFiles, symbolMap)

# Pass 1: Build global symbol map
static func BuildGlobalSymbolMap(allFiles) -> Dictionary:
	var symbolMap : Dictionary = {}
	for fullPath in allFiles:
		var content := FileAccess.get_file_as_string(fullPath)
		BuildSymbolMap(content, symbolMap)

		for symbolName in symbolMap.keys():
			var kind = symbolMap[symbolName].get("kind")
			var replacement = GenerateObfuscatedName()

			symbolMap[symbolName] = {
				"kind": kind,
				"replacement": replacement
			}

	return symbolMap
				
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

# Note: This only supports has_method calls.
static func PreserveSpecialStrings(contentPayload : ContentPayload) -> void:
	var stringRegex := RegEx.new()
	stringRegex.compile(r'has_method\("([^"\\]*)"\)')
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
static func ObfuscateAllFiles(allFiles : Array, symbolMap : Dictionary):
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
		ApplySymbolObfuscation(contentPayload, symbolMap)
		
		RestoreStringLiterals(contentPayload)
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

static func BuildSymbolMap(content : String, symbolMap : Dictionary) -> void:
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
			
		# TODO:
		# Assumes PasalCase function names (for now)
		# - Assuming this will need modification for snake_case
		if not symbolName.begins_with("_"):
			symbolMap[symbolName] = { "kind": "function" }

	# Type references
	#regex = RegEx.new()
	#regex.compile(r"(?::|as)\s+(\w+)")
	#for match in regex.search_all(content):
		#var symbolName = match.get_string(1)
		#if symbolName in _godotReservedKeywords:
			#continue
			#
		#if not map.has(symbolName):
			#map[symbolName] = { "kind": "type" }

static func AddVariablesToSymbolMap(content : String, symbolMap : Dictionary):
	var lines := content.split("\n")
	var filterdExportVariables = []
	for line in lines:
		line = line.strip_edges()
		
		# Note:
		# Skip @export vars because gdscript will
		# reset the GUI assigned values when renamed.
		# We could improve this by digging into the 
		# respective tscn file to remap them but 
		# that's future work.
		#if line.begins_with("@export var"):
			#var exportVariableName = ExtractExportedVarName(line)
			#filterdExportVariables.append(exportVariableName)
			#continue

		var regex := RegEx.new()
		regex.compile(r"\bvar\s+(\w+)")
		var match = regex.search(line)
		if match:
			var symbolName = match.get_string(1)
			if symbolMap.has(symbolName):
				continue
				
			#var kind := "global" if symbolName.begins_with("_") else "variable"
			symbolMap[symbolName] = { "kind": "variable" }

#static func ExtractExportedVarName(line: String) -> String:
	#if line.strip_edges().begins_with("@export"):
		#var match = line.find("var ")
		#if match != -1:
			#var sub = line.substr(match + 4)
			#var name = sub.split(":")[0].strip_edges()
			#return name
	#return ""

	
# For testing locally if needed
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
