extends RefCounted
# Godot's Windows boolean flag only forwards to windows on the same thread.
# Keep the render surface intact; use OS-level click-through for other apps.
const EXTENSION="res://addons/windows_mouse_passthrough/windows_mouse_passthrough.gdextension"
static var attempted=false
static func available() -> bool:
	if OS.get_name()!="Windows" or DisplayServer.get_name()=="headless": return false
	if not attempted:
		attempted=true
		if not Engine.has_singleton("MousePassthrough"):
			var result=GDExtensionManager.load_extension(EXTENSION)
			if result!=GDExtensionManager.LOAD_STATUS_OK and result!=GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
				push_error("Windows click-through extension could not load: %s"%result)
	return Engine.has_singleton("MousePassthrough")

static func apply(window: Window, enabled: bool, force: bool=false) -> void:
	if window.mouse_passthrough!=enabled: window.mouse_passthrough=enabled
	if not window.visible or not available(): return
	var key="native_mouse_passthrough"
	if force or not window.has_meta(key) or window.get_meta(key)!=enabled:
		Engine.get_singleton("MousePassthrough").set_passthrough(window.get_window_id(),enabled)
		window.set_meta(key,enabled)
