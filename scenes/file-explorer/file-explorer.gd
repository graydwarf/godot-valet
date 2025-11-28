extends Panel
class_name FileExplorer

# - Generated with assistance from Claude 4 Sonnet (Anthropic) - December 2024

@onready var _fileTreeViewExplorer: Control = %FileTreeViewExplorer
@onready var _filePreviewer: Control = %FilePreviewer
@onready var _soundPlayerGrid: SoundPlayerGrid = %SoundPlayerGrid
@onready var _imageToolbar: HBoxContainer = %RightPaneSubToolbar

var _currentProjectConfigured: bool = false
var _imageExtensions: Array[String] = [".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".svg", ".tga"]

func _ready():
	InitSignals()
	RemoveGodotButtonFocusBorder()
	# Hide image toolbar initially (only show when image is selected)
	_setImageToolbarVisible(false)

func RemoveGodotButtonFocusBorder():
	# Remove focus border from Godot toggle button
	var empty_style = StyleBoxEmpty.new()
	%GodotToggleButton.add_theme_stylebox_override("focus", empty_style)

# Show/hide image toolbar while preserving its space in the layout
func _setImageToolbarVisible(is_visible: bool):
	# Use modulate alpha to hide visually but preserve space
	_imageToolbar.modulate.a = 1.0 if is_visible else 0.0
	# Disable mouse interaction when hidden
	_imageToolbar.mouse_filter = Control.MOUSE_FILTER_STOP if is_visible else Control.MOUSE_FILTER_IGNORE
	for child in _imageToolbar.get_children():
		if child is BaseButton:
			child.mouse_filter = Control.MOUSE_FILTER_STOP if is_visible else Control.MOUSE_FILTER_IGNORE

# Gently strobe a button to draw user's attention
func _strobe_button(button: BaseButton):
	var original_modulate = button.modulate
	var tween = create_tween()

	# Strobe once: gentle brighten -> return to original
	tween.tween_property(button, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.3)
	tween.tween_property(button, "modulate", original_modulate, 0.3)

func InitSignals():
	_fileTreeViewExplorer.FileSelected.connect(_on_file_selected)
	_fileTreeViewExplorer.DirectorySelected.connect(_on_directory_selected)
	_fileTreeViewExplorer.NavigateToProjectRequested.connect(_on_navigate_to_project_requested)
	_fileTreeViewExplorer.ProjectViewRestoreRequested.connect(_on_project_view_restore_requested)

	# Connect FilterSettings signals
	%FilterSettings.settings_applied.connect(_on_filter_settings_applied)
	%FilterSettings.settings_canceled.connect(_on_filter_settings_closed)

func ConfigureProject(selectedProjectItem):
	if selectedProjectItem == null:
		_currentProjectConfigured = false
		%ProjectContextContainer.visible = false
		_fileTreeViewExplorer.SetNavigateToProjectButtonVisible(false)
		%GodotToggleButton.visible = false
		return

	_currentProjectConfigured = true
	%ProjectContextContainer.visible = true
	_fileTreeViewExplorer.SetNavigateToProjectButtonVisible(true)
	%GodotToggleButton.visible = true
	LoadThumbnailImage(selectedProjectItem.GetThumbnailPath())
	%ProjectNameLineEdit.text = selectedProjectItem.GetProjectName()
	%ProjectPathLineEdit.text = selectedProjectItem.GetProjectPath()

	# Navigate to and highlight the project folder in the file tree
	var projectPath = selectedProjectItem.GetProjectPath()
	if projectPath and not projectPath.is_empty():
		_fileTreeViewExplorer.NavigateToPath(projectPath)

func LoadThumbnailImage(thumbnailPath):
	# Check if this is a Godot resource path (res://)
	if thumbnailPath.begins_with("res://"):
		# Load as a resource (respects Godot's import system)
		var texture = load(thumbnailPath)
		if texture:
			%ProjectThumbnailTextureRect.texture = texture
	else:
		# Load from filesystem (for user-provided external images)
		var image = Image.new()
		var error = image.load(thumbnailPath)
		if error == OK:
			var texture = ImageTexture.create_from_image(image)
			%ProjectThumbnailTextureRect.texture = texture

func CheckForOverwrites(files: Array[String], destinationPath: String) -> int:
	var overwriteCount = 0
	for filePath in files:
		var fileName = filePath.get_file()
		var destFile = destinationPath.path_join(fileName)
		if FileAccess.file_exists(destFile):
			overwriteCount += 1
	return overwriteCount

func ShowOverwriteConfirmation(overwriteCount: int) -> bool:
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "%d file(s) already exist in the destination.\nDo you want to overwrite them?" % overwriteCount
	dialog.title = "Confirm Overwrite"
	dialog.ok_button_text = "Overwrite"
	dialog.cancel_button_text = "Cancel"

	add_child(dialog)

	# Track whether user confirmed - use arrays to work around lambda capture
	var result = [false]
	var closed = [false]

	dialog.confirmed.connect(func():
		print("Dialog confirmed signal received")
		result[0] = true
		closed[0] = true
	)
	dialog.canceled.connect(func():
		print("Dialog canceled signal received")
		result[0] = false
		closed[0] = true
	)

	dialog.popup_centered()

	# Wait for dialog to close
	while not closed[0]:
		await get_tree().process_frame

	print("Final dialog result: ", result[0])
	dialog.queue_free()
	return result[0]

# Handle when a file is selected in the file tree view explorer
func _on_file_selected(filePath: String):
	# Don't change preview if project view (Godot toggle) is active
	if %GodotToggleButton.button_pressed:
		# Check if this file would normally show a preview (not audio when audio filter is active)
		var would_show_preview = true

		# Only skip strobe for audio files when audio filter is active
		if _fileTreeViewExplorer.IsAudioFilterActive():
			var extension = "." + filePath.get_extension().to_lower()
			var audioExtensions = [".ogg", ".mp3", ".wav", ".aac"]
			if extension in audioExtensions:
				would_show_preview = false

		# Strobe the toggle button to hint the user can hide project view
		if would_show_preview:
			_strobe_button(%GodotToggleButton)
		return

	var selectedFiles = _fileTreeViewExplorer.GetSelectedFiles()

	# Check if audio filter is active - if so, always use sound player grid for audio files
	if _fileTreeViewExplorer.IsAudioFilterActive():
		var extension = "." + filePath.get_extension().to_lower()
		var audioExtensions = [".ogg", ".mp3", ".wav", ".aac"]

		if extension in audioExtensions:
			# Audio file(s) with audio filter active - use sound player grid
			ShowSoundPlayerGrid(selectedFiles)
			if selectedFiles.size() > 1:
				%PathLabel.text = "%d audio files selected" % selectedFiles.size()
			else:
				%PathLabel.text = filePath
			return

	# Non-audio file or audio filter not active - use normal preview
	ShowFilePreviewer()
	_filePreviewer.PreviewFile(filePath)
	%PathLabel.text = filePath

	# Show image toolbar only when an image is selected
	var extension = "." + filePath.get_extension().to_lower()
	_setImageToolbarVisible(extension in _imageExtensions)

func _on_directory_selected(dirPath: String):
	# Hide image toolbar when directory is selected
	_setImageToolbarVisible(false)

	# Don't change preview if project view (Godot toggle) is active
	if %GodotToggleButton.button_pressed:
		return

	# Check if audio filter is active
	if _fileTreeViewExplorer.IsAudioFilterActive():
		# Get all audio files from this directory
		var audioFiles = _fileTreeViewExplorer.GetAudioFilesFromDirectory(dirPath)
		if audioFiles.size() > 0:
			# Load audio files in sound player grid
			ShowSoundPlayerGrid(audioFiles)
			%PathLabel.text = "%s (%d audio files)" % [dirPath, audioFiles.size()]
		else:
			# No audio files in directory
			ShowFilePreviewer()
			if _filePreviewer:
				_filePreviewer.PreviewDirectory(dirPath)
			%PathLabel.text = dirPath
	else:
		# Normal directory preview
		ShowFilePreviewer()
		if _filePreviewer:
			_filePreviewer.PreviewDirectory(dirPath)
		%PathLabel.text = dirPath

# Show the sound player grid and hide other views
func ShowSoundPlayerGrid(soundPaths: Array[String]):
	_soundPlayerGrid.visible = true
	_filePreviewer.visible = false
	%DestinationTreeView.visible = false
	_setImageToolbarVisible(false)  # Hide image toolbar when showing audio
	_soundPlayerGrid.LoadSounds(soundPaths)

# Show the file previewer and hide other views
func ShowFilePreviewer():
	_filePreviewer.visible = true
	_soundPlayerGrid.visible = false
	# Don't hide DestinationTreeView here - it's controlled by the Godot toggle button

func _on_back_button_pressed() -> void:
	visible = false

func _on_open_project_path_folder_pressed() -> void:
	FileHelper.OpenFilePathInWindowsExplorer(%ProjectPathLineEdit.text)

func _on_navigate_to_project_requested() -> void:
	# Navigate to the project root folder in the file tree view explorer
	# Reset the tree and expand all folders in the path
	var projectPath = %ProjectPathLineEdit.text
	if projectPath and not projectPath.is_empty():
		var projectRoot = projectPath.get_base_dir()
		await _fileTreeViewExplorer.NavigateToPath(projectRoot, true)

func _on_project_view_restore_requested() -> void:
	# Restore project view state by programmatically toggling the Godot button
	%GodotToggleButton.button_pressed = true
	# Call the toggle handler to update UI
	_on_godot_toggle_button_toggled(true)

func _on_godot_toggle_button_toggled(toggled_on: bool) -> void:
	# Update file tree view multi-select state
	_fileTreeViewExplorer.SetProjectViewActive(toggled_on)

	# Toggle between file preview and destination tree view
	%FilePreviewer.visible = not toggled_on
	_soundPlayerGrid.visible = false  # Hide sound grid when switching modes
	_setImageToolbarVisible(false)  # Hide image toolbar when switching modes
	%DestinationTreeView.visible = toggled_on
	%CopyLeftButton.visible = toggled_on
	%CopyRightButton.visible = toggled_on
	%MoveLeftButton.visible = toggled_on
	%MoveRightButton.visible = toggled_on

	# Update tooltip and modulate color to green when toggled on
	if toggled_on:
		%GodotToggleButton.tooltip_text = "Hide Project"
		# Modulate button to green
		%GodotToggleButton.modulate = Color(0.4, 1.0, 0.4, 1.0)  # Green tint
	else:
		%GodotToggleButton.tooltip_text = "Show & Lock Project At Right"
		# Reset to default color
		%GodotToggleButton.modulate = Color(1.0, 1.0, 1.0, 1.0)  # White (default)

	# Initialize destination tree with project path when toggled on
	if toggled_on and %ProjectPathLineEdit.text:
		await %DestinationTreeView.InitializeProjectTree(%ProjectPathLineEdit.text)

	# When toggling off (back to normal preview), refresh preview based on current selection
	if not toggled_on:
		var selectedFiles = _fileTreeViewExplorer.GetSelectedFiles()
		if selectedFiles.size() > 0:
			# Has file selection - trigger file selected handler
			_on_file_selected(selectedFiles[0])
		else:
			# Check if a directory is selected
			var currentPath = _fileTreeViewExplorer.GetCurrentPath()
			if currentPath and not currentPath.is_empty():
				_on_directory_selected(currentPath)

func _on_copy_right_button_pressed() -> void:
	# Get selected files from left tree view
	var selectedFiles = _fileTreeViewExplorer.GetSelectedFiles()
	if selectedFiles.is_empty():
		OS.alert("No files selected to copy.")
		return

	# Get destination path from right tree view
	var destinationPath = %DestinationTreeView.GetSelectedDestination()
	if not destinationPath or destinationPath.is_empty():
		OS.alert("No destination selected.")
		return

	# Check for overwrites
	var overwriteCount = CheckForOverwrites(selectedFiles, destinationPath)
	if overwriteCount > 0:
		var confirmed = await ShowOverwriteConfirmation(overwriteCount)
		if not confirmed:
			return

	# Copy files
	var successCount = 0
	var failCount = 0
	for filePath in selectedFiles:
		var fileName = filePath.get_file()
		var destFile = destinationPath.path_join(fileName)

		var error = DirAccess.copy_absolute(filePath, destFile)
		if error == OK:
			successCount += 1
		else:
			failCount += 1
			print("Failed to copy: ", filePath, " Error: ", error)

	# Show alert only for failures
	if failCount > 0:
		OS.alert("Failed to copy %d file(s)." % failCount)

	# Refresh destination tree view to show new files
	if successCount > 0:
		await %DestinationTreeView.RefreshProjectTree()

func _on_copy_left_button_pressed() -> void:
	# Get selected files from right tree view (project)
	var selectedFiles = %DestinationTreeView.GetSelectedFiles()
	if selectedFiles.is_empty():
		OS.alert("No files selected to copy.")
		return

	# Get destination path from left tree view (file explorer)
	var destinationPath = _fileTreeViewExplorer.GetCurrentPath()
	if not destinationPath or destinationPath.is_empty():
		OS.alert("Please select a destination folder in the file explorer.")
		return

	# Verify destination is a valid directory
	if not DirAccess.dir_exists_absolute(destinationPath):
		OS.alert("Invalid destination path: " + destinationPath)
		return

	# Check for overwrites
	var overwriteCount = CheckForOverwrites(selectedFiles, destinationPath)
	if overwriteCount > 0:
		var confirmed = await ShowOverwriteConfirmation(overwriteCount)
		if not confirmed:
			return

	# Copy files
	var successCount = 0
	var failCount = 0
	for filePath in selectedFiles:
		var fileName = filePath.get_file()
		var destFile = destinationPath.path_join(fileName)

		var error = DirAccess.copy_absolute(filePath, destFile)
		if error == OK:
			successCount += 1
		else:
			failCount += 1
			print("Failed to copy: ", filePath, " Error: ", error)

	# Show alert only for failures
	if failCount > 0:
		OS.alert("Failed to copy %d file(s)." % failCount)

	# Refresh left tree view to show new files
	if successCount > 0:
		await _fileTreeViewExplorer.RefreshExpandedFolders()

func _on_move_right_button_pressed() -> void:
	print("=== MOVE RIGHT BUTTON PRESSED ===")
	# Get selected files from left tree view
	var selectedFiles = _fileTreeViewExplorer.GetSelectedFiles()
	print("Selected files count: ", selectedFiles.size())
	if selectedFiles.is_empty():
		OS.alert("No files selected to move.")
		return

	# Get destination path from right tree view
	var destinationPath = %DestinationTreeView.GetSelectedDestination()
	print("Destination path: ", destinationPath)
	if not destinationPath or destinationPath.is_empty():
		print("No destination selected - exiting")
		OS.alert("No destination selected.")
		return

	# Check for overwrites
	print("Checking for overwrites...")
	var overwriteCount = CheckForOverwrites(selectedFiles, destinationPath)
	print("Overwrite count: ", overwriteCount)
	if overwriteCount > 0:
		print("Showing overwrite confirmation...")
		var confirmed = await ShowOverwriteConfirmation(overwriteCount)
		print("User confirmed: ", confirmed)
		if not confirmed:
			print("User cancelled - exiting")
			return

	# Move files
	var successCount = 0
	var failCount = 0
	for filePath in selectedFiles:
		var fileName = filePath.get_file()
		var destFile = destinationPath.path_join(fileName)

		print("MOVE RIGHT - Moving: ", filePath, " -> ", destFile)

		# If destination exists and user confirmed overwrite, delete it first
		if FileAccess.file_exists(destFile):
			print("MOVE RIGHT - Destination exists, deleting: ", destFile)
			var deleteError = DirAccess.remove_absolute(destFile)
			if deleteError != OK:
				failCount += 1
				print("MOVE RIGHT - Failed to delete existing file: ", destFile, " Error: ", deleteError)
				continue
			print("MOVE RIGHT - Successfully deleted existing file")

		var error = DirAccess.rename_absolute(filePath, destFile)
		print("MOVE RIGHT - Move result: ", error, " (0 = OK)")
		if error == OK:
			successCount += 1
		else:
			failCount += 1
			print("MOVE RIGHT - Failed to move: ", filePath, " Error: ", error)

	# Show alert only for failures
	if failCount > 0:
		OS.alert("Failed to move %d file(s)." % failCount)

	# Refresh both tree views to reflect moved files
	if successCount > 0:
		await _fileTreeViewExplorer.RefreshExpandedFolders()
		await %DestinationTreeView.RefreshProjectTree()

func _on_move_left_button_pressed() -> void:
	print("=== MOVE LEFT BUTTON PRESSED ===")
	# Get selected files from right tree view (project)
	var selectedFiles = %DestinationTreeView.GetSelectedFiles()
	print("Selected files count: ", selectedFiles.size())
	if selectedFiles.is_empty():
		OS.alert("No files selected to move.")
		return

	# Get destination path from left tree view (file explorer)
	var destinationPath = _fileTreeViewExplorer.GetCurrentPath()
	print("Destination path: ", destinationPath)
	if not destinationPath or destinationPath.is_empty():
		print("No destination selected - exiting")
		OS.alert("Please select a destination folder in the file explorer.")
		return

	# Verify destination is a valid directory
	if not DirAccess.dir_exists_absolute(destinationPath):
		print("Invalid destination path - exiting")
		OS.alert("Invalid destination path: " + destinationPath)
		return

	# Check for overwrites
	print("Checking for overwrites...")
	var overwriteCount = CheckForOverwrites(selectedFiles, destinationPath)
	print("Overwrite count: ", overwriteCount)
	if overwriteCount > 0:
		print("Showing overwrite confirmation...")
		var confirmed = await ShowOverwriteConfirmation(overwriteCount)
		print("User confirmed: ", confirmed)
		if not confirmed:
			print("User cancelled - exiting")
			return

	# Move files
	var successCount = 0
	var failCount = 0
	for filePath in selectedFiles:
		var fileName = filePath.get_file()
		var destFile = destinationPath.path_join(fileName)

		print("MOVE LEFT - Moving: ", filePath, " -> ", destFile)

		# If destination exists and user confirmed overwrite, delete it first
		if FileAccess.file_exists(destFile):
			print("MOVE LEFT - Destination exists, deleting: ", destFile)
			var deleteError = DirAccess.remove_absolute(destFile)
			if deleteError != OK:
				failCount += 1
				print("MOVE LEFT - Failed to delete existing file: ", destFile, " Error: ", deleteError)
				continue
			print("MOVE LEFT - Successfully deleted existing file")

		var error = DirAccess.rename_absolute(filePath, destFile)
		print("MOVE LEFT - Move result: ", error, " (0 = OK)")
		if error == OK:
			successCount += 1
		else:
			failCount += 1
			print("MOVE LEFT - Failed to move: ", filePath, " Error: ", error)

	# Show alert only for failures
	if failCount > 0:
		OS.alert("Failed to move %d file(s)." % failCount)

	# Refresh both tree views to reflect moved files
	if successCount > 0:
		await %DestinationTreeView.RefreshProjectTree()
		await _fileTreeViewExplorer.RefreshExpandedFolders()

# Toolbar button signal handlers - delegate to FileTreeViewExplorer
func _on_flat_list_button_pressed() -> void:
	_fileTreeViewExplorer._on_flat_list_button_pressed()

func _on_add_favorite_button_pressed() -> void:
	_fileTreeViewExplorer._on_add_favorite_button_pressed()

func _on_refresh_button_pressed() -> void:
	_fileTreeViewExplorer._on_refresh_button_pressed()

func _on_open_file_explorer_button_pressed() -> void:
	_fileTreeViewExplorer._on_open_file_explorer_button_pressed()

func _on_filter_option_selected(index: int) -> void:
	_fileTreeViewExplorer._on_filter_option_selected(index)

func _on_previous_button_pressed() -> void:
	_fileTreeViewExplorer._on_previous_button_pressed()

func _on_next_button_pressed() -> void:
	_fileTreeViewExplorer._on_next_button_pressed()

func _on_up_button_pressed() -> void:
	_fileTreeViewExplorer._on_up_button_pressed()

func _on_down_button_pressed() -> void:
	_fileTreeViewExplorer._on_down_button_pressed()

func _on_filter_settings_button_pressed() -> void:
	# Toggle full-screen filter settings view
	if %FilterSettings.visible:
		# Already showing - close it
		HideFilterSettingsFullScreen()
	else:
		# Show filter settings in full-screen mode
		ShowFilterSettingsFullScreen()

func ShowFilterSettingsFullScreen() -> void:
	# Hide main content, show filter settings
	%MainContent.visible = false

	# Get current filter extensions from file tree view explorer
	var current_extensions = _fileTreeViewExplorer.get_current_filter_extensions()

	# Load current extensions into settings panel
	%FilterSettings.load_extensions(current_extensions)

	# Show settings panel
	%FilterSettings.show_panel()

func HideFilterSettingsFullScreen() -> void:
	# Hide filter settings, show main content
	%FilterSettings.visible = false
	%MainContent.visible = true

func _on_filter_settings_closed() -> void:
	HideFilterSettingsFullScreen()

func _on_filter_settings_applied(filter_extensions: Dictionary) -> void:
	# Forward to file tree view explorer to apply the changes
	_fileTreeViewExplorer._on_filter_settings_applied(filter_extensions)
	# Don't close - Save button no longer closes

# Image zoom button signal handlers - delegate to FilePreviewer
func _on_fit_to_screen_button_pressed() -> void:
	_filePreviewer.ApplyImageDisplayMode(0) # FIT_TO_SCREEN

func _on_actual_size_button_pressed() -> void:
	_filePreviewer.ApplyImageDisplayMode(1) # ACTUAL_SIZE

func _on_stretch_button_pressed() -> void:
	_filePreviewer.ApplyImageDisplayMode(2) # STRETCH

func _on_tile_button_pressed() -> void:
	_filePreviewer.ApplyImageDisplayMode(3) # TILE

func _on_background_color_changed(color: Color) -> void:
	_filePreviewer.SetImageBackgroundColor(color)
