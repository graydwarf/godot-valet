extends Panel
class_name ExploreManager

@onready var _fileTreeViewExplorer: Control = %FileTreeViewExplorer
@onready var _filePreviewer: Control = %FilePreviewer

func _ready():
	# Connect FileExplorer signals to FilePreviewer
	_fileTreeViewExplorer.file_selected.connect(_on_file_selected)
	_fileTreeViewExplorer.directory_selected.connect(_on_directory_selected)

# Handle when a file is selected in the file tree view explorer
func _on_file_selected(filePath: String):
	# print("File selected for preview: " + filePath)
	
	# Is supported for preview?
	if _filePreviewer.IsFileSupported(filePath):
		_filePreviewer.PreviewFile(filePath)
	else:
		# Show file info for unsupported files
		# TODO: ???? Improve
		_filePreviewer.PreviewFile(filePath)
	
	%PathLabel.text = filePath

func _on_directory_selected(dirPath: String):
	# Clear preview when directory is selected
	_filePreviewer.ClearPreview()
	%PathLabel.text = dirPath

func _on_back_button_pressed() -> void:
	visible = false
