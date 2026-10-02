## Automatically creates and removes project settings for your plugin.[br]
## Also manages Autoloads and management of removal of obsolete settings.
@tool
class_name CsvPlugin
extends EditorPlugin

#region Settings Definition
## The name of the plugin is also the name of the settings section in the ProjectSettings.
const PLUGIN_NAME := "csv"
## Combined name of coldrock + plugin name. Resolves to [code]"coldrock/PLUGIN_NAME"[/code].
const CONFIG_BASE := "coldrock/%s/"%PLUGIN_NAME

# Definition of all settings. 
# Key = Relative Path, Value = Property Attributes
# See the examples below on how to add hints and hint_strings.
# Remove all the blueprint settings afterwards, just keep your own in here!
# In addition to the default keys known from Godot (hint, hint_string, default, type, ...),
# these keys are interpreted as well:
# "basic":bool=true     - if true, this is a basic settings, if false, this is an advanced setting
# "restart":bool=false  - if true, the editor will show the "Save & Restart" banner when this setting changes
# "editor":bool=false   - if true, this will be added to the [EditorSettings], not the [ProjectSettings]
# "resource":bool=false - if true, the value in "default" will be used as path and will be loaded
# "res_store_in":String - if "resource" is true, this is the name of a local variable in your plugin
#                         where the loaded resource shall be stored in.
var SETTINGS := {
	#"paths/project_gists": {
		#"default": PROJECT_GIST_DEFAULT_PATH,
		#"type": TYPE_STRING,  
		#"hint": PROPERTY_HINT_DIR,
		#"hint_string": ""
	#},
	#"code/empty_lines_between_functions": {
		#"editor": true,
		#"default": 2,
		#"hint": PROPERTY_HINT_RANGE,
		#"hint_string": "0,4,1",
	#},
	#"shortcuts/insert_gist_at_cursor": {
		#"editor": true,
		#"restart": true,
		#"resource": true,
		#"res_store_in": "_shortcut",
		#"default": "res://addons/coldrock-gdgist/res/gdgist_editor_shortcut.tres",
		#"type": TYPE_STRING,  
		#"hint": PROPERTY_HINT_FILE,
		#"hint_string": "*.tres,*.res"
	#},
	#"shortcuts/insert_super_call": {
		#"editor": true,
		#"restart": true,
		#"resource": true,
		#"res_store_in": "_super_shortcut",
		#"default": "res://addons/coldrock-gdgist/res/gdgist_super_shortcut.tres",
		#"type": TYPE_STRING,  
		#"hint": PROPERTY_HINT_FILE,
		#"hint_string": "*.tres,*.res"
	#},
}

# Definition of all autoload singletons.
# Each entry is an array with 2 values: 
# 1. global variable name
# 2. path to the tscn file to set as autoload singleton
# Those will be added as global autoload in the project settings.
const AUTOLOADS := [
]

# Those will be removed from project settings if they still exist.
# The line in the array is an example. Feel free to remove it!
const OBSOLETE_SETTINGS := [
]
#endregion

const MainUIClass = preload("res://addons/coldrock-csv/classes/CSVEditor.gd")

var main_ui_instance:Control = null
var _export_plugin:EditorExportPlugin

func _enter_tree() -> void:
	var sw = _try_create_stopwatch()
	_prepare_settings()
	_prepare_autoloads()
	_remove_obsolete_settings()
	_add_settings_listener()
	_setup_export_plugin()
	_prepare_editor()
	if sw: sw.finish("plugin initialized in")


func _exit_tree() -> void:
	_remove_settings_listener()
	_remove_export_plugin()
	_remove_editor()


func _disable_plugin() -> void:
	_remove_settings()
	_remove_autoloads()


func _notification(what:int) -> void:
	pass


func _on_settings_changed() -> void:
	pass # NOTE: This is called VERY frequently when project settings are open!


#region stopwatch (if available)
static func _try_create_stopwatch(sw_name:String = "") -> Object:
	for class_info:Dictionary in ProjectSettings.get_global_class_list():
		if class_info.get("class", "") == "StopWatch":
			var script_path:String = class_info.get("path", "")
			if ResourceLoader.exists(script_path):
				var sw_script:Script = load(script_path) as Script
				if sw_script:
					return sw_script.new(sw_name if not sw_name.is_empty() else "Coldrock " + PLUGIN_NAME)
	return null
