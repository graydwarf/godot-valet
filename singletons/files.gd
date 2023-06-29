extends Node

func IsDirectoryEmpty(directoryPath: String) -> bool:
	var dir = DirAccess.open(directoryPath)
	dir.include_hidden = true
	dir.include_navigational = false

	if dir == null:
		OS.alert("Failed to open directory:", directoryPath)
		return false
	
	dir.list_dir_begin()
	var file_name = dir.get_next()

	if file_name != "":
		return false

	dir.list_dir_end()
	return true

# Copy contents of folder to specified destination
func CopySourceToDestinationRecursive(sourcePath: String, destinationPath: String) -> void:
	if not DirAccess.dir_exists_absolute(destinationPath):
		DirAccess.make_dir_recursive_absolute(destinationPath)

	var sourceDirectory = DirAccess.open(sourcePath)
	if sourceDirectory != null:
		sourceDirectory.list_dir_begin()
		var sourceName = sourceDirectory.get_next()
		while sourceName != "":
			if sourceName == "." || sourceName == "..":
				sourceName = sourceDirectory.get_next()
				continue
				
			if sourceDirectory.current_is_dir():
				CopySourceToDestinationRecursive(sourcePath + "/" + sourceName, destinationPath + "/" + sourceName)
			else:
				sourceDirectory.copy(sourcePath + "/" + sourceName, destinationPath + "/" + sourceName)

			sourceName = sourceDirectory.get_next()

func FindFirstFileWithExtension(path, extension):
	if !DirAccess.dir_exists_absolute(path):
		return null
		
	var dir = DirAccess.open(path)
	dir.list_dir_begin()

	while true:
		var file = dir.get_next()
		if file.get_extension().length() == 0:
			continue
		if file.begins_with("."):
			continue
		if file.ends_with(extension):
			return file

	dir.list_dir_end()

	return null
	
func GetFilesFromPath(path):
	var files = []
	if !DirAccess.dir_exists_absolute(path):
		return files
		
	var dir = DirAccess.open(path)
	dir.list_dir_begin() # TODOGODOT4 fill missing arguments https://github.com/godotengine/godot/pull/40547

	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with("."):
			files.append(file)

	dir.list_dir_end()

	return files

func GetFileAsText(filePath):
	if FileAccess.file_exists(filePath):
		var file = FileAccess.open(filePath, FileAccess.READ)
		return file.get_as_text()

# Deletes everything in the directory and all sub-directories.
# Carefully review and Use with caution
func DeleteAllFilesAndFolders(folderPath, isSendingToRecycle = true, listOfExistingFilesToLeaveAlone = []):
	var filePaths = GetFilesFromPath(folderPath)
	for filePath in filePaths:
		if listOfExistingFilesToLeaveAlone.find(filePath) >= 0:
			continue
			
		var err = OK
		if isSendingToRecycle:
			# Send to recycle so we can recover if needed
			err = OS.move_to_trash(folderPath + "\\" + filePath) 
		else:
			# Delete without backup
			err = DirAccess.remove_absolute(filePath)
		
		if err != OK:
			return -1
	
	return OK
	
func GetLinesFromFile(path):
	var result = {}
	var file = FileAccess.open(path, FileAccess.READ)
	var listOfLines = []
	if file != null:
		while file.get_position() < file.get_length():
			listOfLines.append(file.get_line())
	else:
		result.error = "Failed to retrieve project name from the godot project file."
		return result

	return listOfLines

func CreateDirectory(directoryName):
	if !DirAccess.dir_exists_absolute(directoryName):
		return DirAccess.make_dir_recursive_absolute(directoryName)
	
	return OK
	
