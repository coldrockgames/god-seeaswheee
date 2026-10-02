@tool
class_name CSVEditor
extends Control

enum LayoutMode { AUTO, VERTICAL, HORIZONTAL }

var doc:CSVDocument = null
var current_key:String = ""
var current_layout_mode:LayoutMode = LayoutMode.AUTO
var is_currently_horizontal:bool = false

var file_label:Label
var save_button:Button
var add_key_button:Button
var manage_langs_button:Button
var layout_mode_button:Button

var filter_input:LineEdit
var key_list:ItemList

var empty_style:StyleBoxEmpty = StyleBoxEmpty.new()
var editor_scroll:ScrollContainer
var editor_container:Container
var size_slider:HSlider
var slider_label:Label
var right_panel:VBoxContainer
var text_editors:Array[TextEdit] = []
var file_list:ItemList
var left_split:VSplitContainer
var include_addons_checkbox:CheckBox

var size_h:int = 320
var size_v:int = 45
var last_scroll_h:int = 0
var last_scroll_v:int = 0

signal file_saved(file_path:String)


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	if Engine.is_editor_hint():
		var fs:EditorFileSystem = EditorInterface.get_resource_filesystem()
		if fs and not fs.filesystem_changed.is_connected(_refresh_file_list):
			fs.filesystem_changed.connect(_refresh_file_list)
	_build_ui()
	_try_restore_state()

#region state perstistence
const STATE_FILE_PATH:String = "res://.csv-editor.state"

