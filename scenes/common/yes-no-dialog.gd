extends Control
class_name YesNoDialog

signal confirmed(choice: String)  # Emits "yes", "no", or custom button text

@onready var _dialogPanel = $Overlay/CenterContainer/DialogPanel
@onready var _messageLabel = $Overlay/CenterContainer/DialogPanel/MarginContainer/VBoxContainer/MessageLabel
@onready var _buttonContainer = $Overlay/CenterContainer/DialogPanel/MarginContainer/VBoxContainer/ButtonContainer
@onready var _yesButton = $Overlay/CenterContainer/DialogPanel/MarginContainer/VBoxContainer/ButtonContainer/YesButton
@onready var _noButton = $Overlay/CenterContainer/DialogPanel/MarginContainer/VBoxContainer/ButtonContainer/NoButton

var _customButtons: Array[Button] = []

func _ready():
	visible = false
	z_index = 500  # High z-index to appear above other UI (but below export blocker at 1000)
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
	_clearCustomButtons()
	_yesButton.visible = true
	_noButton.visible = true
	_messageLabel.text = message
	visible = true
	move_to_front()

# Show dialog with custom buttons (array of button labels)
# First button is primary action, last is cancel
func show_dialog_with_buttons(message: String, buttonLabels: Array[String]):
	_clearCustomButtons()
	_yesButton.visible = false
	_noButton.visible = false

	# Create custom buttons
	for i in range(buttonLabels.size()):
		var label = buttonLabels[i]
		var button = Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(100, 31)

		# Make last button (cancel) look different
		if i == buttonLabels.size() - 1:
			button.modulate = Color(1.0, 0.8, 0.8, 1.0)  # Slight red tint for cancel

		button.pressed.connect(_onCustomButtonPressed.bind(label))
		_buttonContainer.add_child(button)
		_customButtons.append(button)

	_messageLabel.text = message
	visible = true
	move_to_front()

func _clearCustomButtons():
	for button in _customButtons:
		button.queue_free()
	_customButtons.clear()

func hide_dialog():
	visible = false

func _onYesPressed():
	confirmed.emit("yes")
	hide_dialog()

func _onNoPressed():
	confirmed.emit("no")
	hide_dialog()

func _onCustomButtonPressed(buttonLabel: String):
	confirmed.emit(buttonLabel)
	hide_dialog()
