extends WizardPageBase

signal build_started(platform: String)
signal build_completed(platform: String, success: bool)
signal page_modified()  # Emitted when any input is changed

@onready var _platformsContainer = %PlatformsContainer
@onready var _exportSelectedButton = %ExportSelectedButton

var _platformRows: Dictionary = {}  # platform_name -> {mainRow, checkbox, detailsSection, exportPath, exportFilename, obfuscation, button}
var _exportingPlatforms: Array[String] = []
var _folderDialog: FileDialog = null
var _currentPlatformForDialog: String = ""  # Track which platform is selecting a folder

func _ready():
	_exportSelectedButton.pressed.connect(_onExportSelectedPressed)

func _loadPageData():
	if _selectedProjectItem == null:
		return

	_clearPlatformRows()
	_createPlatformRows()
	_loadPlatformSettings()

func _clearPlatformRows():
	for child in _platformsContainer.get_children():
		child.queue_free()
	_platformRows.clear()

func _loadPlatformSettings():
	if _selectedProjectItem == null:
		return

	var allSettings = _selectedProjectItem.GetAllPlatformExportSettings()

	for platform in _platformRows.keys():
		if platform in allSettings:
			var settings = allSettings[platform]
			var data = _platformRows[platform]

			# Restore settings
			data["exportPath"].text = settings.get("exportPath", "")
			data["exportFilename"].text = settings.get("exportFilename", "")
			data["obfuscation"].button_pressed = settings.get("obfuscation", false)

			# Restore enabled state
			var isEnabled = settings.get("enabled", false)
			data["checkbox"].button_pressed = isEnabled

			# Show/hide details section based on enabled state
			data["detailsSection"].visible = isEnabled
			data["button"].disabled = !isEnabled

func _createPlatformRows():
	# Get selected platforms from wizard data (we'll need to pass this through)
	# For now, create rows for all possible platforms
	var platforms = ["Windows Desktop", "Linux", "Web", "Source Code"]

	for i in range(platforms.size()):
		var platform = platforms[i]
		var row = _createPlatformRow(platform)
		_platformsContainer.add_child(row)

		# Add separator between platforms (except after the last one)
		if i < platforms.size() - 1:
			var separator = HSeparator.new()
			_platformsContainer.add_child(separator)

func _createPlatformRow(platform: String) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)

	# === Main Row (always visible) ===
	var mainRow = HBoxContainer.new()
	mainRow.add_theme_constant_override("separation", 10)

	# Checkbox
	var checkbox = CheckBox.new()
	checkbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	checkbox.name = "Checkbox"
	checkbox.focus_mode = Control.FOCUS_NONE
	checkbox.toggled.connect(_onPlatformToggled.bind(platform))
	checkbox.toggled.connect(_onInputChanged.unbind(1))
	mainRow.add_child(checkbox)

	# Platform name label
	var nameLabel = Label.new()
	nameLabel.text = platform
	nameLabel.custom_minimum_size = Vector2(150, 0)
	nameLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mainRow.add_child(nameLabel)

	# Spacer to push Export button to the right
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mainRow.add_child(spacer)

	# Export button
	var exportButton = Button.new()
	exportButton.text = "Export"
	exportButton.custom_minimum_size = Vector2(100, 31)
	exportButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	exportButton.pressed.connect(_onExportPressed.bind(platform))
	exportButton.name = "ExportButton"
	exportButton.disabled = true  # Disabled until platform is selected
	mainRow.add_child(exportButton)

	container.add_child(mainRow)

	# === Details Section (visible when checkbox checked) ===
	var detailsSection = MarginContainer.new()
	detailsSection.add_theme_constant_override("margin_left", 40)  # Indent
	detailsSection.visible = false
	detailsSection.name = "DetailsSection"

	var detailsVBox = VBoxContainer.new()
	detailsVBox.add_theme_constant_override("separation", 8)

	# Export Path Row
	var exportPathRow = HBoxContainer.new()
	exportPathRow.add_theme_constant_override("separation", 5)

	var exportPathLabel = Label.new()
	exportPathLabel.text = "Export Path:"
	exportPathLabel.custom_minimum_size = Vector2(130, 0)
	exportPathLabel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	exportPathLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	exportPathLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exportPathRow.add_child(exportPathLabel)

	var exportPathEdit = LineEdit.new()
	exportPathEdit.placeholder_text = "Where to export..."
	exportPathEdit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exportPathEdit.name = "ExportPathEdit"
	exportPathEdit.text_changed.connect(_onInputChanged)
	exportPathRow.add_child(exportPathEdit)

	var folderButton = Button.new()
	folderButton.text = "📁"
	folderButton.custom_minimum_size = Vector2(32, 31)
	folderButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	folderButton.tooltip_text = "Select export folder"
	folderButton.pressed.connect(_onFolderButtonPressed.bind(platform))
	exportPathRow.add_child(folderButton)

	detailsVBox.add_child(exportPathRow)

	# Export Filename Row
	var filenameRow = HBoxContainer.new()
	filenameRow.add_theme_constant_override("separation", 5)

	var filenameLabel = Label.new()
	filenameLabel.text = "Export Filename:"
	filenameLabel.custom_minimum_size = Vector2(130, 0)
	filenameLabel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	filenameLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	filenameLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	filenameRow.add_child(filenameLabel)

	var filenameEdit = LineEdit.new()
	filenameEdit.placeholder_text = "Base name for export..."
	filenameEdit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filenameEdit.name = "ExportFilenameEdit"
	filenameEdit.text_changed.connect(_onInputChanged)
	filenameRow.add_child(filenameEdit)

	detailsVBox.add_child(filenameRow)

	# Obfuscation Row
	var obfuscationRow = HBoxContainer.new()
	obfuscationRow.add_theme_constant_override("separation", 10)

	var obfuscationCheck = CheckBox.new()
	obfuscationCheck.text = "Enable Obfuscation"
	obfuscationCheck.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	obfuscationCheck.focus_mode = Control.FOCUS_NONE
	obfuscationCheck.name = "ObfuscationCheck"
	obfuscationCheck.toggled.connect(_onInputChanged.unbind(1))
	obfuscationRow.add_child(obfuscationCheck)

	detailsVBox.add_child(obfuscationRow)

	detailsSection.add_child(detailsVBox)
	container.add_child(detailsSection)

	# Store references
	_platformRows[platform] = {
		"container": container,
		"mainRow": mainRow,
		"checkbox": checkbox,
		"detailsSection": detailsSection,
		"exportPath": exportPathEdit,
		"exportFilename": filenameEdit,
		"obfuscation": obfuscationCheck,
		"button": exportButton
	}

	return container

