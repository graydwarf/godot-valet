extends RefCounted

var framework: TestFramework

func setup():
	# Ensure a consistent encryption key for tests
	ObfuscateHelper._encryptionKey = ObfuscateHelper.GenerateEncryptionKey()
	ObfuscateHelper._isEncryptingStrings = true
	ObfuscateHelper._usedNames.clear()

# Core Encryption Tests

func test_encrypt_simple_string():
	# Arrange
	var payload := ContentPayload.new()
	payload.SetContent('var msg = "Hello World"')

	# Act
	ObfuscateHelper.EncryptStringLiterals(payload)

	# Assert
	var result := payload.GetContent()
	framework.assert_false('"Hello World"' in result, "Original string should be replaced")
	framework.assert_true("__d(PackedByteArray(" in result, "Should contain encrypted call")

func test_decrypt_roundtrip():
	# Arrange — manually encrypt and decrypt
	var original := "Hello World"
	var key := ObfuscateHelper._encryptionKey

	# Act
	var encrypted := ObfuscateHelper._xor_encrypt(original, key)
	# Decrypt: XOR again with same key
	var decrypted_bytes := PackedByteArray()
	decrypted_bytes.resize(encrypted.size())
	for i in range(encrypted.size()):
		decrypted_bytes[i] = encrypted[i] ^ key[i % key.size()]
	var decrypted := decrypted_bytes.get_string_from_utf8()

	# Assert
	framework.assert_equal(decrypted, original, "XOR decrypt should recover original string")

func test_skip_empty_string():
	# Arrange
	var payload := ContentPayload.new()
	payload.SetContent('var empty = ""')

	# Act
	ObfuscateHelper.EncryptStringLiterals(payload)

	# Assert
	var result := payload.GetContent()
	framework.assert_true('""' in result, "Empty string should not be encrypted")

func test_skip_resource_path():
	# Arrange
	var payload := ContentPayload.new()
	payload.SetContent('var scene = "res://scenes/main.tscn"')

	# Act
	ObfuscateHelper.EncryptStringLiterals(payload)

	# Assert
	var result := payload.GetContent()
	framework.assert_true('"res://scenes/main.tscn"' in result, "Resource paths should not be encrypted")

func test_skip_user_path():
	# Arrange
	var payload := ContentPayload.new()
	payload.SetContent('var save = "user://saves/game.dat"')

	# Act
	ObfuscateHelper.EncryptStringLiterals(payload)

	# Assert
	var result := payload.GetContent()
	framework.assert_true('"user://saves/game.dat"' in result, "User paths should not be encrypted")

func test_skip_const_line():
	# Arrange
	var payload := ContentPayload.new()
	payload.SetContent('const NAME = "MyGame"')

	# Act
	ObfuscateHelper.EncryptStringLiterals(payload)

	# Assert
	var result := payload.GetContent()
	framework.assert_true('"MyGame"' in result, "Const strings should not be encrypted")

func test_skip_preload_argument():
	# Arrange
	var payload := ContentPayload.new()
	payload.SetContent('var scn = preload("res://main.tscn")')

	# Act
	ObfuscateHelper.EncryptStringLiterals(payload)

	# Assert
	var result := payload.GetContent()
	framework.assert_true('"res://main.tscn"' in result, "Preload paths should not be encrypted")

func test_skip_annotation():
	# Arrange
	var payload := ContentPayload.new()
	payload.SetContent('@export_group("Movement")')

	# Act
	ObfuscateHelper.EncryptStringLiterals(payload)

	# Assert
	var result := payload.GetContent()
	framework.assert_true('"Movement"' in result, "Annotation strings should not be encrypted")

func test_skip_default_parameter():
	# Arrange
	var payload := ContentPayload.new()
	payload.SetContent('func greet(name = "World"):\n\tprint(name)')

	# Act
	ObfuscateHelper.EncryptStringLiterals(payload)

	# Assert
	var result := payload.GetContent()
	framework.assert_true('"World"' in result, "Default parameter strings should not be encrypted")

func test_encrypt_multiple_strings():
	# Arrange
	var payload := ContentPayload.new()
	payload.SetContent('var aa = "First"\nvar bb = "Second"\nvar cc = "Third"')

	# Act
	ObfuscateHelper.EncryptStringLiterals(payload)

	# Assert
	var result := payload.GetContent()
	framework.assert_false('"First"' in result, "First string should be encrypted")
	framework.assert_false('"Second"' in result, "Second string should be encrypted")
	framework.assert_false('"Third"' in result, "Third string should be encrypted")

func test_helper_injected_after_extends():
	# Arrange
	var payload := ContentPayload.new()
	payload.SetContent('extends Node\n\nvar msg = "Hello World"')

	# Act
	ObfuscateHelper.EncryptStringLiterals(payload)

	# Assert
	var result := payload.GetContent()
	var extendsPos := result.find("extends Node")
	var helperPos := result.find("static func __d")
	var msgPos := result.find("var msg")
	framework.assert_true(helperPos > extendsPos, "Helper should be after extends")
	framework.assert_true(helperPos < msgPos, "Helper should be before code")

func test_helper_injected_once():
	# Arrange
	var payload := ContentPayload.new()
	payload.SetContent('var aa = "First"\nvar bb = "Second"')

	# Act
	ObfuscateHelper.EncryptStringLiterals(payload)

	# Assert
	var result := payload.GetContent()
	var firstPos := result.find("static func __d")
	var secondPos := result.find("static func __d", firstPos + 1)
	framework.assert_true(firstPos >= 0, "Helper should be injected")
	framework.assert_equal(secondPos, -1, "Helper should only be injected once")

func test_single_char_string_skipped():
	# Arrange
	var payload := ContentPayload.new()
	payload.SetContent('var ch = "x"')

	# Act
	ObfuscateHelper.EncryptStringLiterals(payload)

	# Assert
	var result := payload.GetContent()
	framework.assert_true('"x"' in result, "Single-char strings should not be encrypted")

func test_key_generation():
	# Act
	var key := ObfuscateHelper.GenerateEncryptionKey(32)

	# Assert
	framework.assert_equal(key.size(), 32, "Key should be 32 bytes")

func test_skip_stringname_literal():
	# Arrange
	var payload := ContentPayload.new()
	payload.SetContent('var sn = &"my_signal"')

	# Act
	ObfuscateHelper.EncryptStringLiterals(payload)

	# Assert
	var result := payload.GetContent()
	framework.assert_true('"my_signal"' in result, "StringName literals should not be encrypted")
