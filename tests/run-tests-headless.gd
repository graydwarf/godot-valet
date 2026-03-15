extends SceneTree

# Headless test runner - invoke with:
#   Godot --headless --path <project> --script res://tests/run-tests-headless.gd

func _init():
	var runner = preload("res://tests/test-runner/test-runner.gd").new()
	root.add_child(runner)
	var result = await runner.run_tests_async(false)

	if result.failed > 0:
		print("\n%d test(s) FAILED" % result.failed)
	else:
		print("\nAll %d tests passed" % result.passed)

	quit(result.failed)
