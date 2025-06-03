extends Label

func _make_custom_tooltip(tooltipText):
	var customTooltip = preload("res://scenes/custom-tooltip/custom-tooltip.tscn").instantiate()
	customTooltip.text = tooltipText
	return customTooltip
