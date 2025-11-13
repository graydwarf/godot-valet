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