func _onInputChanged(_value = null):
	# Emit signal when any input is modified
	page_modified.emit()

func _onPlatformToggled(checked: bool, platform: String):
	var data = _platformRows[platform]

	# Show/hide details section
	data["detailsSection"].visible = checked

	# Enable/disable export button
	data["button"].disabled = !checked

	if checked:
		# Auto-fill from the previous checked platform
		if data["exportPath"].text.is_empty() or data["exportFilename"].text.is_empty():
			_copyFromPreviousPlatform(platform)

func _copyFromPreviousPlatform(targetPlatform: String):
	# Find the last checked platform before this one
	var platforms = ["Windows Desktop", "Linux", "Web", "Source Code"]
	var targetIndex = platforms.find(targetPlatform)

	if targetIndex <= 0:
		return  # No previous platform

	# Search backwards for a checked platform
	for i in range(targetIndex - 1, -1, -1):
		var prevPlatform = platforms[i]
		if prevPlatform in _platformRows:
			var prevData = _platformRows[prevPlatform]
			if prevData["checkbox"].button_pressed:
				var targetData = _platformRows[targetPlatform]

				# Copy export path if empty
				if targetData["exportPath"].text.is_empty():
					targetData["exportPath"].text = prevData["exportPath"].text

				# Copy filename if empty
				if targetData["exportFilename"].text.is_empty():
					targetData["exportFilename"].text = prevData["exportFilename"].text

				# Copy obfuscation setting
				targetData["obfuscation"].button_pressed = prevData["obfuscation"].button_pressed

				return  # Found and copied, we're done

func _onExportPressed(platform: String):
	_exportPlatform(platform)

func _onFolderButtonPressed(platform: String):
	_currentPlatformForDialog = platform
	var data = _platformRows[platform]
	var currentPath = data["exportPath"].text

	# If export path is empty, default to project path
	if currentPath.is_empty() and _selectedProjectItem != null:
		currentPath = _selectedProjectItem.GetProjectPath()

	_openFolderDialog(currentPath)

func _openFolderDialog(currentPath: String):
	if _folderDialog == null:
		_folderDialog = FileDialog.new()
		_folderDialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_folderDialog.access = FileDialog.ACCESS_FILESYSTEM
		_folderDialog.show_hidden_files = true
		_folderDialog.title = "Select Export Folder"
		_folderDialog.ok_button_text = "Select"
		_folderDialog.dir_selected.connect(_onFolderSelected)
		add_child(_folderDialog)

	# Set initial directory if path exists
	if currentPath != "" and DirAccess.dir_exists_absolute(currentPath):
		_folderDialog.current_dir = currentPath

	_folderDialog.popup_centered(Vector2i(800, 600))

func _onFolderSelected(path: String):
	if _currentPlatformForDialog in _platformRows:
		var data = _platformRows[_currentPlatformForDialog]
		data["exportPath"].text = path

func _onExportSelectedPressed():
	for platform in _platformRows.keys():
		var data = _platformRows[platform]
		if data["checkbox"].button_pressed:
			_exportPlatform(platform)

func _exportPlatform(platform: String):
	if platform in _exportingPlatforms:
		return  # Already exporting

	var data = _platformRows[platform]
	_exportingPlatforms.append(platform)

	# Update UI
	data["status"].text = "Exporting..."
	data["button"].disabled = true

	# Emit signal
	build_started.emit(platform)

	# TODO: Actual export logic would go here
	# For now, simulate an export with a timer
	await get_tree().create_timer(2.0).timeout

	# Simulate success
	data["status"].text = "Complete"
	data["button"].disabled = false
	_exportingPlatforms.erase(platform)

	build_completed.emit(platform, true)

func validate() -> bool:
	# Check that selected platforms have valid export paths
	for platform in _platformRows.keys():
		var data = _platformRows[platform]
		if data["checkbox"].button_pressed:
			var exportPath = data["exportPath"].text
			if exportPath.is_empty():
				# TODO: Show validation error
				return false

			# Export path cannot equal project path
			if _selectedProjectItem != null:
				var projectPath = _selectedProjectItem.GetProjectPath()
				if exportPath == projectPath:
					return false

	return true

func save():
	if _selectedProjectItem == null:
		return

	# Save all platform settings
	for platform in _platformRows.keys():
		var data = _platformRows[platform]

		# Only save settings for platforms that have been configured (checkbox checked at some point)
		if data["checkbox"].button_pressed or data["exportPath"].text != "" or data["exportFilename"].text != "":
			var platformSettings = {
				"enabled": data["checkbox"].button_pressed,
				"exportPath": data["exportPath"].text,
				"exportFilename": data["exportFilename"].text,
				"obfuscation": data["obfuscation"].button_pressed
			}
			_selectedProjectItem.SetPlatformExportSettings(platform, platformSettings)

	_selectedProjectItem.SaveProjectItem()
