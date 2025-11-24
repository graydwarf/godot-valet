extends Panel

# Wizard controller for Release Manager

@onready var _projectCard = %ProjectCard
@onready var _breadcrumb = %WizardBreadcrumb
@onready var _pagesContainer = %PagesContainer
@onready var _exitButton = %ExitButton
@onready var _saveButton = %SaveButton
@onready var _nextButton = %NextButton
@onready var _confirmationDialog = %ConfirmationDialog

var _currentPage: int = 0
var _pages: Array[WizardPageBase] = []
var _selectedProjectItem = null
var _hasUnsavedChanges: bool = false
var _isClosingApp: bool = false  # Track if we're closing the app vs just the wizard
var _isGoingBack: bool = false  # Track if we're navigating back vs exiting

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

	# Manually connect breadcrumb signal (tscn connection may not work with dynamic buttons)
	if _breadcrumb and not _breadcrumb.step_clicked.is_connected(_onBreadcrumbStepClicked):
		print("Connecting breadcrumb step_clicked signal manually")
		_breadcrumb.step_clicked.connect(_onBreadcrumbStepClicked)

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
	print("_loadPages: checking children of PagesContainer...")
	for child in _pagesContainer.get_children():
		print("  Child: ", child.name, " is WizardPageBase: ", child is WizardPageBase)
		if child is WizardPageBase:
			_pages.append(child)

			# Connect version change signal to card (from Build page)
			if child.has_signal("version_changed"):
				child.version_changed.connect(_projectCard.update_version_comparison)

			# Connect page_modified signal to track dirty state
			if child.has_signal("page_modified"):
				child.page_modified.connect(_onPageModified)

			# Connect page_saved signal to reset dirty state
			if child.has_signal("page_saved"):
				child.page_saved.connect(_onPageSaved)

	print("_loadPages: total pages loaded = ", _pages.size())

func _onPageModified():
	# Mark as dirty when any page input is modified
	_hasUnsavedChanges = true

func _onPageSaved():
	# Reset dirty flag when page saves
	_hasUnsavedChanges = false

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
	# Exit/Back always visible
	_exitButton.visible = true

	# Next visible on all pages
	_nextButton.visible = true

	# Change Next to Save & Close on last page
	if _currentPage == _pages.size() - 1:
		_nextButton.text = "Save & Close"
	else:
		_nextButton.text = "Next"

func _onNextPressed():
	print("_onNextPressed called - current page: ", _currentPage, " total pages: ", _pages.size())

	# Validate current page
	if !_pages[_currentPage].validate():
		# Show validation error
		print("Validation FAILED for page ", _currentPage)
		return

	print("Validation passed, saving page...")

	# Save current page
	_pages[_currentPage].save()
	_projectCard.show_saved_indicator()
	_hasUnsavedChanges = false  # Just saved, new page starts clean

	# If on last page, finish
	if _currentPage == _pages.size() - 1:
		print("On last page, calling _onFinishPressed")
		_onFinishPressed()
	else:
		print("Navigating to page ", _currentPage + 1)
		_showPage(_currentPage + 1)

func _onFinishPressed():
	# Close wizard
	queue_free()

func _onSavePressed():
	# Save current page
	_pages[_currentPage].save()
	_projectCard.show_saved_indicator()
	_hasUnsavedChanges = false

func _onExitPressed():
	# On first page, exit the wizard; on other pages, go back
	if _currentPage == 0:
		if _hasUnsavedChanges:
			_confirmationDialog.show_dialog("Do you want to save your changes before exiting?")
		else:
			queue_free()
	else:
		# On other pages, go back - prompt if unsaved changes
		if _hasUnsavedChanges:
			_isGoingBack = true
			_confirmationDialog.show_dialog("Do you want to save your changes before going back?")
		else:
			_showPage(_currentPage - 1)

func _onConfirmationDialogChoice(choice: String):
	match choice:
		"save":
			# Save current page
			_pages[_currentPage].save()
			_projectCard.show_saved_indicator()
			_hasUnsavedChanges = false
			if _isGoingBack:
				_isGoingBack = false
				_showPage(_currentPage - 1)
			elif _isClosingApp:
				get_tree().quit()
			else:
				queue_free()
		"dont_save":
			# Discard changes
			_hasUnsavedChanges = false
			if _isGoingBack:
				_isGoingBack = false
				_showPage(_currentPage - 1)
			elif _isClosingApp:
				get_tree().quit()
			else:
				queue_free()
		"cancel":
			# Stay in wizard (dialog already hidden)
			_isClosingApp = false
			_isGoingBack = false

func _onBreadcrumbStepClicked(step_index: int):
	print("_onBreadcrumbStepClicked: step_index=", step_index, " current=", _currentPage, " total pages=", _pages.size())
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
	_nextButton.disabled = not enabled
	_saveButton.disabled = not enabled
	_exitButton.disabled = not enabled
