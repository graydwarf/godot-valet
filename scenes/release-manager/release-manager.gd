extends Panel

# Wizard controller for Release Manager

@onready var _projectCard = %ProjectCard
@onready var _breadcrumb = %WizardBreadcrumb
@onready var _pagesContainer = %PagesContainer
@onready var _exitButton = %ExitButton
@onready var _backButton = %BackButton
@onready var _nextButton = %NextButton
@onready var _confirmationDialog = %ConfirmationDialog

var _currentPage: int = 0
var _pages: Array[WizardPageBase] = []
var _selectedProjectItem = null
var _hasUnsavedChanges: bool = false
var _isClosingApp: bool = false  # Track if we're closing the app vs just the wizard

func _ready():
	LoadTheme()
	LoadBackgroundColor()
	InitSignals()
	_loadPages()

	# Disable auto-quit so we can handle unsaved changes
	get_tree().set_auto_accept_quit(false)

	# Connect to window close request to handle unsaved changes
	var window = get_window()
	if window and not window.close_requested.is_connected(_onWindowCloseRequested):
		window.close_requested.connect(_onWindowCloseRequested)

func _exit_tree():
	# Re-enable auto-quit when wizard closes
	get_tree().set_auto_accept_quit(true)

	# Disconnect from window close signal when wizard is closed
	var window = get_window()
	if window and window.close_requested.is_connected(_onWindowCloseRequested):
		window.close_requested.disconnect(_onWindowCloseRequested)

func InitSignals():
	Signals.connect("SelectedProjecItemUpdated", SelectedProjecItemUpdated)

# When ReleaseManager saves, it triggers a reset of all
# project items on ProjectManager page which invalidates
# our reference to _selectedProjectItem so we rely on
# ProjectManager to give us an update when that happens.
func SelectedProjecItemUpdated(selectedProjectItem):
	_selectedProjectItem = selectedProjectItem

	# Update all pages with the new project item reference
	for page in _pages:
		page._selectedProjectItem = selectedProjectItem

	# Update project card with new reference
	_projectCard._selectedProjectItem = selectedProjectItem

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

	# Clear dirty flag after initial configuration
	# (loading existing data shouldn't count as modifications)
	_hasUnsavedChanges = false

func _loadPages():
	# Hide ALL children first (including placeholder pages)
	for child in _pagesContainer.get_children():
		child.visible = false

	# Get page nodes from container
	for child in _pagesContainer.get_children():
		if child is WizardPageBase:
			_pages.append(child)

			# Connect version change signal to card (from Build page)
			if child.has_signal("version_changed"):
				child.version_changed.connect(_projectCard.update_version_comparison)

			# Connect page_modified signal to track dirty state
			if child.has_signal("page_modified"):
				child.page_modified.connect(_onPageModified)

func _onPageModified():
	# Mark as dirty when any page input is modified
	_hasUnsavedChanges = true

func _showPage(pageIndex: int):
	# Validate and clamp page index
	if pageIndex < 0 || pageIndex >= _pages.size():
		return

	# Hide all pages
	for i in range(_pages.size()):
		_pages[i].visible = (i == pageIndex)

	_currentPage = pageIndex

	# Reload page data to reflect any saved changes
	_pages[pageIndex]._loadPageData()

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
		_hasUnsavedChanges = false  # Just saved, new page starts clean
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
	_hasUnsavedChanges = false  # Just saved, new page starts clean

	# If on last page, finish
	if _currentPage == _pages.size() - 1:
		_onFinishPressed()
	else:
		_showPage(_currentPage + 1)

func _onFinishPressed():
	# Close wizard
	queue_free()

func _onExitPressed():
	if _hasUnsavedChanges:
		_confirmationDialog.show_dialog("Do you want to save your changes before exiting?")
	else:
		# No unsaved changes, just exit
		queue_free()

func _onConfirmationDialogChoice(choice: String):
	match choice:
		"save":
			# Save current page and exit
			_pages[_currentPage].save()
			_projectCard.show_saved_indicator()
			if _isClosingApp:
				get_tree().quit()
			else:
				queue_free()
		"dont_save":
			# Exit without saving
			if _isClosingApp:
				get_tree().quit()
			else:
				queue_free()
		"cancel":
			# Stay in wizard (dialog already hidden)
			_isClosingApp = false  # Reset flag

func _onBreadcrumbStepClicked(step_index: int):
	# Save current page before navigating
	_pages[_currentPage].save()
	_projectCard.show_saved_indicator()
	_hasUnsavedChanges = false  # Just saved, new page starts clean
	_showPage(step_index)

func _onWindowCloseRequested():
	# User clicked X button on window - check for unsaved changes
	if _hasUnsavedChanges:
		# Prevent immediate close, show confirmation dialog
		_isClosingApp = true
		_confirmationDialog.show_dialog("Do you want to save your changes before exiting?")
		# Dialog callback will handle the actual quit
	else:
		# No unsaved changes, allow app to close
		get_tree().quit()

func set_navigation_enabled(enabled: bool):
	# Enable/disable navigation buttons
	_backButton.disabled = not enabled
	_nextButton.disabled = not enabled
	_exitButton.disabled = not enabled
