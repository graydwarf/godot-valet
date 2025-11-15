extends Control
class_name WizardPageBase

signal page_changed()
signal validation_changed(is_valid: bool)

var _selectedProjectItem = null

# Called by wizard controller to configure this page
func configure(projectItem):
	_selectedProjectItem = projectItem
	_loadPageData()

# Override in subclasses to load data from project item
func _loadPageData():
	pass

# Override in subclasses to validate page data
func validate() -> bool:
	return true

# Override in subclasses to save current page data
# Called when user clicks Next or Back
func save():
	pass
