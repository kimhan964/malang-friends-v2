extends RefCounted
## Real native pet/prop views, using the ordinary visit and render paths.
## The review state never writes the player's saved progress or layout.
func run(preview) -> void:
	preview.capture_running=true
	preview.looping=false
	preview.capture_interval=.05
	preview.controls.title="복슬복슬펫 · 식사 동작 연결 점검"
	var selected_species=[]
	var output_folder="dining-native"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dining-output="):
			var candidate=arg.trim_prefix("--dining-output=")
			if candidate.is_valid_filename(): output_folder=candidate
		if arg.begins_with("--capture-species="):
			for id in arg.trim_prefix("--capture-species=").split(","): selected_species.append(int(id))
	var results=[]
	for species in range(16):
		if not selected_species.is_empty() and not selected_species.has(species): continue
		for age in ["baby","adult"]:
			for prop_id in ["water","bowl"]:
				preview.selected=species
				preview.baby=age=="baby"
				preview.modern=true
				preview.select_pet()
				var app=preview.app
				var m=app.pet.motion
				preview.capture_interval=1.0/60.0 if prop_id=="water" and preload("res://scripts/dining_species_art.gd").enabled(m) else .05
				m.cancel_play()
				m.phase="idle"
				var usable=DisplayServer.screen_get_usable_rect()
				var prop=app.props[prop_id]
				for key in app.props: app.props[key].visible=key==prop_id
				prop.position=Vector2i(Vector2(usable.position)+Vector2(usable.size.x*.52,usable.size.y*.62)-prop.anchor_offset())
				prop.show()
				var point=app.pet_dining_point(prop)
				var stride=16.0
				if preview.Smooth.enabled(m): stride=m.smooth_walk_cycle.stride_length(m,preview.Smooth.spec(m))
				m.move_to((point-Vector2(stride*1.25,0)).clamp(m.bounds.position,m.bounds.end))
				m.facing=1.0
				preview.label.text=preview.Catalog.NAMES[species]+" · "+age+" · "+prop_id+" 연결 점검"
				preview.capture_folder="%s/%s-%s-%s"%[output_folder,preview.Catalog.IDS[species],age,prop_id]
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://")+preview.capture_folder)
				preview.capture_prop=prop_id
				preview.capture_frames=[]
				preview.capture_images=[]
				preview.capture_age=0
				preview.capture_timer=0
				preview.capture_index=0
				await preview.get_tree().create_timer(.5).timeout
				preview.capture_enabled=true
				await preview.get_tree().create_timer(.35).timeout
				m.visit(point,"drink" if prop_id=="water" else "eat",prop_id)
				var travel_wait=0.0
				while m.phase=="visit" and travel_wait<8:
					await preview.get_tree().create_timer(.05).timeout
					travel_wait+=.05
				# One full consumption action, its ordinary completion, and return.
				await preview.get_tree().create_timer(maxf(0,m.action_left)+(3.2 if prop_id=="bowl" else .7)).timeout
				preview.capture_enabled=false
				for item in preview.capture_images:
					item.image.save_png(ProjectSettings.globalize_path("res://")+item.file)
				preview.capture_images.clear()
				results.append({"species":preview.Catalog.IDS[species],"stage":age,"requested_action":"drink" if prop_id=="water" else "eat","prop":prop_id,"capture_interval":preview.capture_interval,"modern_walk":preview.Smooth.enabled(m),"travel_timed_out":travel_wait>=8,"frames":preview.capture_frames})
				print("DINING_NATIVE_CAPTURE ",preview.Catalog.IDS[species]," ",age," ",prop_id," ",preview.capture_frames.size())
	var report=FileAccess.open(ProjectSettings.globalize_path("res://")+output_folder+"-report.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_driver_name(),"sampling":"Per-case capture_interval; actual timestamps are authoritative.","results":results},"\t"))
	report.close()
	print("DINING_NATIVE_CAPTURE_DONE ",results.size())
	preview.capture_prop=""
	if OS.get_cmdline_user_args().has("--capture-quit"): preview.get_tree().quit()
	else:
		preview.capture_running=false
		preview.looping=false
