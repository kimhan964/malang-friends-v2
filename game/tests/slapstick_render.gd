extends SceneTree
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const View=preload("res://scripts/desktop_pet_view.gd")
const Slap=preload("res://scripts/slapstick.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
class QuietView extends View:
	func prewarm_current_art() -> void: pass
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport=SubViewport.new()
	viewport.size=Vector2i(256,256)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	DirAccess.make_dir_recursive_absolute("res://builds/slapstick-review")
	var failures=[]
	for species in range(16):
		var sheet=Image.create(1536,1024,false,Image.FORMAT_RGBA8)
		sheet.fill(Color("faf8f3"))
		for age in range(2):
			var m=Motion.new()
			m.species=species
			m.growth_stage=0 if age==0 else 2
			m.growth_scale=.93 if age==0 else 1.0
			m.rabbit_pilot=species==0
			m.smooth_walk_enabled=species>0
			if not Slap.available(m): failures.append("missing "+Catalog.IDS[species]+"/"+Slap.stage(m)); continue
			var view=QuietView.new()
			view.motion=m
			viewport.add_child(view)
			for action in range(2):
				m.silly_kind="stumble" if action==0 else "sneeze"
				m.phase="silly"
				var scale=Vector2.ZERO
				for i in range(6):
					m.elapsed=Slap.DURATIONS[m.silly_kind]*[0,.18,.37,.54,.77,.99][i]
					view.refresh(1.0/60)
					if i==0: scale=view.sprite.scale
					elif view.sprite.scale!=scale: failures.append("scale changed "+Catalog.IDS[species])
					await process_frame
					await RenderingServer.frame_post_draw
					sheet.blend_rect(viewport.get_texture().get_image(),Rect2i(0,0,256,256),Vector2i(i*256,(age*2+action)*256))
			view.queue_free()
			await process_frame
		Slap.release_other_species((species+1)%16)
		sheet.save_png("res://builds/slapstick-review/"+Catalog.IDS[species]+".png")
	print("SLAPSTICK RENDER: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
