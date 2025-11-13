extends Node
class_name FileHelper

# Check if filename is a Windows reserved device name
static func IsWindowsReservedName(fileName: String) -> bool:
	var baseName = fileName.get_basename().to_upper()
	var reserved = ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]
	return baseName in reserved

static func IsDirectoryEmpty(directoryPath: String) -> bool:
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
#
## Entry point that is recursively called as we crawl folders.
#static func CopyDirectory(pathOfDirectory, destinationPath : String):
	#destinationPath = destinationPath.trim_suffix("/")
	#
	#var directoryToCopy = DirAccess.open(pathOfDirectory)
	#if not directoryToCopy:
		#OS.alert("Failed to find/open directory at path: " + pathOfDirectory)
		#return -1
	#var err
	#if !DirAccess.dir_exists_absolute(destinationPath):
		#err = DirAccess.make_dir_recursive_absolute(destinationPath)
		#if err != OK:
			#return err
#
	#var destinationFolder = DirAccess.open(destinationPath)	
	#destinationFolder.change_dir(destinationPath)
	#
	#err = CopyFilesRecursive(directoryToCopy, destinationPath)
	#if err != null && err != OK:
		#return err
		#
	#directoryToCopy.list_dir_end()
	#return destinationPath
#
#static func CopyFilesRecursive(directoryToCopy: DirAccess, destinationPath: String):
	#directoryToCopy.list_dir_begin()
	#var fileName = directoryToCopy.get_next()
	#while fileName != "":
		#if directoryToCopy.current_is_dir():
			#CopyDirectory(directoryToCopy.get_current_dir() + "/" + fileName, destinationPath + "/" + fileName)
		#else:
			#directoryToCopy.copy(directoryToCopy.get_current_dir() + "/" + fileName, destinationPath + "/" + fileName)
		#fileName = directoryToCopy.get_next()

# Copy contents of folder to specified destination
static func CopyFoldersAndFilesRecursive(sourcePath: String, absoluteOutputPath: String, sourceFilters : Array = []):
	if not DirAccess.dir_exists_absolute(absoluteOutputPath):
		DirAccess.make_dir_recursive_absolute(absoluteOutputPath)

	var fileOrDir = DirAccess.open(sourcePath)
	if fileOrDir != null:
		fileOrDir.list_dir_begin()
		var sourceName = fileOrDir.get_next()
		while sourceName != "":
			if sourceName == "." || sourceName == "..":
				sourceName = fileOrDir.get_next()
				continue

			# Skip Windows reserved device names (CON, NUL, PRN, etc.)
			if IsWindowsReservedName(sourceName):
				sourceName = fileOrDir.get_next()
				continue

			var fileOrFolderPath = sourcePath
			if sourcePath != "res://":
				fileOrFolderPath += "/"

			fileOrFolderPath += sourceName
			if fileOrDir.current_is_dir():
				var filterPath = fileOrFolderPath.trim_prefix("res://")
				var foundFilteredItem = false
				for sourceFilter in sourceFilters:
					if filterPath.find(sourceFilter) >= 0:
						foundFilteredItem = true
						break

				if foundFilteredItem:
					sourceName = fileOrDir.get_next()
					continue

				CopyFoldersAndFilesRecursive(fileOrFolderPath, absoluteOutputPath + "/" + sourceName, sourceFilters)
			else:
				var filterPath = fileOrFolderPath.trim_prefix("res://")
				var filterIndex = sourceFilters.find(filterPath)
				if filterIndex >= 0:
					sourceName = fileOrDir.get_next()
					continue

				# Skip Windows reserved device names (CON, NUL, PRN, etc.)
				if IsWindowsReservedName(sourceName):
					sourceName = fileOrDir.get_next()
					continue

				fileOrDir.copy(fileOrFolderPath, absoluteOutputPath + "/" + sourceName)

			sourceName = fileOrDir.get_next()
	
	return OK

static func FindFirstFileWithExtension(path, extension):
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
	
static func GetFilesFromPath(path, isIncludingDotFiles = false, isIncludingDirectories = true):
	var files = []
	if !DirAccess.dir_exists_absolute(path):
		return files
		
	var dir = DirAccess.open(path)
	dir.list_dir_begin() # TODOGODOT4 fill missing arguments https://github.com/godotengine/godot/pull/40547

	while true:
		var file = dir.get_next()
		if file == "":
			break
			
		if dir.current_is_dir():
			if isIncludingDirectories:
				files.append(file)
			else:
				continue
		elif isIncludingDotFiles:
			files.append(file)
		elif !file.begins_with("."):
			files.append(file)

	dir.list_dir_end()

	return files

static func GetFileAsText(filePath):
	if FileAccess.file_exists(filePath):
		var file = FileAccess.open(filePath, FileAccess.READ)
		return file.get_as_text()

