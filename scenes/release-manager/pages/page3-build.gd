extends WizardPageBase

signal build_started(platform: String)
signal build_completed(platform: String, success: bool)
signal version_changed(old_version: String, new_version: String)
signal page_modified()  # Emitted when any input is changed

@onready var _platformsContainer = %PlatformsContainer
@onready var _exportSelectedButton = %ExportSelectedButton
@onready var _projectVersionLineEdit = %ProjectVersionLineEdit

var _platformRows: Dictionary = {}  # platform_name -> {mainRow, checkbox, detailsSection, exportPath, exportFilename, obfuscation, button, configButton}
var _exportingPlatforms: Array[String] = []
var _folderDialog: FileDialog = null
var _currentPlatformForDialog: String = ""  # Track which platform is selecting a folder
var _currentVersion: String = ""  # Store current version for comparison
var _platformBuildConfigs: Dictionary = {}  # platform_name -> build config dict
var _buildConfigDialog: Window = null
var _yesNoDialog: Control = null

func _ready():
	_exportSelectedButton.pressed.connect(_onExportSelectedPressed)
	_projectVersionLineEdit.text_changed.connect(_onVersionChanged)

	# Create build config dialog
	_buildConfigDialog = load("res://scenes/release-manager/build-config-dialog.tscn").instantiate()
	_buildConfigDialog.config_saved.connect(_onBuildConfigSaved)
	add_child(_buildConfigDialog)

	# Create yes/no dialog for overwrite confirmation
	_yesNoDialog = load("res://scenes/common/yes-no-dialog.tscn").instantiate()
	add_child(_yesNoDialog)

func _loadPageData():
	if _selectedProjectItem == null:
		return

	# Load project version
	_currentVersion = _selectedProjectItem.GetProjectVersion()
	_projectVersionLineEdit.text = _currentVersion

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
		var data = _platformRows[platform]

		# Clear status label on page load
		data["status"].text = ""

		if platform in allSettings:
			var settings = allSettings[platform]

			# Restore settings
			data["exportPath"].text = settings.get("exportPath", "")
			data["exportFilename"].text = settings.get("exportFilename", "")
			data["obfuscation"].button_pressed = settings.get("obfuscation", false)

			# Restore build config (obfuscation settings)
			if settings.has("buildConfig"):
				_platformBuildConfigs[platform] = settings["buildConfig"]

			# Restore enabled state
			var isEnabled = settings.get("enabled", false)
			data["checkbox"].button_pressed = isEnabled

			# Show/hide details section based on enabled state
			data["detailsSection"].visible = isEnabled
			data["button"].disabled = !isEnabled

func _createPlatformRows():
	# Get configured export presets from the project
	var platforms = _selectedProjectItem.GetAvailableExportPresets()

	# If no presets configured, show helpful message
	if platforms.is_empty():
		var messageLabel = Label.new()
		messageLabel.text = "No export presets configured.\n\nTo export this project, you need to:\n1. Open the project in Godot\n2. Go to Project > Export\n3. Add export presets for desired platforms\n4. Save and close the project"
		messageLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		messageLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		messageLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		messageLabel.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		_platformsContainer.add_child(messageLabel)
		return

	# Create rows for each configured preset
	for platform in platforms:
		var card = _createPlatformCard(platform)
		_platformsContainer.add_child(card)

