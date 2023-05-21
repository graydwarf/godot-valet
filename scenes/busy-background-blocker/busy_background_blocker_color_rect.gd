extends ColorRect

@onready var _busyDoingWhatLabel = $CenterContainer/VBoxContainer/DoingWhatLabel

func _ready():
	$AnimationPlayer.play("Spin")

func SetBusyDoingWhatLabel(value):
	_busyDoingWhatLabel.text = value
