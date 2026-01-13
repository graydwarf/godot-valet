extends Panel
class_name AssetFinder

# - Generated with assistance from Claude 4 Sonnet (Anthropic) - December 2024

@onready var _fileTreeViewExplorer: Control = %FileTreeViewExplorer
@onready var _filePreviewer: Control = %FilePreviewer
@onready var _soundPlayerGrid: SoundPlayerGrid = %SoundPlayerGrid
@onready var _imageToolbar: HBoxContainer = %RightPaneSubToolbar
@onready var _backgroundColorPicker: ColorPickerButton = %BackgroundColorPicker
@onready var _projectHeader: ProjectHeader = %ProjectHeader
@onready var _searchLineEdit: LineEdit = %SearchLineEdit
@onready var _regexToggleButton: Button = %RegexToggleButton
@onready var _searchButton: Button = %SearchButton
@onready var _tipsDialog: AssetFinderTipsDialog = %TipsDialog
@onready var _autoPlayCheckBox: CheckBox = %AutoPlayCheckBox
@onready var _autoPlayAudioPlayer: AudioStreamPlayer = %AutoPlayAudioPlayer
@onready var _audioToolbar: HBoxContainer = %AudioToolbar
@onready var _volumeSlider: HSlider = %VolumeSlider
@onready var _volumeValueLabel: Label = %VolumeValueLabel