func _createPlatformCard(platform: String) -> PanelContainer:
	# Outer panel with rounded edges
	var panelContainer = PanelContainer.new()

	# Apply styled theme
	var panelTheme = Theme.new()
	var styleBox = StyleBoxFlat.new()
	styleBox.bg_color = _getAdjustedBackgroundColor(-0.08)
	styleBox.border_color = Color(0.6, 0.6, 0.6)
	styleBox.border_width_left = 1
	styleBox.border_width_top = 1
	styleBox.border_width_right = 1
	styleBox.border_width_bottom = 1
	styleBox.corner_radius_top_left = 6
	styleBox.corner_radius_top_right = 6
	styleBox.corner_radius_bottom_right = 6
	styleBox.corner_radius_bottom_left = 6
	panelTheme.set_stylebox("panel", "PanelContainer", styleBox)
	panelContainer.theme = panelTheme

	# Platform content - no inner margin, header uses parent's borders
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 0)
	panelContainer.add_child(container)

	# === Header Row Container (bottom border only) ===
	var headerContainer = PanelContainer.new()

	# Header container theme (transparent bg, bottom border only)
	var headerTheme = Theme.new()
	var headerStyleBox = StyleBoxFlat.new()
	headerStyleBox.bg_color = Color(0, 0, 0, 0)  # Transparent background
	headerStyleBox.border_color = Color(0.6, 0.6, 0.6)
	headerStyleBox.border_width_left = 0
	headerStyleBox.border_width_top = 0
	headerStyleBox.border_width_right = 0
	headerStyleBox.border_width_bottom = 1
	headerTheme.set_stylebox("panel", "PanelContainer", headerStyleBox)
	headerContainer.theme = headerTheme

	# Header inner margin
	var headerMargin = MarginContainer.new()
	headerMargin.add_theme_constant_override("margin_left", 10)
	headerMargin.add_theme_constant_override("margin_top", 10)
	headerMargin.add_theme_constant_override("margin_right", 10)
	headerMargin.add_theme_constant_override("margin_bottom", 10)
	headerContainer.add_child(headerMargin)

	# === Main Row (always visible) ===
	var mainRow = HBoxContainer.new()
	mainRow.add_theme_constant_override("separation", 10)
	headerMargin.add_child(mainRow)

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
	nameLabel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	nameLabel.gui_input.connect(_onPlatformLabelClicked.bind(platform, checkbox))
	mainRow.add_child(nameLabel)

	# Status label
	var statusLabel = Label.new()
	statusLabel.text = ""
	statusLabel.custom_minimum_size = Vector2(100, 0)
	statusLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	statusLabel.name = "StatusLabel"
	mainRow.add_child(statusLabel)

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

	container.add_child(headerContainer)

	# === Details Section (visible when checkbox checked) ===
	var detailsSection = MarginContainer.new()
	detailsSection.add_theme_constant_override("margin_left", 50)  # Indent from left edge
	detailsSection.add_theme_constant_override("margin_top", 10)  # Top padding
	detailsSection.add_theme_constant_override("margin_right", 10)  # Right padding
	detailsSection.add_theme_constant_override("margin_bottom", 10)  # Bottom padding
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

	var openFolderButton = Button.new()
	openFolderButton.text = "🗀"
	openFolderButton.custom_minimum_size = Vector2(32, 31)
	openFolderButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	openFolderButton.tooltip_text = "Open export folder"
	openFolderButton.pressed.connect(_onOpenFolderButtonPressed.bind(platform))
	exportPathRow.add_child(openFolderButton)

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

	# Settings cog button
	var configButton = Button.new()
	configButton.text = "⚙"
	configButton.custom_minimum_size = Vector2(32, 31)
	configButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	configButton.tooltip_text = "Configure obfuscation settings for this platform"
	configButton.pressed.connect(_onConfigButtonPressed.bind(platform))
	configButton.name = "ConfigButton"
	obfuscationRow.add_child(configButton)

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
		"configButton": configButton,
		"button": exportButton,
		"status": statusLabel
	}

	return panelContainer

func _getAdjustedBackgroundColor(amount: float) -> Color:
	var colorToSubtract = Color(amount, amount, amount, 0.0)
	var baseColor = App.GetBackgroundColor()
	return Color(
		max(baseColor.r + colorToSubtract.r, 0),
		max(baseColor.g + colorToSubtract.g, 0),
		max(baseColor.b + colorToSubtract.b, 0),
		baseColor.a
	)

func _onVersionChanged(newText: String):
	# Notify card of version change
	version_changed.emit(_currentVersion, newText)
	page_modified.emit()

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

func _onPlatformLabelClicked(event: InputEvent, platform: String, checkbox: CheckBox):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		checkbox.button_pressed = !checkbox.button_pressed

func _onConfigButtonPressed(platform: String):
	# Get all platform names for the clone dropdown
	var allPlatforms: Array[String] = []
	allPlatforms.assign(_platformRows.keys())

	# Open the dialog
	_buildConfigDialog.openForPlatform(platform, allPlatforms, _platformBuildConfigs)

