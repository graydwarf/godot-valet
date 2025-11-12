extends RefCounted

var framework: TestFramework

# Enum Obfuscation Tests

func test_simple_enum_values_not_obfuscated():
	# Arrange
	var code = """enum MyEnum { VALUE_ONE, VALUE_TWO, VALUE_THREE }
var state = MyEnum.VALUE_ONE"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("VALUE_ONE"), "VALUE_ONE should NOT be in symbol map (enum value)")
	framework.assert_false(symbol_map.has("VALUE_TWO"), "VALUE_TWO should NOT be in symbol map (enum value)")
	framework.assert_false(symbol_map.has("VALUE_THREE"), "VALUE_THREE should NOT be in symbol map (enum value)")
	framework.assert_true(symbol_map.has("state"), "state variable should be obfuscated")

func test_enum_with_explicit_values():
	# Arrange
	var code = """enum AnimationState { Idle = 0, Running = 1, Jumping = 2 }
var _currentAnimationState: AnimationState = AnimationState.Idle"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("Idle"), "Idle should NOT be in symbol map (enum value)")
	framework.assert_false(symbol_map.has("Running"), "Running should NOT be in symbol map (enum value)")
	framework.assert_false(symbol_map.has("Jumping"), "Jumping should NOT be in symbol map (enum value)")
	framework.assert_true(symbol_map.has("_currentAnimationState"), "_currentAnimationState variable should be obfuscated")

func test_anonymous_enum():
	# Arrange
	var code = """enum { OPTION_A, OPTION_B, OPTION_C }
var selected = OPTION_A"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("OPTION_A"), "OPTION_A should NOT be in symbol map (enum value)")
	framework.assert_false(symbol_map.has("OPTION_B"), "OPTION_B should NOT be in symbol map (enum value)")
	framework.assert_false(symbol_map.has("OPTION_C"), "OPTION_C should NOT be in symbol map (enum value)")

func test_enum_in_class():
	# Arrange
	var code = """class_name Enums

enum SortByType { None, PublishedDate, CreatedDate, EditedDate }

func get_sort():
	return SortByType.None"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("None"), "None should NOT be in symbol map (enum value)")
	framework.assert_false(symbol_map.has("PublishedDate"), "PublishedDate should NOT be in symbol map (enum value)")
	framework.assert_false(symbol_map.has("CreatedDate"), "CreatedDate should NOT be in symbol map (enum value)")
	framework.assert_false(symbol_map.has("EditedDate"), "EditedDate should NOT be in symbol map (enum value)")
	framework.assert_true(symbol_map.has("get_sort"), "get_sort function should be obfuscated")

func test_enum_in_match_statement():
	# Arrange
	var code = """enum State { Idle, Running, Jumping }

func handle_state(state_param):
	var current_state = State.Idle
	match state_param:
		State.Idle:
			print("idle")
		State.Running:
			print("running")
		State.Jumping:
			print("jumping")"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("Idle"), "Idle should NOT be in symbol map (enum value)")
	framework.assert_false(symbol_map.has("Running"), "Running should NOT be in symbol map (enum value)")
	framework.assert_false(symbol_map.has("Jumping"), "Jumping should NOT be in symbol map (enum value)")
	framework.assert_true(symbol_map.has("handle_state"), "handle_state function should be obfuscated")
	framework.assert_true(symbol_map.has("current_state"), "current_state variable should be obfuscated")

func test_multiple_enums():
	# Arrange
	var code = """enum Direction { North, South, East, West }
enum Color { Red, Green, Blue }

var dir = Direction.North
var col = Color.Red"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("North"), "North should NOT be in symbol map")
	framework.assert_false(symbol_map.has("South"), "South should NOT be in symbol map")
	framework.assert_false(symbol_map.has("East"), "East should NOT be in symbol map")
	framework.assert_false(symbol_map.has("West"), "West should NOT be in symbol map")
	framework.assert_false(symbol_map.has("Red"), "Red should NOT be in symbol map")
	framework.assert_false(symbol_map.has("Green"), "Green should NOT be in symbol map")
	framework.assert_false(symbol_map.has("Blue"), "Blue should NOT be in symbol map")
	framework.assert_true(symbol_map.has("dir"), "dir variable should be obfuscated")
	framework.assert_true(symbol_map.has("col"), "col variable should be obfuscated")

func test_enum_with_multiline_definition():
	# Arrange
	var code = """enum LongEnum {
	VALUE_ONE,
	VALUE_TWO,
	VALUE_THREE,
	VALUE_FOUR = 10,
	VALUE_FIVE
}"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("VALUE_ONE"), "VALUE_ONE should NOT be in symbol map")
	framework.assert_false(symbol_map.has("VALUE_TWO"), "VALUE_TWO should NOT be in symbol map")
	framework.assert_false(symbol_map.has("VALUE_THREE"), "VALUE_THREE should NOT be in symbol map")
	framework.assert_false(symbol_map.has("VALUE_FOUR"), "VALUE_FOUR should NOT be in symbol map")
	framework.assert_false(symbol_map.has("VALUE_FIVE"), "VALUE_FIVE should NOT be in symbol map")

func test_user_reported_pattern():
	# Arrange - Exact pattern from user's code
	var code = """class_name Enums

enum AnimationState { Idle, Walk, Run, Defend, Attack }

func test():
	var _currentAnimationState: AnimationState = AnimationState.Idle"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_false(symbol_map.has("Idle"), "Idle should NOT be obfuscated (was the user's bug)")
	framework.assert_false(symbol_map.has("Walk"), "Walk should NOT be obfuscated")
	framework.assert_false(symbol_map.has("Run"), "Run should NOT be obfuscated")
	framework.assert_false(symbol_map.has("Defend"), "Defend should NOT be obfuscated")
	framework.assert_false(symbol_map.has("Attack"), "Attack should NOT be obfuscated")
	framework.assert_true(symbol_map.has("test"), "test function should be obfuscated")
	framework.assert_true(symbol_map.has("_currentAnimationState"), "_currentAnimationState variable should be obfuscated")
