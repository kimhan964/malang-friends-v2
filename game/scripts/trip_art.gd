extends RefCounted
const Art=preload("res://scripts/v2_interaction_art.gd")
const SECONDS=2.8
static func at(species: int,time: float) -> Dictionary:
	var clock=clampf(time,0,SECONDS)
	var action="landing" if clock<.55 else ("dizzy" if clock<1.55 else "recover")
	var p=clampf(clock/.55 if action=="landing" else ((clock-.55)/1.0 if action=="dizzy" else (clock-1.55)/1.25),0,1)
	var cels=Art.frames(species,action)
	var index=mini(cels.size()-1,int(p*(cels.size()-1)))
	var angle=1.3*smoothstep(.12,.64,clock)*(1.0-smoothstep(1.55,2.65,clock))
	var texture: Texture2D=cels[index]
	return {"texture":texture,"next_texture":texture,"frame_mix":0.0,"action":"stumble","bank":"trip_"+action,"index":index,"height":float(Art.data(species).reference_height),"anchor":Vector2(128,232),"mouth":Vector2(156,125),"hand":Vector2(151,175),"fixed_cels":true,"soft_roster":true,"trip":true,"trip_angle":angle}
static func sample(m) -> Dictionary:
	var result=at(m.species,m.daily.clock)
	result.stage=preload("res://scripts/smooth_species_art.gd").stage(m)
	return result