func _onBuildConfigSaved(platform: String, config: Dictionary):
	# Store the config for this platform
	_platformBuildConfigs[platform] = config

	# Immediately save to project item (don't wait for page save)
	if _selectedProjectItem != null:
		var platformSettings = _selectedProjectItem.GetPlatformExportSettings(platform)
		if platformSettings.is_empty():
			# Create new settings if platform not configured yet
			platformSettings = {
				"enabled": false,
				"exportPath": "",
				"exportFilename": "",
				"obfuscation": false
			}

		# Update build config in platform settings
		platformSettings["buildConfig"] = config

		# Save to project item immediately
		_selectedProjectItem.SetPlatformExportSettings(platform, platformSettings)
		_selectedProjectItem.SaveProjectItem()

	# Don't mark page as modified since we saved immediately
	# page_modified.emit()

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

func _onOpenFolderButtonPressed(platform: String):
	var data = _platformRows[platform]
	var exportPath = data["exportPath"].text

	if exportPath.is_empty():
		print("Export path not set for platform: ", platform)
		return

	# Get version from version field
	var version = _projectVersionLineEdit.text
	if version.is_empty():
		version = "v1.0.0"

	# Build version folder path
	var versionPath = exportPath.path_join(version)

	# Open the version folder if it exists, otherwise open the base export path
	var pathToOpen = versionPath if DirAccess.dir_exists_absolute(versionPath) else exportPath

	if DirAccess.dir_exists_absolute(pathToOpen):
		OS.shell_open(pathToOpen)
	else:
		print("Export folder does not exist: ", pathToOpen)

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

	# Reset UI - clear status first, then show exporting
	data["status"].text = ""
	await get_tree().process_frame  # Wait one frame so user sees it clear
	data["status"].text = "Exporting..."
	data["button"].disabled = true

	# Emit signal
	build_started.emit(platform)

	# Get export settings
	var exportPath = data["exportPath"].text
	var exportFilename = data["exportFilename"].text
	var obfuscationEnabled = data["obfuscation"].button_pressed

	# Validate export path and filename
	if exportPath.is_empty() or exportFilename.is_empty():
		data["status"].text = "Error: Missing path/filename"
		data["button"].disabled = false
		_exportingPlatforms.erase(platform)
		build_completed.emit(platform, false)
		return

	# Get Godot executable path
	var godotVersionId = _selectedProjectItem.GetGodotVersionId()
	var godotPath = _selectedProjectItem.GetGodotPath(godotVersionId)
	var projectPath = _selectedProjectItem.GetProjectPath()

	# Get project directory (GetProjectPath returns path to project.godot file)
	var projectDir = projectPath.get_base_dir()

	if godotPath == null or godotPath == "???":
		data["status"].text = "Error: Godot path not found"
		data["button"].disabled = false
		_exportingPlatforms.erase(platform)
		build_completed.emit(platform, false)
		return

	# Map platform to export preset name
	var presetName = _getExportPresetName(platform)
	if presetName.is_empty():
		data["status"].text = "Error: Unknown platform"
		data["button"].disabled = false
		_exportingPlatforms.erase(platform)
		build_completed.emit(platform, false)
		return

	# Get version from version field
	var version = _projectVersionLineEdit.text
	if version.is_empty():
		version = "v1.0.0"  # Default version if not specified

	# Create version subfolder path
	var versionPath = exportPath.path_join(version)

	# Check if version directory already exists and prompt user
	if DirAccess.dir_exists_absolute(versionPath):
		# Prompt user to overwrite
		var overwriteDialog = _getYesNoDialog()
		data["status"].text = "Awaiting confirmation..."
		overwriteDialog.show_dialog("Version " + version + " already exists. Overwrite?")
		var choice = await overwriteDialog.confirmed

		if choice != "yes":
			# User cancelled, abort export
			data["status"].text = "Export cancelled"
			data["button"].disabled = false
			_exportingPlatforms.erase(platform)
			build_completed.emit(platform, false)
			return

		# User confirmed, continue with export (existing files will be overwritten)
		data["status"].text = "Exporting..."
	else:
		# Create version directory
		var dir = DirAccess.open(exportPath)
		if dir == null:
			data["status"].text = "Error: Cannot access export path"
			data["button"].disabled = false
			_exportingPlatforms.erase(platform)
			build_completed.emit(platform, false)
			return
		var err = dir.make_dir(version)
		if err != OK:
			data["status"].text = "Error: Cannot create version folder"
			data["button"].disabled = false
			_exportingPlatforms.erase(platform)
			build_completed.emit(platform, false)
			return

	# Add platform-specific file extension
	var filenameWithExtension = _addPlatformExtension(exportFilename, platform)

	# Build output file path: exportPath/version/filename.ext
	var outputPath = versionPath.path_join(filenameWithExtension)

	# Handle obfuscation if enabled - obfuscate BEFORE export
	var projectDirToExport = projectDir
	var tempObfuscatedDir = ""
	var success = true  # Track overall success

	if obfuscationEnabled:
		data["status"].text = "Obfuscating project..."
		var obfResult = await _runObfuscation(projectDir, platform, data)
		if not obfResult["success"]:
			success = false
		else:
			projectDirToExport = obfResult["obfuscated_dir"]
			tempObfuscatedDir = obfResult["obfuscated_dir"]

	# Execute export command (from obfuscated dir if obfuscation enabled)
	if success:
		data["status"].text = "Exporting..."
		success = await _runGodotExport(godotPath, projectDirToExport, presetName, outputPath, data)

	# Clean up temp obfuscated directory if created
	if tempObfuscatedDir != "":
		_cleanupTempDir(tempObfuscatedDir)

	# Update UI
	if success:
		data["status"].text = "✓ Complete"
	else:
		data["status"].text = "✗ Failed"

	data["button"].disabled = false
	_exportingPlatforms.erase(platform)

	build_completed.emit(platform, success)

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

	# Save project version
	_selectedProjectItem.SetProjectVersion(_projectVersionLineEdit.text)

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

			# Save build config if exists
			if platform in _platformBuildConfigs:
				platformSettings["buildConfig"] = _platformBuildConfigs[platform]

			_selectedProjectItem.SetPlatformExportSettings(platform, platformSettings)

	_selectedProjectItem.SaveProjectItem()

