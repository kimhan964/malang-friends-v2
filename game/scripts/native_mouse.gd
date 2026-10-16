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
	var key="native_mouse_passthrough"
	if not window.visible: return
	if force or not window.has_meta(key) or window.get_meta(key)!=enabled:
		# Updating WS_EX_TRANSPARENT needs no non-client frame recalculation.
		# The old extension sent SWP_FRAMECHANGED on every cursor crossing.
		if not preload("res://scripts/native_layer_order.gd").set_passthrough(window,enabled):
			window.mouse_passthrough=enabled
		window.set_meta(key,enabled)
static func enabled(window: Window) -> bool:
	return bool(window.get_meta("native_mouse_passthrough",window.mouse_passthrough))
