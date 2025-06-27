extends Panel
@onready var _projectNameLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/ProjectNameLabel
@onready var _godotVersionLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer2/HBoxContainer/HBoxContainer/GodotVersionLabel
@onready var _projectPathLabel = %ProjectPathLabel
@onready var _hideProjectCheckbox = %HideProjectCheckbox
@onready var _projectVersionLabel = $MarginContainer/HBoxContainer/VBoxContainer/MarginContainer3/ProjectVersionLabel

var _selected := false
var _windowsChecked := false
var _linuxChecked := false
var _webChecked := false
var _macOsChecked := false
var _sourceChecked := false
var _obfuscateFunctionsChecked := false
var _obfuscateVariablesChecked := false
var _obfuscateCommentsChecked := false
var _isHidden := false
var _showTipsForErrors := false

var _godotVersionId := ""
var _projectId := ""
var _exportPath := ""
var _exportType := ""
var _exportFileName := ""
var _packageType := ""
var _itchProjectName := ""
var _itchProfileName := ""
var _installerConfigurationFileName := ""
var _projectName = ""
var _godotVersion = ""
var _projectPath = ""
var _projectVersion = ""
var _thumbnailPath := ""

var _publishedDate : Dictionary = {}
var _createdDate : Dictionary = {}
var _editedDate : Dictionary = {}

var _sourceFilters := []



# Fields



func _ready():
	InitSignals()
	RefreshBackground()
	UpdateProjectItemUi()

func InitSignals():
	Signals.connect("BackgroundColorChanged", BackgroundColorChanged)

func UpdateProjectItemUi():
	_projectNameLabel.text = _projectName
	_godotVersionLabel.text = _godotVersion
	_projectPathLabel.text = _projectPath
	_projectVersionLabel.text = _projectVersion
	_hideProjectCheckbox.button_pressed = _isHidden
	%CreatedDateLabel.text = "Created: " + Date.GetCurrentDateAsString(_createdDate)
	%EditedDateLabel.text = "Edited: " + Date.GetCurrentDateAsString(_editedDate)
	%PublishedDateLabel.text = "Published: " + Date.GetCurrentDateAsString(_publishedDate)
	if _thumbnailPath != "":
		LoadThumbnailImage()

func LoadThumbnailImage():
	var image = Image.new()
	var error = image.load(_thumbnailPath)
	if error == OK:
		var texture = ImageTexture.create_from_image(image)
		%ThumbTextureRect.texture = texture
	
func BackgroundColorChanged(_color = null):
	RefreshBackground()

func RefreshBackground():
	theme = GetDefaultTheme()	

func SetGodotVersionId(value):
	_godotVersionId = value
	
func SetProjectVersion(value):
	_projectVersion = value

func SetThumbnailPath(value):
	_thumbnailPath = value
	
func SetProjectPath(value):
	_projectPath = value

func SetExportFileName(value):
	_exportFileName = value
	
func SetProjectName(value):
	_projectName = value
	
func SetGodotVersion(value):
	_godotVersion = value

func SetItchProjectName(value):
	_itchProjectName = value

func SetWindowsChecked(value):
	_windowsChecked = value

func SetLinuxChecked(value):
	_linuxChecked = value
	
func SetWebChecked(value):
	_webChecked = value

func SetMacOsChecked(value):
	_macOsChecked = value

func SetSourceChecked(value):
	_sourceChecked = value
		
func SetExportPath(value):
	_exportPath = value
	
func SetExportType(value):
	_exportType = value
	
func SetPackageType(value):
	_packageType = value

func SetItchProfileName(value):
	_itchProfileName = value

func SetShowTipsForErrors(value):
	_showTipsForErrors = value
	
func SetPublishedDate(value):
	_publishedDate = value

func SetSourceFilters(value):
	_sourceFilters = value

func SetObfuscateFunctionsChecked(value : bool):
	_obfuscateFunctionsChecked = value

func SetObfuscateVariablesChecked(value : bool):
	_obfuscateVariablesChecked = value	

func SetObfuscateCommentsChecked(value : bool):
	_obfuscateCommentsChecked = value
	
func SetCreatedDate(value):
	_createdDate = value
	
func SetEditedDate(value):
	_editedDate = value
	
func SetProjectId(value):
	_projectId = value

func SetInstallerConfigurationFileName(value):
	_installerConfigurationFileName = value

func SetIsHidden(value):
	_isHidden = value
	
func GetProjectVersion():
	return _projectVersionLabel.text
	
func GetItchProjectName():
	return _itchProjectName

func GetWindowsChecked():
	return _windowsChecked

func GetLinuxChecked():
	return _linuxChecked	

func GetWebChecked():
	return _webChecked	

func GetMacOsChecked():
	return _macOsChecked

func GetSourceChecked():
	return _sourceChecked

