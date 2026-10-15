extends SceneTree
const Prop=preload("res://scripts/desktop_prop.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.transparent_bg=true
	root.mouse_passthrough=true
	root.size=Vector2i.ONE
	Engine.max_fps=60
	var folder="res://acorn-native-review-2026-10-05"
	DirAccess.make_dir_recursive_absolute(folder)
	var props=[]
	for i in range(3):
		var p=Prop.new()
		p.kind="acorn"
		p.prop_id="acorn"
		root.add_child(p)
		p.position=Vector2i(720+i*145,500)
		p.title="오뚝이 잘림 검수 · "+["왼쪽","중앙","오른쪽"][i]
		p.set_process(false)
		p.wobbling=true
		p.wobble_time=[-.25,0.0,.25][i]/1.8
		p.drawing.queue_redraw()
		props.append(p)
	await process_frame
	await RenderingServer.frame_post_draw
	for i in range(3): props[i].get_texture().get_image().save_png(folder+"/%d.png"%i)
	print("ACORN_NATIVE_READY left/center/right")
	await create_timer(45).timeout
	quit()
