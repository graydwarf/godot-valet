extends VBoxContainer
class_name ProjectCard

@onready var _projectHeader: ProjectHeader = %ProjectHeader

var _selectedProjectItem = null

# Called by wizard to update card with project info
func configure(projectItem):
	_selectedProjectItem = projectItem
	_projectHeader.configure(projectItem)

# Show brief "Saved" indicator
func show_saved_indicator():
	_projectHeader.show_saved_indicator()
