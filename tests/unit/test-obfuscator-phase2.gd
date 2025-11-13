extends RefCounted

var framework: TestFramework

# Phase 2 - Signal and Class Name Exclusion Tests

func test_signal_simple_declaration_excluded():
	# Arrange
	var code = """signal health_changed
signal mana_updated

func update_health():
	emit_signal("health_changed")
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - signal names should NOT be obfuscated
	framework.assert_false(symbol_map.has("health_changed"), "health_changed signal should NOT be obfuscated")
	framework.assert_false(symbol_map.has("mana_updated"), "mana_updated signal should NOT be obfuscated")
	framework.assert_true(symbol_map.has("update_health"), "update_health function should be obfuscated")

func test_signal_with_parameters_excluded():
	# Arrange
	var code = """signal damage_taken(amount, source)
signal item_collected(item_id, item_name, item_value)

func take_damage(amount):
	emit_signal("damage_taken", amount, self)
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - signal names should NOT be obfuscated even with parameters
	framework.assert_false(symbol_map.has("damage_taken"), "damage_taken signal should NOT be obfuscated")
	framework.assert_false(symbol_map.has("item_collected"), "item_collected signal should NOT be obfuscated")
	framework.assert_true(symbol_map.has("take_damage"), "take_damage function should be obfuscated")

func test_signal_and_function_same_name():
	# Arrange
	var code = """signal clicked

func clicked():
	print("clicked function")
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - signal takes precedence, so name should NOT be obfuscated
	framework.assert_false(symbol_map.has("clicked"), "clicked should NOT be obfuscated (signal declared)")

func test_signal_and_variable_same_name():
	# Arrange
	var code = """signal updated

var updated = false
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - signal takes precedence, so name should NOT be obfuscated
	framework.assert_false(symbol_map.has("updated"), "updated should NOT be obfuscated (signal declared)")

func test_class_name_simple_declaration_excluded():
	# Arrange
	var code = """class_name Player

var health = 100
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - class_name should NOT be obfuscated
	framework.assert_false(symbol_map.has("Player"), "Player class_name should NOT be obfuscated")
	framework.assert_true(symbol_map.has("health"), "health variable should be obfuscated")

func test_class_name_with_extends_excluded():
	# Arrange
	var code = """class_name Enemy extends CharacterBody2D

var speed = 200
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - class_name should NOT be obfuscated
	framework.assert_false(symbol_map.has("Enemy"), "Enemy class_name should NOT be obfuscated")
	framework.assert_true(symbol_map.has("speed"), "speed variable should be obfuscated")

func test_class_name_and_variable_same_name():
	# Arrange
	var code = """class_name Weapon

var Weapon = null
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - class_name takes precedence, so name should NOT be obfuscated
	framework.assert_false(symbol_map.has("Weapon"), "Weapon should NOT be obfuscated (class_name declared)")

func test_class_name_and_function_same_name():
	# Arrange
	var code = """class_name Item

func Item():
	print("Item function")
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - class_name takes precedence, so name should NOT be obfuscated
	framework.assert_false(symbol_map.has("Item"), "Item should NOT be obfuscated (class_name declared)")

func test_multiple_signals_and_class_names():
	# Arrange
	var code = """class_name GameManager

signal game_started
signal game_ended
signal player_joined(player_id)

var current_state = ""
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - signals and class_name should NOT be obfuscated
	framework.assert_false(symbol_map.has("GameManager"), "GameManager class_name should NOT be obfuscated")
	framework.assert_false(symbol_map.has("game_started"), "game_started signal should NOT be obfuscated")
	framework.assert_false(symbol_map.has("game_ended"), "game_ended signal should NOT be obfuscated")
	framework.assert_false(symbol_map.has("player_joined"), "player_joined signal should NOT be obfuscated")
	framework.assert_true(symbol_map.has("current_state"), "current_state variable should be obfuscated")

func test_signal_used_in_connect():
	# Arrange
	var code = """signal button_pressed

func _ready():
	self.connect("button_pressed", _on_button_pressed)

func _on_button_pressed():
	pass
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - signal name should NOT be obfuscated
	framework.assert_false(symbol_map.has("button_pressed"), "button_pressed signal should NOT be obfuscated")
	framework.assert_true(symbol_map.has("_on_button_pressed"), "_on_button_pressed function should be obfuscated")

func test_class_name_used_in_type_hint():
	# Arrange
	var code = """class_name Projectile

var my_projectile: Projectile = null
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - class_name should NOT be obfuscated
	framework.assert_false(symbol_map.has("Projectile"), "Projectile class_name should NOT be obfuscated")
	framework.assert_true(symbol_map.has("my_projectile"), "my_projectile variable should be obfuscated")

func test_complex_scenario_with_signals_and_class_names():
	# Arrange
	var code = """class_name InventorySystem

signal item_added(item)
signal item_removed(item)

var items = []

func add_item(item):
	items.append(item)
	emit_signal("item_added", item)

func remove_item(item):
	items.erase(item)
	emit_signal("item_removed", item)
"""
	var symbol_map = {}

	# Act
	ObfuscateHelper.BuildSymbolMap(code, symbol_map)

	# Assert - signals and class_name should NOT be obfuscated, everything else should
	framework.assert_false(symbol_map.has("InventorySystem"), "InventorySystem class_name should NOT be obfuscated")
	framework.assert_false(symbol_map.has("item_added"), "item_added signal should NOT be obfuscated")
	framework.assert_false(symbol_map.has("item_removed"), "item_removed signal should NOT be obfuscated")
	framework.assert_true(symbol_map.has("items"), "items variable should be obfuscated")
	framework.assert_true(symbol_map.has("add_item"), "add_item function should be obfuscated")
	framework.assert_true(symbol_map.has("remove_item"), "remove_item function should be obfuscated")
