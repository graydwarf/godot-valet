extends RefCounted

var framework: TestFramework

# Variable Obfuscation Tests

func test_add_variables_identifies_simple_variable():
	# Arrange
	var code = "var player_health = 100"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddVariablesToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("player_health"), "Should identify variable")
	framework.assert_equal(symbol_map["player_health"]["kind"], "variable", "Should mark as variable")

func test_add_variables_identifies_typed_variable():
	# Arrange
	var code = "var score: int = 0"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddVariablesToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("score"), "Should identify typed variable")

func test_add_variables_identifies_inferred_type():
	# Arrange
	var code = "var player_pos := Vector2.ZERO"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddVariablesToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("player_pos"), "Should identify variable with inferred type")

func test_add_variables_handles_multiple_variables():
	# Arrange
	var code = """var health = 100
var mana = 50
var stamina = 75"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddVariablesToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_equal(symbol_map.size(), 3, "Should find 3 variables")
	framework.assert_true(symbol_map.has("health"), "Should find health")
	framework.assert_true(symbol_map.has("mana"), "Should find mana")
	framework.assert_true(symbol_map.has("stamina"), "Should find stamina")

func test_add_variables_no_duplicates():
	# Arrange
	var code = """var player_count = 0
var player_count = 1"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddVariablesToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_equal(symbol_map.size(), 1, "Should not add duplicate variable names")

func test_add_variables_handles_private_variables():
	# Arrange
	var code = "var _internal_state = false"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddVariablesToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("_internal_state"), "Should identify private variables (starting with _)")

func test_add_variables_handles_snake_case():
	# Arrange
	var code = "var player_max_health = 100"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddVariablesToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("player_max_health"), "Should handle snake_case")

func test_add_variables_handles_camel_case():
	# Arrange
	var code = "var playerMaxHealth = 100"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddVariablesToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("playerMaxHealth"), "Should handle camelCase")

func test_add_variables_handles_pascal_case():
	# Arrange
	var code = "var PlayerMaxHealth = 100"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddVariablesToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("PlayerMaxHealth"), "Should handle PascalCase")

func test_add_variables_in_function():
	# Arrange
	var code = """func test():
	var local_var = 5
	return local_var"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddVariablesToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("local_var"), "Should find variables inside functions")

func test_add_variables_with_export_annotation():
	# Arrange
	var code = """@export var speed: float = 10.0
var other_var = 5"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddVariablesToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("speed"), "Should identify @export variables")
	framework.assert_true(symbol_map.has("other_var"), "Should identify non-export variables")
	# Note: @export variables are protected during replacement phase, not during map building

func test_add_variables_array_type():
	# Arrange
	var code = "var items: Array[String] = []"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddVariablesToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("items"), "Should handle array type annotation")

func test_skip_single_letter_variables():
	# Arrange
	var code = "var i = 0\nvar n = 5\nvar x = 10"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddVariablesToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("i"), "Single-letter var 'i' should be skipped")
	framework.assert_false(symbol_map.has("n"), "Single-letter var 'n' should be skipped")
	framework.assert_false(symbol_map.has("x"), "Single-letter var 'x' should be skipped")
	framework.assert_equal(symbol_map.size(), 0, "No short variables should be in map")

func test_skip_two_letter_variables():
	# Arrange
	var code = "var id = 1\nvar hp = 100\nvar ok = true"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddVariablesToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("id"), "Two-letter var 'id' should be skipped")
	framework.assert_false(symbol_map.has("hp"), "Two-letter var 'hp' should be skipped")
	framework.assert_equal(symbol_map.size(), 0, "No short variables should be in map")

func test_include_three_letter_plus_variables():
	# Arrange
	var code = "var idx = 0\nvar pos = Vector2.ZERO\nvar health = 100"
	var symbol_map = {}

	# Act
	ObfuscateHelper.AddVariablesToSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("idx"), "Three-letter var 'idx' should be included")
	framework.assert_true(symbol_map.has("pos"), "Three-letter var 'pos' should be included")
	framework.assert_true(symbol_map.has("health"), "Longer var 'health' should be included")
	framework.assert_equal(symbol_map.size(), 3, "All 3+ char variables should be in map")
