extends ColorRect

@onready var _busyDoingWhatLabel = $CenterContainer/VBoxContainer/DoingWhatLabel

func _ready():
	$AnimationPlayer.play("Spin")

# Use 'call_deferred' when calling from threads
func SetBusyBackgroundLabel(value):
	_busyDoingWhatLabel.text = value
