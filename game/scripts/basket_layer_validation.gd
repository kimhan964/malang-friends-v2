extends Node
var app
func folder() -> String:
	var path=OS.get_executable_path().get_base_dir().path_join("검수/순차수정/01-바구니가림")
	DirAccess.make_dir_recursive_absolute(path);return path
func probe(species: int,phase: String) -> void:
	# The native layer component consumes requests on its own pipe thread.
	await get_tree().create_timer(.15).timeout
	var data={"species":species,"phase":phase,"pet":DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE,app.pet.get_window_id()),"basket":DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE,app.props.basket.get_window_id())}
	FileAccess.open(folder().path_join("probe.json"),FileAccess.WRITE).store_string(JSON.stringify(data))
	await get_tree().create_timer(.35).timeout
func run() -> void:
	await get_tree().process_frame
	app.set_process(false);app.furniture_room.set_process(false);app.behavior_panel.set_process(false)
	for piece in app.furniture_room.pieces.values(): piece.hide();piece.set_process(false)
	for prop in app.props.values(): prop.hide();prop.set_process(false)
	for species in [3,0,15]:
		await app.choose_friend(species);app.pet.set_process(false)
		var m=app.pet.motion;m.autonomy=false;m.daily.enabled=false
		var basket=app.props.basket;basket.show();basket.position=Vector2i(m.bounds.get_center())-Vector2i(0,86)
		m.feet=basket.feet_point();app.pet.advance_frame(0)
		await get_tree().process_frame
		await get_tree().process_frame
		app.layers_dirty=false
		# Deliberately reproduce an OS-raised prop above an overlapping animal.
		preload("res://scripts/native_layer_order.gd").raise_windows([app.pet,basket])
		await get_tree().create_timer(.15).timeout
		await probe(species,"reproduced")
		app.layers_dirty=true;app.restore_layer_order()
		await probe(species,"restored")
		app.use_desktop_prop("basket")
		for tick in range(1800):
			app.pet.advance_frame(1.0/60);app.advance_basket()
			if m.phase=="home_use": break
		app.layers_dirty=true;app.restore_layer_order()
		await probe(species,"playing")
		m.cancel_play();app.advance_basket();basket.hide()
	FileAccess.open(folder().path_join("finished.json"),FileAccess.WRITE).store_string(JSON.stringify({"finished":true}))
	get_tree().quit()
