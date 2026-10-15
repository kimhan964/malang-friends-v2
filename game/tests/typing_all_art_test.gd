extends SceneTree
const Catalog=preload("res://scripts/animal_catalog.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var capture="--capture" in OS.get_cmdline_user_args()
	var folder="res://builds/typing-review/all-art"
	if capture: DirAccess.make_dir_recursive_absolute(folder)
	var app=preload("res://tests/typing_visual_review.gd").FakeApp.new()
	root.add_child(app)
	for species in range(16):
		var art="assets/typing-rabbit-v1" if species==0 else "assets/typing-animals-v1/"+Catalog.IDS[species]
		for pose in ["idle","left","right"]:
			var file=art+"/"+pose+".png"
			assert(FileAccess.get_file_as_bytes("res://"+file)==FileAccess.get_file_as_bytes("C:/Users/rlagk/Documents/바탕화면 친구/"+file),"Installed resource mismatch: "+file)
		var m=preload("res://scripts/desktop_pet_motion.gd").new()
		m.species=species
		m.growth_stage=2
		m.growth_scale=1
		app.pet={"species":species,"motion":m}
		var widget=preload("res://scripts/typing_companion.gd").new()
		widget.app=app
		app.add_child(widget)
		widget.input_bridge.stop()
		widget.paused=true
		widget.set_process(false)
		assert(widget.typing_frames.size()==3 and widget.typing_sprite.visible,"Missing art: "+Catalog.IDS[species])
		assert(not widget.view.visible)
		for key in widget.keys: assert(not key.visible)
		var zoom=widget.typing_sprite.scale
		var anchor=widget.typing_sprite.position
		var poses={}
		for i in range(300):
			widget.pending=true
			widget._process(1.0/60.0)
			poses[widget.typing_index]=true
			assert(widget.typing_sprite.scale==zoom and widget.typing_sprite.position==anchor)
			assert(widget.typing_sprite.rotation==0)
			assert(widget.typing_sprite.texture==widget.typing_frames[widget.typing_index])
		assert(poses.size()==3)
		widget.pending=false
		widget._process(1)
		assert(widget.typing_index==0)
		if capture:
			for pose in range(3):
				widget.pulse_age=1.0 if pose==0 else 0.0
				widget.side=-1 if pose==1 else 1
				widget._process(0)
				assert(widget.typing_index==pose)
				await process_frame
				await RenderingServer.frame_post_draw
				assert(widget.get_texture().get_image().save_png(folder+"/%02d-%d.png"%[species,pose])==OK)
		widget.queue_free()
		await process_frame
		preload("res://scripts/generated_species_art.gd").release_other_species(-1)
		print("TYPING_ART_OK ",Catalog.IDS[species])
	print("ALL_TYPING_ART_PASS: 16 species / 48 full images / 4800 input samples / fixed anchors / idle return")
	quit()
