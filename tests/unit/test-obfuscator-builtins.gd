extends RefCounted

var framework: TestFramework

# Built-In Exclusion Tests

func test_builtin_array_methods_excluded():
	# Arrange
	var code = """func size():
	return 10

func append(item):
	pass

func has(item):
	return false
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - built-in Array methods should NOT be obfuscated
	framework.assert_false(symbol_map.has("size"), "size should NOT be obfuscated (built-in Array method)")
	framework.assert_false(symbol_map.has("append"), "append should NOT be obfuscated (built-in Array method)")
	framework.assert_false(symbol_map.has("has"), "has should NOT be obfuscated (built-in Array/Dictionary method)")

func test_builtin_string_methods_excluded():
	# Arrange
	var code = """func split(delimiter):
	pass

func replace(what, with):
	pass

func begins_with(prefix):
	pass
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - built-in String methods should NOT be obfuscated
	framework.assert_false(symbol_map.has("split"), "split should NOT be obfuscated (built-in String method)")
	framework.assert_false(symbol_map.has("replace"), "replace should NOT be obfuscated (built-in String method)")
	framework.assert_false(symbol_map.has("begins_with"), "begins_with should NOT be obfuscated (built-in String method)")

func test_builtin_node_methods_excluded():
	# Arrange
	var code = """func get_child(index):
	pass

func add_child(node):
	pass

func queue_free():
	pass

func get_parent():
	pass
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - built-in Node methods should NOT be obfuscated
	framework.assert_false(symbol_map.has("get_child"), "get_child should NOT be obfuscated (built-in Node method)")
	framework.assert_false(symbol_map.has("add_child"), "add_child should NOT be obfuscated (built-in Node method)")
	framework.assert_false(symbol_map.has("queue_free"), "queue_free should NOT be obfuscated (built-in Node method)")
	framework.assert_false(symbol_map.has("get_parent"), "get_parent should NOT be obfuscated (built-in Node method)")

func test_builtin_object_methods_excluded():
	# Arrange
	var code = """func get(property):
	pass

func set(property, value):
	pass

func call(method):
	pass

func has_method(method_name):
	pass
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - built-in Object methods should NOT be obfuscated
	framework.assert_false(symbol_map.has("get"), "get should NOT be obfuscated (built-in Object method)")
	framework.assert_false(symbol_map.has("set"), "set should NOT be obfuscated (built-in Object method)")
	framework.assert_false(symbol_map.has("call"), "call should NOT be obfuscated (built-in Object method)")
	framework.assert_false(symbol_map.has("has_method"), "has_method should NOT be obfuscated (built-in Object method)")

func test_user_functions_not_colliding_with_builtins_are_obfuscated():
	# Arrange
	var code = """func my_custom_function():
	pass

func calculate_score():
	pass

func process_data():
	pass
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - user functions should still be obfuscated
	framework.assert_true(symbol_map.has("my_custom_function"), "my_custom_function should be obfuscated")
	framework.assert_true(symbol_map.has("calculate_score"), "calculate_score should be obfuscated")
	framework.assert_true(symbol_map.has("process_data"), "process_data should be obfuscated")

func test_builtin_class_names_excluded_from_variables():
	# Arrange
	var code = """var Array = []
var Node = null
var Dictionary = {}
var String = ""
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - built-in class names should NOT be obfuscated when used as variable names
	framework.assert_false(symbol_map.has("Array"), "Array should NOT be obfuscated (built-in class name)")
	framework.assert_false(symbol_map.has("Node"), "Node should NOT be obfuscated (built-in class name)")
	framework.assert_false(symbol_map.has("Dictionary"), "Dictionary should NOT be obfuscated (built-in class name)")
	framework.assert_false(symbol_map.has("String"), "String should NOT be obfuscated (built-in class name)")

