extends Control

func _ready():
	AnimateBusy()

func AnimateBusy():
	var tween = create_tween().set_loops()
	tween.tween_property(%TextureRect, "rotation", 360, 300.0)
