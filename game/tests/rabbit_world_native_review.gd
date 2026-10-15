extends SceneTree
const Preview=preload("res://scripts/species_walk_preview.gd")
var preview
var failures=[]
var rows=[]
var folder="res://rabbit-world-review-2026-10-05"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	preview=Preview.new()
	root.add_child(preview)
	if not preview.is_node_ready(): await preview.ready
	preview.set_process(false)
	preview.app.set_process(false)
	preview.looping=false
	preview.free_play=false
	for baby in [false,true]:
		preview.selected=0
		preview.baby=baby
		preview.select_pet()
		var pet=preview.app.pet
		pet.window_input.disconnect(pet.handle_input)
		var m=pet.motion
		for direction in [1,-1]:
			preview.direction=direction
			preview.start_walk()
			var origin=m.feet
			var goal=m.target
			var surface=Rect2i(pet.position,pet.size)
			var key=("baby" if baby else "adult")+("-right" if direction==1 else "-left")
			# A FIXED desktop crop makes actual displacement visible. Following
			# the feet with a moving camera masks a failure to travel on screen.
			var crop_origin=Vector2i(minf(origin.x,goal.x)-100,origin.y-190)-pet.position
			var capture=Rect2i(crop_origin,Vector2i(360,220))
			var tick=0
			var began=Time.get_ticks_msec()
			var root_error=0.0
			var previous=m.feet
			var backtrack=0.0
			while m.phase=="wander" and Time.get_ticks_msec()-began<20000:
				await process_frame
				await RenderingServer.frame_post_draw
				root_error=maxf(root_error,(Vector2(pet.position)+pet.view.position+pet.View.FEET).distance_to(m.feet))
				backtrack=maxf(backtrack,(previous.x-m.feet.x)*direction)
				previous=m.feet
				if Rect2i(pet.position,pet.size)!=surface: failures.append(key+" window moved")
				if tick%3==0:
					pet.get_texture().get_image().get_region(capture).save_png(folder+"/%s-%04d.png"%[key,tick])
				tick+=1
			var distance=m.feet.distance_to(origin)
			if distance<159.9 or m.phase!="idle": failures.append(key+" did not finish 160px trip")
			if root_error>.01 or backtrack>.01: failures.append(key+" visual root or reverse motion")
			rows.append({"case":key,"start":[origin.x,origin.y],"end":[m.feet.x,m.feet.y],"distance":distance,"seconds":(Time.get_ticks_msec()-began)/1000.0,"frames":tick,"root_error":root_error,"backtrack":backtrack})
			print("RABBIT_WORLD ",rows.back())
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":rows,"failures":failures},"\t"))
	print("RABBIT_WORLD_DONE failures=",failures)
	quit(0 if failures.is_empty() else 1)
