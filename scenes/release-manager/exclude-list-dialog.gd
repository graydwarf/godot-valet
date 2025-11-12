extends Window

signal lists_saved(function_list: String, variable_list: String)

@onready var function_text_edit = %FunctionTextEdit
@onready var variable_text_edit = %VariableTextEdit
@onready var save_button = %SaveButton
@onready var cancel_button = %CancelButton

func _ready():
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	close_requested.connect(_on_cancel_pressed)

func load_lists(function_list: String, variable_list: String):
	function_text_edit.text = function_list
	variable_text_edit.text = variable_list

func _on_save_pressed():
	lists_saved.emit(function_text_edit.text, variable_text_edit.text)
	hide()

func _on_cancel_pressed():
	hide()
