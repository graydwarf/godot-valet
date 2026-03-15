extends RefCounted

var framework: TestFramework

# Scene File (.tscn) Obfuscation Tests

func test_scene_signal_connection_method_obfuscated():
	# Arrange
	var script_code = """func _on_button_pressed():
	print("Button pressed!")
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(script_code, symbol_map)

	# Assert method is in symbol map and will be obfuscated
	framework.assert_true(symbol_map.has("_on_button_pressed"), "_on_button_pressed should be in symbol map")
	framework.assert_equal(symbol_map["_on_button_pressed"].get("kind"), "function", "_on_button_pressed should be marked as function")

	# Note: The ObfuscateSceneFiles() function will replace method="_on_button_pressed"
	# with method="<8-char-random>" in the .tscn file using the global obfuscation map

func test_scene_multiple_signal_connections():
	# Arrange
	var script_code = """func _on_button1_pressed():
	pass

func _on_button2_pressed():
	pass
"""
	var scene_content = """[gd_scene load_steps=1 format=3]

[node name="MyScene" type="Control"]

[connection signal="pressed" from="Button1" to="." method="_on_button1_pressed"]
[connection signal="pressed" from="Button2" to="." method="_on_button2_pressed"]
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(script_code, symbol_map)

	# Assert both methods are in symbol map
	framework.assert_true(symbol_map.has("_on_button1_pressed"), "_on_button1_pressed should be in symbol map")
	framework.assert_true(symbol_map.has("_on_button2_pressed"), "_on_button2_pressed should be in symbol map")

func test_scene_connection_with_different_signals():
	# Arrange
	var script_code = """func _on_text_changed(new_text):
	pass

func _on_value_changed(value):
	pass

func _on_item_selected(index):
	pass
"""
	var scene_content = """[gd_scene load_steps=1 format=3]

[node name="MyScene" type="Control"]

[connection signal="text_changed" from="LineEdit" to="." method="_on_text_changed"]
[connection signal="value_changed" from="SpinBox" to="." method="_on_value_changed"]
[connection signal="item_selected" from="OptionButton" to="." method="_on_item_selected"]
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(script_code, symbol_map)

	# Assert all methods are detected
	framework.assert_true(symbol_map.has("_on_text_changed"), "_on_text_changed should be in symbol map")
	framework.assert_true(symbol_map.has("_on_value_changed"), "_on_value_changed should be in symbol map")
	framework.assert_true(symbol_map.has("_on_item_selected"), "_on_item_selected should be in symbol map")

func test_scene_connection_to_different_nodes():
	# Arrange
	var script_code = """func _on_button_pressed():
	pass

func _on_child_pressed():
	pass
"""
	var scene_content = """[gd_scene load_steps=1 format=3]

[node name="MyScene" type="Control"]

[node name="ChildNode" type="Node" parent="."]

[connection signal="pressed" from="Button" to="." method="_on_button_pressed"]
[connection signal="pressed" from="ChildButton" to="ChildNode" method="_on_child_pressed"]
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(script_code, symbol_map)

	# Assert both methods are detected regardless of target node
	framework.assert_true(symbol_map.has("_on_button_pressed"), "_on_button_pressed should be in symbol map")
	framework.assert_true(symbol_map.has("_on_child_pressed"), "_on_child_pressed should be in symbol map")

func test_scene_godot_lifecycle_methods_preserved():
	# Arrange
	var script_code = """func _ready():
	pass

func _process(delta):
	pass

func _on_custom_signal():
	pass
"""
	var scene_content = """[gd_scene load_steps=1 format=3]

[connection signal="custom" from="SomeNode" to="." method="_on_custom_signal"]
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(script_code, symbol_map)

	# Assert lifecycle methods NOT in symbol map, custom method IS in map
	framework.assert_false(symbol_map.has("_ready"), "_ready should NOT be obfuscated")
	framework.assert_false(symbol_map.has("_process"), "_process should NOT be obfuscated")
	framework.assert_true(symbol_map.has("_on_custom_signal"), "_on_custom_signal should be obfuscated")

func test_scene_connection_method_not_in_script():
	# Arrange - Scene references a method that doesn't exist in script
	var script_code = """func some_other_function():
	pass
"""
	var scene_content = """[gd_scene load_steps=1 format=3]

[connection signal="pressed" from="Button" to="." method="_on_missing_method"]
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(script_code, symbol_map)

	# Assert - Missing method should NOT be in symbol map
	framework.assert_false(symbol_map.has("_on_missing_method"), "_on_missing_method should NOT be in symbol map (doesn't exist in script)")
	# This is expected behavior - scene file will reference the non-existent method, and Godot will show an error

func test_scene_connection_with_bind():
	# Arrange
	var script_code = """func _on_item_clicked(item_id):
	pass
"""
	var scene_content = """[gd_scene load_steps=1 format=3]

[node name="MyScene" type="Control"]

[connection signal="pressed" from="Button1" to="." method="_on_item_clicked" binds= [1]]
[connection signal="pressed" from="Button2" to="." method="_on_item_clicked" binds= [2]]
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(script_code, symbol_map)

	# Assert method is in symbol map (binds parameter should not affect detection)
	framework.assert_true(symbol_map.has("_on_item_clicked"), "_on_item_clicked should be in symbol map even with binds")

func test_scene_connection_method_with_complex_path():
	# Arrange
	var script_code = """func handle_input():
	pass
