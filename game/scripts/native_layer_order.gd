extends RefCounted
# Windows foreground API ignores unfocusable windows. Keep focus and surface
# styles unchanged; the bundled runtime component applies SWP_NOACTIVATE.
static var process_info: Dictionary={}
static var attempted=false
static func raise_windows(windows: Array) -> void:
	if OS.get_name()!="Windows" or DisplayServer.get_name()=="headless": return
	if not attempted:
		attempted=true
		var bytes=FileAccess.get_file_as_bytes("res://addons/native_layer_order/NativeLayerOrder.exe")
		if bytes.is_empty(): push_error("Native layer runtime missing"); return
		var cache="user://native-layer-order-"+str(hash(bytes))+".exe"
		if not FileAccess.file_exists(cache):
			var output=FileAccess.open(cache,FileAccess.WRITE)
			if output==null: push_error("Cannot prepare native layer runtime: %s (%s)"%[ProjectSettings.globalize_path(cache),FileAccess.get_open_error()]); return
			output.store_buffer(bytes)
			output.close()
		process_info=OS.execute_with_pipe(ProjectSettings.globalize_path(cache),[str(OS.get_process_id())],false)
	if process_info.is_empty(): return
	var handles=PackedStringArray()
	for window in windows:
		if is_instance_valid(window) and window.visible:
			handles.append(str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE,window.get_window_id())))
	if not handles.is_empty(): process_info.stdio.store_string(" ".join(handles)+"\n")
