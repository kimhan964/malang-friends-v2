extends Node
## One immutable, SHA256-verified pack per species. No changes to player saves.
signal finished(ok: bool)
const Catalog=preload("res://scripts/animal_catalog.gd")
const Images=preload("res://scripts/asset_images.gd")
var manifest: Dictionary={}
var busy=false
var species_id=""
var cache_root="user://animal-packs"
var local_root=""
var panel: Window
var status: Label
var progress: ProgressBar
var retry: Button
var cancel_button: Button
var request: HTTPRequest
var last_error=""
var startup=false
var part_path=""
var mounted: Dictionary={}

func _ready() -> void:
	var path="res://assets/animal-packs.json"
	if FileAccess.file_exists(path): manifest=JSON.parse_string(FileAccess.get_file_as_string(path))
	local_root=OS.get_executable_path().get_base_dir().path_join("animal-packs")

func available(species: int) -> bool:
	if species>=0 and species<Catalog.IDS.size() and FileAccess.file_exists("res://assets/soft-roster-v2/"+Catalog.IDS[species]+"/manifest.json"): return true
	# The base pack already embeds rabbit. This isolated skin remains offline.
	if species==0 and FileAccess.file_exists("res://assets/soft-rabbit/manifest.json"): return true
	if species<0 or species>=Catalog.IDS.size(): return false
	var id: String=Catalog.IDS[species]
	if manifest.is_empty(): return true # Full source checkout.
	if id==str(manifest.get("default","rabbit")): return true
	if mounted.has(id): return true
	return false

func pack_path(id: String) -> String:
	return cache_root.path_join(str(manifest.version)).path_join(str(manifest.animals[id].file))

func mount_verified(path: String,id: String) -> bool:
	if not manifest.get("animals",{}).has(id) or not FileAccess.file_exists(path): return false
	var spec: Dictionary=manifest.animals[id]
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()!=int(spec.size): return false
	file=null
	if FileAccess.get_sha256(path).to_lower()!=str(spec.sha256).to_lower(): return false
	if not ProjectSettings.load_resource_pack(path,false): return false
	for required in spec.required_paths:
		if not FileAccess.file_exists(str(required)): return false
	# Image aliases must resolve to mounted bytes, not just the global index.
	if not Images.exists("res://assets/emotions-v2/otter/adult.png" if id=="otter" else "res://assets/emotions-v1/"+id+"/adult.png"): return false
	mounted[id]=true
	return true

func ensure(species: int,initial: bool=false) -> bool:
	if available(species): return true
	if busy: return false
	var id: String=Catalog.IDS[species]
	if not manifest.get("animals",{}).has(id): return false
	if mount_verified(local_root.path_join(str(manifest.animals[id].file)),id): return true
	if mount_verified(pack_path(id),id): return true
	busy=true
	startup=initial
	species_id=id
	make_panel(species)
	begin_download()
	var result: bool=await finished
	return result

func make_panel(species: int) -> void:
	panel=Window.new()
	panel.visible=false
	panel.force_native=true
	panel.title="복슬복슬펫 · 친구 데려오기"
	panel.size=Vector2i(440,240)
	panel.unresizable=true
	panel.always_on_top=true
	panel.theme=preload("res://scripts/cozy_ui.gd").theme()
	panel.close_requested.connect(cancel)
	var paper=PanelContainer.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.add_theme_stylebox_override("panel",preload("res://scripts/cozy_ui.gd").box("faf8f3",14))
	panel.add_child(paper)
	var column=VBoxContainer.new()
	column.add_theme_constant_override("separation",14)
	paper.add_child(column)
	var title=Label.new()
	title.text=Catalog.NAMES[species]+" 만나기"
	preload("res://scripts/cozy_ui.gd").label(title,"title")
	column.add_child(title)
	status=Label.new()
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	preload("res://scripts/cozy_ui.gd").label(status)
	column.add_child(status)
	progress=ProgressBar.new()
	progress.custom_minimum_size.y=20
	column.add_child(progress)
	var hint=Label.new()
	hint.text="한 번만 다운로드하면 다음부터 인터넷 없이 만나요."
	preload("res://scripts/cozy_ui.gd").label(hint,"caption")
	column.add_child(hint)
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	column.add_child(row)
	retry=Button.new()
	retry.text="다시 다운로드"
	retry.custom_minimum_size=Vector2(160,44)
	retry.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	retry.pressed.connect(begin_download)
	preload("res://scripts/cozy_ui.gd").button(retry)
	preload("res://scripts/ui_icons.gd").decorate(retry,"together",28)
	row.add_child(retry)
	cancel_button=Button.new()
	cancel_button.text="종료" if startup else "취소"
	cancel_button.custom_minimum_size=Vector2(110,44)
	cancel_button.pressed.connect(cancel)
	preload("res://scripts/cozy_ui.gd").button(cancel_button)
	row.add_child(cancel_button)
	add_child(panel)
	if DisplayServer.get_name()!="headless":
		var screen=DisplayServer.screen_get_usable_rect(DisplayServer.SCREEN_PRIMARY)
		panel.position=screen.position+(screen.size-panel.size)/2
	panel.show()
	if get_parent().has_method("request_layer_order"): get_parent().request_layer_order()