func GetObfuscateFunctionsChecked():
	return _obfuscateFunctionsChecked

func GetObfuscateVariablesChecked():
	return _obfuscateVariablesChecked

func GetObfuscateCommentsChecked():
	return _obfuscateCommentsChecked
		
func GetExportType():
	return _exportType

func GetExportFileName():
	return _exportFileName
	
func GetPackageType():
	return _packageType

func GetItchProfileName():
	return _itchProfileName

func GetShowTipsForErrors():
	return _showTipsForErrors
	
func GetPublishedDate():
	return _publishedDate

func GetCreatedDate():
	return _createdDate
	
func GetEditedDate():
	return _editedDate
	
# Strip off the file name
# /project.godot
func GetProjectPathBaseDir():
	return _projectPathLabel.text.get_base_dir()

func GetThumbnailPath():
	return _thumbnailPath
	
func GetProjectPath():
	return _projectPathLabel.text
	
func GetProjectPathWithProjectFile():
	return _projectPathLabel.text
	
func GetGodotVersion():
	return _godotVersionLabel.text

func GetGodotVersionId():
	return _godotVersionId
	
func GetProjectName():
	return _projectNameLabel.text

func GetExportPath():
	return _exportPath
	
func GetProjectId():
	return _projectId

func GetSourceFilters():
	return _sourceFilters
	
func GetDefaultTheme():
	var customTheme = Theme.new()
	var styleBox = GetDefaultStyleBoxSettings()
	customTheme.set_stylebox("panel", "Panel", styleBox)
	return customTheme

func GetHoverTheme():
	var customTheme = Theme.new()
	var styleBox = GetDefaultStyleBoxSettings()
	styleBox.bg_color = AdjustBackgroundColor(0.001)
	customTheme.set_stylebox("panel", "Panel", styleBox)
	return customTheme

func GetSelectedTheme():
	var customTheme = Theme.new()
	var styleBox = GetDefaultStyleBoxSettings()
	styleBox.bg_color = AdjustBackgroundColor(0.32)
	customTheme.set_stylebox("panel", "Panel", styleBox)
	return customTheme

func GetIsHidden():
	return _hideProjectCheckbox.button_pressed
	
func AdjustBackgroundColor(amount):
	var colorToSubtract = Color(amount, amount, amount, 0.0)

	var newColor = Color(
		max(App.GetBackgroundColor().r + colorToSubtract.r, 0),
		max(App.GetBackgroundColor().g + colorToSubtract.g, 0),
		max(App.GetBackgroundColor().b + colorToSubtract.b, 0),
		max(App.GetBackgroundColor().a + colorToSubtract.a, 0)
	)
	
	return newColor
	
func GetDefaultStyleBoxSettings():
	var styleBox = StyleBoxFlat.new()
	styleBox.bg_color = AdjustBackgroundColor(-0.08)
	styleBox.border_color = Color(0.6, 0.6, 0.6)
	styleBox.border_width_left = 2
	styleBox.border_width_top = 2
	styleBox.border_width_right = 2
	styleBox.border_width_bottom = 2
	styleBox.corner_radius_top_left = 6
	styleBox.corner_radius_top_right = 6
	styleBox.corner_radius_bottom_right = 6
	styleBox.corner_radius_bottom_left = 6
	return styleBox
	
func GetGodotPath(godotVersionId):
	var files = FileHelper.GetFilesFromPath("user://godot-version-items")
	for file in files:
		if !file.ends_with(".cfg"):
			continue

		var fileName = file.trim_suffix(".cfg")
		if fileName != godotVersionId:
			continue
			
		var config = ConfigFile.new()
		var err = config.load("user://" + App.GetGodotVersionItemFolder() + "/" + fileName + ".cfg")
		if err == OK:
			return config.get_value("GodotVersionSettings", "godot_path", "???")

func GetFormattedProjectPath():
	return GetProjectPathBaseDir().to_lower()

func RestoreDefaultColor():
	theme = GetDefaultTheme()
	
func ShowHoverColor():
	theme = GetHoverTheme()
	
func ShowSelectedColor():
	theme = GetSelectedTheme()
	
func SelectProjectItem():
	ShowSelectedColor()
	_selected = true

func UnselectProjectItem():
	RestoreDefaultColor()
	_selected = false

func GetProjectSelected():
	return _selected
	
