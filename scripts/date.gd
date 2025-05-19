extends Node
class_name Date

static func GetCurrentDateAsString(dateTimeAsDictionary : Dictionary) -> String:
	if dateTimeAsDictionary == {}:
		return ""
		
	var time : Dictionary = dateTimeAsDictionary
	var am_pm := "AM" if time.hour < 12 else "PM"
	var hour = time.hour % 12
	hour = hour if hour != 0 else 12  # Convert 0 (midnight) to 12
	return "%d/%d/%d %d:%02d %s" % [time.month, time.day, time.year, hour, time.minute, am_pm];

static func GetCurrentDateAsDictionary() -> Dictionary:
	var time: Dictionary = Time.get_datetime_dict_from_system()
	return {
		"year": time.year,
		"month": time.month,
		"day": time.day,
		"hour": time.hour,
		"minute": time.minute
		# You can add seconds or other fields if needed
	}

static func ConvertDateStringToDictionary(date_string : String) -> Variant:
	if date_string == "":
		return {}
	
	# Expected format: MM/DD/YYYY HH:MM AM/PM
	var parts = date_string.split(" ")
	if parts.size() != 3:
		return {}
	
	var date_parts = parts[0].split("/")
	var time_parts = parts[1].split(":")
	if date_parts.size() != 3 or time_parts.size() != 2:
		return {}
	
	var hour = int(time_parts[0])
	var minute = int(time_parts[1])
	var am_pm = parts[2]
	
	# Validate AM/PM
	if am_pm != "AM" and am_pm != "PM":
		return {}
	
	# Validate hour and minute ranges
	if hour < 1 or hour > 12 or minute < 0 or minute > 59:
		return {}
	
	# Adjust hour for AM/PM
	if am_pm == "PM" and hour != 12:
		hour += 12
	elif am_pm == "AM" and hour == 12:
		hour = 0
	
	# Validate date
	var year = int(date_parts[2])
	var month = int(date_parts[0])
	var day = int(date_parts[1])
	if year < 1 or month < 1 or month > 12 or day < 1 or day > 31:  # Simplistic validation; does not account for different month lengths or leap years
		return {}
	
	# Build the dictionary
	return {
		"year": year,
		"month": month,
		"day": day,
		"hour": hour,
		"minute": minute
	}
