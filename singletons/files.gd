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
