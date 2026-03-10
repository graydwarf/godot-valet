extends RefCounted

var framework: TestFramework

# Constant/Enum Inlining Tests

func test_extract_simple_const():
	# Arrange
	var code = """const MAX_SPEED = 100
const GRAVITY = 9.8
var velocity = 0"""

	# Act
	ObfuscateHelper._constantExcludeList.clear()
	var constants = ObfuscateHelper.ExtractConstantsFromContent(code)

	# Assert
	framework.assert_true(constants.has("MAX_SPEED"), "Should extract MAX_SPEED")
	framework.assert_equal(constants["MAX_SPEED"], "100", "MAX_SPEED should be 100")
	framework.assert_true(constants.has("GRAVITY"), "Should extract GRAVITY")
	framework.assert_equal(constants["GRAVITY"], "9.8", "GRAVITY should be 9.8")

func test_extract_typed_const():
	# Arrange
	var code = """const MAX_HP: int = 50
const SPEED: float = 3.14"""

	# Act
	ObfuscateHelper._constantExcludeList.clear()
	var constants = ObfuscateHelper.ExtractConstantsFromContent(code)

	# Assert
	framework.assert_true(constants.has("MAX_HP"), "Should extract typed int const")
	framework.assert_equal(constants["MAX_HP"], "50", "MAX_HP should be 50")
	framework.assert_true(constants.has("SPEED"), "Should extract typed float const")
	framework.assert_equal(constants["SPEED"], "3.14", "SPEED should be 3.14")

func test_extract_bool_const():
	# Arrange
	var code = """const IS_DEBUG = true
const SHOW_UI = false"""

	# Act
	ObfuscateHelper._constantExcludeList.clear()
	var constants = ObfuscateHelper.ExtractConstantsFromContent(code)

	# Assert
	framework.assert_true(constants.has("IS_DEBUG"), "Should extract boolean true const")
	framework.assert_equal(constants["IS_DEBUG"], "true", "IS_DEBUG should be true")
	framework.assert_true(constants.has("SHOW_UI"), "Should extract boolean false const")
	framework.assert_equal(constants["SHOW_UI"], "false", "SHOW_UI should be false")

func test_skip_string_const():
	# Arrange
	var code = """const PLAYER_NAME = "Hero"
const PATH = '/root/main'
const COUNT = 42"""

	# Act
	ObfuscateHelper._constantExcludeList.clear()
	var constants = ObfuscateHelper.ExtractConstantsFromContent(code)

	# Assert
	framework.assert_false(constants.has("PLAYER_NAME"), "Should skip string const")
	framework.assert_false(constants.has("PATH"), "Should skip single-quote string const")
	framework.assert_true(constants.has("COUNT"), "Should still extract numeric const")

func test_skip_preload_and_load_const():
	# Arrange
	var code = """const PlayerScene = preload("res://player.tscn")
const EnemyScene = load("res://enemy.tscn")
const TILE_SIZE = 16"""

	# Act
	ObfuscateHelper._constantExcludeList.clear()
	var constants = ObfuscateHelper.ExtractConstantsFromContent(code)

	# Assert
	framework.assert_false(constants.has("PlayerScene"), "Should skip preload const")
	framework.assert_false(constants.has("EnemyScene"), "Should skip load const")
	framework.assert_true(constants.has("TILE_SIZE"), "Should extract numeric const")

func test_skip_expression_const():
	# Arrange
	var code = """const DOUBLE_SPEED = MAX * 2
const HALF = 100 / 2
const NEG_ONE = -1"""

	# Act
	ObfuscateHelper._constantExcludeList.clear()
	var constants = ObfuscateHelper.ExtractConstantsFromContent(code)

	# Assert
	framework.assert_false(constants.has("DOUBLE_SPEED"), "Should skip expression with *")
	framework.assert_false(constants.has("HALF"), "Should skip expression with /")
	framework.assert_true(constants.has("NEG_ONE"), "Should extract negative number")
	framework.assert_equal(constants["NEG_ONE"], "-1", "NEG_ONE should be -1")

func test_enum_ordinals_sequential():
	# Arrange
	var code = """enum State { Idle, Running, Jumping }"""

	# Act
	ObfuscateHelper._constantExcludeList.clear()
	var constants = ObfuscateHelper.ExtractEnumValuesWithIndices(code)

	# Assert - Named enums only get qualified keys (no bare keys)
	framework.assert_equal(constants["State.Idle"], "0", "State.Idle should be 0")
	framework.assert_equal(constants["State.Running"], "1", "State.Running should be 1")
	framework.assert_equal(constants["State.Jumping"], "2", "State.Jumping should be 2")
	framework.assert_false(constants.has("Idle"), "Named enum values should NOT have bare keys")

