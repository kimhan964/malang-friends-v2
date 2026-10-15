extends SceneTree
const Pet=preload("res://scripts/desktop_pet.gd")
const State=preload("res://scripts/pet_state.gd")
const Outline=preload("res://scripts/animation_outline.gd")
class TestState extends State:
	func save_game() -> void: pass
class PreviousPet extends Pet:
	func sync_position() -> void:
		var local_feet=motion.feet-Vector2(position)
		var top_limit=165 if motion.is_struggling() else 125
		if local_feet.x<70 or local_feet.x>size.x-70 or local_feet.y<top_limit or local_feet.y>size.y-12:
			position=Vector2i(motion.feet-View.FEET-Vector2(240,0))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.mouse_passthrough=true
	var before=OS.get_cmdline_user_args().has("--before")
	var folder="res://pointer-carry-review/"+("before" if before else "after")
	DirAccess.make_dir_recursive_absolute(folder)
	var results=[]
	for species in ([1] if before else [0,1,6,14]):
		for stage in [0,2]:
			var pet=PreviousPet.new() if before else Pet.new()
			pet.species=species
			pet.state=TestState.new()
			root.add_child(pet)
			pet.set_process(false)
			var m=pet.motion
			m.autonomy=false
			m.growth_stage=stage
			m.growth_scale=.93 if stage==0 else 1.0
			m.rabbit_pilot=species==0
			m.smooth_walk_enabled=species!=0
			m.move_to(Vector2(850,490))
			pet.advance_frame(0)
			await process_frame
			pet.begin_pointer(m.feet-Vector2(0,65))
			pet.move_pointer(m.feet-Vector2(0,95),1.0/60)
			var frames=[]
			for step in range(481):
				var cursor=Vector2(850+sin(step/48.0)*610,395+sin(step/37.0)*245)
				if step<360: pet.move_pointer(cursor,1.0/60)
				elif step==360: pet.release_pointer()
				pet.advance_frame(1.0/60)
				var fitted=pet.view.sprite.scale.abs()
				var points=Outline.blended_points(pet.view.sprite)
				var clipped=false
				for point in points:
					if not Rect2(Vector2.ZERO,Vector2(pet.size)).has_point(point): clipped=true
				await RenderingServer.frame_post_draw
				var sample=pet.view.generated_sample
				var natural=pet.view.Art.DISPLAY_HEIGHT*pet.view.Art.HEIGHTS[species]/sample.height*m.growth_scale
				var record={"step":step,"time":step/60.0,"bank":sample.get("bank","legacy"),"scale_ratio":fitted.y/natural,"clipped":clipped,"cursor":[cursor.x,cursor.y],"feet":[m.feet.x,m.feet.y],"window":[pet.position.x,pet.position.y],"canvas":[pet.size.x,pet.size.y]}
				if step%12==0:
					var image=pet.get_texture().get_image()
					var region=Rect2i(Vector2i(m.feet-Vector2(pet.position)-Vector2(150,220)),Vector2i(300,260)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
					var name="%d-%d-%03d.png"%[species,stage,step]
					image.get_region(region).save_png(folder+"/"+name)
					record.file=name
				frames.append(record)
			results.append({"species":species,"stage":stage,"frames":frames})
			pet.free()
			await process_frame
			print("POINTER_NATIVE ",species,"/",stage)
	var file=FileAccess.open(folder+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results))
	print("POINTER_NATIVE_DONE ",results.size())
	quit()