func _save_state(path:String) -> void:
	var data:Dictionary = {
		"file_path": path,
		"size_h": size_h,
		"size_v": size_v
	}
	var file:FileAccess = FileAccess.open(STATE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func _try_restore_state() -> void:
	if not FileAccess.file_exists(STATE_FILE_PATH):
		return
	var file:FileAccess = FileAccess.open(STATE_FILE_PATH, FileAccess.READ)
	if not file:
		return
	var content:String = file.get_as_text().strip_edges()
	file.close()
	var json:JSON = JSON.new()
	if json.parse(content) == OK and json.data is Dictionary:
		var data:Dictionary = json.data
		size_h = int(data.get("size_h", 320))
		size_v = int(data.get("size_v", 45))
		var saved_path:String = str(data.get("file_path", ""))
		if not saved_path.is_empty() and FileAccess.file_exists(saved_path):
			load_csv(saved_path)
#endregion

#region ui
func _build_ui() -> void:
	for child:Node in get_children():
		child.queue_free()
	var root_margin:MarginContainer = MarginContainer.new()
	root_margin.set_anchors_preset(PRESET_FULL_RECT)
	root_margin.size_flags_horizontal = SIZE_EXPAND_FILL
	root_margin.size_flags_vertical = SIZE_EXPAND_FILL
	root_margin.add_theme_constant_override("margin_left", 12)
	root_margin.add_theme_constant_override("margin_top", 12)
	root_margin.add_theme_constant_override("margin_right", 12)
	root_margin.add_theme_constant_override("margin_bottom", 12)
	add_child(root_margin)
	var main_vbox:VBoxContainer = VBoxContainer.new()
	main_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 12)
	root_margin.add_child(main_vbox)
	# --- Toolbar ---
	var toolbar:HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(toolbar)
	file_label = Label.new()
	file_label.text = "No File Open"
	file_label.size_flags_horizontal = SIZE_EXPAND_FILL
	toolbar.add_child(file_label)
	# --- Toolbar Slider ---
	var slider_box:HBoxContainer = HBoxContainer.new()
	slider_box.add_theme_constant_override("separation", 6)
	slider_box.size_flags_vertical = SIZE_SHRINK_CENTER
	slider_label = Label.new()
	slider_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider_label.text = "Size:"
	slider_box.add_child(slider_label)
	size_slider = HSlider.new()
	size_slider.custom_minimum_size = Vector2(160, 24)
	size_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	size_slider.step = 8
	size_slider.value_changed.connect(_on_slider_value_changed)
	slider_box.add_child(size_slider)
	toolbar.add_child(slider_box)
	layout_mode_button = Button.new()
	layout_mode_button.text = "Layout: Auto"
	layout_mode_button.icon = get_theme_icon(&"AnimationAutoFitBezier", &"EditorIcons")
	layout_mode_button.pressed.connect(_on_toggle_layout_mode)
	toolbar.add_child(layout_mode_button)
	manage_langs_button = Button.new()
	manage_langs_button.text = "Manage Languages"
	manage_langs_button.icon = get_theme_icon(&"Translation", &"EditorIcons")
	manage_langs_button.pressed.connect(_on_manage_langs_pressed)
	toolbar.add_child(manage_langs_button)
	add_key_button = Button.new()
	add_key_button.text = "New Key"
	add_key_button.icon = get_theme_icon(&"Add", &"EditorIcons")
	add_key_button.tooltip_text = "Add a key (INS)"
	add_key_button.pressed.connect(_on_add_key_pressed)
	toolbar.add_child(add_key_button)
	var paste_csv_button:Button = Button.new()
	paste_csv_button.text = "Paste CSV"
	paste_csv_button.icon = get_theme_icon(&"ActionPaste", &"EditorIcons")
	paste_csv_button.tooltip_text = "Import single or multiple CSV lines from Clipboard"
	paste_csv_button.pressed.connect(_on_paste_csv_pressed)
	toolbar.add_child(paste_csv_button)
	save_button = Button.new()
	save_button.text = "Save & Reimport"
	save_button.icon = get_theme_icon(&"Save", &"EditorIcons")
	save_button.pressed.connect(_on_save_pressed)
	toolbar.add_child(save_button)
	# --- Main Split ---
	var split:HSplitContainer = HSplitContainer.new()
	split.size_flags_vertical = SIZE_EXPAND_FILL
	split.split_offset = 250
	main_vbox.add_child(split)
	# --- Left Side (Split: Keys Top / Files Bottom) ---
	left_split = VSplitContainer.new()
	left_split.custom_minimum_size.x = 220
	left_split.size_flags_vertical = SIZE_EXPAND_FILL
	split.add_child(left_split)
	# Fetch native dark stylebox from editor theme
	var editor_theme:Theme = EditorInterface.get_editor_theme()
	var dark_style:StyleBox = editor_theme.get_stylebox(&"normal", &"LineEdit") if editor_theme else null
	# --- Top Half: Keys ---
	var keys_vbox:VBoxContainer = VBoxContainer.new()
	keys_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	keys_vbox.size_flags_stretch_ratio = 2.0
	left_split.add_child(keys_vbox)
	filter_input = LineEdit.new()
	filter_input.placeholder_text = "Filter keys..."
	filter_input.clear_button_enabled = true
	filter_input.text_changed.connect(_on_filter_changed)
	filter_input.gui_input.connect(_on_filter_gui_input)
	keys_vbox.add_child(filter_input)
	key_list = ItemList.new()
	key_list.add_theme_stylebox_override(&"focus", empty_style)
	key_list.add_theme_stylebox_override(&"selected_focus", empty_style)
	key_list.add_theme_stylebox_override(&"hovered_selected_focus", empty_style)
	key_list.size_flags_horizontal = SIZE_EXPAND_FILL
	key_list.size_flags_vertical = SIZE_EXPAND_FILL
	key_list.focus_mode = Control.FOCUS_ALL
	var self_path:NodePath = NodePath(".")
	key_list.focus_neighbor_top = self_path
	key_list.focus_neighbor_bottom = self_path
	key_list.item_selected.connect(_on_key_selected)
	key_list.item_activated.connect(_on_key_activated)
	key_list.item_clicked.connect(_on_key_list_item_clicked)
	key_list.gui_input.connect(_on_key_list_gui_input)
	if dark_style:
		key_list.add_theme_stylebox_override(&"panel", dark_style)
	keys_vbox.add_child(key_list)
	# --- Bottom Half: CSV Files ---
	var files_vbox:VBoxContainer = VBoxContainer.new()
	files_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	files_vbox.size_flags_stretch_ratio = 1.0
	left_split.add_child(files_vbox)
	var files_header:HBoxContainer = HBoxContainer.new()
	files_vbox.add_child(files_header)
	var files_label:Label = Label.new()
	files_label.text = "Project CSVs:"
	files_label.size_flags_horizontal = SIZE_EXPAND_FILL
	files_header.add_child(files_label)
	include_addons_checkbox = CheckBox.new()
	include_addons_checkbox.text = "Addons"
	include_addons_checkbox.tooltip_text = "Scan /addons for csv files"
	include_addons_checkbox.toggled.connect(_on_include_addons_toggled)
	files_header.add_child(include_addons_checkbox)
	var refresh_btn:Button = Button.new()
	refresh_btn.icon = get_theme_icon(&"Reload", &"EditorIcons")
	refresh_btn.tooltip_text = "Refresh csv file list"
	refresh_btn.flat = true
	refresh_btn.pressed.connect(_refresh_file_list)
	files_header.add_child(refresh_btn)
	file_list = ItemList.new()
	file_list.add_theme_stylebox_override(&"focus", empty_style)
	file_list.add_theme_stylebox_override(&"selected_focus", empty_style)
	file_list.add_theme_stylebox_override(&"hovered_selected_focus", empty_style)
	file_list.size_flags_horizontal = SIZE_EXPAND_FILL
	file_list.size_flags_vertical = SIZE_EXPAND_FILL
	file_list.item_selected.connect(_on_file_selected)
	if dark_style:
		file_list.add_theme_stylebox_override(&"panel", dark_style)
	files_vbox.add_child(file_list)
	_refresh_file_list()
	# Right Side
	right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = SIZE_EXPAND_FILL
	split.add_child(right_panel)
	editor_scroll = ScrollContainer.new()
	editor_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	editor_scroll.size_flags_vertical = SIZE_EXPAND_FILL