func _getExportPresetName(platform: String) -> String:
	# Platform name IS the preset name (read from export_presets.cfg)
	return platform

func _addPlatformExtension(filename: String, platform: String) -> String:
	# Don't add extension if filename already has one
	if filename.get_extension() != "":
		return filename

	# Add platform-specific extension
	match platform:
		"Windows Desktop":
			return filename + ".exe"
		"Linux/X11", "Linux":
			return filename + ".x86_64"
		"Web":
			return filename + ".html"
		_:
			return filename

func _runGodotExport(godotPath: String, projectPath: String, presetName: String, outputPath: String, data: Dictionary) -> bool:
	# Build Godot export command
	var command = "\"%s\" --headless --path \"%s\" --export-release \"%s\" \"%s\"" % [godotPath, projectPath, presetName, outputPath]

	# Create output file to capture stdout/stderr
	var outputFilePath = "user://export_output.txt"
	var fullCommand = "%s > \"%s\" 2>&1" % [command, ProjectSettings.globalize_path(outputFilePath)]

	# Execute export command in background
	var pid = OS.create_process("cmd.exe", ["/c", fullCommand])

	if pid == -1:
		data["status"].text = "Error: Failed to start export"
		return false

	# Poll until process completes
	while OS.is_process_running(pid):
		await get_tree().create_timer(0.1).timeout  # Check every 100ms

	# Read output file
	var output = ""
	if FileAccess.file_exists(outputFilePath):
		var file = FileAccess.open(outputFilePath, FileAccess.READ)
		if file:
			output = file.get_as_text()
			file.close()
			# Clean up output file
			DirAccess.remove_absolute(outputFilePath)

	print("Export output: ", output)

	# Check for common error conditions in output
	if "export_presets.cfg" in output:
		data["status"].text = "Error: No export presets configured"
		print("Project needs export presets: Open project in Godot and configure presets via Project > Export")
		return false
	elif "Please provide a valid project path" in output or "Invalid project path" in output:
		data["status"].text = "Error: Invalid project path"
		return false
	elif "ERROR" in output or "Error" in output:
		data["status"].text = "Error: Export failed (see console)"
		return false

	# Verify output file was created
	if not FileAccess.file_exists(outputPath):
		print("Export command completed but output file not found: ", outputPath)
		data["status"].text = "Error: Output file not created"
		return false

	return true

