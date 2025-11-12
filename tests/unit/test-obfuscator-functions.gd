extends RefCounted

var framework: TestFramework

# Function Obfuscation Tests

func test_add_functions_identifies_simple_function():
	# Arrange
	var code = "func MyFunction():\n\tpass"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddFunctionsToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("MyFunction"), "Should identify function")
	framework.assert_equal(symbol_map["MyFunction"]["kind"], "function", "Should mark as function")

func test_add_functions_identifies_static_function():
	# Arrange
	var code = "static func MyStaticFunction():\n\tpass"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddFunctionsToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("MyStaticFunction"), "Should identify static function")

func test_add_functions_identifies_function_with_params():
	# Arrange
	var code = "func CalculateDamage(base: int, multiplier: float) -> int:\n\treturn base * multiplier"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddFunctionsToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("CalculateDamage"), "Should identify function with parameters")

func test_add_functions_preserves_godot_ready():
	# Arrange
	var code = "func _ready():\n\tpass"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddFunctionsToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("_ready"), "_ready should be preserved (not added to map)")

func test_add_functions_preserves_godot_process():
	# Arrange
	var code = "func _process(delta):\n\tpass"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddFunctionsToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("_process"), "_process should be preserved")

func test_add_functions_skips_private_functions():
	# Arrange
	var code = "func _my_private_helper():\n\tpass"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddFunctionsToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("_my_private_helper"), "Private functions (starting with _) should be skipped")

func test_add_functions_handles_multiple_functions():
	# Arrange
	var code = """func First():
	pass

func Second():
	pass

func Third():
	pass"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddFunctionsToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("First"), "Should find First")
	framework.assert_true(symbol_map.has("Second"), "Should find Second")
	framework.assert_true(symbol_map.has("Third"), "Should find Third")
	framework.assert_equal(symbol_map.size(), 3, "Should find exactly 3 functions")

func test_add_functions_no_duplicates():
	# Arrange
	var code = """func SameFunction():
	pass

func SameFunction():
	pass"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddFunctionsToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_equal(symbol_map.size(), 1, "Should not add duplicate function names")

func test_add_functions_handles_pascal_case():
	# Arrange
	var code = "func SaveGameData():\n\tpass"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddFunctionsToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("SaveGameData"), "Should handle PascalCase")

func test_add_functions_handles_camel_case():
	# Arrange
	var code = "func saveGameData():\n\tpass"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddFunctionsToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("saveGameData"), "Should handle camelCase")

# Note: snake_case functions starting with _ are currently skipped
# This is a known limitation documented in obfuscation.md Phase 2
func test_add_functions_skips_snake_case_with_underscore():
	# Arrange
	var code = "func _calculate_damage():\n\tpass"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddFunctionsToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("_calculate_damage"), "Currently skips all functions starting with _")