# Deletes everything in the directory and all sub-directories.
# Carefully review and Use with caution
static func DeleteAllFilesAndFolders(folderPath, filesToIgnore = [], isSendingToRecycle = true, isIncludingDotFiles = false):
	if !DirAccess.dir_exists_absolute(folderPath):
		return OK  # Nothing to delete, consider it success

	var filePaths = GetFilesFromPath(folderPath, isIncludingDotFiles)
	for filePath in filePaths:
		if filesToIgnore.find(filePath) >= 0:
			continue

		var err = OK
		var fullFilePath = folderPath.path_join(filePath)

		# Check if it's a directory - need to recursively delete contents first
		if DirAccess.dir_exists_absolute(fullFilePath):
			# Recursively delete subdirectory contents
			err = DeleteAllFilesAndFolders(fullFilePath, [], isSendingToRecycle, isIncludingDotFiles)
			if err != OK:
				return -1

		if isSendingToRecycle:
			# Send to recycle so we can recover if needed
			err = OS.move_to_trash(fullFilePath)
		else:
			# Delete file or empty directory
			if FileAccess.file_exists(fullFilePath):
				err = DirAccess.remove_absolute(fullFilePath)
			elif DirAccess.dir_exists_absolute(fullFilePath):
				err = DirAccess.remove_absolute(fullFilePath)

		if err != OK:
			return -1

	return OK
	
static func GetLinesFromFile(path):
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

static func CreateDirectory(directoryName):
	if !DirAccess.dir_exists_absolute(directoryName):
		return DirAccess.make_dir_recursive_absolute(directoryName)
	
	return OK

static func CreateChecksum(filePath):
	const CHUNK_SIZE = 1024
	if not FileAccess.file_exists(filePath):
		return

	# Start a SHA-256 context.
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)

	# Open the file to hash.
	var file = FileAccess.open(filePath, FileAccess.READ)

	# Update the context after reading each chunk.
	while not file.eof_reached():
		var buffer = file.get_buffer(CHUNK_SIZE)
		if buffer.size() > 0:
			ctx.update(buffer)

	# Get the computed hash.
	var res = ctx.finish()

	return res.hex_encode()

# Passing in empty allowedExtensions returns all files.
# allowedExtensions example: = ["gd", "tscn"]
static func GetFilesRecursive(path: String, allowedExtensions : Array) -> Array:
	var results := []
	var dir := DirAccess.open(path)
	if dir == null:
		return results

	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		var fullPath := path + "/" + filename
		if dir.current_is_dir():
			if filename != "." and filename != "..":
				results += GetFilesRecursive(fullPath, allowedExtensions)
		elif allowedExtensions == null || allowedExtensions.size() == 0:
			# No filter used, add any/all files.
			results.append(fullPath)
		else:
			for extension in allowedExtensions:
				if filename.ends_with("." + extension):
					results.append(fullPath)
					break

		filename = dir.get_next()

	dir.list_dir_end()
	return results

# Open the file or folder in Windows Explorer
static func OpenFilePathInWindowsExplorer(filePath: String):
	if filePath.is_empty():
		return
	
	# Check if it's a file or directory
	var dir = DirAccess.open(filePath)

	if dir != null:
		OpenDirectoryInExplorer(filePath)
	else:
		OpenFileInExplorer(filePath)

# Open a directory in Windows Explorer
static func OpenDirectoryInExplorer(dirPath: String):
	var normalizedPath = dirPath.replace("/", "\\")
	var args = [normalizedPath]
	OS.execute("explorer.exe", args)

# Open Windows Explorer and select the specified file
# Using cmd.exe because explorer.exe doesn't work with /select 
# for some reason.
static func OpenFileInExplorer(filePath: String):
	var normalizedPath = filePath.replace("/", "\\")
	var command = "explorer.exe /select,\"" + normalizedPath + "\""
	OS.execute("cmd.exe", ["/c", command])

static func OpenFileWithDefaultProgram(filePath: String):
	"""Open the file with its default associated program"""
	if filePath.is_empty():
		print("Empty file path provided")
		return
	
	print("Opening file with default program: " + filePath)
	OS.shell_open(filePath)

# Alternative method using shell_open for directories
static func OpenDirectoryWithShellOpen(dirPath: String):
	"""Alternative method to open directory using shell_open"""
	print("Opening directory with shell_open: " + dirPath)
	OS.shell_open(dirPath)

# Utility function to check if path exists
static func PathExists(path: String) -> bool:
	"""Check if a file or directory exists"""
	var file = FileAccess.open(path, FileAccess.READ)
	if file != null:
		file.close()
		return true
	
	var dir = DirAccess.open(path)
	return dir != null

# Enhanced version with error handling
static func OpenFilePathInWindowsExplorerSafe(filePath: String) -> bool:
	"""Safe version with error handling - returns true if successful"""
	if filePath.is_empty():
		print("Error: Empty file path provided")
		return false
	
	if not PathExists(filePath):
		print("Error: Path does not exist: " + filePath)
		return false
	
	var normalizedPath = filePath.replace("/", "\\")
	var dir = DirAccess.open(filePath)
	
	if dir != null:
		# It's a directory
		var result = OS.execute("explorer.exe", [normalizedPath])
		if result != 0:
			print("Error opening directory, trying alternative method")
			OS.shell_open(filePath)
		return true
	else:
		# It's a file
		var result = OS.execute("explorer.exe", ["/select,", normalizedPath])
		if result != 0:
			print("Error opening file in explorer, result code: " + str(result))
			return false
		return true
		
