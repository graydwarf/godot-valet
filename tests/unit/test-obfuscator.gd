extends RefCounted

var framework: TestFramework

func test_generate_obfuscated_name_creates_8_char_string():
	# Arrange
	ObfuscateHelper._usedNames.clear()

	# Act
	var name1 = ObfuscateHelper.GenerateObfuscatedName()

	# Assert
	framework.assert_equal(name1.length(), 8, "Obfuscated name should be 8 characters")

func test_generate_obfuscated_name_no_duplicates():
	# Arrange
	ObfuscateHelper._usedNames.clear()
	var names = {}

	# Act - Generate 100 names
	for i in range(100):
		var name = ObfuscateHelper.GenerateObfuscatedName()
		names[name] = true

	# Assert - All 100 should be unique
	framework.assert_equal(names.size(), 100, "All generated names should be unique")

func test_generate_obfuscated_name_only_letters():
	# Arrange
	ObfuscateHelper._usedNames.clear()
	var valid_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

	# Act
	var name = ObfuscateHelper.GenerateObfuscatedName()

	# Assert - Each character should be a letter
	for i in range(name.length()):
		var char = name[i]
		framework.assert_true(char in valid_chars, "Character %s should be a valid letter" % char)

func test_remove_comments_from_simple_line():
	# Arrange
	var content_payload = ContentPayload.new()
	content_payload.SetContent("var x = 5 # This is a comment")

	# Act
	ObfuscateHelper.RemoveCommentsFromCode(content_payload)

	# Assert
	var result = content_payload.GetContent()
	framework.assert_false("# This is a comment" in result, "Comment should be removed")
	framework.assert_true("var x = 5" in result, "Code should remain")

func test_remove_comments_preserves_hash_in_string():
	# Arrange
	var content_payload = ContentPayload.new()
	content_payload.SetContent('var url = "http://example.com#anchor" # Real comment')

	# Act
	ObfuscateHelper.RemoveCommentsFromCode(content_payload)

	# Assert
	var result = content_payload.GetContent()
	framework.assert_true("http://example.com#anchor" in result, "Hash in string should be preserved")
	framework.assert_false("Real comment" in result, "Actual comment should be removed")

func test_remove_comments_handles_multiple_lines():
	# Arrange
	var content_payload = ContentPayload.new()
	var code = """func test():
	var x = 1 # Comment 1
	var y = 2 # Comment 2
	return x + y"""
	content_payload.SetContent(code)

	# Act
	ObfuscateHelper.RemoveCommentsFromCode(content_payload)

	# Assert
	var result = content_payload.GetContent()
	framework.assert_false("Comment 1" in result, "First comment should be removed")
	framework.assert_false("Comment 2" in result, "Second comment should be removed")
	framework.assert_true("var x = 1" in result, "First var should remain")
	framework.assert_true("var y = 2" in result, "Second var should remain")

func test_remove_comments_empty_lines():
	# Arrange
	var content_payload = ContentPayload.new()
	var code = """# Full line comment
var x = 1
# Another full line comment"""
	content_payload.SetContent(code)

	# Act
	ObfuscateHelper.RemoveCommentsFromCode(content_payload)

	# Assert
	var result = content_payload.GetContent()
	framework.assert_true("var x = 1" in result, "Code should remain")
	framework.assert_false("Full line comment" in result, "Full line comments should be removed")
	framework.assert_false("Another full line comment" in result, "Full line comments should be removed")

# Triple-quote comment stripping tests

func test_remove_comments_preserves_triple_quoted_string():
	# Arrange
	var content_payload = ContentPayload.new()
	var code = 'var text = """\nThis has a # hash inside\nand more text\n"""'
	content_payload.SetContent(code)

	# Act
	ObfuscateHelper.RemoveCommentsFromCode(content_payload)

	# Assert
	var result = content_payload.GetContent()
	framework.assert_true("# hash inside" in result, "Hash inside triple-quoted string should be preserved")
	framework.assert_true('"""' in result, "Triple quotes should be preserved")

