extends RefCounted
## Complete raster cels only. Generated poses and whole-image inbetweens.
static var banks: Dictionary={}
static var data: Dictionary={}
static func frames(action: String) -> Array:
 if data.is_empty(): data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/soft-hedgehog/basic-manifest.json"))
 if not banks.has(action):
  var spec: Dictionary=data.sequences[action]
  var image=Image.new()
  if image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/soft-hedgehog/"+str(spec.file)))!=OK: return []
  var result: Array=[]
  for i in range(int(spec.count)):
   result.append(ImageTexture.create_from_image(image.get_region(Rect2i(i%8*256,i/8*256,256,256))))
  banks[action]=result
 return banks[action]
static func action_for(motion) -> String:
 if motion.phase=="home_use":
  var kind: String=preload("res://scripts/home_animation.gd").KINDS.get(motion.visit_id,"rest")
  return {"nap":"sleep","tea":"eat","music":"pet","play":"pet","groom":"pet","read":"idle","rest":"idle"}.get(kind,"idle")
 var action=preload("res://scripts/generated_species_art.gd").action_for(motion)
 if action=="walk": return "walk"
 if action in ["eat","drink"]: return "eat"
 if action in ["sleep","rest"]: return "sleep"
 if action in ["pet","wave","jump"]: return "pet"
 if motion.phase=="react" or motion.joy_left>0: return "pet"
 return "idle"
static func sample(motion) -> Dictionary:
 var action=action_for(motion)
 if action=="walk":
  var walking=preload("res://scripts/smooth_species_art.gd").sample(motion,"walk")
  walking.soft_hedgehog=true
  walking.anchor=Vector2(128,232)
  return walking
 var cels=frames(action)
 var seconds=float(data.sequences[action].duration)
 var time=float(motion.reaction_time if motion.phase=="react" else motion.elapsed)
 var index=mini(cels.size()-1,int(fposmod(time/seconds,1.0)*cels.size()))
 return {"texture":cels[index],"next_texture":cels[index],"frame_mix":0.0,"action":action,"stage":preload("res://scripts/smooth_species_art.gd").stage(motion),"index":index,"height":210.0,"mouth":Vector2(128,148),"hand":Vector2(143,175),"fixed_cels":true,"soft_hedgehog":true,"bank":action,"anchor":Vector2(128,232),"root_offset":Vector2.ZERO,"home_animation":motion.phase=="home_use"}
