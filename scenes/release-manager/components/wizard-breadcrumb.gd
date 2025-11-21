extends HBoxContainer
class_name WizardBreadcrumb

signal step_clicked(step_index: int)

var _steps = ["Build", "Publish"]
var _currentStep: int = 0
var _stepButtons: Array[Button] = []

func _ready():
	_createStepButtons()

func _createStepButtons():
	# Clear any existing children
	for child in get_children():
		child.queue_free()
	_stepButtons.clear()

	for i in range(_steps.size()):
		# Add arrow separator (except before first step)
		if i > 0:
			var arrow = Label.new()
			arrow.text = "→"
			arrow.add_theme_font_size_override("font_size", 22)
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			add_child(arrow)

		# Add step button
		var button = Button.new()
		button.text = "%d. %s" % [(i + 1), _steps[i]]
		button.flat = true
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.focus_mode = Control.FOCUS_NONE  # Remove focus border
		button.add_theme_font_size_override("font_size", 22)  # 20% reduction from 28
		button.pressed.connect(_onStepPressed.bind(i))
		add_child(button)
		_stepButtons.append(button)

	_updateStepVisuals()

func update_progress(current: int):
	_currentStep = current
	_updateStepVisuals()

func _updateStepVisuals():
	for i in range(_stepButtons.size()):
		var button = _stepButtons[i]

		if i == _currentStep:
			# Current step - very bright lime green, not clickable
			button.modulate = Color(1.3, 1.0, 0.0, 1.0)  # Brighter lime green, full opacity
			button.disabled = true
			button.mouse_default_cursor_shape = Control.CURSOR_ARROW
		else:
			# All other steps - very light gray, clickable
			button.modulate = Color(0.95, 0.95, 0.95, 1.0)  # Near white, full opacity
			button.disabled = false
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _onStepPressed(step_index: int):
	# Allow jumping to any page
	print("WizardBreadcrumb._onStepPressed: step_index=", step_index)
	step_clicked.emit(step_index)
