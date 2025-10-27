extends Panel
class_name FileExplorer

# - Generated with assistance from Claude 4 Sonnet (Anthropic) - December 2024

@onready var _fileTreeViewExplorer: Control = %FileTreeViewExplorer
@onready var _filePreviewer: Control = %FilePreviewer

func _ready():
	InitSignals()
	ShowFileExplorerStep()
	
func InitSignals():
	_fileTreeViewExplorer.FileSelected.connect(_on_file_selected)
	_fileTreeViewExplorer.DirectorySelected.connect(_on_directory_selected)

func ShowFileExplorerStep():
	%FileTreeViewExplorer.visible = true
	%ProjectTreeView.visible = false
	%ChooseDestinationButton.visible = true
	%ImportButton.visible = false
	%CancelButton.visible = false
	%BackButton.visible = true

func ShowDestinationStep():
	%FileTreeViewExplorer.visible = false
	%ProjectTreeView.visible = true
	%ChooseDestinationButton.visible = false
	%ImportButton.visible = true
	%ProjectTreeView.InitializeProjectTree(%ProjectPathLineEdit.text)
	%BackButton.visible = false
	%CancelButton.visible = true
	
func ConfigureProject(selectedProjectItem):
	if selectedProjectItem == null:
		%ProjectContextContainer.visible = false
		%ChooseDestinationButton.visible = false
		return
	
	%ProjectContextContainer.visible = true
	%ChooseDestinationButton.visible = true
	LoadThumbnailImage(selectedProjectItem.GetThumbnailPath())
	%ProjectNameLineEdit.text = selectedProjectItem.GetProjectName()
	%ProjectPathLineEdit.text = selectedProjectItem.GetProjectPath()
	ShowFileExplorerStep()

func LoadThumbnailImage(thumbnailPath):
	var image = Image.new()
	var error = image.load(thumbnailPath)
	if error == OK:
		var texture = ImageTexture.create_from_image(image)
		%ProjectThumbnailTextureRect.texture = texture

func PerformImport(files: Array[String], destinationPath: String):
	var successCount = 0
	for filePath in files:
		var fileName = filePath.get_file()
		var destFile = destinationPath + "/" + fileName
		
		if CopyFile(filePath, destFile):
			successCount += 1
		else:
			OS.alert("Failed to copy: " + fileName)
	
	OS.alert("Import completed! " + str(successCount) + "/" + str(files.size()) + " files copied")
	
	# Return to file explorer step
	ShowFileExplorerStep()

func CopyFile(sourcePath: String, destPath: String) -> bool:
	if "::" in sourcePath:
		return CopyFileFromZip(sourcePath, destPath)
	else:
		return CopyRegularFile(sourcePath, destPath)

func CopyRegularFile(sourcePath: String, destPath: String) -> bool:
	var sourceFile = FileAccess.open(sourcePath, FileAccess.READ)
	if sourceFile == null:
		return false
	
	var destFile = FileAccess.open(destPath, FileAccess.WRITE)
	if destFile == null:
		sourceFile.close()
		return false
	
	destFile.store_buffer(sourceFile.get_buffer(sourceFile.get_length()))
	sourceFile.close()
	destFile.close()
	return true

func CopyFileFromZip(zipFilePath: String, destPath: String) -> bool:
	var parts = zipFilePath.split("::")
	var zipPath = parts[0]
	var internalPath = parts[1]
	
	var zip = ZIPReader.new()
	var error = zip.open(zipPath)
	if error != OK:
		return false
	
	var fileData = zip.read_file(internalPath)
	zip.close()
	
	if fileData.size() == 0:
		return false
	
	var destFile = FileAccess.open(destPath, FileAccess.WRITE)
	if destFile == null:
		return false
	
	destFile.store_buffer(fileData)
	destFile.close()
	return true
	
# Handle when a file is selected in the file tree view explorer
func _on_file_selected(filePath: String):
	if _filePreviewer:
		_filePreviewer.PreviewFile(filePath)
	%PathLabel.text = filePath

func _on_directory_selected(dirPath: String):
	if _filePreviewer:
		_filePreviewer.PreviewDirectory(dirPath)
	%PathLabel.text = dirPath

func _on_back_button_pressed() -> void:
	visible = false

func _on_open_project_path_folder_pressed() -> void:
	FileHelper.OpenFilePathInWindowsExplorer(%ProjectPathLineEdit.text)

func _on_choose_destination_button_pressed() -> void:
	var selectedFiles = %FileTreeViewExplorer.GetSelectedFiles()
	
	if selectedFiles.is_empty():
		OS.alert("No files selected for import.")
		return
	
	ShowDestinationStep()

func _on_import_button_pressed() -> void:
	var selectedFiles = %FileTreeViewExplorer.GetSelectedFiles()
	var destinationPath = %ProjectTreeView.GetSelectedDestination()
	
	if destinationPath.is_empty():
		OS.alert("No destination folder selected")
		return
	
	PerformImport(selectedFiles, destinationPath)

func _on_cancel_button_pressed() -> void:
	ShowFileExplorerStep()
