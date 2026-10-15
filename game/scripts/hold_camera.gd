extends RefCounted
const Catalog=preload("res://scripts/animal_catalog.gd")
static var measurements={}
static func entries(species: int,stage: String) -> Array:
	if measurements.is_empty(): measurements=JSON.parse_string(FileAccess.get_file_as_string("res://assets/hold-camera-v2.json"))
	return measurements[Catalog.IDS[species]+"/"+stage]["struggle-v1"]

static func registration(species: int,sample: Dictionary) -> Dictionary:
	var bank=str(sample.get("bank",""))
	var index=int(sample.get("index",0))
	var list=entries(species,sample.stage)
	var factor=1.0
	var pivot=Vector2(128,130)
	if bank=="struggle-v1":
		var entry=list[index]
		factor=entry.scale
		pivot=Vector2(entry.pivot[0],entry.pivot[1])
	elif bank in ["hold-carry_entry","hold-idle_entry"]:
		factor=lerpf(1,float(list[0].scale),smoothstep(0,1,index/16.0))
		pivot=sample.get("grip",pivot)
	elif bank.begins_with("hold-release"):
		var key=int(bank.trim_prefix("hold-release"))*15
		factor=lerpf(float(list[key].scale),1,smoothstep(0,1,index/16.0))
		pivot=sample.get("grip",pivot)
	return {"scale":factor,"pivot":pivot}

static func apply(view) -> void:
	var sample: Dictionary=view.generated_sample
	if not sample.get("hold_visual",false): return
	var spec=registration(view.motion.species,sample)
	var pivot=view.sprite.transform*spec.pivot
	view.sprite.position=pivot+(view.sprite.position-pivot)*spec.scale
	view.sprite.scale*=spec.scale
