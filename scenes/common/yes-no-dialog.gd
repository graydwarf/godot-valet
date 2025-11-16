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
	_applyTheme()
	if _yesButton:
		_yesButton.pressed.connect(_onYesPressed)
	if _noButton:
		_noButton.pressed.connect(_onNoPressed)

func _applyTheme():
	# Apply the app's background color theme to the dialog panel
	var customTheme = Theme.new()
	var styleBox = StyleBoxFlat.new()
	styleBox.bg_color = _getAdjustedBackgroundColor(-0.08)
	styleBox.border_color = Color(0.6, 0.6, 0.6)
	styleBox.border_width_left = 2
	styleBox.border_width_top = 2
	styleBox.border_width_right = 2
	styleBox.border_width_bottom = 2
	styleBox.corner_radius_top_left = 6
	styleBox.corner_radius_top_right = 6
	styleBox.corner_radius_bottom_right = 6
	styleBox.corner_radius_bottom_left = 6

	customTheme.set_stylebox("panel", "Panel", styleBox)
	_dialogPanel.theme = customTheme

func _getAdjustedBackgroundColor(amount: float) -> Color:
	var colorToSubtract = Color(amount, amount, amount, 0.0)
	var baseColor = App.GetBackgroundColor()
	return Color(
		max(baseColor.r + colorToSubtract.r, 0),
		max(baseColor.g + colorToSubtract.g, 0),
		max(baseColor.b + colorToSubtract.b, 0),
		baseColor.a
	)

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
