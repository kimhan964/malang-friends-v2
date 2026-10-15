extends RefCounted
## One visual-size reference for every action of a species and age.
## Alpha coverage measures the whole painted animal, independent of padding,
## raised ears/arms or curled posture. Never stretch its width and height apart.
const Art=preload("res://scripts/generated_species_art.gd")
const Smooth=preload("res://scripts/smooth_species_art.gd")
const Rabbit=preload("res://scripts/rabbit_pilot_art.gd")
const Metrics=preload("res://scripts/texture_metrics.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
static var references={}
static var eating_areas={}

static func size_reference(m) -> Dictionary:
	var stage=Art.stage_name(m)
	var key="%d/%s/%s/%s/%d"%[m.species,stage,m.rabbit_pilot,m.smooth_walk_enabled,Smooth.version]
	if not references.has(key):
		var tex: Texture2D
		var height: float
		if m.rabbit_pilot and m.species==0:
			tex=Rabbit.frames(stage,"idle")[0]
			height=float(Rabbit.data().stages[stage].reference_height)
		elif m.smooth_walk_enabled and m.species>0 and Smooth.data(m.species).get("stages",{}).has(stage):
			tex=Smooth.frames(m.species,stage,"idle")[0]
			height=float(Smooth.data(m.species).stages[stage].reference_height)
		else:
			tex=Art.frames(m.species,stage,"idle")[0]
			height=float(Art.data(m.species).stages[stage].reference_height)
		references[key]={"coverage":Metrics.opaque_area(tex)/(height*height)}
	return references[key]

static func apply(view) -> void:
	var m=view.motion
	var sample: Dictionary=view.generated_sample
	if sample.get("regenerated_expression",false): return
	if sample.get("home_animation",false): return
	if sample.get("slapstick",false): return
	if sample.get("dining",false) or (sample.get("pilot",false) and sample.action=="drink"): return
	# Approved locomotion retains its authored camera and low rabbit hop.
	if sample.action in ["idle","walk"] and (sample.get("pilot",false) or sample.get("smooth_walk",false)):
		return
	var target=Catalog.DISPLAY_HEIGHT*Catalog.HEIGHTS[m.species]*m.growth_scale
	var coverage=Metrics.opaque_area(view.sprite.texture)
	if sample.action=="eat" or (sample.action=="drink" and m.visit_id=="home_water"):
		# Fix the camera for the whole meal. A raised paw or a disappearing bite
		# must not rescale the animal every time its painted area changes.
		var key="%d/%s/%s/%d/%s/%s"%[m.species,sample.stage,sample.get("pilot",false),m.outfit_style,sample.get("dressed",false),sample.action]
		if not eating_areas.has(key):
			var sequence=Rabbit.frames(sample.stage,sample.action) if sample.get("pilot",false) else Art.frames(m.species,sample.stage,sample.action)
			if sample.get("dressed",false): sequence=Art.dressed_frames(m.species,sample.stage,m.outfit_style,sample.action)
			eating_areas[key]=Metrics.opaque_area(sequence[0])
		coverage=float(eating_areas[key])
	var scale=target*sqrt(float(size_reference(m).coverage)/coverage)
	var previous=absf(view.sprite.scale.y)
	var ratio=scale/maxf(.00001,previous)
	# Keep the established feet/root and existing bridge registration. Moving
	# the window or fitting its bounds here would detach the pet from the mouse.
	view.sprite.position=view.FEET+(view.sprite.position-view.FEET)*ratio
	view.sprite.scale=Vector2(scale*m.facing,scale)