func test_remove_comments_after_triple_quoted_string():
	# Arrange
	var content_payload = ContentPayload.new()
	var code = 'var text = """\nMultiline\n"""\nvar x = 1 # Real comment'
	content_payload.SetContent(code)

	# Act
	ObfuscateHelper.RemoveCommentsFromCode(content_payload)

	# Assert
	var result = content_payload.GetContent()
	framework.assert_true("Multiline" in result, "Triple-quoted content should be preserved")
	framework.assert_true("var x = 1" in result, "Code after triple-quote should remain")
	framework.assert_false("Real comment" in result, "Comment after triple-quote block should be removed")

func test_remove_comments_single_quote_triple():
	# Arrange
	var content_payload = ContentPayload.new()
	var code = "var text = '''\nHas a # hash\n'''\nvar y = 2 # Comment"
	content_payload.SetContent(code)

	# Act
	ObfuscateHelper.RemoveCommentsFromCode(content_payload)

	# Assert
	var result = content_payload.GetContent()
	framework.assert_true("# hash" in result, "Hash inside single-quote triple string should be preserved")
	framework.assert_false("# Comment" in result, "Comment after triple-quote block should be removed")

func test_remove_comments_triple_quote_does_not_corrupt_state():
	# Arrange — This was the original bug: """ toggled in_string 3x, leaving parser in wrong state
	var content_payload = ContentPayload.new()
	var code = 'var a = """\nblock\n"""\nvar b = "normal" # comment1\nvar c = 3 # comment2'
	content_payload.SetContent(code)

	# Act
	ObfuscateHelper.RemoveCommentsFromCode(content_payload)

	# Assert — Both comments after the triple-quote block should be stripped
	var result = content_payload.GetContent()
	framework.assert_true('"normal"' in result, "Regular string after triple-quote should be preserved")
	framework.assert_false("comment1" in result, "Comment 1 after triple-quote should be removed")
	framework.assert_false("comment2" in result, "Comment 2 after triple-quote should be removed")

func test_remove_comments_escaped_quote_before_hash():
	# Arrange
	var content_payload = ContentPayload.new()
	content_payload.SetContent('var text = "She said \\"hi\\"" # comment')

	# Act
	ObfuscateHelper.RemoveCommentsFromCode(content_payload)

	# Assert
	var result = content_payload.GetContent()
	framework.assert_true('She said' in result, "String with escaped quotes should be preserved")
	framework.assert_false("# comment" in result, "Comment after string with escaped quotes should be removed")

func test_remove_comments_multiple_triple_quote_blocks():
	# Arrange
	var content_payload = ContentPayload.new()
	var code = 'var a = """\nblock1 # hash1\n"""\nvar x = 1 # real1\nvar b = """\nblock2 # hash2\n"""\nvar y = 2 # real2'
	content_payload.SetContent(code)

	# Act
	ObfuscateHelper.RemoveCommentsFromCode(content_payload)

	# Assert
	var result = content_payload.GetContent()
	framework.assert_true("# hash1" in result, "Hash in first triple-quote block preserved")
	framework.assert_true("# hash2" in result, "Hash in second triple-quote block preserved")
	framework.assert_false("# real1" in result, "Comment between blocks should be removed")
	framework.assert_false("# real2" in result, "Comment after second block should be removed")

func test_godot_reserved_keywords_preserved():
	# Arrange
	var lifecycle_methods = ObfuscateHelper._godotLifecycleMethods

	# Assert - Check key lifecycle methods are protected
	framework.assert_true("_ready" in lifecycle_methods, "_ready should be reserved")
	framework.assert_true("_process" in lifecycle_methods, "_process should be reserved")
	framework.assert_true("_physics_process" in lifecycle_methods, "_physics_process should be reserved")
	framework.assert_true("_input" in lifecycle_methods, "_input should be reserved")
