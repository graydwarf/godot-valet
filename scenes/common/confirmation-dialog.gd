extends Control
class_name SaveConfirmationDialog

signal confirmed(choice: String)  # Emits "save", "dont_save", or "cancel"

@onready var _dialogPanel = $Overlay/CenterContainer/DialogPanel
@onready var _messageLabel = $Overlay/CenterContainer/DialogPanel/MarginContainer/VBoxContainer/MessageLabel
@onready var _saveButton = $Overlay/CenterContainer/DialogPanel/MarginContainer/VBoxContainer/ButtonContainer/SaveButton
@onready var _dontSaveButton = $Overlay/CenterContainer/DialogPanel/MarginContainer/VBoxContainer/ButtonContainer/DontSaveButton
@onready var _cancelButton = $Overlay/CenterContainer/DialogPanel/MarginContainer/VBoxContainer/ButtonContainer/CancelButton

func _ready():
	visible = false
	z_index = 500  # High z-index to appear above other UI
	_applyTheme()
	if _saveButton:
		_saveButton.pressed.connect(_onSavePressed)
	if _dontSaveButton:
		_dontSaveButton.pressed.connect(_onDontSavePressed)
	if _cancelButton:
		_cancelButton.pressed.connect(_onCancelPressed)

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

func _onSavePressed():
	confirmed.emit("save")
	hide_dialog()

func _onDontSavePressed():
	confirmed.emit("dont_save")
	hide_dialog()

func _onCancelPressed():
	confirmed.emit("cancel")
	hide_dialog()
