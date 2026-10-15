extends SceneTree
const Main=preload("res://scripts/main.gd")
const State=preload("res://scripts/pet_state.gd")
class MemoryState extends State:
	func load_game() -> void: pass
	func save_game() -> void: pass
func _initialize() -> void: call_deferred("run")
func run() -> void:
	ProjectSettings.set_setting("commerce/enabled",false)
	var app=Main.new();app.state=MemoryState.new()
	app.state.guide_seen=true;app.state.play_affection={"0":200}
	root.add_child(app);await process_frame
	app.set_process(false);app.pet.set_process(false)
	var room=app.furniture_room;room.set_process(false)
	app.delivery_queue.clear()
	for id in room.pieces.keys(): room.remove_piece(id)
	for prop in app.props.values(): prop.hide()
	var m=app.pet.motion;m.autonomy=false
	var metadata=[]
	var directory="res://builds/toy-pursuit-review"
	DirAccess.make_dir_recursive_absolute(directory)
	for id in ["toy_mouse","toy_ball"]:
		m.cancel_play();room.toy_play.cancel()
		m.move_to(Vector2(700,m.bounds.get_center().y))
		room.place(id,Vector2(760,300),false)
		var piece=room.pieces[id];piece.set_process(false)
		room.use_piece(id)
		for tick in range(720):
			app.pet.advance_frame(1.0/60)
			room.toy_play.advance(room,1.0/60)
			piece.set_active(m.visit_id=="home_"+id and m.phase!="visit")
			piece._process(1.0/60)
			if tick%12==0:
				await process_frame
				await RenderingServer.frame_post_draw
				var prefix=id+"-%03d"%(tick/12)
				app.pet.get_texture().get_image().save_png(directory+"/"+prefix+"-pet.png")
				piece.get_texture().get_image().save_png(directory+"/"+prefix+"-piece.png")
				metadata.append({"prefix":prefix,"pet":[app.pet.position.x,app.pet.position.y],"piece":[piece.position.x,piece.position.y],"phase":m.phase,"stage":room.toy_play.stage})
		room.remove_piece(id)
	var f=FileAccess.open(directory+"/frames.json",FileAccess.WRITE);f.store_string(JSON.stringify(metadata))
	app.queue_free();await process_frame
	print("TOY PURSUIT RENDER: COMPLETE")
	quit()
