extends SceneTree
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const View=preload("res://scripts/desktop_pet_view.gd")
const Gesture=preload("res://scripts/pointer_gesture.gd")
const Clutter=preload("res://scripts/desktop_clutter.gd")
const Outline=preload("res://scripts/animation_outline.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for fps in [30,60,144]:
		var motion=Motion.new()
		motion.configure(Rect2(0,0,1280,720),Vector2(500,250))
		motion.begin_drop()
		assert(motion.drop_ground.y-motion.feet.y>400)
		var last_y=motion.feet.y
		var steps=0
		while motion.phase=="drop":
			motion.advance(1.0/fps)
			assert(motion.feet.y>=last_y and motion.feet.y<=motion.bounds.end.y)
			last_y=motion.feet.y
			steps+=1
			assert(steps<fps*2)
		assert(motion.feet==motion.drop_ground and motion.phase=="dizzy")
		motion.advance(4.0)
		assert(motion.phase=="dizzy")
		motion.advance(.81)
		assert(motion.phase=="idle" and motion.target==motion.feet)
	var visiting=Motion.new()
	visiting.configure(Rect2(0,0,1280,720),Vector2(500,250))
	visiting.visit(Vector2(540,500),"prop_use","acorn")
	visiting.begin_drop()
	assert(visiting.drop_ground.y==500)
	visiting.advance(2)
	visiting.advance(Motion.DIZZY_DURATION)
	assert(visiting.phase=="visit" and visiting.visit_id=="acorn" and visiting.target==Vector2(540,500))
	visiting.begin_drop()
	visiting.cancel_play()
	assert(visiting.phase=="idle" and visiting.drop_duration==0)
	var gesture=Gesture.new()
	assert(gesture.sample(Vector2(15,0),.1)=="press")
	assert(gesture.sample(Vector2(-15,0),.1)=="stroke")
	assert(gesture.sample(Vector2(20,0),.1)=="stroke" and gesture.stroke_distance>=35)
	assert(gesture.sample(Vector2(0,-40),.016)=="drag")
	gesture.reset()
	assert(gesture.sample(Vector2(70,0),.016)=="drag")
	var all=["bowl","water","cushion","shelter","lamp","plant","basket","acorn"]
	assert(Clutter.visible_ids(all)==["bowl","water","cushion","acorn"])
	assert(Clutter.visible_ids(all,"shelter")==["bowl","water","shelter","acorn"])
	assert(Clutter.visible_ids(all,"plant")==["bowl","water","cushion","plant"])
	assert(Clutter.visible_ids(all,"shelter","plant")==["bowl","water","shelter","plant"])
	assert(Clutter.visible_ids(["plant"],"cushion")==["plant"])
	assert(Clutter.capped_scale("shelter",10)<=1.4)
	var checked=0
	for species in range(16):
		for stage in [0,2]:
			var motion=Motion.new()
			motion.species=species
			motion.growth_stage=stage
			motion.growth_scale=.93 if stage==0 else 1.0
			motion.begin_dizzy()
			var view=View.new()
			view.motion=motion
			root.add_child(view)
			for age in [.1,.3,.7,1.6,2.4,3.2,4.6]:
				motion.elapsed=age
				motion.landing_left=maxf(0,Motion.DIZZY_LANDING-age)
				view.refresh()
				Outline.fit(view.sprite,View.FEET,View.WINDOW_SIZE)
				for point in Outline.blended_points(view.sprite): assert(Rect2(Vector2(4,4),Vector2(248,216)).has_point(point))
				var layout=view.dizzy_effects.orbit_layout()
				assert(layout.center.y-layout.radius.y-8>=0 and layout.center.x-layout.radius.x-8>=0)
				checked+=1
			view.free()
	print("DROP_INTERACTION_TEST_PASSED: 3 fall rates; gestures; compact props; %d dizzy bounds"%checked)
	quit()
