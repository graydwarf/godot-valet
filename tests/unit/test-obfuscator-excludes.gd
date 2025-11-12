extends RefCounted

var framework: TestFramework

# Exclude-List Obfuscation Tests

func test_excluded_function_not_obfuscated():
	# Arrange
	var code = "func SaveGame():\n\tpass\n\nfunc LoadGame():\n\tpass"
	var symbol_map = {}
	var function_excludes: Array[String] = ["SaveGame"]

	# Act
	ObfuscateHelper.SetFunctionExcludeList(function_excludes)
	ObfuscateHelper.AddFunctionsToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("SaveGame"), "SaveGame should be excluded from obfuscation")
	framework.assert_true(symbol_map.has("LoadGame"), "LoadGame should be obfuscated")

	# Cleanup
	ObfuscateHelper.SetFunctionExcludeList([])

func test_excluded_variable_not_obfuscated():
	# Arrange
	var code = "var API_KEY = \"secret\"\nvar game_state = 0"
	var symbol_map = {}
	var variable_excludes: Array[String] = ["API_KEY"]

	# Act
	ObfuscateHelper.SetVariableExcludeList(variable_excludes)
	ObfuscateHelper.AddVariablesToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("API_KEY"), "API_KEY should be excluded from obfuscation")
	framework.assert_true(symbol_map.has("game_state"), "game_state should be obfuscated")

	# Cleanup
	ObfuscateHelper.SetVariableExcludeList([])

func test_multiple_functions_excluded():
	# Arrange
	var code = "func SaveGame():\n\tpass\n\nfunc LoadGame():\n\tpass\n\nfunc ProcessPayment():\n\tpass"
	var symbol_map = {}
	var function_excludes: Array[String] = ["SaveGame", "ProcessPayment"]

	# Act
	ObfuscateHelper.SetFunctionExcludeList(function_excludes)
	ObfuscateHelper.AddFunctionsToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("SaveGame"), "SaveGame should be excluded")
	framework.assert_false(symbol_map.has("ProcessPayment"), "ProcessPayment should be excluded")
	framework.assert_true(symbol_map.has("LoadGame"), "LoadGame should be obfuscated")

	# Cleanup
	ObfuscateHelper.SetFunctionExcludeList([])

func test_multiple_variables_excluded():
	# Arrange
	var code = "var API_KEY = \"secret\"\nvar _connectionString = \"\"\nvar game_state = 0"
	var symbol_map = {}
	var variable_excludes: Array[String] = ["API_KEY", "_connectionString"]

	# Act
	ObfuscateHelper.SetVariableExcludeList(variable_excludes)
	ObfuscateHelper.AddVariablesToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("API_KEY"), "API_KEY should be excluded")
	framework.assert_false(symbol_map.has("_connectionString"), "_connectionString should be excluded")
	framework.assert_true(symbol_map.has("game_state"), "game_state should be obfuscated")

	# Cleanup
	ObfuscateHelper.SetVariableExcludeList([])

func test_empty_exclude_list_obfuscates_all():
	# Arrange
	var code = "func SaveGame():\n\tpass\n\nfunc LoadGame():\n\tpass"
	var symbol_map = {}
	var function_excludes: Array[String] = []

	# Act
	ObfuscateHelper.SetFunctionExcludeList(function_excludes)
	ObfuscateHelper.AddFunctionsToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("SaveGame"), "SaveGame should be obfuscated with empty exclude list")
	framework.assert_true(symbol_map.has("LoadGame"), "LoadGame should be obfuscated with empty exclude list")

	# Cleanup
	ObfuscateHelper.SetFunctionExcludeList([])

func test_exclude_list_case_sensitive():
	# Arrange
	var code = "func SaveGame():\n\tpass\n\nfunc savegame():\n\tpass"
	var symbol_map = {}
	var function_excludes: Array[String] = ["SaveGame"]

	# Act
	ObfuscateHelper.SetFunctionExcludeList(function_excludes)
	ObfuscateHelper.AddFunctionsToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("SaveGame"), "SaveGame should be excluded")
	framework.assert_true(symbol_map.has("savegame"), "savegame (lowercase) should be obfuscated")

	# Cleanup
	ObfuscateHelper.SetFunctionExcludeList([])

func test_excluded_function_with_other_symbols():
	# Arrange
	var code = "func SaveGame():\n\tvar data = 0\n\tfunc calculate_damage():\n\t\treturn data * 2"
	var symbol_map = {}
	var function_excludes: Array[String] = ["SaveGame"]

	# Act
	ObfuscateHelper.SetFunctionExcludeList(function_excludes)
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("SaveGame"), "SaveGame should be excluded from symbol map")
	framework.assert_true(symbol_map.has("calculate_damage"), "calculate_damage should be in symbol map")
	framework.assert_true(symbol_map.has("data"), "data variable should be in symbol map")

	# Cleanup
	ObfuscateHelper.SetFunctionExcludeList([])

func test_excluded_variable_with_other_symbols():
	# Arrange
	var code = "var API_KEY = \"secret\"\nvar game_state = 0\n\nfunc _ready():\n\tpass"
	var symbol_map = {}
	var variable_excludes: Array[String] = ["API_KEY"]

	# Act
	ObfuscateHelper.SetVariableExcludeList(variable_excludes)
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("API_KEY"), "API_KEY should be excluded from symbol map")
	framework.assert_true(symbol_map.has("game_state"), "game_state should be in symbol map")

	# Cleanup
	ObfuscateHelper.SetVariableExcludeList([])

func test_excluded_private_function():
	# Arrange
	var code = "func _calculate_damage():\n\tpass\n\nfunc _process_input():\n\tpass"
	var symbol_map = {}
	var function_excludes: Array[String] = ["_calculate_damage"]

	# Act
	ObfuscateHelper.SetFunctionExcludeList(function_excludes)
	ObfuscateHelper.AddFunctionsToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("_calculate_damage"), "_calculate_damage should be excluded")
	framework.assert_true(symbol_map.has("_process_input"), "_process_input should be obfuscated")

	# Cleanup
	ObfuscateHelper.SetFunctionExcludeList([])

func test_excluded_private_variable():
	# Arrange
	var code = "var _connectionString = \"\"\nvar _health = 100"
	var symbol_map = {}
	var variable_excludes: Array[String] = ["_connectionString"]

	# Act
	ObfuscateHelper.SetVariableExcludeList(variable_excludes)
	ObfuscateHelper.AddVariablesToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("_connectionString"), "_connectionString should be excluded")
	framework.assert_true(symbol_map.has("_health"), "_health should be obfuscated")

	# Cleanup
	ObfuscateHelper.SetVariableExcludeList([])
