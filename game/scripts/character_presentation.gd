extends RefCounted
const Metrics=preload("res://scripts/texture_metrics.gd")
const Art=preload("res://scripts/generated_species_art.gd")
static var neutral_heights: Dictionary={}
static var walk_poses: Dictionary={}
const UPRIGHT=["idle","walk","pet","eat","drink","carry","land","wave"]

static func neutral_height(species: int, stage: String) -> float:
	var key="%d/%s"%[species,stage]
	if not neutral_heights.has(key):
		var heights: Array=[]
		for cel in Art.frames(species,stage,"idle"): heights.append(float(Metrics.used_rect(cel).size.y))
		heights.sort()
		neutral_heights[key]=heights[heights.size()/2]
	return neutral_heights[key]

static func pose(species: int, sample: Dictionary, expression: bool=false) -> Dictionary:
	var texture: Texture2D=sample.texture
	var used=Metrics.used_rect(texture)
	var stage: String=sample.stage
	var action: String=sample.action
	var reference=neutral_height(species,stage)
	var correction=Vector2.ONE
	var anchor=Art.ROOT
	if action in ["walk","carry"] and not expression:
		# Calibrate the entire bank once. Per-cel height fitting and odd-cel
		# width correction made an animated animal visibly pulse in size.
		var key="%d/%s/%s"%[species,stage,action]
		if not walk_poses.has(key):
			var heights: Array=[]
			var bottoms: Array=[]
			for cel in Art.frames(species,stage,action):
				var rect=Metrics.used_rect(cel)
				heights.append(float(rect.size.y))
				bottoms.append(float(rect.end.y))
			heights.sort()
			bottoms.sort()
			walk_poses[key]={"scale":Vector2.ONE*reference/maxf(1.0,heights[heights.size()/2]),"anchor":Vector2(Art.ROOT.x,bottoms[bottoms.size()/2])}
		return walk_poses[key]
	if action in UPRIGHT or expression:
		correction=Vector2.ONE*reference/maxf(1.0,used.size.y)
		anchor.y=used.end.y
	else:
		# Crouching/sleeping must retain their authored silhouette. Calibrate the
		# whole sequence from its standing start, rather than enlarging each crouch.
		var first=Art.frames(species,stage,action)[0]
		correction=Vector2.ONE*reference/maxf(1,Metrics.used_rect(first).size.y)
	return {"scale":correction,"anchor":anchor}
