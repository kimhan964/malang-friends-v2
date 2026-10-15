extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.transparent_bg=true
	root.mouse_passthrough=true
	var manager=preload("res://scripts/animal_pack_manager.gd").new()
	root.add_child(manager)
	manager.species_id="otter"
	manager.busy=true
	manager.make_panel(1)
	manager.status.text="친구의 동작을 데려오고 있어요… 49.6 MB"
	manager.progress.value=48
	manager.retry.disabled=true
	await create_timer(30).timeout
	manager.fail("친구를 데려오지 못했어요. 인터넷 연결을 확인하고 다시 시도해 주세요.")
	await create_timer(30).timeout
	quit()
