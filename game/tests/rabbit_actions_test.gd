extends SceneTree
const Art=preload("res://scripts/rabbit_pilot_art.gd")
const Generated=preload("res://scripts/generated_species_art.gd")
const Motion=preload("res://scripts/desktop_pet_motion.gd")
var errors=[]
func _initialize() -> void:
	Art.select_version(9)
	var neutral=Art.frames("adult","walk")[0].get_image().get_data()
	for action in ["idle","eat","drink"]:
		var cels=Art.frames("adult",action)
		if cels.size()!=60: errors.append(action+": wrong count")
		if cels[0].get_image().get_data()!=neutral or cels[59].get_image().get_data()!=neutral:
			errors.append(action+": neutral transition mismatch")
		for fps in [30,60,144]:
			var motion=Motion.new()
			motion.rabbit_pilot=true
			motion.growth_stage=1
			motion.resting=true
			motion.autonomy=false
			motion.phase=action
			motion.action_left=5.5
			motion.food_id=0
			motion.visit_id="water" if action=="drink" else ""
			var seen={}
			for tick in range(ceilf(5.6*fps)):
				var sample=Generated.sample(motion)
				if sample.get("bank","")==action: seen[sample.index]=true
				if sample.height!=216 or sample.root_offset!=Vector2.ZERO: errors.append(action+": scale/root drift")
				if sample.frame_mix!=0: errors.append(action+": runtime crossfade")
				motion.advance(1.0/fps)
			if action!="idle" and motion.phase!="idle": errors.append(action+": did not return to idle")
			if fps>=60 and seen.size()!=60: errors.append("%s at %d Hz showed %d/60"%[action,fps,seen.size()])
	print("RABBIT_ACTION_PLAYBACK ","PASS" if errors.is_empty() else errors)
	quit(0 if errors.is_empty() else 1)
