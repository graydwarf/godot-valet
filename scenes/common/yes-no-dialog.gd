extends Control
class_name YesNoDialog

signal confirmed(choice: String)  # Emits "yes" or "no"

@onready var _overlay = $Overlay
@onready var _dialogPanel = $Overlay/CenterContainer/DialogPanel
@onready var _messageLabel = $Overlay/CenterContainer/DialogPanel/MarginContainer/VBoxContainer/MessageLabel
@onready var _yesButton = $Overlay/CenterContainer/DialogPanel/MarginContainer/VBoxContainer/ButtonContainer/YesButton
@onready var _noButton = $Overlay/CenterContainer/DialogPanel/MarginContainer/VBoxContainer/ButtonContainer/NoButton

func _ready():
	visible = false
	if _yesButton:
		_yesButton.pressed.connect(_onYesPressed)
	if _noButton:
		_noButton.pressed.connect(_onNoPressed)

func show_dialog(message: String):
	_messageLabel.text = message
	visible = true
	move_to_front()

func hide_dialog():
	visible = false

func _onYesPressed():
	confirmed.emit("yes")
	hide_dialog()

func _onNoPressed():
	confirmed.emit("no")
	hide_dialog()