func test_enum_ordinals_explicit():
	# Arrange
	var code = """enum Priority { Low = 10, Medium = 20, High = 30 }"""

	# Act
	ObfuscateHelper._constantExcludeList.clear()
	var constants = ObfuscateHelper.ExtractEnumValuesWithIndices(code)

	# Assert
	framework.assert_equal(constants["Priority.Low"], "10", "Priority.Low should be 10")
	framework.assert_equal(constants["Priority.Medium"], "20", "Priority.Medium should be 20")
	framework.assert_equal(constants["Priority.High"], "30", "Priority.High should be 30")

func test_enum_ordinals_anonymous():
	# Arrange
	var code = """enum { NONE, ACTIVE, DISABLED }"""

	# Act
	ObfuscateHelper._constantExcludeList.clear()
	var constants = ObfuscateHelper.ExtractEnumValuesWithIndices(code)

	# Assert
	framework.assert_equal(constants["NONE"], "0", "NONE should be 0")
	framework.assert_equal(constants["ACTIVE"], "1", "ACTIVE should be 1")
	framework.assert_equal(constants["DISABLED"], "2", "DISABLED should be 2")
	# Anonymous enums should NOT have qualified references
	framework.assert_false(constants.has(".NONE"), "Anonymous enums should not have qualified refs")

func test_inline_const_in_code():
	# Arrange
	var code = """const MAX_SPEED = 100
var speed = MAX_SPEED
func go():
	if speed > MAX_SPEED:
		speed = MAX_SPEED"""
	var payload = ContentPayload.new()
	payload.SetContent(code)

	ObfuscateHelper._constantMap = {"MAX_SPEED": "100"}

	# Act
	ObfuscateHelper.InlineConstants(payload)

	# Assert
	var result = payload.GetContent()
	# The const declaration line keeps MAX_SPEED (it's on a const line)
	framework.assert_true("var speed = 100" in result, "MAX_SPEED in var assignment should be inlined to 100")
	framework.assert_true("if speed > 100:" in result, "MAX_SPEED in comparison should be inlined to 100")

func test_inline_qualified_enum_refs():
	# Arrange
	var code = """var current = State.Idle
if current == State.Running:
	pass"""
	var payload = ContentPayload.new()
	payload.SetContent(code)

	# Named enums only have qualified keys (no bare keys to avoid collisions)
	ObfuscateHelper._constantMap = {
		"State.Idle": "0",
		"State.Running": "1"
	}

	# Act
	ObfuscateHelper.InlineConstants(payload)

	# Assert - Qualified refs replaced correctly
	var result = payload.GetContent()
	framework.assert_true("var current = 0" in result, "State.Idle should be inlined to 0")
	framework.assert_true("if current == 1:" in result, "State.Running should be inlined to 1")
	framework.assert_false("State.0" in result, "Should NOT produce State.0")

func test_inline_preserves_strings():
	# Arrange
	var code = """const MAX = 10
var label_text = "MAX value is great"
var x = MAX"""
	var payload = ContentPayload.new()
	payload.SetContent(code)

	# First preserve strings as the real pipeline does
	ObfuscateHelper.PreserveStringLiterals(payload)
	ObfuscateHelper._constantMap = {"MAX": "10"}

	# Act
	ObfuscateHelper.InlineConstants(payload)
	ObfuscateHelper.RestoreStringLiterals(payload)

	# Assert
	var result = payload.GetContent()
	framework.assert_true('"MAX value is great"' in result, "String containing MAX should be preserved")
	framework.assert_true("var x = 10" in result, "Code reference to MAX should be inlined")

func test_remove_const_declarations():
	# Arrange
	var code = "const MAX_SPEED = 100\nvar speed = MAX_SPEED\nconst LABEL = \"hello\"\nfunc go():\n\tpass"
	var payload = ContentPayload.new()
	payload.SetContent(code)

	ObfuscateHelper._constantMap = {"MAX_SPEED": "100"}

	# Act
	ObfuscateHelper.RemoveConstantDeclarations(payload)

	# Assert
	var result = payload.GetContent()
	framework.assert_false("const MAX_SPEED" in result, "Inlined const declaration should be removed")
	framework.assert_true("const LABEL" in result, "Non-inlined const should remain")
	framework.assert_true("var speed" in result, "Other code should remain")
	framework.assert_true("func go():" in result, "Functions should remain")

func test_remove_enum_blocks():
	# Arrange
	var code = "enum State { Idle, Running }\nvar current = 0\nfunc go():\n\tpass"
	var payload = ContentPayload.new()
	payload.SetContent(code)

	ObfuscateHelper._constantMap = {"State.Idle": "0", "State.Running": "1"}

	# Act
	ObfuscateHelper.RemoveConstantDeclarations(payload)

	# Assert
	var result = payload.GetContent()
	framework.assert_false("enum State" in result, "Enum block should be removed")
	framework.assert_true("var current = 0" in result, "Other code should remain")