func _build_editor_fields(force_rebuild:bool = false) -> void:
	if current_key.is_empty() or not doc:
		return
	var langs:Array[String] = doc.get_languages()
	if langs.is_empty():
		return
	var target_is_horizontal:bool = _determine_layout_is_horizontal()
	if not force_rebuild and text_editors.size() == langs.size() and target_is_horizontal == is_currently_horizontal:
		for i:int in range(langs.size()):
			text_editors[i].text = doc.get_value(current_key, i)
		return
	is_currently_horizontal = target_is_horizontal
	if is_instance_valid(editor_scroll):
		if editor_scroll.scroll_horizontal > 0:
			last_scroll_h = editor_scroll.scroll_horizontal
		if editor_scroll.scroll_vertical > 0:
			last_scroll_v = editor_scroll.scroll_vertical
	for child:Node in right_panel.get_children():
		right_panel.remove_child(child)
		child.queue_free()
	editor_container = null
	text_editors.clear()
	if current_key.is_empty() or not doc:
		return
	var is_horizontal:bool = _determine_layout_is_horizontal()
	_update_slider_limits()
	editor_scroll = ScrollContainer.new()
	editor_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	editor_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	if is_horizontal:
		editor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		editor_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		var outer_hbox:HBoxContainer = HBoxContainer.new()
		outer_hbox.size_flags_horizontal = SIZE_EXPAND_FILL
		outer_hbox.size_flags_vertical = SIZE_EXPAND_FILL
		outer_hbox.add_theme_constant_override("separation", 12)
		right_panel.add_child(outer_hbox)
		var pinned_vbox:VBoxContainer = VBoxContainer.new()
		pinned_vbox.size_flags_vertical = SIZE_EXPAND_FILL
		var pinned_label:Label = Label.new()
		pinned_label.text = langs[0].to_upper() + ":"
		pinned_vbox.add_child(pinned_label)
		var pinned_edit:TextEdit = TextEdit.new()
		pinned_edit.text = doc.get_value(current_key, 0)
		pinned_edit.add_theme_stylebox_override(&"focus", empty_style)
		pinned_edit.gui_input.connect(_on_text_edit_gui_input.bind(pinned_edit))
		pinned_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		pinned_edit.custom_minimum_size = Vector2(size_h, 0)
		pinned_edit.size_flags_vertical = SIZE_EXPAND_FILL
		text_editors.append(pinned_edit)
		pinned_vbox.add_child(pinned_edit)
		outer_hbox.add_child(pinned_vbox)
		outer_hbox.add_child(VSeparator.new())
		outer_hbox.add_child(editor_scroll)
		var inner_hbox:HBoxContainer = HBoxContainer.new()
		inner_hbox.size_flags_horizontal = SIZE_EXPAND_FILL
		inner_hbox.size_flags_vertical = SIZE_EXPAND_FILL
		inner_hbox.add_theme_constant_override("separation", 12)
		editor_container = inner_hbox
		editor_scroll.add_child(editor_container)
		for i:int in range(1, langs.size()):
			var col_vbox:VBoxContainer = VBoxContainer.new()
			col_vbox.size_flags_vertical = SIZE_EXPAND_FILL
			var label:Label = Label.new()
			label.text = langs[i].to_upper() + ":"
			col_vbox.add_child(label)
			var text_edit:TextEdit = TextEdit.new()
			text_edit.text = doc.get_value(current_key, i)
			text_edit.add_theme_stylebox_override(&"focus", empty_style)
			text_edit.gui_input.connect(_on_text_edit_gui_input.bind(text_edit))
			text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			text_edit.custom_minimum_size = Vector2(size_h, 0)
			text_edit.size_flags_vertical = SIZE_EXPAND_FILL
			text_editors.append(text_edit)
			col_vbox.add_child(text_edit)
			editor_container.add_child(col_vbox)
	else:
		editor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		editor_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		var outer_vbox:VBoxContainer = VBoxContainer.new()
		outer_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		outer_vbox.size_flags_vertical = SIZE_EXPAND_FILL
		outer_vbox.add_theme_constant_override("separation", 8)
		right_panel.add_child(outer_vbox)
		var pinned_grid:GridContainer = GridContainer.new()
		pinned_grid.columns = 2
		pinned_grid.size_flags_horizontal = SIZE_EXPAND_FILL
		pinned_grid.add_theme_constant_override("h_separation", 12)
		var pinned_label:Label = Label.new()
		pinned_label.text = langs[0].to_upper() + ":"
		pinned_label.custom_minimum_size.x = 80
		pinned_grid.add_child(pinned_label)
		var pinned_edit:TextEdit = TextEdit.new()
		pinned_edit.text = doc.get_value(current_key, 0)
		pinned_edit.add_theme_stylebox_override(&"focus", empty_style)
		pinned_edit.gui_input.connect(_on_text_edit_gui_input.bind(pinned_edit))
		pinned_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		pinned_edit.size_flags_horizontal = SIZE_EXPAND_FILL
		pinned_edit.custom_minimum_size.y = size_v
		text_editors.append(pinned_edit)
		pinned_grid.add_child(pinned_edit)
		outer_vbox.add_child(pinned_grid)
		outer_vbox.add_child(HSeparator.new())
		outer_vbox.add_child(editor_scroll)
		var grid:GridContainer = GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 8)
		editor_container = grid
		editor_scroll.add_child(editor_container)
		for i:int in range(1, langs.size()):
			var label:Label = Label.new()
			label.text = langs[i].to_upper() + ":"
			label.custom_minimum_size.x = 80
			editor_container.add_child(label)
			var text_edit:TextEdit = TextEdit.new()
			text_edit.text = doc.get_value(current_key, i)
			text_edit.add_theme_stylebox_override(&"focus", empty_style)
			text_edit.gui_input.connect(_on_text_edit_gui_input.bind(text_edit))
			text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			text_edit.size_flags_horizontal = SIZE_EXPAND_FILL
			text_edit.custom_minimum_size.y = size_v
			text_editors.append(text_edit)
			editor_container.add_child(text_edit)
	_restore_scroll_positions.call_deferred(last_scroll_h, last_scroll_v)


