class_name CSVDocument
extends RefCounted


var file_path:String = ""
var headers:Array[String] = []
var keys:Array[String] = []
var rows:Dictionary[String, Array] = {}


func get_languages() -> Array[String]:
	if headers.size() <= 1:
		return []
	return headers.slice(1)


func get_value(key:String, lang_idx:int) -> String:
	if not rows.has(key):
		return ""
	var vals:Array[String] = rows[key]
	if lang_idx >= 0 and lang_idx < vals.size():
		return vals[lang_idx]
	return ""


func set_value(key:String, lang_idx:int, text:String) -> void:
	if not rows.has(key):
		return
	var vals:Array[String] = rows[key]
	if lang_idx >= 0 and lang_idx < vals.size():
		vals[lang_idx] = text


func add_key(new_key:String) -> bool:
	var clean_key:String = new_key.strip_edges()
	if clean_key.is_empty() or rows.has(clean_key):
		return false
	keys.append(clean_key)
	var empty_vals:Array[String] = []
	empty_vals.resize(maxi(0, headers.size() - 1))
	empty_vals.fill("")
	rows[clean_key] = empty_vals
	return true


func rename_key(old_key:String,new_key:String) -> bool:
	var clean_new_key:String = new_key.strip_edges()
	if not rows.has(old_key):
		return false
	if clean_new_key.is_empty():
		return false
	if clean_new_key == old_key:
		return true
	if rows.has(clean_new_key):
		return false
	var vals:Array = rows[old_key]
	rows.erase(old_key)
	rows[clean_new_key] = vals
	var idx:int = keys.find(old_key)
	if idx != -1:
		keys[idx] = clean_new_key
	return true


func remove_key(key:String) -> void:
	if rows.has(key):
		rows.erase(key)
		keys.erase(key)


func add_language(lang_code:String) -> bool:
	var clean_lang:String = lang_code.strip_edges()
	if clean_lang.is_empty() or headers.has(clean_lang):
		return false
	headers.append(clean_lang)
	for key:String in keys:
		var vals:Array[String] = rows[key]
		vals.append("")
	return true


func remove_language(lang_code:String) -> bool:
	var idx:int = headers.find(lang_code)
	if idx <= 0: # Index 0 is 'id'/'key', cannot remove
		return false
	headers.remove_at(idx)
	var val_idx:int = idx - 1
	for key:String in keys:
		var vals:Array[String] = rows[key]
		if val_idx >= 0 and val_idx < vals.size():
			vals.remove_at(val_idx)
	return true
