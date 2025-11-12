extends Window

@onready var summary_label: Label = $VBoxContainer/SummaryLabel
@onready var results_text: RichTextLabel = $VBoxContainer/ScrollContainer/ResultsText
@onready var continue_button: Button = $VBoxContainer/ButtonContainer/ContinueButton
@onready var exit_button: Button = $VBoxContainer/ButtonContainer/ExitButton

func _ready():
	continue_button.pressed.connect(_on_continue_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	close_requested.connect(_on_continue_pressed)

func display_results(test_results: Dictionary, total_passed: int, total_failed: int):
	summary_label.text = "Summary: %d tests run | %d passed | %d failed" % [
		total_passed + total_failed, total_passed, total_failed
	]

	var output = "[b]Test Execution Results[/b]\n\n"

	if total_failed > 0:
		output += "[color=red]⚠️ FAILURES DETECTED[/color]\n\n"

	for test_name in test_results:
		var result = test_results[test_name]
		if result["status"] == "PASSED":
			output += "[color=green]✅[/color] %s\n" % test_name
		else:
			output += "[color=red]❌[/color] %s\n" % test_name
			output += "    [color=yellow]Error: %s[/color]\n" % result["error"]

	results_text.text = output

	if total_failed == 0:
		hide()
	else:
		popup_centered()

func _on_continue_pressed():
	hide()

func _on_exit_pressed():
	get_tree().quit()
