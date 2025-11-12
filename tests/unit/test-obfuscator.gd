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

func test_godot_reserved_keywords_preserved():
	# Arrange
	var reserved_keywords = ObfuscateHelper._godotReservedKeywords

	# Assert - Check key lifecycle methods are protected
	framework.assert_true("_ready" in reserved_keywords, "_ready should be reserved")
	framework.assert_true("_process" in reserved_keywords, "_process should be reserved")
	framework.assert_true("_physics_process" in reserved_keywords, "_physics_process should be reserved")
	framework.assert_true("_input" in reserved_keywords, "_input should be reserved")