func _unhandled_key_input(event:InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_INSERT):
		return
	if not is_visible_in_tree() or doc == null:
		return
	var focus_owner:Control = get_viewport().gui_get_focus_owner()
	if focus_owner and (focus_owner == self or is_ancestor_of(focus_owner)):
		get_viewport().set_input_as_handled()
		_on_add_key_pressed()


func _on_text_edit_gui_input(event:InputEvent,text_edit:TextEdit) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			accept_event()
			var target:Control = text_edit.find_prev_valid_focus() if event.shift_pressed else text_edit.find_next_valid_focus()
			if target:
				target.grab_focus()
				if target is TextEdit:
					_transfer_caret_position(text_edit, target as TextEdit)
		elif event.keycode == KEY_INSERT:
			accept_event()
			_on_add_key_pressed()


func _transfer_caret_position(from_edit:TextEdit,to_edit:TextEdit) -> void:
	var from_offset:int = _get_caret_offset(from_edit)
	var from_total_len:int = from_edit.text.length()
	if from_offset >= from_total_len:
		_set_caret_offset(to_edit, to_edit.text.length())
	else:
		_set_caret_offset(to_edit, from_offset)


func _get_caret_offset(te:TextEdit) -> int:
	var line:int = te.get_caret_line()
	var col:int = te.get_caret_column()
	var offset:int = 0
	for i:int in range(line):
		offset += te.get_line(i).length() + 1 # +1 for newline character
	return offset + col


