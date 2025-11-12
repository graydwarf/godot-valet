class_name TestFramework
extends RefCounted

signal test_started(test_name: String)
signal test_passed(test_name: String)
signal test_failed(test_name: String, reason: String)
signal all_tests_completed(results: Dictionary)

var _current_test_name: String = ""
var _test_results: Dictionary = {}
var _setup_func: Callable
var _teardown_func: Callable
var _silent_mode: bool = false

func run_test_suite(test_object: Object) -> Dictionary:
	_test_results.clear()
	var methods = []

	for method in test_object.get_method_list():
		if method.name.begins_with("test_"):
			methods.append(method.name)

	if not _silent_mode:
		print("\n========== Running Test Suite ==========")
		print("Found %d tests to run\n" % methods.size())

	for method_name in methods:
		_run_single_test(test_object, method_name)

	_print_summary()
	all_tests_completed.emit(_test_results)
	return _test_results

func _run_single_test(test_object: Object, method_name: String):
	_current_test_name = method_name
	test_started.emit(_current_test_name)

	# Call setup method if it exists
	if test_object.has_method("setup"):
		test_object.setup()

	if _setup_func:
		_setup_func.call()

	# Execute test and check if it failed via _fail_test call
	test_object.call(method_name)

	# Check if test failed (would have been set by _fail_test)
	if not _test_results.has(_current_test_name):
		# Test passed - no failure was recorded
		_test_results[_current_test_name] = {"status": "PASSED", "error": ""}
		test_passed.emit(_current_test_name)
		if not _silent_mode:
			print("✅ %s" % _current_test_name)
	else:
		# Test failed - error was already recorded by _fail_test
		test_failed.emit(_current_test_name, _test_results[_current_test_name]["error"])
		if not _silent_mode:
			print("❌ %s - %s" % [_current_test_name, _test_results[_current_test_name]["error"]])

	if _teardown_func:
		_teardown_func.call()

	# Call teardown method if it exists
	if test_object.has_method("teardown"):
		test_object.teardown()

func _print_summary():
	if not _silent_mode:
		print("\n========== Test Summary ==========")
		var passed = 0
		var failed = 0

		for test_name in _test_results:
			if _test_results[test_name]["status"] == "PASSED":
				passed += 1
			else:
				failed += 1

		print("Total: %d | Passed: %d | Failed: %d" % [passed + failed, passed, failed])

		if failed == 0:
			print("🎉 All tests passed!")
		else:
			print("⚠️ Some tests failed. See details above.")
		print("==================================\n")

func setup(callable: Callable):
	_setup_func = callable

func teardown(callable: Callable):
	_teardown_func = callable

func set_silent_mode(silent: bool):
	_silent_mode = silent

# Assertion methods
func assert_true(condition: bool, message: String = "Expected true"):
	if not condition:
		_fail_test(message)

func assert_false(condition: bool, message: String = "Expected false"):
	if condition:
		_fail_test(message)

func assert_equal(actual, expected, message: String = ""):
	if actual != expected:
		var msg = message if message else "Expected %s but got %s" % [str(expected), str(actual)]
		_fail_test(msg)

func assert_not_equal(actual, expected, message: String = ""):
	if actual == expected:
		var msg = message if message else "Expected values to be different but both were %s" % str(actual)
		_fail_test(msg)

func assert_null(value, message: String = "Expected null"):
	if value != null:
		_fail_test(message + " but got %s" % str(value))

func assert_not_null(value, message: String = "Expected non-null value"):
	if value == null:
		_fail_test(message)

func assert_greater(actual, expected, message: String = ""):
	if not (actual > expected):
		var msg = message if message else "Expected %s > %s" % [str(actual), str(expected)]
		_fail_test(msg)

func assert_less(actual, expected, message: String = ""):
	if not (actual < expected):
		var msg = message if message else "Expected %s < %s" % [str(actual), str(expected)]
		_fail_test(msg)

func assert_in_range(value: float, min_val: float, max_val: float, message: String = ""):
	if value < min_val or value > max_val:
		var msg = message if message else "Expected %s to be between %s and %s" % [str(value), str(min_val), str(max_val)]
		_fail_test(msg)

func assert_has(container, item, message: String = ""):
	if not container.has(item):
		var msg = message if message else "Expected container to have item %s" % str(item)
		_fail_test(msg)

func assert_empty(container, message: String = "Expected empty container"):
	if container.size() > 0:
		_fail_test(message + " but had %d items" % container.size())

func assert_size(container, expected_size: int, message: String = ""):
	if container.size() != expected_size:
		var msg = message if message else "Expected size %d but got %d" % [expected_size, container.size()]
		_fail_test(msg)

func _fail_test(message: String):
	_test_results[_current_test_name] = {"status": "FAILED", "error": message}
	push_error("Test failed: " + message)
