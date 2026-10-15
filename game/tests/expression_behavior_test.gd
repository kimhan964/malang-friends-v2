extends SceneTree
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const View=preload("res://scripts/desktop_pet_view.gd")
const Behavior=preload("res://scripts/expression_behavior.gd")
const Metrics=preload("res://scripts/texture_metrics.gd")
var failures=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var poses=0
	var max_size_error=0.0
	var max_effect_error=0.0
	for species in range(16):
		for stage in [0,2]:
			var m=Motion.new()
			m.species=species
			m.growth_stage=stage
			m.growth_scale=.93 if stage==0 else 1.0
			m.rabbit_pilot=species==0
			m.smooth_walk_enabled=species!=0
			m.autonomy=false
			var view=View.new()
			view.motion=m
			root.add_child(view)
			m.cancel_play()
			view.refresh()
			var neutral_height=sqrt(Metrics.opaque_area(view.sprite.texture))*view.sprite.scale.y
			for kind in Behavior.Emotions.KINDS:
				m.react(kind,Behavior.duration(species,kind))
				var movement=0.0
				for index in range(61):
					m.reaction_time=m.reaction_duration*index/60.0
					view.position=Vector2(850,540) if index%2==0 else Vector2(170,-40)
					view.refresh()
					var body_height=sqrt(Metrics.opaque_area(view.sprite.texture))*view.sprite.scale.y
					max_size_error=maxf(max_size_error,absf(body_height-neutral_height))
					var rect=view.visible_head_bounds()
					var head=view.dizzy_effects.orbit_layout().center
					max_effect_error=maxf(max_effect_error,absf(head.y-(rect.position.y-11)))
					var pose=Behavior.pose(m)
					movement=maxf(movement,pose.offset.length()+absf(pose.angle)*100)
					poses+=1
				if movement<1: failures.append("static behavior %d/%s"%[species,kind])
			view.free()
	if max_size_error>.1: failures.append("expression changes whole-character visual size")
	if max_effect_error>.01: failures.append("effect detached from actual head")
	print("EXPRESSION_BEHAVIOR poses=",poses," size_error_px=",max_size_error," effect_error_px=",max_effect_error," failures=",failures)
	quit(0 if failures.is_empty() else 1)