func _set_caret_offset(te:TextEdit,offset:int) -> void:
	var current_offset:int = 0
	var line_count:int = te.get_line_count()
	for i:int in range(line_count):
		var line_len:int = te.get_line(i).length()
		if current_offset + line_len >= offset:
			te.set_caret_line(i)
			te.set_caret_column(offset - current_offset)
			return
		current_offset += line_len + 1
	var last_line:int = max(0, line_count - 1)
	te.set_caret_line(last_line)
	te.set_caret_column(te.get_line(last_line).length())


func _focus_first_editor() -> void:
	if not text_editors.is_empty() and is_instance_valid(text_editors[0]):
		var first_edit:TextEdit = text_editors[0]
		first_edit.grab_focus()
		_set_caret_offset(first_edit, first_edit.text.length())
#endregion

#region save & load
func load_csv(path:String) -> void:
	var loaded_doc:CSVDocument = CSVParser.parse_file(path)
	if not loaded_doc:
		printerr("CSVTranslator: Failed to parse " + path)
		return
	doc = loaded_doc
	file_label.text = doc.file_path.get_file() + " (" + str(doc.keys.size()) + " Keys, " + str(doc.get_languages().size()) + " Languages)"
	_refresh_key_list()
	if not doc.keys.is_empty():
		_select_key(doc.keys[0])
	_save_state(path)


func _on_save_pressed() -> void:
	if not doc:
		return
	_save_current_key_values()
	if CSVParser.save_file(doc):
		file_saved.emit(doc.file_path)
#endregion

#region clipboard csv import
func _on_paste_csv_pressed() -> void:
	if not doc:
		return
	var clipboard_text:String = DisplayServer.clipboard_get().strip_edges()
	if clipboard_text.is_empty():
		_show_paste_dialog("Clipboard Empty", "There is no text in the clipboard to paste.")
		return
	if doc.headers.size() <= 1:
		_show_paste_dialog("No Languages", "The current CSV document has no active language columns.")
		return
	var content_to_parse:String = clipboard_text
	var first_line:String = clipboard_text.split("\n", true, 1)[0].strip_edges().to_lower()
	var key_col_name:String = doc.headers[0].to_lower()
	if not (first_line.begins_with(key_col_name + ",") or first_line == key_col_name):
		var fake_header:String = ",".join(doc.headers)
		content_to_parse = fake_header + "\n" + clipboard_text
	var temp_doc:CSVDocument = CSVParser.parse_string(content_to_parse)
	if not temp_doc or temp_doc.keys.is_empty():
		_show_paste_dialog("Import Failed", "Could not parse any valid CSV data from clipboard.")
		return
	_save_current_key_values()
	var imported_count:int = 0
	var last_key:String = ""
	var lang_count:int = doc.get_languages().size()
	for key:String in temp_doc.keys:
		if not doc.rows.has(key):
			doc.add_key(key)
		for i:int in range(lang_count):
			var val:String = temp_doc.get_value(key, i)
			doc.set_value(key, i, val)
		imported_count += 1
		last_key = key
	if is_instance_valid(filter_input) and not filter_input.text.is_empty():
		filter_input.clear()
	var saved_selected:String = current_key
	current_key = ""
	_refresh_key_list("")
	var target_key:String = saved_selected if (not saved_selected.is_empty() and doc.rows.has(saved_selected)) else last_key
	if not target_key.is_empty():
		_select_key(target_key, false)


func _show_paste_dialog(title_text:String,msg_text:String) -> void:
	var dialog:AcceptDialog = AcceptDialog.new()
	dialog.title = title_text
	var label:Label = Label.new()
	label.text = msg_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.add_child(label)
	add_child(dialog)
	dialog.popup_centered(Vector2i(380, 120))
	dialog.confirmed.connect(func() -> void: dialog.queue_free())
#endregion

#region slider and live update
func _update_slider_limits() -> void:
	if not size_slider:
		return
	size_slider.set_block_signals(true)
	var is_horizontal:bool = _determine_layout_is_horizontal()
	if is_horizontal:
		size_slider.max_value = 1024
		size_slider.min_value = 256
		size_slider.value = size_h
		slider_label.text = "Width: " + str(size_h) + "px"
	else:
		size_slider.max_value = 256
		size_slider.min_value = 32
		size_slider.value = size_v
		slider_label.text = "Height: " + str(size_v) + "px"
	size_slider.set_block_signals(false)


