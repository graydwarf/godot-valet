extends Control

signal accepted

func _on_accept_button_pressed():
	App.SetDisclaimerAccepted(true)
	accepted.emit()
	queue_free()