#endregion

#region core
func _has_main_screen() -> bool:
	return true


func _make_visible(visible:bool) -> void:
	if main_ui_instance:
		main_ui_instance.visible = visible


func _get_plugin_name() -> String:
	return "CSV"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_base_control().get_theme_icon("Translation", "EditorIcons")


func _handles(object:Object) -> bool:
	if object is Resource:
		return object.resource_path.get_extension().to_lower() == "csv"
	return false


func _edit(object:Object) -> void:
	if object is Resource and object.resource_path.get_extension().to_lower() == "csv":
		var path:String = object.resource_path
		main_ui_instance.load_csv(path)
		EditorInterface.set_main_screen_editor("CSV Translator")


func _on_file_saved(file_path:String) -> void:
	if file_path.is_empty():
		push_warning("CSV Translator: File path is empty, reimport skipped.")
		return
	if not file_path.ends_with(".csv"):
		push_warning("CSV Translator: Saved file is not a CSV: " + file_path)
		return
	if FileAccess.file_exists(file_path):
		print("CSV Translator: Reimporting targeted file: " + file_path)
		var efs:EditorFileSystem = EditorInterface.get_resource_filesystem()
		efs.reimport_files(PackedStringArray([file_path]))
	else:
		push_error("CSV Translator: Save completed, but file missing for reimport: " + file_path)
#endregion

#region editor management
func _prepare_editor() -> void:
	if main_ui_instance and is_instance_valid(main_ui_instance) and main_ui_instance.is_inside_tree():
		return
	main_ui_instance = MainUIClass.new()
	main_ui_instance.file_saved.connect(_on_file_saved)
	EditorInterface.get_editor_main_screen().add_child(main_ui_instance)
	_make_visible(false)


func _remove_editor() -> void:
	if main_ui_instance:
		main_ui_instance.queue_free()
#endregion

#region export management
func _setup_export_plugin() -> void:
	_export_plugin = load("res://addons/coldrock-csv/plugin_export.gd").new()
	add_export_plugin(_export_plugin)


func _remove_export_plugin() -> void:
	if _export_plugin:
		remove_export_plugin(_export_plugin)
		_export_plugin = null
#endregion

#region --- Generic Settings Management ---
func _add_settings_listener() -> void:
	ProjectSettings.settings_changed.connect(_on_settings_changed)


func _remove_settings_listener() -> void:
	ProjectSettings.settings_changed.disconnect(_on_settings_changed)


# Runs through the SETTINGS struct and applies all settings and defaults
func _prepare_settings() -> void:
	var changed := false
	var editor_settings := EditorInterface.get_editor_settings()
	for key:String in SETTINGS:
		var def:Dictionary = SETTINGS[key]
		var full_path := CONFIG_BASE + key
		var default_val = def.get("default")
		# Auto-detect type if not explicit
		var type         = def.get("type", typeof(default_val)) 
		var hint         = def.get("hint", PROPERTY_HINT_NONE)
		var basic        = def.get("basic", true)
		var restart      = def.get("restart", false)
		var editor       = def.get("editor", false)
		var hint_string  = def.get("hint_string", "")
		var is_resource  = def.get("resource", false)
		var res_store    = def.get("res_store_in", "") as String
		# 1. Create/Set Default if missing
		var settings = editor_settings if editor else ProjectSettings
		if is_resource:
			if not res_store.is_empty():
				var loaded_resource = load(default_val)
				set(res_store, loaded_resource)
			else:
				push_warning(get_script().get_global_name(), ": \"resource\" is set, but no storage defined in \"res_store_in\"!")
		if not settings.has_setting(full_path):
			settings.set_setting(full_path, default_val)
			if not editor: changed = true
		# 2. Register for Editor UI
		var info_struct = {
			"name": full_path,
			"type": type,
			"hint": hint,
			"hint_string": hint_string
		}
		settings.add_property_info(info_struct)
		if editor:
			editor_settings.set_initial_value(full_path, default_val, false)
		else:
			settings.set_initial_value(full_path, default_val)
			settings.set_restart_if_changed(full_path, restart)
			settings.set_as_basic(full_path, basic)
	if changed:
		ProjectSettings.save()


