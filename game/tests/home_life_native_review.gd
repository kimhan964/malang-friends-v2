extends SceneTree
const Preview=preload("res://scripts/species_walk_preview.gd")
var preview
var failures=[]
var records=[]
var folder="res://home-life-review-2026-10-05"
func _initialize() -> void: call_deferred("run")
func run() -> void:
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
	var screen=app.usable_screen()
	for id in room.Catalog.ITEMS:
		room.place(id,Vector2(screen.position)+Vector2(screen.size)*.65,false)
		room.pieces[id].position=Vector2i(Vector2(screen.position)+Vector2(screen.size)*.65)
		room.pieces[id].hide()
	for test in [[0,false,"home_food"],[0,true,"home_food"],[1,false,"home_food"],[14,false,"home_food"],[0,false,"home_water"],[0,true,"home_water"],[1,false,"home_water"],[14,false,"home_water"],[0,false,"home_sofa"],[0,false,"home_shelf"],[0,false,"home_lamp"]]:
		if OS.get_cmdline_user_args().has("--water-only") and test[2]!="home_water": continue
		preview.selected=test[0]
		preview.baby=test[1]
		preview.select_pet()
		var pet=app.pet
		var m=pet.motion
		m.autonomy=false
		var id: String=test[2]
		var piece_id: String=room.HOME_IDS[id]
		var piece=room.pieces[piece_id]
		piece.show()
		m.move_to(room.destination_point(id)-Vector2(26,0))
		room.use_piece(piece_id,"drink" if id=="home_water" else "default")
		var began=Time.get_ticks_msec()
		var key="%d-%s-%s"%[test[0],test[1],id]
		var next_capture=.4
		var count=0
		while Time.get_ticks_msec()-began<16000:
			await process_frame
			room._process(0)
			app.restore_layer_order()
			await RenderingServer.frame_post_draw
			if m.phase!="visit" and m.elapsed>=next_capture:
				var crop=Rect2i(Vector2i(m.feet)-Vector2i(130,190),Vector2i(260,240))
				pet.get_texture().get_image().get_region(Rect2i(crop.position-pet.position,crop.size)).save_png(folder+"/%s-%d-pet.png"%[key,count])
				piece.get_texture().get_image().save_png(folder+"/%s-%d-furniture.png"%[key,count])
				records.append({"key":key,"index":count,"pet_position":[crop.position.x,crop.position.y],"piece_position":[piece.position.x,piece.position.y],"phase":m.phase,"elapsed":m.elapsed})
				next_capture+=1.3
				count+=1
			if count>=4 or (m.visit_id!=id and m.phase!="visit"): break
		if count==0: failures.append(key+" did not interact")
		if app.props.bowl.visible or app.props.water.visible: failures.append("old outdoor dining still visible")
		print("HOME_NATIVE ",key," count=",count)
		piece.hide()
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"frames":records},"\t"))
	print("HOME_LIFE_NATIVE failures=",failures)
	quit(0 if failures.is_empty() else 1)
