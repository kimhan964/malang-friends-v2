extends "res://scripts/main.gd"
const SkinState=preload("res://scripts/pet_state.gd")
var validating_skin=false
class ValidationState extends SkinState:
 func load_game() -> void:
  selected=3
  guide_seen=true
  home_initialized=true
  growth["3"]=36
 func save_game() -> void: pass
func _ready() -> void:
 var pack=OS.get_executable_path().get_base_dir().path_join("animal-packs/pet-hedgehog.pck")
 if not ProjectSettings.load_resource_pack(pack,false):
  push_error("Local hedgehog pack is missing: "+pack)
  get_tree().quit(1)
  return
 validating_skin=OS.get_cmdline_user_args().has("--validate-skin") or OS.get_cmdline_user_args().has("--validate-walk")
 if validating_skin: state=ValidationState.new()
 super._ready()
 if OS.get_cmdline_user_args().has("--validate-walk"): validate_walk.call_deferred()
 elif validating_skin: validate_skin.call_deferred()
 elif OS.get_cmdline_user_args().has("--rabbit-preview"): choose_friend.call_deferred(0)
func validate_skin() -> void:
 var records: Array=[]
 var out=OS.get_executable_path().get_base_dir().path_join("검수/토끼-애니메이션")
 DirAccess.make_dir_recursive_absolute(out)
 for species in [0,3]:
  await choose_friend(species)
  if not is_instance_valid(pet) or pet.species!=species:
   push_error("Species switch failed: "+str(species))
   get_tree().quit(4)
   return
  var m=pet.motion
  m.autonomy=false
  m.resting=true
  var screen=DisplayServer.screen_get_usable_rect()
  m.move_to(Vector2(screen.position)+Vector2(screen.size.x*.45,screen.size.y*.65))
  for stage in [0,2]:
   m.growth_stage=stage
   m.growth_scale=.93 if stage==0 else 1.0
   for action in ["idle","wander","pet","doze","eat","left_walk"]:
    m.cancel_play()
    m.phase="wander" if action=="left_walk" else action
    m.joy_left=0
    m.action_left=30
    m.elapsed=0
    m.food_id=0
    m.visit_id="hand_feed" if action=="eat" else ""
    if action in ["wander","left_walk"]: m.target=m.feet+Vector2(-80 if action=="left_walk" else 80,0)
    if action=="pet":
     m.cooldown=0
     pet.menu_action(0)
    await get_tree().create_timer(.7).timeout
    await RenderingServer.frame_post_draw
    var sample: Dictionary=pet.view.generated_sample
    var image=pet.get_texture().get_image()
    var rect=image.get_used_rect().grow(8).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
    var name="%s-%s-%s.png"%[species,stage,action]
    if not rect.has_area():
     push_error("Empty native pet: "+action)
     get_tree().quit(2)
     return
    image.get_region(rect).save_png(out.path_join(name))
    var correct_skin=sample.get("soft_rabbit",false) if species==0 else sample.get("soft_hedgehog",false)
    var expected_bank={"idle":"idle","wander":"walk","pet":"pet","doze":"sleep","eat":"eat","left_walk":"walk"}[action]
    var expected_facing=-1 if action=="left_walk" else 1
    var pass_direction=action not in ["wander","left_walk"] or m.facing==expected_facing
    records.append({"species":species,"stage":stage,"phase":action,"bank":sample.get("bank",""),"index":sample.get("index",-1),"skin":correct_skin,"file":name,"facing":m.facing,"cycle_seconds":preload("res://scripts/smooth_species_art.gd").spec(m).cycle_seconds})
    if not correct_skin or sample.get("bank","")!=expected_bank or not pass_direction or m.rabbit_pilot:
     push_error("Animation routing failed: "+name)
     get_tree().quit(3)
     return
 var file=FileAccess.open(out.path_join("native-validation.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"full_game":true,"records":records},"\t"))
 print("RABBIT_AND_HEDGEHOG_NATIVE_VALIDATED ",records.size())
 get_tree().quit()

func validate_walk() -> void:
 await choose_friend(0)
 pet.set_process(false)
 var m=pet.motion
 var smooth=preload("res://scripts/smooth_species_art.gd")
 var records: Array=[]
 var out=OS.get_executable_path().get_base_dir().path_join("검수/토끼-접지걷기")
 DirAccess.make_dir_recursive_absolute(out)
 for stage in [0,2]:
  m.growth_stage=stage
  m.growth_scale=.93 if stage==0 else 1.0
  for direction in [-1,1]:
   m.cancel_play()
   m.phase="wander"
   m.action_left=30
   m.joy_left=0
   m.elapsed=0
   m.smooth_walk_cycle.reset()
   m.walk_phase=0
   var screen=DisplayServer.screen_get_usable_rect()
   m.move_to(Vector2(screen.position)+Vector2(screen.size.x*.5,screen.size.y*.65))
   var start=m.feet.x
   m.target=m.feet+Vector2(direction*400,0)
   m.facing=direction
   var metadata=smooth.spec(m)
   var factor=110.0*preload("res://scripts/animal_catalog.gd").HEIGHTS[0]*m.growth_scale/float(metadata.reference_height)
   var cycles=0
   var maximum_drift=0.0
   var checks=0
   var anchors: Dictionary={}
   for tick in range(288):
    m.advance_travel(1.0/60.0)
    if not m.smooth_walk_cycle.active: cycles+=1
    var sample=smooth.sample(m,"walk")
    var frame=int(sample.index)
    var image: Image=sample.texture.get_image()
    var rect=image.get_used_rect()
    # Scan the actual loaded raster's opaque bottom sole, using the same
    # >128 alpha boundary as registration; do not infer contact from its root.
    var bottom=-1
    for y in range(rect.end.y-1,rect.position.y-1,-1):
     for x in range(rect.position.x,rect.end.x):
      if image.get_pixel(x,y).a>.5: bottom=y; break
     if bottom>=0: break
    var longest=0
    var run_start=-1
    var sole_x=0.0
    for x in range(image.get_width()+1):
     var opaque=x<image.get_width() and image.get_pixel(x,bottom).a>.5
     if opaque and run_start<0: run_start=x
     elif not opaque and run_start>=0:
      if x-run_start>longest:
       longest=x-run_start
       sole_x=(run_start+x-1)*.5
      run_start=-1
    if bottom!=231 or m.facing!=direction:
     push_error("Ground or direction mismatch")
     get_tree().quit(5)
     return
    var expected=start+direction*(cycles+m.walk_phase)*float(metadata.stride)*factor
    if absf(expected-m.feet.x)>.02:
     push_error("Native stride/phase mismatch")
     get_tree().quit(6)
     return
    for segment in range(2):
     var lo=6+48*segment
     if frame>=lo and frame<=lo+24:
      var key="%d/%d"%[cycles,segment]
      var world=m.feet.x+direction*(sole_x-128.0)*factor
      if not anchors.has(key): anchors[key]=world
      maximum_drift=maxf(maximum_drift,absf(world-float(anchors[key])))
      checks+=1
   pet.view.show_generated_species()
   await RenderingServer.frame_post_draw
   var screenshot=pet.get_texture().get_image()
   var crop=screenshot.get_used_rect().grow(8).intersection(Rect2i(Vector2i.ZERO,screenshot.get_size()))
   screenshot.get_region(crop).save_png(out.path_join("%d-%d.png"%[stage,direction]))
   records.append({"stage":stage,"direction":direction,"ticks":288,"contact_checks":checks,"max_world_contact_drift_px":maximum_drift,"stride_source_px":metadata.stride,"scale":factor})
   if maximum_drift>1.8*factor:
    push_error("Native planted sole drift exceeded raster tolerance")
    get_tree().quit(7)
    return
 var file=FileAccess.open(out.path_join("validation.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"actual_native_motion":true,"records":records},"\t"))
 print("RABBIT_NATIVE_GROUNDED_WALK_VALIDATED ",records.size())
 get_tree().quit()
