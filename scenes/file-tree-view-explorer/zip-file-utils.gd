class_name ZipFileUtils
extends RefCounted

# Zip File Utilities - Pure utility functions for working with zip archives
# Extracted from file-tree-view-explorer.gd to reduce file size

# Default zip extensions
const DEFAULT_ZIP_EXTENSIONS = [".zip", ".rar", ".7z", ".tar", ".gz"]

# Check if a file path is a zip archive based on extension
static func IsZipFile(filePath: String, zipExtensions: Array = DEFAULT_ZIP_EXTENSIONS) -> bool:
	var extension = filePath.get_extension().to_lower()
	return ("." + extension) in zipExtensions

# Open a zip file and return a ZIPReader (caller must close it)
static func OpenZipFile(zipPath: String) -> ZIPReader:
	var zip = ZIPReader.new()
	var error = zip.open(zipPath)
	if error != OK:
		return null
	return zip

# Get contents of zip file organized by directories and files at root level
static func GetZipContents(zipPath: String) -> Dictionary:
	var zip = OpenZipFile(zipPath)
	if zip == null:
		return {}

	var contents = {"directories": [], "files": []}
	var files = zip.get_files()
	var directories = {}

	for file in files:
		if file.ends_with("/"):
			# It's a directory
			var dirName = file.trim_suffix("/")
			if not "/" in dirName:  # Root level directory
				contents.directories.append(dirName)
		else:
			# It's a file
			if not "/" in file:  # Root level file
				contents.files.append(file)
			else:
				# File in subdirectory - track the directory
				var dirName = file.split("/")[0]
				directories[dirName] = true

	# Add directories that contain files but weren't explicitly listed
	for dir in directories.keys():
		if not dir in contents.directories:
			contents.directories.append(dir)

	zip.close()
	return contents

# Check if a path inside a zip is a directory
static func IsZipDirectory(zipPath: String, internalPath: String) -> bool:
	var zip = ZIPReader.new()
	var error = zip.open(zipPath)
	if error != OK:
		return false

	var files = zip.get_files()
	var targetPath = internalPath
	if not targetPath.ends_with("/"):
		targetPath += "/"

	# Check if this path exists as a directory in the zip
	for file in files:
		if file == targetPath or file.begins_with(targetPath):
			zip.close()
			return true

	zip.close()
	return false

# Get list of files inside a zip directory that match given extensions
static func GetFilesInZipDirectory(zipPath: String, internalPath: String, extensions: Array) -> Array[String]:
	var result: Array[String] = []
	var zip = OpenZipFile(zipPath)
	if not zip:
		return result

	var files = zip.get_files()
	var searchPrefix = internalPath
	if searchPrefix != "" and not searchPrefix.ends_with("/"):
		searchPrefix += "/"

	for file in files:
		if file.begins_with(searchPrefix) and not file.ends_with("/"):
			var relativePath = file.substr(searchPrefix.length())
			# Only files in this directory (not subdirectories)
			if not "/" in relativePath:
				var extension = "." + relativePath.get_extension().to_lower()
				if extension in extensions:
					result.append(zipPath + "::" + file)

	zip.close()
	result.sort()
	return result

# Recursively scan zip for files matching extensions
static func ScanZipRecursively(zipPath: String, basePath: String, extensions: Array, checkFunc: Callable) -> Array[String]:
	var result: Array[String] = []
	var zip = ZIPReader.new()
	var error = zip.open(zipPath)
	if error != OK:
		return result

	var files = zip.get_files()
	var searchPrefix = basePath
	if searchPrefix != "" and not searchPrefix.ends_with("/"):
		searchPrefix += "/"

	for file in files:
		if file.begins_with(searchPrefix) and not file.ends_with("/"):
			var fileName = file.get_file()
			if checkFunc.call(fileName):
				var fullPath = zipPath + "::" + file
				result.append(fullPath)

	zip.close()
	return result

# Check if zip contains any files matching given extensions in a directory (recursive)
static func HasFilteredContent(zipPath: String, basePath: String, filterExtensions: Array) -> bool:
	var zip = OpenZipFile(zipPath)
	if zip == null:
		return false

	var files = zip.get_files()
	var searchPrefix = basePath
	if not searchPrefix.ends_with("/"):
		searchPrefix += "/"

	# Check for files in this directory that match the filter
	for file in files:
		if file.begins_with(searchPrefix) and not file.ends_with("/"):
			var fileName = file.get_file()
			var extension = "." + fileName.get_extension().to_lower()
			if extension in filterExtensions:
				zip.close()
				return true

	zip.close()
	return false