func test_builtin_control_nodes_excluded():
	# Arrange
	var code = """var Button = null
var Label = null
var LineEdit = null
var Control = null
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - Control node types should NOT be obfuscated
	framework.assert_false(symbol_map.has("Button"), "Button should NOT be obfuscated (built-in Control node)")
	framework.assert_false(symbol_map.has("Label"), "Label should NOT be obfuscated (built-in Control node)")
	framework.assert_false(symbol_map.has("LineEdit"), "LineEdit should NOT be obfuscated (built-in Control node)")
	framework.assert_false(symbol_map.has("Control"), "Control should NOT be obfuscated (built-in class)")

func test_external_plugin_classes_excluded():
	# Arrange
	var code = """var SQLite = null
var SupabaseAPI = null
var MyCustomPlugin = null
"""
	var symbol_map = {}

	# Configure external plugin classes
	ObfuscateHelper.SetExternalPluginClasses(["SQLite", "SupabaseAPI", "MyCustomPlugin"])

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - external plugin classes should NOT be obfuscated
	framework.assert_false(symbol_map.has("SQLite"), "SQLite should NOT be obfuscated (external plugin class)")
	framework.assert_false(symbol_map.has("SupabaseAPI"), "SupabaseAPI should NOT be obfuscated (external plugin class)")
	framework.assert_false(symbol_map.has("MyCustomPlugin"), "MyCustomPlugin should NOT be obfuscated (external plugin class)")

	# Clean up
	ObfuscateHelper.SetExternalPluginClasses([])

func test_user_variables_not_colliding_with_builtins_are_obfuscated():
	# Arrange
	var code = """var player_score = 0
var game_state = ""
var health_points = 100
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - user variables should be obfuscated
	framework.assert_true(symbol_map.has("player_score"), "player_score should be obfuscated")
	framework.assert_true(symbol_map.has("game_state"), "game_state should be obfuscated")
	framework.assert_true(symbol_map.has("health_points"), "health_points should be obfuscated")

func test_mixed_builtin_and_user_code():
	# Arrange
	var code = """func size():
	return 10

func my_custom_size_calculator():
	return 20

var Array = []
var my_array = []

func get_child(index):
	pass

func get_my_child():
	pass
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - built-ins excluded, user code obfuscated
	framework.assert_false(symbol_map.has("size"), "size should NOT be obfuscated (built-in)")
	framework.assert_true(symbol_map.has("my_custom_size_calculator"), "my_custom_size_calculator should be obfuscated")
	framework.assert_false(symbol_map.has("Array"), "Array should NOT be obfuscated (built-in class)")
	framework.assert_true(symbol_map.has("my_array"), "my_array should be obfuscated")
	framework.assert_false(symbol_map.has("get_child"), "get_child should NOT be obfuscated (built-in)")
	framework.assert_true(symbol_map.has("get_my_child"), "get_my_child should be obfuscated")

func test_lifecycle_methods_still_excluded():
	# Arrange
	var code = """func _ready():
	pass

func _process(delta):
	pass

func _physics_process(delta):
	pass

func _input(event):
	pass
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - lifecycle methods should NOT be obfuscated
	framework.assert_false(symbol_map.has("_ready"), "_ready should NOT be obfuscated (lifecycle method)")
	framework.assert_false(symbol_map.has("_process"), "_process should NOT be obfuscated (lifecycle method)")
	framework.assert_false(symbol_map.has("_physics_process"), "_physics_process should NOT be obfuscated (lifecycle method)")
	framework.assert_false(symbol_map.has("_input"), "_input should NOT be obfuscated (lifecycle method)")

func test_file_directory_methods_excluded():
	# Arrange
	var code = """func open(path):
	pass

func close():
	pass

func file_exists(path):
	pass

func get_files():
	pass
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - FileAccess/DirAccess methods should NOT be obfuscated
	framework.assert_false(symbol_map.has("open"), "open should NOT be obfuscated (built-in File method)")
	framework.assert_false(symbol_map.has("close"), "close should NOT be obfuscated (built-in File method)")
	framework.assert_false(symbol_map.has("file_exists"), "file_exists should NOT be obfuscated (built-in File method)")
	framework.assert_false(symbol_map.has("get_files"), "get_files should NOT be obfuscated (built-in DirAccess method)")