func _runObfuscation(projectDir: String, platform: String, data: Dictionary) -> Dictionary:
	# Create temp directory for obfuscated project
	var tempDir = "user://temp_obfuscated_" + str(Time.get_ticks_msec())
	var tempDirGlobal = ProjectSettings.globalize_path(tempDir)

	# Create temp directory
	var dir = DirAccess.open("user://")
	if dir == null:
		data["status"].text = "Error: Cannot access user directory"
		return {"success": false, "obfuscated_dir": ""}

	var err = dir.make_dir_recursive(tempDir)
	if err != OK:
		data["status"].text = "Error: Cannot create temp directory"
		return {"success": false, "obfuscated_dir": ""}

	# Copy project to temp directory
	if not _copyDirectory(projectDir, tempDirGlobal):
		data["status"].text = "Error: Failed to copy project"
		return {"success": false, "obfuscated_dir": ""}

	# Get obfuscation settings from platform build config
	var buildConfig = _platformBuildConfigs.get(platform, {})
	var obfuscateFunctions = buildConfig.get("obfuscate_functions", false)
	var obfuscateVariables = buildConfig.get("obfuscate_variables", false)
	var obfuscateComments = buildConfig.get("obfuscate_comments", false)

	# Parse exclude lists (comma-separated to array)
	var functionExcludes = _parseExcludeList(buildConfig.get("function_excludes", ""))
	var variableExcludes = _parseExcludeList(buildConfig.get("variable_excludes", ""))

	# Set exclude lists in obfuscator
	ObfuscateHelper.SetFunctionExcludeList(functionExcludes)
	ObfuscateHelper.SetVariableExcludeList(variableExcludes)

	# Run obfuscation on temp directory
	ObfuscateHelper.ObfuscateScripts(tempDirGlobal, tempDirGlobal, obfuscateFunctions, obfuscateVariables, obfuscateComments)

	# Allow UI to update
	await get_tree().process_frame

	return {"success": true, "obfuscated_dir": tempDirGlobal}

func _parseExcludeList(excludeListString: String) -> Array[String]:
	var result: Array[String] = []
	if excludeListString.is_empty():
		return result

	var items = excludeListString.split(",")
	for item in items:
		var trimmed = item.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)

	return result

func _copyDirectory(source: String, dest: String) -> bool:
	# Create destination directory
	var destDir = DirAccess.open(dest.get_base_dir())
	if destDir == null:
		return false

	destDir.make_dir_recursive(dest)

	# Copy all files recursively
	var sourceDir = DirAccess.open(source)
	if sourceDir == null:
		return false

	sourceDir.list_dir_begin()
	var fileName = sourceDir.get_next()

	while fileName != "":
		var sourcePath = source.path_join(fileName)
		var destPath = dest.path_join(fileName)

		if sourceDir.current_is_dir():
			# Skip . and .. and hidden directories
			if fileName != "." and fileName != ".." and not fileName.begins_with("."):
				_copyDirectory(sourcePath, destPath)
		else:
			# Copy file
			DirAccess.copy_absolute(sourcePath, destPath)

		fileName = sourceDir.get_next()

	sourceDir.list_dir_end()
	return true

func _cleanupTempDir(tempDir: String):
	# Recursively delete temp directory
	var dir = DirAccess.open(tempDir)
	if dir == null:
		return

	dir.list_dir_begin()
	var fileName = dir.get_next()

	while fileName != "":
		var filePath = tempDir.path_join(fileName)

		if dir.current_is_dir():
			if fileName != "." and fileName != "..":
				_cleanupTempDir(filePath)
		else:
			dir.remove(fileName)

		fileName = dir.get_next()

	dir.list_dir_end()

	# Remove the directory itself
	DirAccess.remove_absolute(tempDir)

func _getYesNoDialog() -> Control:
	return _yesNoDialog