func begin_download() -> void:
	if is_instance_valid(request): return
	last_error=""
	var spec: Dictionary=manifest.animals[species_id]
	var folder=pack_path(species_id).get_base_dir()
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:
		fail("저장 공간을 준비하지 못했어요. 쓰기 권한을 확인해 주세요.")
		return
	part_path=pack_path(species_id)+".part"
	DirAccess.remove_absolute(part_path)
	request=HTTPRequest.new()
	request.use_threads=true
	request.timeout=120
	request.body_size_limit=int(spec.size)+1
	request.download_file=part_path
	request.request_completed.connect(completed)
	add_child(request)
	retry.disabled=true
	progress.value=0
	status.text="친구의 동작을 데려오고 있어요… %.1f MB"%(float(spec.size)/1000000.0)
	var error=request.request(str(spec.url))
	if error!=OK: fail("다운로드를 시작하지 못했어요. 인터넷 연결을 확인해 주세요.")

func _process(_delta: float) -> void:
	if not is_instance_valid(request) or not is_instance_valid(progress): return
	var total=int(manifest.animals[species_id].size)
	progress.value=100.0*request.get_downloaded_bytes()/maxi(1,total)

func completed(result: int,code: int,_headers: PackedStringArray,_body: PackedByteArray) -> void:
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
		fail("친구를 데려오지 못했어요. 인터넷 연결을 확인하고 다시 시도해 주세요.")
		return
	status.text="다운로드한 그림과 동작을 확인하고 있어요…"
	var spec: Dictionary=manifest.animals[species_id]
	var file=FileAccess.open(part_path,FileAccess.READ)
	var valid=file!=null and file.get_length()==int(spec.size)
	file=null
	if not valid or FileAccess.get_sha256(part_path).to_lower()!=str(spec.sha256).to_lower():
		fail("파일이 온전히 도착하지 않았어요. 다시 다운로드해 주세요.")
		return
	var final_path=pack_path(species_id)
	DirAccess.remove_absolute(final_path)
	if DirAccess.rename_absolute(part_path,final_path)!=OK or not mount_verified(final_path,species_id):
		fail("친구의 파일을 열지 못했어요. 다시 시도해 주세요.")
		return
	cleanup_request()
	finish(true)

func cleanup_request() -> void:
	if is_instance_valid(request):
		request.cancel_request()
		request.queue_free()
	request=null
	if not part_path.is_empty(): DirAccess.remove_absolute(part_path)

func fail(message: String) -> void:
	last_error=message
	cleanup_request()
	if is_instance_valid(status): status.text=message
	if is_instance_valid(retry): retry.disabled=false

func finish(ok: bool) -> void:
	busy=false
	if is_instance_valid(panel):
		panel.hide()
		panel.queue_free()
	finished.emit(ok)

func cancel() -> void:
	cleanup_request()
	finish(false)
	if startup: get_parent().shutdown()

func _exit_tree() -> void:
	cleanup_request()
