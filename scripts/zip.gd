extends Node
class_name Zip

# TODO: Not used. Was testing different methods for
# zipping source files. None of these options meet the need
# of packaging up a .zip.
static func Create(directoryToZip: String, zipFilePath: String, packageType = "Zip") -> int:
	var result
	var std_output = []
	if packageType == "Zip":
		if OS.get_name() == "Windows":
			var command = "powershell"
			var arguments = ["-Command", "Compress-Archive", "-Path", directoryToZip, "-DestinationPath", zipFilePath]
			result = OS.execute(command, arguments, std_output, true, true)
			print("Standard Output:", std_output)
		elif OS.get_name() == "Linux":
			result = OS.execute("zip", ["-r", zipFilePath, directoryToZip])
	else:
		if OS.get_name() == "Windows":
			result = OS.execute("tar", ["-cf", zipFilePath, "*"])
			if result == OK:
				print("Copy successful")
			else:
				print("Copy failed")
			
	return result
