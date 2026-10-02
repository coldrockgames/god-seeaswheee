class_name CSVParser
extends Object


static func parse_file(path:String) -> CSVDocument:
	if not FileAccess.file_exists(path):
		return null
	var file:FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var content:String = file.get_as_text()
	file.close()
	var doc:CSVDocument = parse_string(content)
	doc.file_path = path
	return doc


static func parse_string(content:String) -> CSVDocument:
	var doc:CSVDocument = CSVDocument.new()
	var current_row:Array[String] = []
	var current_field:String = ""
	var in_quotes:bool = false
	var i:int = 0
	var length:int = content.length()
	while i < length:
		var c:String = content[i]
		if in_quotes:
			if c == '"':
				if i + 1 < length and content[i + 1] == '"':
					current_field += '"'
					i += 1 # Skip escaped quote
				else:
					in_quotes = false
			else:
				current_field += c
		else:
			if c == '"':
				in_quotes = true
			elif c == ',':
				current_row.append(current_field)
				current_field = ""
			elif c == '\r':
				pass # Ignore carriage return
			elif c == '\n':
				current_row.append(current_field)
				_process_row(doc, current_row)
				current_row = []
				current_field = ""
			else:
				current_field += c
		i += 1
	if not current_field.is_empty() or not current_row.is_empty():
		current_row.append(current_field)
		_process_row(doc, current_row)
	return doc


static func _process_row(doc:CSVDocument, row:Array[String]) -> void:
	if row.is_empty():
		return
	if doc.headers.is_empty():
		doc.headers = row
	else:
		var key:String = row[0].strip_edges()
		if key.is_empty():
			return
		doc.keys.append(key)
		var values:Array[String] = []
		for idx:int in range(1, row.size()):
			values.append(row[idx])
		# Pad values if row has missing columns
		while values.size() < doc.headers.size() - 1:
			values.append("")
		doc.rows[key] = values


static func encode(doc:CSVDocument) -> String:
	var lines:Array[String] = []
	lines.append(",".join(doc.headers))
	for key:String in doc.keys:
		var row_fields:Array[String] = [key] # Column 0 (Key) is NEVER quoted
		var vals:Array[String] = doc.rows.get(key, [])
		for val:String in vals:
			var escaped:String = val.replace('"', '""')
			row_fields.append('"' + escaped + '"')
		lines.append(",".join(row_fields))
	return "\n".join(lines) + "\n"


static func save_file(doc:CSVDocument) -> bool:
	if doc.file_path.is_empty():
		return false
	var content:String = encode(doc)
	var file:FileAccess = FileAccess.open(doc.file_path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(content)
	file.close()
	return true
