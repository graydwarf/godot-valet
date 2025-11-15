extends Control
class_name SaveConfirmationDialog

signal confirmed(choice: String)  # Emits "save", "dont_save", or "cancel"

@onready var _overlay = $Overlay
@onready var _dialogPanel = $Overlay/CenterContainer/DialogPanel
@onready var _messageLabel = $Overlay/CenterContainer/DialogPanel/MarginContainer/VBoxContainer/MessageLabel
@onready var _saveButton = $Overlay/CenterContainer/DialogPanel/MarginContainer/VBoxContainer/ButtonContainer/SaveButton
@onready var _dontSaveButton = $Overlay/CenterContainer/DialogPanel/MarginContainer/VBoxContainer/ButtonContainer/DontSaveButton
@onready var _cancelButton = $Overlay/CenterContainer/DialogPanel/MarginContainer/VBoxContainer/ButtonContainer/CancelButton

func _ready():
	visible = false
	if _saveButton:
		_saveButton.pressed.connect(_onSavePressed)
	if _dontSaveButton:
		_dontSaveButton.pressed.connect(_onDontSavePressed)
	if _cancelButton:
		_cancelButton.pressed.connect(_onCancelPressed)

func show_dialog(message: String):
	_messageLabel.text = message
	visible = true
	move_to_front()

func hide_dialog():
	visible = false

func _onSavePressed():
	confirmed.emit("save")
	hide_dialog()

func _onDontSavePressed():
	confirmed.emit("dont_save")
	hide_dialog()

func _onCancelPressed():
	confirmed.emit("cancel")
	hide_dialog()
