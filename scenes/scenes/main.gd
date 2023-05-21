extends Control

func _ready():
	InitSignals()

func InitSignals():
	Signals.connect("ProjectItemClicked", ProjectItemClicked)

func ProjectItemClicked(projectItem):
	pass
