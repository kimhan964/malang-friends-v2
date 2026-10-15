extends SceneTree
const Widget=preload("res://scripts/typing_companion.gd")
class FakeApp extends Node:
	var typing_activity=preload("res://scripts/typing_activity.gd").new()
	var state=preload("res://scripts/pet_state.gd").new()
	var app_theme=preload("res://scripts/cozy_ui.gd").theme()
	var pet: Dictionary={}
	var commerce_access=null
	func usable_screen() -> Rect2i: return Rect2i(0,0,1280,720)
	func set_play_mode(_mode): pass
	func shutdown(): pass
	func choose_friend(_id): pass

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var folder="res://builds/typing-review"
	DirAccess.make_dir_recursive_absolute(folder)
	var app=FakeApp.new()
	root.add_child(app)
	for species in range(16):
		var m=preload("res://scripts/desktop_pet_motion.gd").new()
		m.species=species
		m.growth_stage=2
		m.growth_scale=1
		app.pet={"species":species,"motion":m}
		var widget=Widget.new()
		widget.app=app
		app.add_child(widget)
		widget.input_bridge.stop()
		widget.paused=true
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var texture=widget.view.sprite.texture
		assert(texture!=null)
		var initial_scale=widget.view.sprite.scale
		widget.get_texture().get_image().save_png(folder+"/species-%02d.png"%species)
		# Hundreds of key events must never create a growing queue or change body size.
		for i in range(240):
			widget.pending=true
			widget._process(1.0/60.0)
			assert(widget.view.sprite.scale==initial_scale)
			assert(absf(widget.pivot.position.x-110)<=.701)
			assert(widget.pivot.position.y>=158 and widget.pivot.position.y<=160.201)
		widget.pending=false
		widget._process(1.0)
		assert(widget.pivot.position.is_equal_approx(Vector2(110,158)))
		widget.queue_free()
		await process_frame
		preload("res://scripts/generated_species_art.gd").release_other_species(-1)
	print("TYPING_VISUAL_PASS 16 species / 3840 rapid-input poses / stable scale")
	quit()
