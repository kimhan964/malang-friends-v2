extends SceneTree
const Preview=preload("res://scripts/species_walk_preview.gd")
const Home=preload("res://scripts/home_animation.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
var folder="res://home-v2-native-matrix"
var records=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var preview=Preview.new()
	root.add_child(preview)
	if not preview.is_node_ready(): await preview.ready
	preview.set_process(false)
	preview.looping=false
	var app=preview.app
	app.set_process(false)
	var room=app.furniture_room
	room.set_process(false)
	for id in room.Catalog.ITEMS: room.place(id,Vector2(900,650),false)
	for p in room.pieces.values(): p.hide()
	for species in range(16):
		for baby in [true,false]:
			preview.selected=species
			preview.baby=baby
			preview.select_pet()
			app.pet.set_process(false)
			var m=app.pet.motion
			m.autonomy=false
			for id in room.Catalog.ITEMS:
				var p=room.pieces[id]
				p.position=Vector2i(900,650)
				p.show()
				var key="home_tea" if id=="table" else "home_"+id
				m.move_to(room.destination_point(key))
				m.phase="home_use"
				m.visit_id=key
				m.facing=1
				m.elapsed=Home.duration(key)*.42
				m.action_left=Home.duration(key)-m.elapsed
				# Keep the real stationary desktop canvas and view offset. Moving
				# only the native window would double-apply the original offset.
				app.pet._process(0.0)
				await process_frame
				await RenderingServer.frame_post_draw
				var name="%s-%s-%s"%[Catalog.IDS[species],"baby" if baby else "adult",id]
				var crop=Rect2i(Vector2i(m.feet)-Vector2i(140,210),Vector2i(330,275))
				app.pet.get_texture().get_image().get_region(Rect2i(crop.position-app.pet.position,crop.size)).save_png(folder+"/"+name+"-pet.png")
				p.get_texture().get_image().save_png(folder+"/"+name+"-furniture.png")
				records.append({"name":name,"species":Catalog.IDS[species],"age":"baby" if baby else "adult","id":id,"pet":[crop.position.x,crop.position.y],"furniture":[p.position.x,p.position.y],"scale":app.pet.view.sprite.scale.y,"bank":app.pet.view.generated_sample.get("bank","")})
				p.hide()
		print("HOME_NATIVE_MATRIX ",Catalog.IDS[species])
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	quit()
