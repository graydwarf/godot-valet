extends Node

signal tests_completed(results: Dictionary, passed: int, failed: int)

var test_framework
var test_suites: Array = []

func run_tests_async(silent: bool = false):
	var TestFrameworkClass = preload("res://tests/test-framework.gd")
	test_framework = TestFrameworkClass.new()
	test_framework.set_silent_mode(silent)
	_register_test_suites()
	return await _run_all_tests()

func _register_test_suites():
	# Obfuscator Tests (8 tests)
	var obfuscator_tests = preload("res://tests/unit/test-obfuscator.gd").new()
	obfuscator_tests.framework = test_framework
	test_suites.append(obfuscator_tests)

func _run_all_tests():
	var total_results = {}

	for suite in test_suites:
		var suite_name = suite.get_class() if suite.has_method("get_class") else "TestSuite"

		var results = test_framework.run_test_suite(suite)
		for test_name in results:
			total_results[suite_name + "." + test_name] = results[test_name]

	var summary = _calculate_summary(total_results)
	tests_completed.emit(total_results, summary.passed, summary.failed)
	return {"results": total_results, "passed": summary.passed, "failed": summary.failed}

func _calculate_summary(results: Dictionary):
	var total_passed = 0
	var total_failed = 0

	for test_name in results:
		if results[test_name]["status"] == "PASSED":
			total_passed += 1
		else:
			total_failed += 1

	return {"passed": total_passed, "failed": total_failed}
