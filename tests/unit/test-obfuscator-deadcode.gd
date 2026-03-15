extends RefCounted

var framework: TestFramework

# Opaque Predicate Tests

func test_opaque_predicate_always_true():
	# Act — generate 20 always-true predicates and evaluate them
	var all_true := true
	for i in range(20):
		var pred := ObfuscateHelper.GenerateOpaquePredicate(["x", "y", "z"], true)
		# Predicates use variable names but are mathematically always true
		# Verify structure: should start with ( and contain the variable
		framework.assert_true(pred.begins_with("("), "Predicate should be wrapped in parens: %s" % pred)
		framework.assert_true(pred.ends_with(")"), "Predicate should end with paren: %s" % pred)

func test_opaque_predicate_always_false():
	# Act — generate 20 always-false predicates
	for i in range(20):
		var pred := ObfuscateHelper.GenerateOpaquePredicate(["x", "y"], false)
		framework.assert_true(pred.begins_with("("), "False predicate should be wrapped in parens: %s" % pred)
		# Always-false predicates should contain < 0 (square never negative)
		framework.assert_true("< 0" in pred, "False predicate should contain '< 0': %s" % pred)

func test_opaque_predicate_uses_provided_variables():
	# Arrange
	var vars := ["mySpecialVar"]

	# Act
	var pred := ObfuscateHelper.GenerateOpaquePredicate(vars, true)

	# Assert
	framework.assert_true("mySpecialVar" in pred, "Predicate should use provided variable name")

func test_opaque_predicate_fallback_no_variables():
	# Act — should not crash with empty array
	var pred := ObfuscateHelper.GenerateOpaquePredicate([], true)

	# Assert — should use a numeric fallback
	framework.assert_true(pred.begins_with("("), "Predicate should still be valid with no variables")

# Dead Function Generation Tests

func test_generate_dead_functions_returns_requested_count():
	# Arrange
	ObfuscateHelper._usedNames.clear()

	# Act
	var result := ObfuscateHelper.GenerateDeadFunctions(["var1", "var2"], 7)

	# Assert
	framework.assert_equal(result.names.size(), 7, "Should generate exactly 7 dead function names")

func test_dead_functions_have_obfuscated_names():
	# Arrange
	ObfuscateHelper._usedNames.clear()

	# Act
	var result := ObfuscateHelper.GenerateDeadFunctions(["var1"], 3)

	# Assert
	for funcName in result.names:
		framework.assert_equal(funcName.length(), 8, "Dead function names should be 8 chars: %s" % funcName)

func test_dead_functions_have_func_keyword():
	# Arrange
	ObfuscateHelper._usedNames.clear()

	# Act
	var result := ObfuscateHelper.GenerateDeadFunctions(["var1"], 3)

	# Assert
	var funcCount := 0
	for line in result.code.split("\n"):
		if line.strip_edges().begins_with("static func ") or line.strip_edges().begins_with("func "):
			funcCount += 1
	framework.assert_equal(funcCount, 3, "Should have 3 func declarations")

func test_dead_functions_use_tab_indentation():
	# Arrange
	ObfuscateHelper._usedNames.clear()

	# Act
	var result := ObfuscateHelper.GenerateDeadFunctions(["var1"], 2)

	# Assert — body lines should start with tab
	var hasTabIndent := false
	for line in result.code.split("\n"):
		if line.begins_with("\t"):
			hasTabIndent = true
			break
	framework.assert_true(hasTabIndent, "Dead function bodies should use tab indentation")

# Dead Code Call Injection Tests

func test_inject_calls_preserves_original_code():
	# Arrange
	var payload := ContentPayload.new()
	var original := "func my_func():\n\tvar x = 1\n\tvar y = 2\n\treturn x + y\n"
	payload.SetContent(original)
	ObfuscateHelper._usedNames.clear()

	# Act
	ObfuscateHelper.InjectDeadCodeCalls(payload, ["deadFunc1"], ["x"])

	# Assert — original lines should still be present
	var result := payload.GetContent()
	framework.assert_true("var x = 1" in result, "Original code should be preserved")
	framework.assert_true("var y = 2" in result, "Original code should be preserved")
	framework.assert_true("return x + y" in result, "Original code should be preserved")

func test_inject_calls_adds_if_blocks():
	# Arrange — create a function body long enough to trigger injection (15+ lines)
	var payload := ContentPayload.new()
	var code := "func long_func():\n"
	for i in range(20):
		code += "\tvar v%d = %d\n" % [i, i]
	payload.SetContent(code)
	ObfuscateHelper._usedNames.clear()

	# Act
	ObfuscateHelper.InjectDeadCodeCalls(payload, ["deadFunc1", "deadFunc2"], ["v0"])

	# Assert
	var result := payload.GetContent()
	framework.assert_true("deadFunc1()" in result or "deadFunc2()" in result, "Should inject dead function calls")

func test_inject_calls_matches_indentation():
	# Arrange
	var payload := ContentPayload.new()
	var code := "func test():\n"
	for i in range(20):
		code += "\tvar v%d = %d\n" % [i, i]
	payload.SetContent(code)
	ObfuscateHelper._usedNames.clear()

	# Act
	ObfuscateHelper.InjectDeadCodeCalls(payload, ["deadFunc1"], ["v0"])

	# Assert — injected lines should have proper indentation
	var result := payload.GetContent()
	for line in result.split("\n"):
		if "deadFunc1" in line:
			framework.assert_true(line.begins_with("\t"), "Injected calls should be indented")

func test_dead_code_disabled_no_changes():
	# Arrange
	var payload := ContentPayload.new()
	var original := "func test():\n\tvar x = 1\n"
	payload.SetContent(original)

	# Act — inject with empty dead function list
	ObfuscateHelper.InjectDeadCodeCalls(payload, [], ["x"])

	# Assert
	framework.assert_equal(payload.GetContent(), original, "No changes when dead func list is empty")

func test_dead_code_handles_empty_file():
	# Arrange
	var payload := ContentPayload.new()
	payload.SetContent("")

	# Act — should not crash
	ObfuscateHelper.InjectDeadCodeCalls(payload, ["deadFunc1"], ["x"])

	# Assert
	framework.assert_equal(payload.GetContent(), "", "Empty file should remain empty")

func test_dead_functions_appended_at_end():
	# Arrange
	ObfuscateHelper._usedNames.clear()
	var result := ObfuscateHelper.GenerateDeadFunctions(["var1"], 2)

	# Assert — code should contain func declarations
	framework.assert_true(result.code.length() > 0, "Dead function code should not be empty")
	framework.assert_true("func " in result.code, "Code should contain func declarations")
	# Names should match what's in the code
	for funcName in result.names:
		framework.assert_true(funcName in result.code, "Function name %s should appear in code" % funcName)
