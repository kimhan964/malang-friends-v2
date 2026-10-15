extends SceneTree
const Activity=preload("res://scripts/typing_activity.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var stats=Activity.new()
	stats.update(1000,10,true)
	assert(stats.apm==200 and stats.active_ms==0,"Immediate per-minute speed")
	stats.update(3999,0,true)
	assert(stats.apm==200,"Actions remain until the 3-second boundary")
	stats.update(4000,0,true)
	assert(stats.apm==0,"Exact 3-second cutoff")
	stats.update(31000,20,true)
	assert(stats.apm==400 and stats.active_ms==30000)
	stats.update(61000,0,true)
	assert(stats.apm==0 and stats.active_ms==60000)
	stats.update(91000,0,true)
	assert(stats.apm==0 and stats.active_ms==60000,"Idle grace caps at 30 seconds")
	stats.update(100000,5,true)
	stats.suspend(105000)
	assert(stats.apm==0,"Pause clears current speed")
	stats.update(140000,999,false)
	assert(stats.total==35 and stats.active_ms==65000,"Pause excludes actions and time")
	stats.update(145000,1,true)
	stats.update(150000,0,true)
	assert(stats.total==36 and stats.active_ms==70000 and stats.time_text()=="00:01:10")
	stats.update(500000,0,false)
	assert(stats.apm==0 and stats.active_ms==70000,"Disconnected/suspended time excluded")
	var burst=Activity.new()
	for i in range(1000): burst.update(i*10,3,true)
	assert(burst.total==3000 and burst.apm==18000)
	burst.update(70000,0,true)
	assert(burst.apm==0 and burst.recent.is_empty(),"Rolling history is bounded")
	var paced=Activity.new()
	for now in range(0,3001,200): paced.update(now,1,true)
	assert(paced.apm==300,"5 actions/sec must show 300 APM")
	for now in range(3100,6001,100): paced.update(now,1,true)
	assert(paced.apm==600,"10 actions/sec must show 600 APM after 3 seconds")
	for now in range(6500,9001,500): paced.update(now,1,true)
	assert(paced.apm==120,"Slowing to 2 actions/sec must show 120 APM")
	paced.update(12000,0,true)
	assert(paced.apm==0,"Stopping reaches zero within 3 seconds")
	print("REALTIME_APM_PASS: 5/s=300, 10/s=600, 2/s=120, 3-second decay, pause, totals and activity time")
	if "--capture" in OS.get_cmdline_user_args(): await capture()
	quit()

func capture() -> void:
	var app=preload("res://tests/typing_visual_review.gd").FakeApp.new()
	root.add_child(app)
	var m=preload("res://scripts/desktop_pet_motion.gd").new()
	m.species=8
	m.growth_stage=2
	m.growth_scale=1
	app.pet={"species":8,"motion":m}
	var widget=preload("res://scripts/typing_companion.gd").new()
	widget.app=app
	app.add_child(widget)
	widget.set_process(false)
	widget.input_bridge.stop()
	widget.input_bridge.connected=true
	app.typing_activity.update(0,120,true)
	app.typing_activity.update(10000,60,true)
	app.typing_activity.update(20000,15,true)
	widget.total=app.typing_activity.total
	widget.refresh_activity_display()
	assert(widget.status.text=="APM 300")
	assert(widget.activity_detail.text=="활동 00:00:20 · 195회")
	var folder="res://builds/typing-review/apm"
	DirAccess.make_dir_recursive_absolute(folder)
	for zoom in range(3):
		app.state.typing_size=zoom
		widget.place()
		await process_frame
		await RenderingServer.frame_post_draw
		widget.get_texture().get_image().save_png(folder+"/size-%d.png"%zoom)
	app.state.typing_size=1
	widget.place()
	widget.update_input_lights(0,1)
	await process_frame
	await RenderingServer.frame_post_draw
	widget.get_texture().get_image().save_png(folder+"/light-single.png")
	widget.update_input_lights(.12,1)
	widget.update_input_lights(.08,1)
	await process_frame
	await RenderingServer.frame_post_draw
	widget.get_texture().get_image().save_png(folder+"/light-trail.png")
	widget.update_input_lights(.4,0)
	widget.paused=true
	widget.refresh_activity_display()
	assert(widget.status.text=="APM —")
	assert(widget.activity_detail.text.contains("쉬는 중"))
	widget.queue_free()
	await process_frame
	print("TYPING_ACTIVITY_RENDER_PASS: three sizes, numeric APM, active time, pause label")