func _remove_settings() -> void:
	var any_changed := false
	for key:String in SETTINGS:
		var s:String = CONFIG_BASE + key
		_remove_editor_setting(s)
		if _remove_project_setting(s):
			any_changed = true;
	if any_changed:
		ProjectSettings.save()


func _prepare_autoloads() -> void:
	for a:Array in AUTOLOADS:
		_add_autoload(a[0], a[1])


func _remove_autoloads() -> void:
	for a:Array in AUTOLOADS:
		remove_autoload_singleton(a[0])


# Safely add an autoload (avoiding to add it again if it exists)
func _add_autoload(name:String, path:String) -> void:
	var full_key:String = "autoload/" + name
	if ProjectSettings.has_setting(full_key):
		var current_val:String = str(ProjectSettings.get_setting(full_key)).trim_prefix("*")
		var resolved_path:String = current_val
		# Godot 4: Convert uid:// string back to a usable res:// path
		if current_val.begins_with("uid://"):
			var id:int = ResourceUID.text_to_id(current_val)
			if id != ResourceUID.INVALID_ID:
				resolved_path = ResourceUID.get_id_path(id)
		if resolved_path == path:
			return # Exit here if the autoload already exists and is the same path
	add_autoload_singleton(name, path)


func _remove_obsolete_settings() -> void:
	var any_changed:bool = false
	for s:String in OBSOLETE_SETTINGS:
		_remove_editor_setting(s)
		if _remove_project_setting(s):
			any_changed = true;
	if any_changed:
		ProjectSettings.save()


func _remove_project_setting(full_path:String) -> bool:
	if not full_path.begins_with(CONFIG_BASE):
		full_path = CONFIG_BASE + full_path
	if ProjectSettings.has_setting(full_path):
		ProjectSettings.set_setting(full_path, null)
		return true
	return false


func _remove_editor_setting(full_path:String) -> bool:
	if not full_path.begins_with(CONFIG_BASE):
		full_path = CONFIG_BASE + full_path
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings.has_setting(full_path):
		editor_settings.erase(full_path)
		return true
	return false


## Get a value from the project settings.[br]
## [color=orange]NOTE:[/color] [code]path[/code] is the same as you specified in 
## [member SETTINGS]! The [member CONFIG_BASE] path is added for you.
func get_project_setting(path:String, default:Variant = null) -> Variant:
	var full_path := CONFIG_BASE + path
	return ProjectSettings.get_setting(full_path, default)


## Get a value from the project settings.[br]
## [color=orange]NOTE:[/color] [code]path[/code] is the same as you specified in 
## [member SETTINGS]! The [member CONFIG_BASE] path is added for you.
func get_editor_setting(path:String, default:Variant = null) -> Variant:
	var editor_settings := EditorInterface.get_editor_settings()
	var full_path := CONFIG_BASE + path
	if editor_settings.has_setting(full_path):
		return editor_settings.get_setting(full_path)
	return default


## Get a value from the project settings.[br]
## [color=orange]NOTE:[/color] [code]path[/code] is the same as you specified in 
## [member SETTINGS]! The [member CONFIG_BASE] path is added for you.
func set_project_setting(path:String, value:Variant = null, overwrite:bool = false) -> void:
	var full_path := path
	if not full_path.begins_with(CONFIG_BASE):
		full_path = CONFIG_BASE + full_path
	if overwrite or not ProjectSettings.has_setting(full_path):
		ProjectSettings.set_setting(full_path, value)


## Get a value from the project settings.[br]
## [color=orange]NOTE:[/color] [code]path[/code] is the same as you specified in 
## [member SETTINGS]! The [member CONFIG_BASE] path is added for you.
func set_editor_setting(path:String, value:Variant, overwrite:bool = false) -> void:
	var editor_settings := EditorInterface.get_editor_settings()
	var full_path := path
	if not full_path.begins_with(CONFIG_BASE):
		full_path = CONFIG_BASE + full_path
	if overwrite or not editor_settings.has_setting(full_path):
		editor_settings.set_setting(full_path, value)
#endregion