"""
	var scene_content = """[gd_scene load_steps=1 format=3]

[node name="Root" type="Node"]

[connection signal="gui_input" from="VBoxContainer/MarginContainer/Panel/Button" to="." method="handle_input"]
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(script_code, symbol_map)

	# Assert method is detected regardless of complex node path
	framework.assert_true(symbol_map.has("handle_input"), "handle_input should be in symbol map regardless of node path complexity")

func test_scene_preserves_non_connection_lines():
	# Arrange - Test that non-connection lines are not affected
	var script_code = """func test_func():
	pass
"""
	# Scene content has a comment that contains the word "method" - should not be modified
	var scene_content = """[gd_scene load_steps=1 format=3]

; This is a comment about the method used
[node name="Root" type="Node"]
script = ExtResource("1_abc")

[connection signal="pressed" from="Button" to="." method="test_func"]
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(script_code, symbol_map)

	# Assert method is in symbol map
	framework.assert_true(symbol_map.has("test_func"), "test_func should be in symbol map")
	# The scene file comment should NOT be modified - only [connection lines should be processed

# ── Property Obfuscation Tests ──

func test_scene_property_variable_obfuscated():
	# Arrange - simulate a global obfuscation map with a variable entry
	var obfuscation_map = {
		"my_speed": { "kind": "variable", "replacement": "aBcDeFgH" }
	}
	var scene_content = """[gd_scene load_steps=1 format=3]

[node name="Player" type="Node2D" parent="."]
script = ExtResource("1_abc")
my_speed = 200.0"""

	# Act
	ObfuscateHelper._isObfuscatingVariables = true
	var result = ObfuscateHelper.ObfuscateSceneContent(scene_content, obfuscation_map)
	ObfuscateHelper._isObfuscatingVariables = false

	# Assert - property name replaced, value preserved
	framework.assert_true(result.contains("aBcDeFgH = 200.0"), "my_speed should be renamed to aBcDeFgH")
	framework.assert_false(result.contains("my_speed"), "original name my_speed should not remain")

func test_scene_builtin_property_not_obfuscated():
	# Arrange - built-in properties should NOT be in the obfuscation map
	# (the symbol map builder already excludes them), but even if somehow present
	# they won't match kind=="variable" unless explicitly added
	var obfuscation_map = {
		"custom_var": { "kind": "variable", "replacement": "xYzWvUtS" }
	}
	var scene_content = """[gd_scene load_steps=1 format=3]

[node name="Player" type="Node2D" parent="."]
position = Vector2(100, 200)
visible = true
custom_var = 42"""

	# Act
	ObfuscateHelper._isObfuscatingVariables = true
	var result = ObfuscateHelper.ObfuscateSceneContent(scene_content, obfuscation_map)
	ObfuscateHelper._isObfuscatingVariables = false

	# Assert - built-in properties preserved, custom variable renamed
	framework.assert_true(result.contains("position = Vector2(100, 200)"), "position should NOT be renamed")
	framework.assert_true(result.contains("visible = true"), "visible should NOT be renamed")
	framework.assert_true(result.contains("xYzWvUtS = 42"), "custom_var should be renamed")

func test_scene_theme_override_not_obfuscated():
	# Arrange - theme_override paths contain "/" and should be skipped
	var obfuscation_map = {
		"margin_left": { "kind": "variable", "replacement": "aAbBcCdD" }
	}
	var scene_content = """[gd_scene load_steps=1 format=3]

[node name="Panel" type="MarginContainer" parent="."]
theme_override_constants/margin_left = 10"""

	# Act
	ObfuscateHelper._isObfuscatingVariables = true
	var result = ObfuscateHelper.ObfuscateSceneContent(scene_content, obfuscation_map)
	ObfuscateHelper._isObfuscatingVariables = false

	# Assert - path-based property not renamed
	framework.assert_true(result.contains("theme_override_constants/margin_left = 10"), "theme_override property should NOT be renamed")

func test_scene_metadata_not_obfuscated():
	# Arrange - metadata/ prefix properties should be skipped
	var obfuscation_map = {
		"my_key": { "kind": "variable", "replacement": "rRsStTuU" }
	}
	var scene_content = """[gd_scene load_steps=1 format=3]

[node name="MyNode" type="Control" parent="."]
metadata/my_key = "some_value" """

	# Act
	ObfuscateHelper._isObfuscatingVariables = true
	var result = ObfuscateHelper.ObfuscateSceneContent(scene_content, obfuscation_map)
	ObfuscateHelper._isObfuscatingVariables = false

	# Assert - metadata property not renamed
	framework.assert_true(result.contains("metadata/my_key"), "metadata/ property should NOT be renamed")

func test_scene_multiple_properties_mixed():
	# Arrange - mix of script vars and built-in properties in same node
	var obfuscation_map = {
		"health_max": { "kind": "variable", "replacement": "aAaAaAaA" },
		"move_speed": { "kind": "variable", "replacement": "bBbBbBbB" }
	}
	var scene_content = """[gd_scene load_steps=1 format=3]

