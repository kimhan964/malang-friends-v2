extends SceneTree
const Preview=preload("res://scripts/species_walk_preview.gd")
var preview
var failures=[]
var rows=[]
var folder="res://travel-native-review-2026-10-05"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	preview=Preview.new()
	root.add_child(preview)
	if not preview.is_node_ready(): await preview.ready
	preview.set_process(false)
	preview.app.set_process(false)
	for species in [0,1,14]:
		for baby in [false,true]:
			preview.selected=species
			preview.baby=baby
			preview.looping=false
			preview.free_play=false
			preview.select_pet()
			var pet=preview.app.pet
			pet.set_process(false)
			pet.window_input.disconnect(pet.handle_input)
			var m=pet.motion
			m.cancel_play()
			m.phase="wander"
			m.target=m.feet+Vector2(400,0)
			var initial_rect=Rect2i(pet.position,pet.size)
			var initial_scale=Vector2.ZERO
			var key="%d-%s"%[species,"baby" if baby else "adult"]
			var blank=0
			var changes=0
			var samples=[]
			for tick in range(180):
				pet.advance_frame(1.0/60.0)
				await process_frame
				await RenderingServer.frame_post_draw
				if Rect2i(pet.position,pet.size)!=initial_rect:
					if changes==0: print("NATIVE_RECT_CHANGE ",tick," initial=",initial_rect," current=",Rect2i(pet.position,pet.size))
					changes+=1
				var center=Vector2i(m.feet)-pet.position
				var crop=pet.get_texture().get_image().get_region(Rect2i(center-Vector2i(120,190),Vector2i(240,220)))
				if crop.get_used_rect().size==Vector2i.ZERO: blank+=1
				if tick==0: initial_scale=pet.view.sprite.scale
				elif not initial_scale.is_equal_approx(pet.view.sprite.scale): failures.append(key+" scale changed")
				if tick%3==0: crop.save_png(folder+"/%s-%03d.png"%[key,tick])
				samples.append({"frame":tick,"phase":m.walk_phase,"x":m.feet.x,"cel":pet.view.generated_sample.index})
			if blank>0: failures.append(key+" blank rendered frames")
			# Cross the old 640 px window's recenter boundaries and check that
			# neither walking nor holding changes native geometry anymore.
			for offset in [Vector2(-250,-100),Vector2(300,40),Vector2.ZERO]:
				m.feet+=offset
				pet.sync_position()
				if Rect2i(pet.position,pet.size)!=initial_rect: changes+=1
			m.held=true
			m.pointer_grab=true
			pet.sync_position()
			if Rect2i(pet.position,pet.size)!=initial_rect: changes+=1
			if changes>0: failures.append(key+" native geometry changed")
			rows.append({"case":key,"blank":blank,"geometry_changes":changes,"samples":samples})
			print("TRAVEL_NATIVE ",key," blank=",blank," geometry_changes=",changes)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":rows,"failures":failures}))
	print("TRAVEL_NATIVE_DONE cases=",rows.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
