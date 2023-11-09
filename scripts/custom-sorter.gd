class_name CustomSorter

static func sort_by_published_date(a, b) -> bool:
	return sort_by_date_field(a, b, "_publishedDate")

static func sort_by_created_date(a, b) -> bool:
	return sort_by_date_field(a, b, "_createdDate")

static func sort_by_edited_date(a, b) -> bool:
	return sort_by_date_field(a, b, "_editedDate")	
	
static func sort_by_date_field(a, b, field_name: String) -> bool:
	var a_date: Dictionary = a.get(field_name) if typeof(a.get(field_name)) == TYPE_DICTIONARY else {}
	var b_date: Dictionary = b.get(field_name) if typeof(b.get(field_name)) == TYPE_DICTIONARY else {}

	# Set default values for missing date parts
	a_date = {"year": a_date.get("year", 0), "month": a_date.get("month", 1), "day": a_date.get("day", 1), "hour": a_date.get("hour", 0), "minute": a_date.get("minute", 0)}
	b_date = {"year": b_date.get("year", 0), "month": b_date.get("month", 1), "day": b_date.get("day", 1), "hour": b_date.get("hour", 0), "minute": b_date.get("minute", 0)}

	# Comparison logic
	if a_date["year"] != b_date["year"]:
		return a_date["year"] < b_date["year"]
	if a_date["month"] != b_date["month"]:
		return a_date["month"] < b_date["month"]
	if a_date["day"] != b_date["day"]:
		return a_date["day"] < b_date["day"]
	if a_date["hour"] != b_date["hour"]:
		return a_date["hour"] < b_date["hour"]
	if a_date["minute"] != b_date["minute"]:
		return a_date["minute"] < b_date["minute"]
	return false  # If all the components are equal