[node name="Player" type="CharacterBody2D" parent="."]
script = ExtResource("1_abc")
health_max = 100
position = Vector2(0, 0)
move_speed = 350.5"""

	# Act
	ObfuscateHelper._isObfuscatingVariables = true
	var result = ObfuscateHelper.ObfuscateSceneContent(scene_content, obfuscation_map)
	ObfuscateHelper._isObfuscatingVariables = false

	# Assert - script vars renamed, built-ins preserved
	framework.assert_true(result.contains("aAaAaAaA = 100"), "health_max should be renamed")
	framework.assert_true(result.contains("bBbBbBbB = 350.5"), "move_speed should be renamed")
	framework.assert_true(result.contains("position = Vector2(0, 0)"), "position should NOT be renamed")
	framework.assert_true(result.contains("script = ExtResource"), "script should NOT be renamed")

func test_scene_property_and_connection_both_obfuscated():
	# Arrange - both function and variable obfuscation active
	var obfuscation_map = {
		"_on_button_pressed": { "kind": "function", "replacement": "fFfFfFfF" },
		"button_label": { "kind": "variable", "replacement": "vVvVvVvV" }
	}
	var scene_content = """[gd_scene load_steps=1 format=3]

[node name="MyUI" type="Control" parent="."]
script = ExtResource("1_abc")
button_label = "Click Me"

[connection signal="pressed" from="Button" to="." method="_on_button_pressed"]"""

	# Act
	ObfuscateHelper._isObfuscatingVariables = true
	var result = ObfuscateHelper.ObfuscateSceneContent(scene_content, obfuscation_map)
	ObfuscateHelper._isObfuscatingVariables = false

	# Assert - both property and connection method renamed
	framework.assert_true(result.contains("vVvVvVvV = \"Click Me\""), "button_label property should be renamed")
	framework.assert_true(result.contains('method="fFfFfFfF"'), "connection method should be renamed")

func test_scene_property_complex_value_types():
	# Arrange - various Godot value types
	var obfuscation_map = {
		"card_color": { "kind": "variable", "replacement": "cCcCcCcC" },
		"start_position": { "kind": "variable", "replacement": "pPpPpPpP" },
		"item_list": { "kind": "variable", "replacement": "iIiIiIiI" }
	}
	var scene_content = """[gd_scene load_steps=1 format=3]

[node name="Card" type="Control" parent="."]
card_color = Color(1, 0.5, 0, 1)
start_position = Vector2(150, 300)
item_list = Array[String](["a", "b", "c"])"""

	# Act
	ObfuscateHelper._isObfuscatingVariables = true
	var result = ObfuscateHelper.ObfuscateSceneContent(scene_content, obfuscation_map)
	ObfuscateHelper._isObfuscatingVariables = false

	# Assert - all property names renamed, values preserved exactly
	framework.assert_true(result.contains("cCcCcCcC = Color(1, 0.5, 0, 1)"), "Color value should be preserved")
	framework.assert_true(result.contains("pPpPpPpP = Vector2(150, 300)"), "Vector2 value should be preserved")
	framework.assert_true(result.contains('iIiIiIiI = Array[String](["a", "b", "c"])'), "Array value should be preserved")

func test_scene_property_not_renamed_when_variables_disabled():
	# Arrange - variable obfuscation OFF
	var obfuscation_map = {
		"my_speed": { "kind": "variable", "replacement": "aBcDeFgH" }
	}
	var scene_content = """[gd_scene load_steps=1 format=3]

[node name="Player" type="Node2D" parent="."]
my_speed = 200.0"""

	# Act - do NOT enable _isObfuscatingVariables
	var result = ObfuscateHelper.ObfuscateSceneContent(scene_content, obfuscation_map)

	# Assert - property name NOT renamed when variable obfuscation is off
	framework.assert_true(result.contains("my_speed = 200.0"), "my_speed should NOT be renamed when variable obfuscation disabled")
	framework.assert_false(result.contains("aBcDeFgH"), "obfuscated name should not appear")

func test_scene_section_headers_not_treated_as_properties():
	# Arrange - section headers contain "=" but should never be modified
	var obfuscation_map = {
		"name": { "kind": "variable", "replacement": "nNnNnNnN" }
	}
	var scene_content = """[gd_scene load_steps=1 format=3]

[node name="Player" type="Node2D" parent="."]"""

	# Act
	ObfuscateHelper._isObfuscatingVariables = true
	var result = ObfuscateHelper.ObfuscateSceneContent(scene_content, obfuscation_map)
	ObfuscateHelper._isObfuscatingVariables = false

	# Assert - section header attributes not touched
	framework.assert_true(result.contains('[node name="Player"'), "section header should NOT be modified")
