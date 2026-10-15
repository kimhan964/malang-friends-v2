extends SceneTree
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const View=preload("res://scripts/desktop_pet_view.gd")
const Metrics=preload("res://scripts/texture_metrics.gd")
var failures=[]
func _initialize() -> void:
	if not preload("res://tests/pack_fixture.gd").mount(): quit(1);return
	call_deferred("run")
func run() -> void:
	for age in [0,2]:
		var m=Motion.new();m.species=1;m.growth_stage=age;m.growth_scale=.93 if age==0 else 1.0;m.rabbit_pilot=false;m.smooth_walk_enabled=true;m.autonomy=false
		var view=View.new();view.motion=m;root.add_child(view)
		m.phase="idle";view.refresh()
		var width=Metrics.torso_span(view.sprite.texture)*absf(view.sprite.scale.x)
		var reference_scale=absf(view.sprite.scale.x)
		var reference_height=view.visible_pet_bounds().size.y
		for emotion in ["happy","surprised","angry","sleepy"]:
			m.react(emotion,2.0);m.reaction_time=1;view.refresh()
			var actual=Metrics.torso_span(view.sprite.texture)*absf(view.sprite.scale.x)
			if actual/width<.9 or actual/width>1.1: failures.append(str(age)+emotion+" authored torso mismatch "+str(actual/width))
			if absf(absf(view.sprite.scale.x)-reference_scale)>.00001: failures.append("runtime expression scale fitting returned")
			if not view.generated_sample.get("regenerated_expression",false): failures.append("old expression bank used")
			if absf(view.visible_pet_bounds().size.y-reference_height)>12: failures.append("height discontinuity")
			if view.sprite.material.get_shader_parameter("next_frame")!=view.sprite.texture: failures.append("expression blended unrelated frame")
			print("OTTER ",age," ",emotion," authored_torso_px=",actual," reference=",width)
		view.free()
	print("OTTER EXPRESSION: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
