extends SceneTree
const Main=preload("res://scripts/main.gd")
const State=preload("res://scripts/pet_state.gd")
const Catalog=preload("res://scripts/furniture_catalog.gd")
class MemoryState extends State:
	func load_game() -> void: pass
	func save_game() -> void: pass
var failures=[]
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message);push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	ProjectSettings.set_setting("commerce/enabled",false)
	var app=Main.new()
	app.state=MemoryState.new()
	app.state.guide_seen=true
	app.state.play_affection={"0":200}
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.pet.set_process(false)
	var room=app.furniture_room
	room.set_process(false)
	room.open()
	for id in Catalog.ITEMS:
		room.place(id,Vector2(500,350),false)
		var piece=room.pieces[id]
		check(not piece.menu.has_node("color") and not piece.menu.has_node("finish"),"appearance controls still exposed "+id)
		check(piece.menu.get_item_index(10)<0 and piece.menu.get_item_index(11)<0,"move buttons still exposed "+id)
		piece.menu.id_pressed.emit(12)
		check(piece.mirrored and app.state.furniture[id][2]==true,"right click flip not saved "+id)
		piece.menu.id_pressed.emit(12)
		check(not piece.mirrored,"second flip not restored "+id)
		var contact=piece.ground_point()
		var original_size=piece.sprite.texture.get_size()*piece.sprite.scale
		piece.menu.id_pressed.emit(22)
		check(piece.size_editor.visible,"percent editor missing "+id)
		piece.size_percent.value=110
		check(is_equal_approx(piece.user_scale,1.1),"enlarge menu "+id)
		check((piece.sprite.texture.get_size()*piece.sprite.scale).distance_to(original_size*1.1)<.1,"image scale "+id)
		check(absf(piece.ground_point().y-contact.y)<1.1,"resize lost floor contact "+id)
		check(is_equal_approx(app.state.furniture[id][3],1.1),"scale not saved "+id)
		piece.size_slider.value=87
		check(is_equal_approx(piece.user_scale,.87) and piece.size_percent.value==87,"percent slider sync "+id)
		piece.size_percent.value=113
		check(is_equal_approx(piece.user_scale,1.13) and piece.size_slider.value==113,"precise percent input "+id)
		piece.size_editor.hide()
		piece.set_user_scale(9,true)
		check(is_equal_approx(piece.user_scale,1.6),"maximum scale "+id)
		piece.set_user_scale(.1,true)
		check(is_equal_approx(piece.user_scale,.6),"minimum scale "+id)
		piece.menu.id_pressed.emit(24)
		check(is_equal_approx(piece.user_scale,1.0),"reset scale "+id)
		piece.menu.id_pressed.emit(20)
		check(room.ordered_pieces().back()==piece,"front order "+id)
		piece.menu.id_pressed.emit(21)
		check(room.ordered_pieces().front()==piece,"back order "+id)
		piece.set_appearance({"color":2,"finish":2},true)
		check(room.pieces[id].appearance.color==2 and room.pieces[id].appearance.finish==2,"saved appearance not applied "+id)
		check(room.pieces[id].sprite.material.get_shader_parameter("color_choice")==2,"color material "+id)
		check(room.pieces[id].sprite.material.get_shader_parameter("finish_choice")==2,"finish material "+id)
		check(room.use_piece(id),"styled furniture interaction "+id)
	for design in range(3):
		room.pieces.alarm_clock.set_appearance({"color":2,"finish":2,"design":design},true)
		check(room.pieces.alarm_clock.sprite.texture==Catalog.texture("alarm_clock",design),"alarm design not updated")
	room.buttons.sofa.pressed.emit()
	check(not room.pieces.has("sofa") and room.buttons.sofa.text=="배치","remove button did not update")
	room.buttons.sofa.pressed.emit()
	check(room.pieces.has("sofa") and room.buttons.sofa.text=="치우기","place button did not update")
	for button in room.buttons.values():
		check(button.alignment==HORIZONTAL_ALIGNMENT_CENTER and button.get_theme_font_size("font_size")==14,"inconsistent button text")
	check(room.pieces.sofa.appearance.color==2,"appearance lost on replacement")
	var saved=State.new()
	saved.save_path="user://furniture-style-test-only.json"
	saved.furniture_styles=app.state.furniture_styles.duplicate(true)
	saved.furniture=app.state.furniture.duplicate(true)
	saved.save_game()
	var restored=State.new()
	restored.save_path=saved.save_path
	restored.load_game()
	check(restored.furniture_styles==saved.furniture_styles,"appearance lost after restart")
	check(restored.furniture.size()==saved.furniture.size(),"furniture missing after restart")
	for id in saved.furniture:
		var at=saved.furniture[id]
		var after=restored.furniture.get(id,[])
		check(after.size()==5 and is_equal_approx(float(after[3]),float(at[3])) and int(after[4])==int(at[4]),"scale/order lost after restart "+id)
	DirAccess.remove_absolute(saved.save_path)
	if OS.get_cmdline_user_args().has("--capture"):
		DirAccess.make_dir_recursive_absolute("user://furniture-style-review")
		for design in range(3):
			room.pieces.alarm_clock.set_appearance({"design":design})
			for i in range(4): await process_frame
			await RenderingServer.frame_post_draw
			room.pieces.alarm_clock.get_texture().get_image().save_png("user://furniture-style-review/alarm-%d.png"%design)
		for color in range(6):
			room.pieces.sofa.set_appearance({"color":color,"finish":color%4})
			for i in range(4): await process_frame
			await RenderingServer.frame_post_draw
			room.pieces.sofa.get_texture().get_image().save_png("user://furniture-style-review/sofa-%d.png"%color)
		for piece in room.pieces.values(): piece.set_appearance({})
		for id in room.buttons: room.remove_piece(id)
		for id in ["table","sofa","play_rug"]: room.place(id,Vector2(500,350),false)
		app.state.play_affection={"0":0}
		room.refresh_buttons()
		for i in range(8): await process_frame
		await RenderingServer.frame_post_draw
		room.panel.get_texture().get_image().save_png("user://furniture-style-review/panel.png")
	app.queue_free()
	await process_frame
	print("FURNITURE STYLES: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