func test_const_removed_from_symbol_map():
	# Arrange
	ObfuscateHelper._isInliningConstants = true
	ObfuscateHelper._constantExcludeList.clear()
	ObfuscateHelper._constantMap.clear()
	ObfuscateHelper._usedNames.clear()
	ObfuscateHelper._enumValueExcludeList.clear()
	ObfuscateHelper._signalExcludeList.clear()
	ObfuscateHelper._classNameExcludeList.clear()

	var code = """const MAX_SPEED = 100
var velocity = 0
func Move():
	pass"""
	var symbol_map = {}

	# Act - Build symbol map the normal way
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Extract constants
	var constants = ObfuscateHelper.ExtractConstantsFromContent(code)
	ObfuscateHelper._constantMap = constants

	# Prune inlined names (simulating what BuildGlobalObfuscationMap does)
	for const_name in ObfuscateHelper._constantMap.keys():
		if symbol_map.has(const_name):
			symbol_map.erase(const_name)

	# Assert
	framework.assert_false(symbol_map.has("MAX_SPEED"), "MAX_SPEED should be pruned from symbol map (will be inlined)")
	framework.assert_true(symbol_map.has("velocity"), "velocity should remain in symbol map")
	framework.assert_true(symbol_map.has("Move"), "Move should remain in symbol map")

	# Cleanup
	ObfuscateHelper._isInliningConstants = false

func test_constant_exclude_list():
	# Arrange
	var code = """const MAX_SPEED = 100
const KEEP_ME = 50
var x = MAX_SPEED + KEEP_ME"""

	# Act
	ObfuscateHelper._constantExcludeList = ["KEEP_ME"] as Array[String]
	var constants = ObfuscateHelper.ExtractConstantsFromContent(code)

	# Assert
	framework.assert_true(constants.has("MAX_SPEED"), "MAX_SPEED should be extracted")
	framework.assert_false(constants.has("KEEP_ME"), "KEEP_ME should be excluded")

	# Cleanup
	ObfuscateHelper._constantExcludeList.clear()

func test_multiline_enum_removal():
	# Arrange
	var code = "enum LongEnum {\n\tVALUE_ONE,\n\tVALUE_TWO,\n\tVALUE_THREE\n}\nvar x = 0\nfunc go():\n\tpass"
	var payload = ContentPayload.new()
	payload.SetContent(code)

	ObfuscateHelper._constantMap = {"LongEnum.VALUE_ONE": "0"}

	# Act
	ObfuscateHelper.RemoveConstantDeclarations(payload)

	# Assert
	var result = payload.GetContent()
	framework.assert_false("enum LongEnum" in result, "Multiline enum block should be removed")
	framework.assert_false("VALUE_ONE" in result, "Enum values should be removed with block")
	framework.assert_true("var x = 0" in result, "Code after enum should remain")

func test_skip_signal_param_replacement():
	# Arrange - signal parameter names must not be replaced with constant values
	var code = """signal CardDragStarted(card, ctrlPressed: bool)
var x = card"""
	var payload = ContentPayload.new()
	payload.SetContent(code)

	ObfuscateHelper._constantMap = {"card": "12"}

	# Act
	ObfuscateHelper.InlineConstants(payload)

	# Assert
	var result = payload.GetContent()
	framework.assert_true("signal CardDragStarted(card," in result, "Signal param 'card' should NOT be replaced")
	framework.assert_true("var x = 12" in result, "Usage of 'card' in code should be inlined")

func test_skip_func_param_replacement():
	# Arrange - function parameter names must not be replaced with constant values
	var code = """func process(delta, mode):
	var x = mode"""
	var payload = ContentPayload.new()
	payload.SetContent(code)

	ObfuscateHelper._constantMap = {"mode": "3"}

	# Act
	ObfuscateHelper.InlineConstants(payload)

	# Assert
	var result = payload.GetContent()
	framework.assert_true("func process(delta, mode):" in result, "Func param 'mode' should NOT be replaced")
	framework.assert_true("var x = 3" in result, "Usage of 'mode' in code body should be inlined")

func test_named_enum_no_bare_keys():
	# Arrange - Named enums should only produce qualified keys
	var code = """enum Format { TEXT, JSON, CSV }"""

	# Act
	ObfuscateHelper._constantExcludeList.clear()
	var constants = ObfuscateHelper.ExtractEnumValuesWithIndices(code)

	# Assert - Only qualified keys, no bare keys
	framework.assert_true(constants.has("Format.TEXT"), "Should have qualified Format.TEXT")
	framework.assert_true(constants.has("Format.JSON"), "Should have qualified Format.JSON")
	framework.assert_true(constants.has("Format.CSV"), "Should have qualified Format.CSV")
	framework.assert_false(constants.has("TEXT"), "Named enum should NOT have bare TEXT key")
	framework.assert_false(constants.has("JSON"), "Named enum should NOT have bare JSON key")
	framework.assert_false(constants.has("CSV"), "Named enum should NOT have bare CSV key")
