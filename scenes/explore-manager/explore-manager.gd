extends Panel
class_name ExploreManager

@onready var fileExplorer: Control = %FileExplorer
@onready var filePreviewer: Control = %FilePreviewer

func _ready():
	# Connect FileExplorer signals to FilePreviewer
	fileExplorer.file_selected.connect(_on_file_selected)
	fileExplorer.directory_selected.connect(_on_directory_selected)

func _on_file_selected(filePath: String):
	"""Handle when a file is selected in the explorer"""
	print("File selected for preview: " + filePath)
	
	# Check if the file is supported for preview
	if filePreviewer.IsFileSupported(filePath):
		filePreviewer.PreviewFile(filePath)
	else:
		# Show file info for unsupported files
		filePreviewer.PreviewFile(filePath)  # Will show "unsupported" message

func _on_directory_selected(dirPath: String):
	"""Handle when a directory is selected"""
	print("Directory selected: " + dirPath)
	
	# Clear preview when directory is selected
	filePreviewer.ClearPreview()

# Example main scene structure:
# Main (Control)
# ├── HSplitContainer
#     ├── FileExplorer (Control) - your existing file explorer
#     └── FilePreviewer (Control) - the new file previewer
