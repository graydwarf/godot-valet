extends RefCounted

var framework: TestFramework

# String Preservation Tests

func test_preserve_string_literals_simple():
	# Arrange
	var payload = ContentPayload.new()
	payload.SetContent('var message = "Hello World"')

	# Act
	ObfuscateHelper.PreserveStringLiterals(payload)

	# Assert
	var content = payload.GetContent()
	framework.assert_false('"Hello World"' in content, "String literal should be replaced with token")
	framework.assert_true("__STRING_TOKEN_" in content, "Should contain token")

func test_preserve_string_literals_multiple():
	# Arrange
	var payload = ContentPayload.new()
	payload.SetContent('var a = "First"\nvar b = "Second"\nvar c = "Third"')

	# Act
	ObfuscateHelper.PreserveStringLiterals(payload)

	# Assert
	var preserved = payload.GetPreservedStrings()
	framework.assert_equal(preserved.size(), 3, "Should preserve 3 strings")
	framework.assert_true(preserved.values().has('"First"'), "Should preserve First")
	framework.assert_true(preserved.values().has('"Second"'), "Should preserve Second")
	framework.assert_true(preserved.values().has('"Third"'), "Should preserve Third")

func test_preserve_string_literals_with_escaped_quotes():
	# Arrange
	var payload = ContentPayload.new()
	payload.SetContent('var text = "He said \\"Hello\\""')

	# Act
	ObfuscateHelper.PreserveStringLiterals(payload)

	# Assert
	var preserved = payload.GetPreservedStrings()
	framework.assert_equal(preserved.size(), 1, "Should preserve string with escaped quotes")

func test_restore_string_literals():
	# Arrange
	var payload = ContentPayload.new()
	payload.SetContent('var message = "Test"')
	ObfuscateHelper.PreserveStringLiterals(payload)

	# Act
	ObfuscateHelper.RestoreStringLiterals(payload)

	# Assert
	var content = payload.GetContent()
	framework.assert_true('"Test"' in content, "String should be restored")
	framework.assert_false("__STRING_TOKEN_" in content, "Tokens should be removed")

func test_preserve_and_restore_roundtrip():
	# Arrange
	var original = 'var url = "http://example.com"\nvar path = "/api/data"'
	var payload = ContentPayload.new()
	payload.SetContent(original)

	# Act
	ObfuscateHelper.PreserveStringLiterals(payload)
	ObfuscateHelper.RestoreStringLiterals(payload)

	# Assert
	framework.assert_equal(payload.GetContent(), original, "Content should match after roundtrip")

func test_preserve_special_strings_has_method():
	# Arrange
	var payload = ContentPayload.new()
	payload.SetContent('if player.has_method("jump"):\n\tplayer.jump()')

	# Act
	ObfuscateHelper.PreserveSpecialStrings(payload)

	# Assert
	var content = payload.GetContent()
	framework.assert_false('has_method("jump")' in content, "has_method pattern should be replaced")
	framework.assert_true("__SPECIAL_STRING_TOKEN_" in content, "Should contain special token")

func test_preserve_special_strings_multiple_has_method():
	# Arrange
	var payload = ContentPayload.new()
	payload.SetContent('has_method("jump")\nhas_method("run")\nhas_method("attack")')

	# Act
	ObfuscateHelper.PreserveSpecialStrings(payload)

	# Assert
	var preserved = payload.GetPreservedSpecialStrings()
	framework.assert_equal(preserved.size(), 3, "Should preserve 3 has_method patterns")

func test_restore_special_strings():
	# Arrange
	var payload = ContentPayload.new()
	payload.SetContent('if obj.has_method("test"):\n\tpass')
	ObfuscateHelper.PreserveSpecialStrings(payload)

	# Act
	ObfuscateHelper.RestoreSpecialStrings(payload)

	# Assert
	var content = payload.GetContent()
	framework.assert_true('has_method("test")' in content, "has_method should be restored")
	framework.assert_false("__SPECIAL_STRING_TOKEN_" in content, "Special tokens should be removed")

func test_preserve_strings_with_hash():
	# Arrange
	var payload = ContentPayload.new()
	payload.SetContent('var url = "http://example.com#anchor"')

	# Act
	ObfuscateHelper.PreserveStringLiterals(payload)

	# Assert
	var preserved = payload.GetPreservedStrings()
	framework.assert_equal(preserved.size(), 1, "Should preserve string with hash")
	framework.assert_true(preserved.values().has('"http://example.com#anchor"'), "Hash should be preserved in string")

func test_preserve_empty_string():
	# Arrange
	var payload = ContentPayload.new()
	payload.SetContent('var empty = ""')

	# Act
	ObfuscateHelper.PreserveStringLiterals(payload)

	# Assert
	var preserved = payload.GetPreservedStrings()
	framework.assert_equal(preserved.size(), 1, "Should preserve empty string")
	framework.assert_true(preserved.values().has('""'), "Should preserve empty string literal")

func test_preserve_string_with_special_chars():
	# Arrange
	var payload = ContentPayload.new()
	payload.SetContent('var text = "Line1\\nLine2\\tTabbed"')

	# Act
	ObfuscateHelper.PreserveStringLiterals(payload)
	ObfuscateHelper.RestoreStringLiterals(payload)

	# Assert
	var content = payload.GetContent()
	framework.assert_true('"Line1\\nLine2\\tTabbed"' in content, "Should preserve escape sequences")
