extends RefCounted

var framework: TestFramework

# Integration Tests - Real-world code patterns

func test_build_symbol_map_complete_class():
	# Arrange
	var code = """extends Node
class_name Player

var health = 100
var speed: float = 5.0

func _ready():
	initialize()

func initialize():
	health = 100

func TakeDamage(amount: int):
	health -= amount

func _private_helper():
	pass
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - Should find: health, speed, initialize, TakeDamage
	# Should NOT find: _ready, _private_helper (both start with _)
	framework.assert_true(symbol_map.has("health"), "Should find health variable")
	framework.assert_true(symbol_map.has("speed"), "Should find speed variable")
	framework.assert_true(symbol_map.has("initialize"), "Should find initialize function")
	framework.assert_true(symbol_map.has("TakeDamage"), "Should find TakeDamage function")
	framework.assert_false(symbol_map.has("_ready"), "Should skip _ready")
	framework.assert_false(symbol_map.has("_private_helper"), "Should skip _private_helper")

func test_obfuscation_preserves_has_method_strings():
	# Arrange
	var code = """func check_ability(entity):
	if entity.has_method("jump"):
		entity.jump()
	if entity.has_method("attack"):
		entity.attack()
"""
	var payload = ContentPayload.new()
	payload.SetContent(code)

	# Act - Full preservation flow
	ObfuscateHelper.PreserveSpecialStrings(payload)
	ObfuscateHelper.PreserveStringLiterals(payload)
	ObfuscateHelper.RestoreStringLiterals(payload)

	# Assert
	var result = payload.GetContent()
	framework.assert_false('"jump"' in result, "String should still be tokenized (special strings)")
	framework.assert_false('"attack"' in result, "String should still be tokenized (special strings)")

	# Restore special strings
	ObfuscateHelper.RestoreSpecialStrings(payload)
	result = payload.GetContent()
	framework.assert_true('"jump"' in result, "Jump should be restored")
	framework.assert_true('"attack"' in result, "Attack should be restored")

func test_global_symbol_map_consistency():
	# Arrange
	ObfuscateHelper._usedNames.clear()
	var symbol_map = {}

	# Act - Build map with duplicate function names
	var code1 = "func Process():\n\tpass"
	var code2 = "func Process():\n\tpass\nfunc Update():\n\tpass"

	ObfuscateHelper.BuildSymbolMap(code1, symbol_map)
	var first_process_entry = symbol_map["Process"]

	symbol_map = {}
	ObfuscateHelper.BuildSymbolMap(code2, symbol_map)
	var second_process_entry = symbol_map["Process"]

	# Assert - Both should identify Process, but replacement happens later
	framework.assert_not_null(first_process_entry, "First map should have Process")
	framework.assert_not_null(second_process_entry, "Second map should have Process")

func test_obfuscation_handles_function_calls():
	# Arrange
	var code = """func SaveGame():
	var data = GetSaveData()
	WriteToDisk(data)

func GetSaveData():
	return {}

func WriteToDisk(data):
	pass
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - All three functions should be found
	framework.assert_true(symbol_map.has("SaveGame"), "Should find SaveGame")
	framework.assert_true(symbol_map.has("GetSaveData"), "Should find GetSaveData")
	framework.assert_true(symbol_map.has("WriteToDisk"), "Should find WriteToDisk")
	framework.assert_equal(symbol_map.size(), 4, "Should find 3 functions + 1 variable (data)")

func test_obfuscation_handles_static_functions():
	# Arrange
	var code = """static func CreateInstance():
	return Player.new()

func _ready():
	var player = Player.CreateInstance()
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("CreateInstance"), "Should find static function")
	framework.assert_false(symbol_map.has("_ready"), "Should skip _ready")
	framework.assert_true(symbol_map.has("player"), "Should find player variable")

func test_obfuscation_handles_exported_variables():
	# Arrange
	var code = """@export var max_health: int = 100
var current_health = 100
@export var speed: float = 5.0
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - @export variables ARE added to symbol map
	# They're protected during the replacement phase (GetObfuscationReplacement)
	framework.assert_true(symbol_map.has("max_health"), "Should find @export variable in map")
	framework.assert_true(symbol_map.has("current_health"), "Should find regular variable")
	framework.assert_true(symbol_map.has("speed"), "Should find @export variable in map")

func test_obfuscation_handles_complex_function_signatures():
	# Arrange
	var code = """func ComplexFunction(
	param1: int,
	param2: String,
	param3: float = 0.0
) -> Dictionary:
	return {}

static func AnotherOne() -> void:
	pass
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("ComplexFunction"), "Should handle multi-line function signature")
	framework.assert_true(symbol_map.has("AnotherOne"), "Should handle static with return type")

func test_obfuscation_preserves_godot_lifecycle_methods():
	# Arrange
	var code = """func _ready():
	pass

func _process(delta):
	pass

func _physics_process(delta):
	pass

func _input(event):
	pass

func _unhandled_input(event):
	pass
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - None of these should be in the map
	framework.assert_false(symbol_map.has("_ready"), "_ready should be protected")
	framework.assert_false(symbol_map.has("_process"), "_process should be protected")
	framework.assert_false(symbol_map.has("_physics_process"), "_physics_process should be protected")
	framework.assert_false(symbol_map.has("_input"), "_input should be protected")
	framework.assert_false(symbol_map.has("_unhandled_input"), "_unhandled_input should be protected")
	framework.assert_equal(symbol_map.size(), 0, "Should not add any protected functions")

func test_comment_removal_integration():
	# Arrange
	var code = """# This is a comment
var health = 100 # Inline comment
# Another comment
func Test():
	# Function comment
	pass # End comment"""
	var payload = ContentPayload.new()
	payload.SetContent(code)

	# Act
	ObfuscateHelper._isObfuscatingComments = true
	ObfuscateHelper.RemoveCommentsFromCode(payload)

	# Assert
	var result = payload.GetContent()
	framework.assert_false("This is a comment" in result, "Full line comment should be removed")
	framework.assert_false("Inline comment" in result, "Inline comment should be removed")
	framework.assert_false("Function comment" in result, "Function comment should be removed")
	framework.assert_true("var health = 100" in result, "Code should remain")
	framework.assert_true("func Test():" in result, "Function should remain")
