@tool
extends EditorExportPlugin


func _get_name() -> String:
	return "CsvExportPlugin"


func _export_file(path:String, type:String, features:PackedStringArray) -> void:
	if path.begins_with("res://addons/coldrock-csv"):
		skip()