func _on_slider_value_changed(val:float) -> void:
	var int_val:int = int(val)
	var is_horizontal:bool = _determine_layout_is_horizontal()
	if is_horizontal:
		size_h = int_val
		slider_label.text = "Width: " + str(size_h) + "px"
	else:
		size_v = int_val
		slider_label.text = "Height: " + str(size_v) + "px"
	_apply_live_sizes()
	if doc and not doc.file_path.is_empty():
		_save_state(doc.file_path)


func _apply_live_sizes() -> void:
	var is_horizontal:bool = _determine_layout_is_horizontal()
	for text_edit:TextEdit in text_editors:
		if is_horizontal:
			text_edit.custom_minimum_size.x = size_h
		else:
			text_edit.custom_minimum_size.y = size_v
#endregion

#region file browser
func _refresh_file_list() -> void:
	if not is_instance_valid(file_list):
		return
	file_list.clear()
	var include_addons:bool = include_addons_checkbox.button_pressed if is_instance_valid(include_addons_checkbox) else false
	var csv_files:Array[String] = _scan_csv_files("res://",include_addons)
	csv_files.sort()
	for path:String in csv_files:
		var idx:int = file_list.add_item(path.get_file())
		file_list.set_item_metadata(idx,path)
		if doc and doc.file_path == path:
			file_list.select(idx)


