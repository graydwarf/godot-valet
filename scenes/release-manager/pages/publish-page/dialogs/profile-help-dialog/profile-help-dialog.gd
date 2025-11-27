extends CanvasLayer

signal closed()

@onready var _dialogCard = %DialogCard
@onready var _closeButton = %CloseButton
@onready var _dimmer = $Dimmer

func _ready():
	visible = false

	_closeButton.pressed.connect(_onClosePressed)
	_dimmer.gui_input.connect(_onDimmerInput)
	_applyCardStyling()

func _applyCardStyling():
	# Style the dialog card
	var panelTheme = Theme.new()
	var styleBox = StyleBoxFlat.new()
	styleBox.bg_color = _getAdjustedBackgroundColor(-0.08)
	styleBox.border_color = Color(0.6, 0.6, 0.6)
	styleBox.border_width_left = 1
	styleBox.border_width_top = 1
	styleBox.border_width_right = 1
	styleBox.border_width_bottom = 1
	styleBox.corner_radius_top_left = 6
	styleBox.corner_radius_top_right = 6
	styleBox.corner_radius_bottom_right = 6
	styleBox.corner_radius_bottom_left = 6
	panelTheme.set_stylebox("panel", "PanelContainer", styleBox)
	_dialogCard.theme = panelTheme

	# Style the header with bottom border
	var headerContainer = _dialogCard.find_child("CardHeader", true, false)
	if headerContainer:
		var headerTheme = Theme.new()
		var headerStyleBox = StyleBoxFlat.new()
		headerStyleBox.bg_color = Color(0, 0, 0, 0)
		headerStyleBox.border_color = Color(0.6, 0.6, 0.6)
		headerStyleBox.border_width_left = 0
		headerStyleBox.border_width_top = 0
		headerStyleBox.border_width_right = 0
		headerStyleBox.border_width_bottom = 1
		headerTheme.set_stylebox("panel", "PanelContainer", headerStyleBox)
		headerContainer.theme = headerTheme

func _getAdjustedBackgroundColor(amount: float) -> Color:
	var colorToSubtract = Color(amount, amount, amount, 0.0)
	var baseColor = App.GetBackgroundColor()
	return Color(
		max(baseColor.r + colorToSubtract.r, 0),
		max(baseColor.g + colorToSubtract.g, 0),
		max(baseColor.b + colorToSubtract.b, 0),
		baseColor.a
	)

func showDialog():
	visible = true

func _onClosePressed():
	visible = false
	closed.emit()

func _onDimmerInput(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		_onClosePressed()
