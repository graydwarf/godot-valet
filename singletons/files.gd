extends Node

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

func DeleteAllFilesAndFolders(folderPath, isSendingToRecycle = true, listOfExistingFilesToLeaveAlone = []):
	var errors = []
	var filePaths = GetFilesFromPath(folderPath)
	for filePath in filePaths:
		if listOfExistingFilesToLeaveAlone.find(filePath) >= 0:
			continue
			
		var error = 0
		if isSendingToRecycle:
			# Send to recycle so we can recover if needed
			error = OS.move_to_trash(folderPath + "\\" + filePath) 
		else:
			# Delete without backup
			error = DirAccess.remove_absolute(filePath)
		
		if error != 0:
			errors.append(error)
			
	return errors
