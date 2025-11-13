extends RefCounted

var framework: TestFramework

# Callable Pattern Obfuscation Tests

func test_function_bind_pattern_obfuscated():
	# Arrange
	var code = "func ApplyDamage():\n\tpass\n\nfunc _ready():\n\tvar callback = ApplyDamage.bind()"
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("ApplyDamage"), "ApplyDamage should be in symbol map")
	framework.assert_equal(symbol_map["ApplyDamage"]["kind"], "function", "ApplyDamage should be marked as function")

func test_function_unbind_pattern_obfuscated():
	# Arrange
	var code = "func ProcessData():\n\tpass\n\nvar cb = ProcessData.bind(1).unbind(1)"
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("ProcessData"), "ProcessData should be in symbol map")

func test_function_call_pattern_obfuscated():
	# Arrange
	var code = "func Execute():\n\tpass\n\nvar result = Execute.call()"
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("Execute"), "Execute should be in symbol map")

func test_function_callv_pattern_obfuscated():
	# Arrange
	var code = "func RunCommand():\n\tpass\n\nvar args = []\nvar result = RunCommand.callv(args)"
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("RunCommand"), "RunCommand should be in symbol map")

func test_signal_connect_with_bind():
	# Arrange
	var code = "func _on_button_pressed(btn):\n\tpass\n\nfunc _ready():\n\tvar my_button = Button.new()\n\tmy_button.pressed.connect(_on_button_pressed.bind(my_button))"
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("_on_button_pressed"), "_on_button_pressed should be in symbol map")
	framework.assert_true(symbol_map.has("my_button"), "my_button variable should be in symbol map")

func test_thread_start_with_bind():
	# Arrange
	var code = "func RunThread(path):\n\tpass\n\nfunc _ready():\n\tvar thread = Thread.new()\n\tthread.start(RunThread.bind(\"/path\"))"
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("RunThread"), "RunThread should be in symbol map")
	framework.assert_true(symbol_map.has("thread"), "thread variable should be in symbol map")

func test_tween_callback_with_bind():
	# Arrange
	var code = "func ApplyDamage(dmg):\n\tpass\n\nfunc _ready():\n\tvar heldItem = Item.new()\n\tvar tween = create_tween()\n\ttween.tween_callback(ApplyDamage.bind(heldItem))"
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("ApplyDamage"), "ApplyDamage should be in symbol map (this was the bug!)")
	framework.assert_true(symbol_map.has("heldItem"), "heldItem variable should be in symbol map")
	framework.assert_true(symbol_map.has("tween"), "tween variable should be in symbol map")

func test_mixed_callable_and_string_reflection():
	# Arrange
	var code = """func SaveGame():
	pass

func LoadGame():
	pass

func _ready():
	# Direct reference - should obfuscate
	var callback = SaveGame.bind()

	# String reflection - should preserve
	if has_method("LoadGame"):
		call("LoadGame")
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("SaveGame"), "SaveGame should be in symbol map (direct reference)")
	framework.assert_true(symbol_map.has("LoadGame"), "LoadGame should be in symbol map (also direct reference)")

func test_multiple_bind_patterns():
	# Arrange
	var code = """func OnTimeout():
	pass

func OnFinished():
	pass

func _ready():
	timer.timeout.connect(OnTimeout.bind())
	animation.finished.connect(OnFinished.bind())
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("OnTimeout"), "OnTimeout should be in symbol map")
	framework.assert_true(symbol_map.has("OnFinished"), "OnFinished should be in symbol map")

func test_chained_callable_methods():
	# Arrange
	var code = "func Process(a, b):\n\tpass\n\nvar cb = Process.bind(1).bind(2).unbind(1)"
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("Process"), "Process should be in symbol map (first .bind() triggers detection)")

func test_sort_custom_with_class_method():
	# Arrange
	var code = """class_name CommonHelper

static func SortAscending(a, b):
	return a < b

func test():
	var items = [3, 1, 2]
	items.sort_custom(CommonHelper.SortAscending)
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("SortAscending"), "SortAscending should be in symbol map (callable reference in sort_custom)")
	framework.assert_true(symbol_map.has("test"), "test should be in symbol map")
	framework.assert_true(symbol_map.has("items"), "items should be in symbol map")

func test_callable_reference_as_parameter():
	# Arrange
	var code = """func my_callback():
	pass

func register_callback(cb):
	pass

func _ready():
	register_callback(my_callback)
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert
	framework.assert_true(symbol_map.has("my_callback"), "my_callback should be in symbol map (callable reference)")
