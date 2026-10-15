extends SceneTree
const Preview=preload("res://scripts/species_walk_preview.gd")
var preview
var time=0.0
var records=[]
var falls=[]
var visits=[]
var failures=[]
var max_step=0.0
var previous=Vector2.ZERO
var folder="res://tool-delivery-review-2026-10-05"
var seen={}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	preview=Preview.new()
	root.add_child(preview)
	# A child added while SceneTree is setting up may receive _ready later.
	if not preview.is_node_ready(): await preview.ready
	var app=preview.app
	# Review uses preview state, with no writes to the player's progression.
	app.pet.window_input.disconnect(app.pet.handle_input)
	app.pet.motion.rng.seed=24
	previous=app.pet.motion.feet
	app.pet.motion.visited.connect(func(id): visits.append(id); print("NATIVE_VISIT ",time," ",id))
	for frame in range(60*105):
		await process_frame
		time+=1.0/60.0
		var m=app.pet.motion
		if frame%600==0: print("NATIVE_STATE ",time," ",m.phase," held=",m.held," resting=",m.resting," autonomy=",m.autonomy," queue=",app.delivery_queue," delay=",app.delivery_delay)
		max_step=maxf(max_step,previous.distance_to(m.feet))
		previous=m.feet
		if app.falling_gifts.size()>1: failures.append("overlapping drops")
		for id in app.falling_gifts:
			if id not in falls:
				falls.append(id)
				print("NATIVE_FALL ",time," ",id)
			var fall=app.falling_gifts[id]
			if float(fall.time)>.65 and not seen.has("fall/"+id):
				seen["fall/"+id]=true
				await RenderingServer.frame_post_draw
				app.props[id].get_texture().get_image().save_png(folder+"/fall-"+id+".png")
		if m.phase=="prop_use" and not seen.has("play/"+m.visit_id):
			seen["play/"+m.visit_id]=true
			await RenderingServer.frame_post_draw
			app.pet.get_texture().get_image().save_png(folder+"/play-"+m.visit_id+".png")
		if frame%60==0: records.append({"time":time,"phase":m.phase,"id":m.visit_id,"feet":[m.feet.x,m.feet.y],"falling":app.falling_gifts.keys(),"queue":app.delivery_queue.duplicate()})
		if "plant" in visits and app.delivery_queue.is_empty() and time>65: break
	if falls!=["acorn","basket","plant"]: failures.append("missing sequence "+str(falls))
	if "acorn" not in visits or "plant" not in visits: failures.append("missing interaction")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"falls":falls,"visits":visits,"max_frame_step":max_step,"failures":failures,"records":records}))
	print("NATIVE_DELIVERY_DONE falls=",falls," visits=",visits," max_frame_step=",max_step," failures=",failures)
	quit(0 if failures.is_empty() else 1)

func get_process_time() -> float:
	return root.get_process_delta_time()
