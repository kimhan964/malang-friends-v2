extends SceneTree
const Manager=preload("res://scripts/animal_pack_manager.gd")
const State=preload("res://scripts/pet_state.gd")
class MemoryState extends State:
	func load_game() -> void: guide_seen=true
	func save_game() -> void: pass
var failures=[]
var base=""
var test_root=""
var pending_result=null
var app
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: failures.append(message)
func manager(route: String,version: String) -> Node:
	var m=Manager.new();root.add_child(m)
	m.local_root=test_root.path_join("absent")
	m.cache_root=test_root.path_join("cache")
	m.manifest=m.manifest.duplicate(true)
	m.manifest.version=version
	m.manifest.animals.otter.url=base+route
	return m
func wait_error(m) -> void:
	var end=Time.get_ticks_msec()+20000
	while m.last_error.is_empty() and Time.get_ticks_msec()<end: await process_frame
	check(not m.last_error.is_empty(),"Missing download error")
func pending(m) -> void:
	pending_result=await m.ensure(1)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-url="): base=arg.trim_prefix("--test-url=")
		if arg.begins_with("--test-cache="): test_root=arg.trim_prefix("--test-cache=")
	check(not base.is_empty() and not test_root.is_empty(),"Test arguments required")
	if not failures.is_empty(): quit(1);return
	var good=manager("/good","download-test")
	check(await good.ensure(1),"Valid pack download failed")
	check(good.mounted.has("otter"),"Verified pack not mounted")
	check(FileAccess.file_exists(good.pack_path("otter")),"No persistent verified cache")
	check(not FileAccess.file_exists(good.pack_path("otter")+".part"),"Part file left after success")
	good.queue_free();await process_frame
	var offline=manager("/unreachable","download-test")
	check(await offline.ensure(1),"Offline cached animal unavailable")
	check(offline.request==null,"Cache unexpectedly requested network")
	offline.queue_free();await process_frame
	var corrupt=manager("/corrupt","corrupt-test")
	pending_result=null;pending(corrupt)
	await wait_error(corrupt)
	check(not FileAccess.file_exists(corrupt.pack_path("otter")),"Corrupt file installed")
	check(not corrupt.retry.disabled,"Retry unavailable")
	corrupt.cancel();await process_frame
	check(pending_result==false,"Corrupt download cancellation not completed")
	corrupt.queue_free();await process_frame
	var slow=manager("/slow","cancel-test")
	pending_result=null;pending(slow)
	var until=Time.get_ticks_msec()+5000
	while is_instance_valid(slow.request) and slow.request.get_downloaded_bytes()==0 and Time.get_ticks_msec()<until: await process_frame
	slow.cancel();await process_frame
	check(pending_result==false,"Cancellation did not return false")
	check(not FileAccess.file_exists(slow.pack_path("otter")+".part"),"Cancelled transfer left part file")
	slow.queue_free();await process_frame
	var retrying=manager("/missing","retry-test")
	pending_result=null;pending(retrying)
	await wait_error(retrying)
	retrying.manifest.animals.otter.url=base+"/good"
	retrying.begin_download()
	var deadline=Time.get_ticks_msec()+20000
	while pending_result==null and Time.get_ticks_msec()<deadline: await process_frame
	check(pending_result==true,"Retry did not complete original selection")
	retrying.queue_free();await process_frame
	# Exercise actual app selection without reading or writing the player's save.
	app=preload("res://scripts/main.gd").new()
	app.state=MemoryState.new()
	root.add_child(app)
	var selected=app.state.selected
	var previous=app.pet.get_instance_id()
	app.animal_packs.local_root=test_root.path_join("absent")
	app.animal_packs.cache_root=test_root.path_join("app-cache")
	app.animal_packs.manifest=app.animal_packs.manifest.duplicate(true)
	app.animal_packs.manifest.animals.otter.url=base+"/missing"
	app.choose_friend(1)
	await wait_error(app.animal_packs)
	check(app.pet.get_instance_id()==previous and app.state.selected==selected,"Failed selection replaced pet or save")
	app.animal_packs.cancel();await process_frame
	check(app.pet.get_instance_id()==previous,"Cancel removed current pet")
	app.animal_packs.manifest.animals.otter.url=base+"/good"
	app.choose_friend(1)
	var end=Time.get_ticks_msec()+20000
	while app.state.selected!=1 and Time.get_ticks_msec()<end: await process_frame
	check(app.state.selected==1 and app.pet.species==1,"Verified selection not applied")
	app.free()
	print("ANIMAL PACK DOWNLOAD: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
