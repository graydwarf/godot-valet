extends Panel

# Wizard controller for Release Manager

@onready var _projectCard = %ProjectCard
@onready var _breadcrumb = %WizardBreadcrumb
@onready var _pagesContainer = %PagesContainer
@onready var _exitButton = %ExitButton
@onready var _backButton = %BackButton
@onready var _nextButton = %NextButton

var _currentPage: int = 0
var _pages: Array[WizardPageBase] = []
var _selectedProjectItem = null

func _ready():
	LoadTheme()
	LoadBackgroundColor()
	InitSignals()
	_loadPages()

func InitSignals():
	Signals.connect("SelectedProjecItemUpdated", SelectedProjecItemUpdated)

# When ReleaseManager saves, it triggers a reset of all
# project items on ProjectManager page which invalidates
# our reference to _selectedProjectItem so we rely on
# ProjectManager to give us an update when that happens.
func SelectedProjecItemUpdated(selectedProjectItem):
	_selectedProjectItem = selectedProjectItem

func LoadBackgroundColor():
	var style_box = theme.get_stylebox("panel", "Panel") as StyleBoxFlat
	if style_box:
		style_box.bg_color = App.GetBackgroundColor()

func LoadTheme():
	theme = load(App.GetThemePath())

func ConfigureReleaseManagementForm(selectedProjectItem):
	_selectedProjectItem = selectedProjectItem

	# Configure project card
	_projectCard.configure(selectedProjectItem)

	# Configure all pages
	for page in _pages:
		page.configure(selectedProjectItem)

	# Show first page
	_showPage(0)

func _loadPages():
	# Hide ALL children first (including placeholder pages)
	for child in _pagesContainer.get_children():
		child.visible = false

	# Get page nodes from container
	for child in _pagesContainer.get_children():
		if child is WizardPageBase:
			_pages.append(child)

			# Connect Page 1 version change signal to card
			if child.has_signal("version_changed"):
				child.version_changed.connect(_projectCard.update_version_comparison)

func _showPage(pageIndex: int):
	# Validate and clamp page index
	if pageIndex < 0 || pageIndex >= _pages.size():
		return

	# Hide all pages
	for i in range(_pages.size()):
		_pages[i].visible = (i == pageIndex)

	_currentPage = pageIndex

	# Update breadcrumb
	_breadcrumb.update_progress(_currentPage)

	# Update navigation buttons
	_updateNavigationButtons()

func _updateNavigationButtons():
	# Exit always visible
	_exitButton.visible = true

	# Back visible if not on first page
	_backButton.visible = (_currentPage > 0)

	# Next visible on all pages
	_nextButton.visible = true

	# Change Next to Finish on last page
	if _currentPage == _pages.size() - 1:
		_nextButton.text = "Finish"
	else:
		_nextButton.text = "Next →"

func _onBackPressed():
	if _currentPage > 0:
		# Save current page before navigating
		_pages[_currentPage].save()
		_projectCard.show_saved_indicator()
		_showPage(_currentPage - 1)

func _onNextPressed():
	# Validate current page
	if !_pages[_currentPage].validate():
		# Show validation error
		# TODO: Add validation error display
		return

	# Save current page
	_pages[_currentPage].save()
	_projectCard.show_saved_indicator()

	# If on last page, finish
	if _currentPage == _pages.size() - 1:
		_onFinishPressed()
	else:
		_showPage(_currentPage + 1)

func _onFinishPressed():
	# Close wizard
	queue_free()

func _onExitPressed():
	# TODO: Prompt if unsaved changes
	queue_free()

func _onBreadcrumbStepClicked(step_index: int):
	# Save current page before navigating
	_pages[_currentPage].save()
	_projectCard.show_saved_indicator()
	_showPage(step_index)