func _scan_csv_files(path:String,include_addons:bool=false) -> Array[String]:
	var results:Array[String] = []
	var dir:DirAccess = DirAccess.open(path)
	if not dir:
		return results
	dir.list_dir_begin()
	var file_name:String = dir.get_next()
	while not file_name.is_empty():
		if dir.current_is_dir():
			if file_name.begins_with(".") or file_name == "android":
				file_name = dir.get_next()
				continue
			if file_name == "addons" and not include_addons:
				file_name = dir.get_next()
				continue
			results.append_array(_scan_csv_files(path.path_join(file_name),include_addons))
		else:
			if file_name.ends_with(".csv"):
				results.append(path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	return results


func _on_include_addons_toggled(_toggled_on:bool) -> void:
	_refresh_file_list()


func _on_file_selected(index:int) -> void:
	var target_path:String = file_list.get_item_metadata(index) as String
	if doc and doc.file_path == target_path:
		return
	_save_current_key_values()
	load_csv(target_path)
#endregion

#region keys
func _refresh_key_list(filter:String = "") -> void:
	key_list.clear()
	if not doc:
		return
	var sorted_keys:Array[String] = doc.keys.duplicate()
	sorted_keys.sort()
	var filter_lower:String = filter.to_lower()
	for key:String in sorted_keys:
		if filter_lower.is_empty() or key.to_lower().contains(filter_lower):
			key_list.add_item(key)


func _select_key(key:String, save_previous:bool = true) -> void:
	if save_previous:
		_save_current_key_values()
	current_key = key
	for i:int in range(key_list.item_count):
		if key_list.get_item_text(i) == key:
			key_list.select(i)
			key_list.ensure_current_is_visible()
			break
	_build_editor_fields(true)
	if not key_list.has_focus():
		key_list.grab_focus()


func _save_current_key_values() -> void:
	if current_key.is_empty() or not doc or text_editors.is_empty():
		return
	var langs:Array[String] = doc.get_languages()
	for i:int in range(text_editors.size()):
		if i < langs.size():
			doc.set_value(current_key, i, text_editors[i].text)


func _on_key_selected(index:int) -> void:
	var key:String = key_list.get_item_text(index)
	_select_key(key)


func _on_filter_changed(new_text:String) -> void:
	_refresh_key_list(new_text)


func _on_filter_gui_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_INSERT:
		accept_event()
		_on_add_key_pressed()
#endregion

#region key deletion & context menu
func _on_key_list_gui_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE:
			var selected:PackedInt32Array = key_list.get_selected_items()
			if not selected.is_empty():
				accept_event()
				var key_name:String = key_list.get_item_text(selected[0])
				_confirm_delete_key(key_name)


func _on_key_list_item_clicked(index:int,_at_position:Vector2,mouse_button_index:int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		var key_name:String = key_list.get_item_text(index)
		_select_key(key_name)
		var popup:PopupMenu = PopupMenu.new()
		popup.add_icon_item(get_theme_icon(&"ActionCopy", &"EditorIcons"), "Copy Key Name", 0)
		popup.add_icon_item(get_theme_icon(&"Edit", &"EditorIcons"), "Rename Key", 1)
		popup.add_icon_item(get_theme_icon(&"Remove", &"EditorIcons"), "Delete Key", 2)
		add_child(popup)
		popup.position = DisplayServer.mouse_get_position()
		popup.id_pressed.connect(func(id:int) -> void:
			match id:
				0: DisplayServer.clipboard_set(key_name)
				1: _on_key_activated(index)
				2: _confirm_delete_key(key_name)
			popup.queue_free()
		)
		popup.popup()


func _confirm_delete_key(key_name:String) -> void:
	if not doc or not doc.rows.has(key_name):
		return
	var dialog:ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Delete Key"
	dialog.ok_button_text = "Delete"
	var label:Label = Label.new()
	label.text = "Are you sure you want to delete key '%s' (NO UNDO!)?" % key_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.add_child(label)
	add_child(dialog)
	dialog.popup_centered(Vector2i(350, 120))
	dialog.confirmed.connect(func() -> void:
		var current_idx:int = -1
		for i:int in range(key_list.item_count):
			if key_list.get_item_text(i) == key_name:
				current_idx = i
				break
		doc.remove_key(key_name)
		_refresh_key_list(filter_input.text)
		if key_list.item_count > 0:
			var next_idx:int = clampi(current_idx, 0, key_list.item_count - 1)
			_select_key(key_list.get_item_text(next_idx))
		else:
			current_key = ""
			_build_editor_fields(true)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
#endregion

#region layout direction
func _determine_layout_is_horizontal() -> bool:
	if current_layout_mode == LayoutMode.HORIZONTAL:
		return true
	if current_layout_mode == LayoutMode.VERTICAL:
		return false
	var langs:Array[String] = doc.get_languages()
	for i:int in range(langs.size()):
		var val:String = doc.get_value(current_key, i)
		if val.contains("\n") or val.length() > 80:
			return true
	return false


func _on_toggle_layout_mode() -> void:
	match current_layout_mode:
		LayoutMode.AUTO:
			current_layout_mode = LayoutMode.VERTICAL
			layout_mode_button.text = "Layout: Vertical"
		LayoutMode.VERTICAL:
			current_layout_mode = LayoutMode.HORIZONTAL
			layout_mode_button.text = "Layout: Horizontal"
		LayoutMode.HORIZONTAL:
			current_layout_mode = LayoutMode.AUTO
			layout_mode_button.text = "Layout: Auto"
	_build_editor_fields(true)


func _restore_scroll_positions(h:int, v:int) -> void:
	if is_instance_valid(editor_scroll):
		editor_scroll.scroll_horizontal = h
		editor_scroll.scroll_vertical = v
#endregion

#region add new key
func _on_add_key_pressed() -> void:
	if not doc:
		return
	var dialog:ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Add New Key"
	var input:LineEdit = LineEdit.new()
	input.placeholder_text = "KEY_NAME"
	dialog.add_child(input)
	dialog.register_text_enter(input)
	add_child(dialog)
	dialog.popup_centered(Vector2i(300, 100))
	input.grab_focus.call_deferred()
	dialog.confirmed.connect(func() -> void:
		var new_key:String = input.text.strip_edges()
		if not new_key.is_empty() and doc.add_key(new_key):
			_refresh_key_list(filter_input.text)
			_select_key(new_key)
			_focus_first_editor.call_deferred()
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
#endregion

#region manage languages
func _on_manage_langs_pressed() -> void:
	if not doc:
		return
	var dialog:AcceptDialog = AcceptDialog.new()
	dialog.title = "Manage Languages"
	var main_vbox:VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	dialog.add_child(main_vbox)
	var scroll:ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 180)
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	var lang_list_vbox:VBoxContainer = VBoxContainer.new()
	lang_list_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	lang_list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(lang_list_vbox)
	var populate_list:Callable
	populate_list = func() -> void:
		for child:Node in lang_list_vbox.get_children():
			child.queue_free()
		var langs:Array[String] = doc.get_languages()
		if langs.is_empty():
			var empty_lbl:Label = Label.new()
			empty_lbl.text = "No active languages."
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lang_list_vbox.add_child(empty_lbl)
			return
		for lang:String in langs:
			var row:HBoxContainer = HBoxContainer.new()
			row.size_flags_horizontal = SIZE_EXPAND_FILL
			var lbl:Label = Label.new()
			lbl.text = "  " + lang.to_upper()
			lbl.size_flags_horizontal = SIZE_EXPAND_FILL
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(lbl)
			var del_btn:Button = Button.new()
			del_btn.icon = get_theme_icon(&"Remove", &"EditorIcons")
			del_btn.tooltip_text = "Delete language '" + lang + "'"
			del_btn.flat = true
			var target_lang:String = lang
			del_btn.pressed.connect(func() -> void:
				_confirm_delete_language(target_lang, func() -> void:
					populate_list.call()
					_refresh_key_list(filter_input.text)
					_build_editor_fields(true)
				)
			)
			row.add_child(del_btn)
			lang_list_vbox.add_child(row)
	populate_list.call()
	main_vbox.add_child(HSeparator.new())
	var add_hbox:HBoxContainer = HBoxContainer.new()
	add_hbox.add_theme_constant_override("separation", 8)
	var add_input:LineEdit = LineEdit.new()
	add_input.placeholder_text = "e.g. ja, ko, uk"
	add_input.size_flags_horizontal = SIZE_EXPAND_FILL
	add_hbox.add_child(add_input)
	var add_btn:Button = Button.new()
	add_btn.text = "Add"
	add_btn.icon = get_theme_icon(&"Add", &"EditorIcons")
	var do_add_lang:Callable = func() -> void:
		var code:String = add_input.text.strip_edges()
		if not code.is_empty() and doc.add_language(code):
			add_input.clear()
			populate_list.call()
			_refresh_key_list(filter_input.text)
			_build_editor_fields(true)
	add_btn.pressed.connect(do_add_lang)
	add_input.text_submitted.connect(func(_text:String) -> void: do_add_lang.call())
	add_hbox.add_child(add_btn)
	main_vbox.add_child(add_hbox)
	add_child(dialog)
	dialog.popup_centered(Vector2i(384, 450))
	dialog.confirmed.connect(func() -> void: dialog.queue_free())
	dialog.canceled.connect(func() -> void: dialog.queue_free())


func _confirm_delete_language(lang_code:String,on_deleted:Callable) -> void:
	var warn_dialog:ConfirmationDialog = ConfirmationDialog.new()
	warn_dialog.title = "DANGER: Delete Language Column"
	warn_dialog.ok_button_text = "Yes, PERMANENTLY Delete"
	var msg:String = "Are you ABSOLUTELY sure you want to delete '%s'?\n\nThis will PERMANENTLY destroy the entire language column\nand ALL translations for '%s' across ALL %d keys!\n\nTHERE IS NO UNDO (except Git revert)!" % [lang_code.to_upper(), lang_code.to_upper(), doc.keys.size()]
	var label:Label = Label.new()
	label.text = msg
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_dialog.add_child(label)
	add_child(warn_dialog)
	warn_dialog.popup_centered(Vector2i(450, 180))
	warn_dialog.confirmed.connect(func() -> void:
		if doc.remove_language(lang_code):
			on_deleted.call()
		warn_dialog.queue_free()
	)
	warn_dialog.canceled.connect(func() -> void:
		warn_dialog.queue_free()
	)
#endregion

#region key edit
func _on_key_activated(index:int) -> void:
	var old_key:String = key_list.get_item_text(index)
	var dialog:ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Edit / Rename Key"
	var input:LineEdit = LineEdit.new()
	input.text = old_key
	dialog.add_child(input)
	dialog.register_text_enter(input)
	add_child(dialog)
	dialog.popup_centered(Vector2i(350, 100))
	input.grab_focus.call_deferred()
	input.select_all.call_deferred()
	dialog.confirmed.connect(func() -> void:
		var new_key:String = input.text.strip_edges()
		if not new_key.is_empty() and new_key != old_key:
			_rename_key(old_key, new_key)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)


func _rename_key(old_key:String,new_key:String) -> void:
	if not doc:
		return
	_save_current_key_values()
	if doc.rename_key(old_key, new_key):
		var clean_key:String = new_key.strip_edges()
		current_key = clean_key
		_refresh_key_list(filter_input.text)
		_select_key(clean_key)
#endregion