var _isSearchInProgress: bool = false
var _lastAutoPlayedFile: String = ""
var _audioExtensions: Array[String] = [".ogg", ".mp3", ".wav", ".aac"]
var _currentProjectConfigured: bool = false
var _currentProjectPath: String = ""
var _imageExtensions: Array[String] = [".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".svg", ".tga"]

func _ready():
	InitSignals()
	RemoveGodotButtonFocusBorder()
	# Hide image toolbar initially (only show when image is selected)
	_setImageToolbarVisible(false)
	# Load saved image background color
	_loadImageBackgroundColor()
	# Initialize audio volume to 20%
	_initAudioVolume()

func RemoveGodotButtonFocusBorder():
	# Remove focus border from Godot toggle button
	var empty_style = StyleBoxEmpty.new()
	%GodotToggleButton.add_theme_stylebox_override("focus", empty_style)

# Show/hide image toolbar while preserving its space in the layout
func _setImageToolbarVisible(toolbar_visible: bool):
	# Use modulate alpha to hide visually but preserve space
	_imageToolbar.modulate.a = 1.0 if toolbar_visible else 0.0
	# Disable mouse interaction when hidden
	_imageToolbar.mouse_filter = Control.MOUSE_FILTER_STOP if toolbar_visible else Control.MOUSE_FILTER_IGNORE
	for child in _imageToolbar.get_children():
		if child is BaseButton:
			child.mouse_filter = Control.MOUSE_FILTER_STOP if toolbar_visible else Control.MOUSE_FILTER_IGNORE

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
	_fileTreeViewExplorer.TipsRequested.connect(_on_tips_requested)

	# Connect FilterSettings signals
	%FilterSettings.settings_applied.connect(_on_filter_settings_applied)
	%FilterSettings.settings_canceled.connect(_on_filter_settings_closed)

	# Connect ProjectHeader folder button
	_projectHeader.folder_button_pressed.connect(_on_project_header_folder_pressed)

func _on_tips_requested():
	_tipsDialog.show_dialog()

func ConfigureProject(selectedProjectItem):
	if selectedProjectItem == null:
		_currentProjectConfigured = false
		_currentProjectPath = ""
		_projectHeader.visible = false
		_fileTreeViewExplorer.SetNavigateToProjectButtonVisible(false)
		%GodotToggleButton.visible = false
		return

	_currentProjectConfigured = true
	_projectHeader.visible = true
	_fileTreeViewExplorer.SetNavigateToProjectButtonVisible(true)
	%GodotToggleButton.visible = true

	# Configure project header with project item
	_projectHeader.configure(selectedProjectItem)

	# Store project path for navigation
	_currentProjectPath = selectedProjectItem.GetProjectPath()

	# Navigate to and highlight the project folder in the file tree
	if _currentProjectPath and not _currentProjectPath.is_empty():
		_fileTreeViewExplorer.NavigateToPath(_currentProjectPath)

func _on_project_header_folder_pressed(_path: String):
	# Open project folder when folder button is pressed
	if _currentProjectPath and not _currentProjectPath.is_empty():
		FileHelper.OpenFilePathInWindowsExplorer(_currentProjectPath)

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
			var fileExt = "." + filePath.get_extension().to_lower()
			var audioExtensions = [".ogg", ".mp3", ".wav", ".aac"]
			if fileExt in audioExtensions:
				would_show_preview = false

		# Strobe the toggle button to hint the user can hide project view
		if would_show_preview:
			_strobe_button(%GodotToggleButton)
		return

	var selectedFiles = _fileTreeViewExplorer.GetSelectedFiles()

	# Check if audio filter is active - if so, always use sound player grid for audio files
	if _fileTreeViewExplorer.IsAudioFilterActive():
		var fileExt = "." + filePath.get_extension().to_lower()

		if fileExt in _audioExtensions:
			# Audio file(s) with audio filter active - use sound player grid
			ShowSoundPlayerGrid(selectedFiles)
			if selectedFiles.size() > 1:
				%PathLabel.text = "%d audio files selected" % selectedFiles.size()
			else:
				%PathLabel.text = filePath

			# Auto-play if checkbox is checked and single file selected
			if _autoPlayCheckBox.button_pressed and selectedFiles.size() == 1:
				_playAudioFile(filePath)

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
		# Always show sound player grid when audio filter is active (even if empty)
		ShowSoundPlayerGrid(audioFiles)
		if audioFiles.size() > 0:
			%PathLabel.text = "%s (%d audio files)" % [dirPath, audioFiles.size()]
		else:
			%PathLabel.text = "%s (no audio files)" % dirPath
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

# Play an audio file using the auto-play audio player
func _playAudioFile(filePath: String):
	# Stop any currently playing audio
	_autoPlayAudioPlayer.stop()

	# Load the audio stream
	var stream = _loadAudioStream(filePath)
	if stream:
		_autoPlayAudioPlayer.stream = stream
		_autoPlayAudioPlayer.play()
		_lastAutoPlayedFile = filePath

# Load an audio stream from file path
func _loadAudioStream(filePath: String) -> AudioStream:
	var extension = filePath.get_extension().to_lower()

	# For files within the project, use the resource loader
	if filePath.begins_with("res://"):
		return load(filePath) as AudioStream

	# For external files, load from filesystem
	match extension:
		"wav":
			return AudioStreamWAV.load_from_file(filePath)
		"mp3":
			var file = FileAccess.open(filePath, FileAccess.READ)
			if file:
				var data = file.get_buffer(file.get_length())
				file.close()
				var stream = AudioStreamMP3.new()
				stream.data = data
				return stream
		"ogg":
			return AudioStreamOggVorbis.load_from_file(filePath)

	return null

# Show the file previewer and hide other views
func ShowFilePreviewer():
	_filePreviewer.visible = true
	_soundPlayerGrid.visible = false
	# Don't hide DestinationTreeView here - it's controlled by the Godot toggle button

func _on_back_button_pressed() -> void:
	visible = false

func _on_navigate_to_project_requested() -> void:
	# Navigate to the project root folder in the file tree view explorer
	# Reset the tree and expand all folders in the path
	if _currentProjectPath and not _currentProjectPath.is_empty():
		var projectRoot = _currentProjectPath.get_base_dir()
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
	if toggled_on and _currentProjectPath:
		await %DestinationTreeView.InitializeProjectTree(_currentProjectPath)

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

	# Get destination path from left tree view (asset finder)
	var destinationPath = _fileTreeViewExplorer.GetCurrentPath()
	if not destinationPath or destinationPath.is_empty():
		OS.alert("Please select a destination folder in the Asset Finder.")
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

	# Get destination path from left tree view (asset finder)
	var destinationPath = _fileTreeViewExplorer.GetCurrentPath()
	print("Destination path: ", destinationPath)
	if not destinationPath or destinationPath.is_empty():
		print("No destination selected - exiting")
		OS.alert("Please select a destination folder in the Asset Finder.")
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
	# Show auto-play checkbox only when Sounds filter is selected (index 2)
	var isSoundsFilter = (index == 2)
	_autoPlayCheckBox.visible = isSoundsFilter
	# Hide spacer when checkbox is visible (checkbox provides enough separation)
	%FiltersSpacer.visible = not isSoundsFilter
	# Show audio toolbar only when Sounds filter is selected
	_audioToolbar.visible = isSoundsFilter
	# Completely hide image toolbar when sounds filter is active (don't preserve space)
	_imageToolbar.visible = not isSoundsFilter
	# Stop any playing audio when switching filters
	if not isSoundsFilter:
		_autoPlayAudioPlayer.stop()
		_lastAutoPlayedFile = ""

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
	App.SetImagePreviewBackgroundColor(color)

# Load image background color from App settings
func _loadImageBackgroundColor():
	var color = App.GetImagePreviewBackgroundColor()
	_backgroundColorPicker.color = color
	_filePreviewer.SetImageBackgroundColor(color)

# Initialize audio volume to 20% and connect slider
func _initAudioVolume():
	_volumeSlider.value = 20
	_applyVolume(20)
	_volumeSlider.value_changed.connect(_on_volume_slider_changed)

func _on_volume_slider_changed(value: float):
	_applyVolume(value)

func _applyVolume(percent: float):
	# Convert percent (0-100) to linear volume (0-1) then to dB
	var linear = percent / 100.0
	var db = linear_to_db(linear)
	# Apply to master audio bus (affects all sounds including auto-play and SoundPlayerGrid)
	var masterBusIdx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(masterBusIdx, db)
	_volumeValueLabel.text = "%d%%" % int(percent)

# Search signal handlers
func _on_search_button_pressed() -> void:
	_execute_search()

func _on_search_submitted(_text: String) -> void:
	# Enter key pressed in search field
	_execute_search()

func _on_regex_mode_toggled(_pressed: bool) -> void:
	# Only search if there's a query
	if not _searchLineEdit.text.is_empty():
		_execute_search()

# Execute the search with current settings
func _execute_search() -> void:
	# Prevent multiple concurrent searches
	if _isSearchInProgress:
		return

	_isSearchInProgress = true

	# Disable controls during search
	_searchButton.disabled = true
	_searchLineEdit.editable = false

	# Show busy indicator
	_fileTreeViewExplorer.ShowBusyIndicator()

	# Wait a frame for UI to render the busy indicator
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for good measure

	# Execute the search (always deep search)
	var query = _searchLineEdit.text
	var is_regex = _regexToggleButton.button_pressed
	await _fileTreeViewExplorer.ApplySearch(query, is_regex, true)

	# Wait 0.4 seconds before re-enabling to prevent rapid re-clicks
	await get_tree().create_timer(0.4).timeout

	# Re-enable controls
	_searchButton.disabled = false
	_searchLineEdit.editable = true
	_isSearchInProgress = false

	# Hide busy indicator (search functions already hide it, but ensure it's hidden)
	_fileTreeViewExplorer.HideBusyIndicator()

# Get current search query (used by filter to combine with search)
func GetCurrentSearchQuery() -> String:
	return _searchLineEdit.text
