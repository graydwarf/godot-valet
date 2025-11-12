extends Node

@onready var test_runner = $TestRunner
@onready var test_results_window = $TestResultsWindow

func _ready():
	print("Starting unit tests...")
	test_runner.tests_completed.connect(_on_tests_completed)
	var _results = await test_runner.run_tests_async(false)

func _on_tests_completed(results: Dictionary, passed: int, failed: int):
	print("\n=== Test Execution Complete ===")
	print("Passed: %d" % passed)
	print("Failed: %d" % failed)

	test_results_window.display_results(results, passed, failed)

	# Exit after showing results (or user closes window)
	if failed == 0:
		print("All tests passed! Exiting in 2 seconds...")
		await get_tree().create_timer(2.0).timeout
		get_tree().quit()
