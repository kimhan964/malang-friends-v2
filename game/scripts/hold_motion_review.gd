extends RefCounted
## Replay pointer handlers in real native windows, without changing save data.
func run(preview) -> void:
	preview.capture_running=true
	preview.looping=false
	var selected_species=[]
	var output="hold-native"
	var edge_path=OS.get_cmdline_user_args().has("--capture-edge-path")
	var full_transition=OS.get_cmdline_user_args().has("--capture-transitions")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-species="):
			for id in argument.trim_prefix("--capture-species=").split(","): selected_species.append(int(id))
		if argument.begins_with("--capture-output="):
			var name=argument.trim_prefix("--capture-output=")
			if name.is_valid_filename(): output=name
	var folder=ProjectSettings.globalize_path("res://")+output
	DirAccess.make_dir_recursive_absolute(folder)
	var results=[]
	for species in range(16):
		if not selected_species.is_empty() and not selected_species.has(species): continue
		for stage in ["baby","adult"]:
			preview.selected=species
			preview.baby=stage=="baby"
			preview.select_pet()
			var pet=preview.app.pet
			pet.set_process(false)
			pet.motion.move_to(Vector2(900,460))
			pet.motion.facing=1
			for prop in preview.app.props.values(): prop.hide()
			pet.advance_frame(0)
			await preview.get_tree().process_frame
			var point=pet.motion.feet-Vector2(0,75)
			pet.begin_pointer(point)
			var frames=[]
			# Baby: completely stationary long press. Adult: lift then hold.
			for step in range(721 if full_transition else 421):
				var elapsed=step/60.0
				if step<360:
					var offset=Vector2(0,-minf(70.0,elapsed*140.0)) if stage=="adult" else Vector2.ZERO
					if edge_path and stage=="adult": offset.y-=maxf(0.0,elapsed-3.0)*30.0
					pet.move_pointer(point+offset,1.0/60.0)
				elif step==360: pet.release_pointer()
				pet.advance_frame(1.0/60.0)
				await RenderingServer.frame_post_draw
				if step%3!=0: continue
				var m=pet.motion
				var sample=pet.view.generated_sample
				var name="%s-%s-%03d.png"%[preview.Catalog.IDS[species],stage,step]
				pet.get_texture().get_image().save_png(folder+"/"+name)
				frames.append({"file":name,"time":(step+1)/60.0,"held_seconds":m.carry_elapsed,"struggling":m.is_struggling(),"bank":sample.get("bank","legacy"),"index":sample.index,"scale":[pet.view.sprite.scale.x,pet.view.sprite.scale.y],"phase":m.phase,"held":m.held,"carried":m.carried,"hold_visual":sample.get("hold_visual",false),"landing_left":m.landing_left,"dizzy_age":m.elapsed if m.phase=="dizzy" else 0.0})
			results.append({"species":preview.Catalog.IDS[species],"stage":stage,"input":"stationary" if stage=="baby" else ("lift-and-move" if edge_path else "lift-and-hold"),"frames":frames})
			print("HOLD_NATIVE_REVIEW ",species," ",stage)
	var file=FileAccess.open(folder+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_driver_name(),"input":"deterministic replay of production pointer handlers at 60 Hz; real native window rendering","results":results},"\t"))
	file.close()
	print("HOLD_NATIVE_REVIEW_DONE ",results.size())
	if OS.get_cmdline_user_args().has("--capture-quit"): preview.get_tree().quit()
	else:
		preview.capture_running=false
		preview.select_pet()
