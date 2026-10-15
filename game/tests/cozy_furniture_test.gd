extends SceneTree
const Main=preload("res://scripts/main.gd")
const State=preload("res://scripts/pet_state.gd")
const Catalog=preload("res://scripts/furniture_catalog.gd")
class MemoryState extends State:
	func load_game() -> void: pass
	func save_game() -> void: pass
var failures=[]
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
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
	check(Catalog.ITEMS.size()==21,"expected 21 furniture items")
	for id in Catalog.ITEMS:
		check(Catalog.texture(id)!=null,"missing texture "+id)
		check(app.state.UNLOCKS.has("home_"+id),"missing home progression "+id)
		room.place(id,Vector2(500,400),false)
		check(room.pieces.has(id),"placement failed "+id)
	for mode in ["floor","desktop"]:
		app.set_activity_space(mode)
		for id in ["wall_clock","wall_shelf","plant_stand","dresser","fireplace","aquarium"]:
			var piece=room.pieces[id]
			check(room.use_piece(id),"use failed "+id)
			check(app.pet.motion.visit_id=="home_"+id,"wrong visit "+id)
			check(app.pet.motion.bounds.grow(.1).has_point(room.destination_point("home_"+id)),"out of bounds "+id)
			room.on_visit("home_"+id)
			if Catalog.is_wall(id):
				check(not piece.floor_locked,"wall ornament floor locked")
				piece.press_position=Vector2(piece.position)
				piece.press_cursor=Vector2.ZERO
				piece.move_dragged_to(Vector2(0,-24))
				check(piece.position.y==int(piece.press_position.y)-24,"wall vertical placement failed")
			piece.set_mirrored(true)
			check(room.use_piece(id),"mirrored use failed")
	room.save()
	check(app.state.furniture.wall_clock[1]==room.pieces.wall_clock.position.y,"wall position not saved")
	room.open()
	check(room.buttons.size()==21,"missing placement buttons")
	if OS.get_cmdline_user_args().has("--capture"):
		for i in range(8): await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://builds/cozy-furniture-review")
		room.panel.get_texture().get_image().save_png("res://builds/cozy-furniture-review/panel.png")
		for id in room.pieces:
			room.pieces[id].get_texture().get_image().save_png("res://builds/cozy-furniture-review/"+id+".png")
	app.queue_free()
	await process_frame
	print("COZY FURNITURE: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