func SaveProjectItem():
	var config = ConfigFile.new()
	config.set_value("ProjectSettings", "project_name", _projectName)
	config.set_value("ProjectSettings", "export_path", _exportPath)
	config.set_value("ProjectSettings", "godot_version_id", _godotVersionId)
	config.set_value("ProjectSettings", "project_path", _projectPath)
	config.set_value("ProjectSettings", "export_file_name", _exportFileName)
	config.set_value("ProjectSettings", "project_version", _projectVersion)
	config.set_value("ProjectSettings", "windows_preset_checked", _windowsChecked)
	config.set_value("ProjectSettings", "linux_preset_checked", _linuxChecked)
	config.set_value("ProjectSettings", "web_preset_checked", _webChecked)
	config.set_value("ProjectSettings", "macos_preset_checked", _macOsChecked)
	config.set_value("ProjectSettings", "source_checked", _sourceChecked)
	config.set_value("ProjectSettings", "obfuscate_functions_checked", _obfuscateFunctionsChecked)
	config.set_value("ProjectSettings", "obfuscate_variables_checked", _obfuscateVariablesChecked)
	config.set_value("ProjectSettings", "obfuscate_comments_checked", _obfuscateCommentsChecked)
	config.set_value("ProjectSettings", "export_type", _exportType)
	config.set_value("ProjectSettings", "package_type", _packageType)
	config.set_value("ProjectSettings", "itch_profile_name", _itchProfileName)
	config.set_value("ProjectSettings", "show_tips_for_errors", _showTipsForErrors)
	config.set_value("ProjectSettings", "itch_project_name", _itchProjectName)
	config.set_value("ProjectSettings", "is_hidden", _hideProjectCheckbox.button_pressed)
	config.set_value("ProjectSettings", "published_date", _publishedDate)
	config.set_value("ProjectSettings", "created_date", _createdDate)
	config.set_value("ProjectSettings", "edited_date", _editedDate)
	config.set_value("ProjectSettings", "source_filters", _sourceFilters)
	config.set_value("ProjectSettings", "thumbnail_path", _thumbnailPath)
	
	# Save the config file.
	var err = config.save("user://" + App.GetProjectItemFolder() + "/" + _projectId + ".cfg")

	if err != OK:
		OS.alert("An error occurred while saving the config file.")

	Signals.emit_signal("ProjectSaved")

func HideProjectItem():
	visible = false
	
func ShowProjectItem():
	visible = true

func ShowThumbnailSelector():
	var file_dialog = FileDialog.new()
	add_child(file_dialog)
	
	# Configure the file dialog
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	if _thumbnailPath == "":
		file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	else:
		# Check if the thumbnail path exists and extract directory
		if FileAccess.file_exists(_thumbnailPath):
			file_dialog.current_dir = _thumbnailPath.get_base_dir()
			file_dialog.current_file = _thumbnailPath.get_file()  # Pre-select the current file
		else:
			# File doesn't exist, but try to use the directory if it exists
			var directory = _thumbnailPath.get_base_dir()
			if DirAccess.dir_exists_absolute(directory):
				file_dialog.current_dir = directory
			else:
				# Fall back to Pictures folder
				file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
			
	
	# Set up image file filters
	file_dialog.add_filter("*.png", "PNG Images")
	file_dialog.add_filter("*.jpg,*.jpeg", "JPEG Images")
	file_dialog.add_filter("*.bmp", "BMP Images")
	file_dialog.add_filter("*.svg", "SVG Images")
	file_dialog.add_filter("*.webp", "WebP Images")
	file_dialog.add_filter("*.tga", "TGA Images")
	file_dialog.add_filter("*.exr", "EXR Images")
	file_dialog.add_filter("*.hdr", "HDR Images")
	
	# Connect the file selected signal
	file_dialog.file_selected.connect(_on_thumbnail_file_selected)
	
	# Show the dialog
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_thumbnail_file_selected(filePath: String):
	# Check if file exists and is accessible
	if not FileAccess.file_exists(filePath):
		OS.alert("Error: File does not exist: " + filePath)
		return
	
	# Try to open the file first to check permissions
	var file = FileAccess.open(filePath, FileAccess.READ)
	if file == null:
		OS.alert("Error: Cannot access file (permissions?): " + filePath)
		return

	file.close()
	
	# Load the image
	var image = Image.new()
	var error = image.load(filePath)
	
	if error != OK:
		OS.alert("Error loading image: " + filePath + " Error code: " + str(error))
		return
	
	# Create texture and assign to TextureRect
	var texture = ImageTexture.create_from_image(image)
	%ThumbTextureRect.texture = texture
	_thumbnailPath = filePath
	SaveProjectItem()
	CleanupFileDialog()

func CleanupFileDialog():
	var fileDialog = get_children().filter(func(child): return child is FileDialog)[0]
	if fileDialog:
		fileDialog.queue_free()
		
func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Signals.emit_signal("ToggleProjectItemSelection", self, !_selected)

func _on_mouse_entered():
	if _selected:
		return
	
	ShowHoverColor()

func _on_mouse_exited():
	if _selected:
		return
	
	RestoreDefaultColor()

func _on_hide_check_box_pressed():
	SaveProjectItem()
	if _hideProjectCheckbox.button_pressed:
		Signals.emit_signal("HidingProjectItem")

func _on_thumb_texture_rect_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		ShowThumbnailSelector()
