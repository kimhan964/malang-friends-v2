extends SceneTree
const Preview=preload("res://scripts/species_walk_preview.gd")
var preview
var folder="res://home-v2-native-review"
var records=[]
var failures=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var ids=["sofa","table","reading_chair","daybed"]
	if OS.get_cmdline_user_args().has("--home-review-new"):
		folder="res://home-v2-native-review-new"
		ids=["vanity","record_player","play_rug","window_seat"]
	DirAccess.make_dir_recursive_absolute(folder)
	preview=Preview.new()
	root.add_child(preview)
	if not preview.is_node_ready(): await preview.ready
	preview.set_process(false)
	preview.app.set_process(false)
	preview.looping=false
	var app=preview.app
	var room=app.furniture_room
	room.set_process(false)
	for p in room.pieces.values(): p.hide()
	for id in ids:
		room.place(id,Vector2(900,650),false)
		var p=room.pieces[id]
		p.position=Vector2i(900,650)
		p.show()
		var key="home_"+id if id!="table" else "home_tea"
		var m=app.pet.motion
		m.autonomy=false
		m.move_to(room.destination_point(key)-Vector2(20,0))
		room.use_piece(id)
		var n=0
		var next=.5
		var began=Time.get_ticks_msec()
		while Time.get_ticks_msec()-began<18000:
			await process_frame
			await RenderingServer.frame_post_draw
			if m.phase=="home_use" and m.elapsed>=next:
				var crop=Rect2i(Vector2i(m.feet)-Vector2i(130,190),Vector2i(300,245))
				app.pet.get_texture().get_image().get_region(Rect2i(crop.position-app.pet.position,crop.size)).save_png(folder+"/%s-%d-pet.png"%[id,n])
				p.get_texture().get_image().save_png(folder+"/%s-%d-furniture.png"%[id,n])
				records.append({"id":id,"n":n,"pet":[crop.position.x,crop.position.y],"furniture":[p.position.x,p.position.y],"scale":app.pet.view.sprite.scale.y,"index":app.pet.view.generated_sample.index})
				n+=1
				next+=.7
			if n>0 and m.phase=="idle": break
		if n<3: failures.append(id+" missing interaction")
		print("HOME_V2_NATIVE ",id," frames=",n)
		p.hide()
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"frames":records,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
