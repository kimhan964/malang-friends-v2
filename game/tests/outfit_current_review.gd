extends SceneTree
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
class ReviewView extends "res://scripts/desktop_pet_view.gd":
	func prewarm_current_art() -> void: pass
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var ids=[0,1,14]
	var folder="res://design/outfit-current-before"
	for arg in OS.get_cmdline_user_args():
		if arg=="--all": ids=range(16)
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(folder)
	for species in ids:
		var viewport=SubViewport.new()
		viewport.size=Vector2i(1536,896)
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var bg=ColorRect.new()
		bg.color=Color("faf8f3")
		bg.size=viewport.size
		viewport.add_child(bg)
		for row in range(4):
			for col in range(6):
				var m=Motion.new()
				m.species=species
				m.growth_stage=0 if row<2 else 2
				m.growth_scale=.93 if row<2 else 1.0
				m.rabbit_pilot=species==0
				m.smooth_walk_enabled=species>0
				m.outfit_style=col%4 if row%2==0 else 1
				m.outfit_color=0
				m.phase="idle" if row%2==0 else ["wander","eat","doze","carry","home_use","react"][col]
				if row%2==0 and col>3:
					m.outfit_style=col-3
					m.phase="wander"
				m.food_id=Catalog.DEFAULT_MEALS[species]
				m.visit_id="home_sofa" if m.phase=="home_use" else ""
				m.carried=m.phase=="carry"
				m.carry_elapsed=2.4 if m.carried else 0
				m.elapsed=1.4
				m.action_left=4
				m.walk_phase=.35
				m.reaction="happy"
				m.reaction_time=.4
				var view=ReviewView.new()
				view.motion=m
				view.position=Vector2(col*256,row*224)
				viewport.add_child(view)
				view.refresh(0)
				var label=Label.new()
				label.text="%s / %s / %s / %s"%[Catalog.IDS[species],"baby" if row<2 else "adult",m.outfit_style,m.phase]
				label.position=view.position+Vector2(8,8)
				label.add_theme_color_override("font_color",Color("59564f"))
				label.add_theme_font_size_override("font_size",13)
				viewport.add_child(label)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(folder+"/"+Catalog.IDS[species]+".png")
		viewport.queue_free()
		await process_frame
		preload("res://scripts/generated_species_art.gd").release_other_species(-1)
		print("OUTFIT_REVIEW ",species)
	quit()
