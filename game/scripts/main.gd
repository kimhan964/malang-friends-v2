extends Node

signal friend_changed(species: int)

const Pet=preload("res://scripts/desktop_pet.gd")
const Prop=preload("res://scripts/desktop_prop.gd")
const State=preload("res://scripts/pet_state.gd")
const Profiles=preload("res://scripts/companion_profiles.gd")
const Food=preload("res://scripts/food_catalog.gd")
const HeldFood=preload("res://scripts/held_food.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
const CommerceAccess=preload("res://scripts/commerce_access.gd")
const NativeMouse=preload("res://scripts/native_mouse.gd")
const NativeLayer=preload("res://scripts/native_layer_order.gd")
var commerce_access
var world_started=false
var rabbit_pilot_mode=false
var held_food
var held_food_id=-1
const FAVORITES=["cushion","water","basket","plant","cushion","plant","cushion","lamp","shelter","basket","bowl","plant","shelter","cushion","cushion","water"]
var state=State.new()
var pet
var props: Dictionary={}
var hunt: Array=[]
var hidden_snack=0
var hunt_resolved=false
var hunt_previous_resting=false
var decorating=false
var expanded_props=false
var focus_prop=""
var preferred_rest=""
var preferred_toy=""
var info: AcceptDialog
var app_theme: Theme
var gift_notices: Array=[]
var gift_notice_gap=0.0
var gift_notice: Window
var falling_gifts: Dictionary={}
var pending_gift_visits: Array[String]=[]
var delivery_queue: Array[String]=[]
var delivery_seen: Dictionary={}
var delivery_delay=3.0
const SMALL_TOOLS=["acorn","basket","plant"]
var layers_dirty=true
var layer_restore_queued=false
var layer_settle_until=0
var furniture_room
var behavior_panel
var animal_packs

func request_layer_order(settle: bool=true) -> void:
	layers_dirty=true
	if settle: layer_settle_until=Time.get_ticks_msec()+150
	if not layer_restore_queued:
		layer_restore_queued=true
		call_deferred("restore_layer_order")

func objects_are_dragging() -> bool:
	if is_instance_valid(held_food): return true
	if is_instance_valid(furniture_room):
		for piece in furniture_room.pieces.values():
			if piece.dragging: return true
	for prop in props.values()+hunt:
		if is_instance_valid(prop) and prop.dragging: return true
	return false

func restore_layer_order() -> void:
	layer_restore_queued=false
	var download_visible=is_instance_valid(animal_packs) and is_instance_valid(animal_packs.panel) and animal_packs.panel.visible
	if not layers_dirty or (not download_visible and (not is_instance_valid(pet) or not pet.visible)): return
	# Raising an existing window does not change its transparent surface.
	# Keep the animal visible even while it or a furniture piece is dragged.
	# A furniture click raises its native window immediately. Restore on the
	# next frame even during an approach, rather than hiding the pet until it
	# arrives. This runs only on layer-changing events, never every walk frame.
	if DisplayServer.get_name()=="headless": return
	layers_dirty=false
	# Clicking/dragging can reorder the SAME windows. A membership comparison
	# cannot tell whether the animal is still in front of its furniture.
	# Toggling ALWAYS_ON_TOP on the transparent native canvas can hide the pet.
	# Raise existing unfocusable windows only after a layer-changing event.
	# Order from back to front: furniture, animal, held objects, placement UI.
	var ordered_windows: Array=[]
	if is_instance_valid(furniture_room):
		for piece in furniture_room.ordered_pieces():
			if is_instance_valid(piece) and piece.visible:
				ordered_windows.append(piece)
	# Small desktop props are independent native windows too. Include them
	# before the animal so a basket click cannot leave it above the pet.
	for prop in props.values()+hunt:
		if is_instance_valid(prop) and prop.visible:
			ordered_windows.append(prop)
	var ball=pet.ball_window if is_instance_valid(pet) else null
	for window in [pet,ball,held_food,gift_notice]:
		if is_instance_valid(window) and window.visible:
			ordered_windows.append(window)
	if is_instance_valid(furniture_room) and is_instance_valid(furniture_room.panel) and furniture_room.panel.visible:
		ordered_windows.append(furniture_room.panel)
	# Menus remain above the pet; opening one must not raise its furniture
	# owner over the animal. NOACTIVATE preserves menu keyboard/mouse focus.
	if is_instance_valid(furniture_room):
		for piece in furniture_room.pieces.values():
			if piece.menu.visible: ordered_windows.append(piece.menu)
			if is_instance_valid(piece.size_editor) and piece.size_editor.visible: ordered_windows.append(piece.size_editor)
	if is_instance_valid(pet) and pet.menu.visible: ordered_windows.append(pet.menu)
	if is_instance_valid(info) and info.visible: ordered_windows.append(info)
	# Independent reference windows stay above the transparent pet canvas.
	for child in get_children()+get_tree().root.get_children():
		if child.get_script()==preload("res://scripts/action_codex.gd") and is_instance_valid(child.panel) and child.panel.visible:
			ordered_windows.append(child.panel)
	if download_visible: ordered_windows.append(animal_packs.panel)
	if OS.get_name()=="Windows": NativeLayer.raise_windows(ordered_windows)
	else:
		for window in ordered_windows: DisplayServer.window_move_to_foreground(window.get_window_id())

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--check-package"):
		add_child(load("res://tools/check_package.gd").new())
		return
	# Load the raw packaged PNG so the window icon also works without editor imports.
	if DisplayServer.get_name()!="headless":
		var icon=Image.new()
		if preload("res://scripts/asset_images.gd").decode_into(icon,"res://assets/icon/pet-icon.png")==OK: DisplayServer.set_icon(icon)
	Engine.max_fps=60
	get_tree().auto_accept_quit=false
	get_window().transparent_bg=true
	# Godot cannot hide its primary window; keep this transparent host passive.
	get_window().mouse_passthrough=true
	get_window().unfocusable=true
	NativeMouse.apply(get_window(),true,true)
	app_theme=preload("res://scripts/cozy_ui.gd").theme()
	state.load_game()
	animal_packs=preload("res://scripts/animal_pack_manager.gd").new()
	add_child(animal_packs)
	if state.test_unlocks(): state.hidden.clear()
	if bool(ProjectSettings.get_setting("commerce/enabled",false)):
		commerce_access=CommerceAccess.new()
		add_child(commerce_access)
		commerce_access.allowed_changed.connect(_commerce_changed)
		commerce_access.begin()
		return
	_start_world()

func _start_world() -> void:
	if world_started: return
	world_started=true
	state.affection_changed.connect(on_affection_changed)
	state.food_unlocked.connect(show_food_unlock)
	state.growth_changed.connect(on_growth_changed)
	build_props()
	choose_friend(state.selected)
	furniture_room=preload("res://scripts/furniture_room.gd").new()
	furniture_room.app=self
	add_child(furniture_room)
	behavior_panel=preload("res://scripts/behavior_panel.gd").new()
	behavior_panel.app=self
	add_child(behavior_panel)
	if OS.get_cmdline_user_args().has("--furniture"):
		furniture_room.open.call_deferred()
	var startup_record=FileAccess.open("user://latest-runtime-startup.json",FileAccess.WRITE)
	if startup_record:
		startup_record.store_string(JSON.stringify({"user_args":OS.get_cmdline_user_args(),"main_sha256":FileAccess.get_file_as_string("res://scripts/main.gd").sha256_text(),"executable":OS.get_executable_path(),"furniture_requested":OS.get_cmdline_user_args().has("--furniture")}))
	var timer=Timer.new()
	timer.wait_time=3
	timer.autostart=true
	timer.timeout.connect(refresh_destinations)
	add_child(timer)

func _commerce_changed(ids: PackedStringArray) -> void:
	if ids.is_empty():
		clear_falling_gifts()
		cancel_feeding()
		cancel_hunt()
		if is_instance_valid(pet):
			pet.hide()
			pet.queue_free()
		for prop in props.values(): prop.hide()
		return
	if not commerce_access.permits(state.selected): state.selected=Catalog.IDS.find(ids[0])
	if not world_started: _start_world()
	elif not is_instance_valid(pet) or pet.is_queued_for_deletion() or not commerce_access.permits(pet.species): choose_friend(state.selected)
	if is_instance_valid(pet) and not pet.is_queued_for_deletion():
		pet.set_available_species(ids)

func usable_screen() -> Rect2i:
	if DisplayServer.get_name()=="headless": return Rect2i(0,0,1280,720)
	return DisplayServer.screen_get_usable_rect(DisplayServer.SCREEN_PRIMARY)

func floor_prop(prop) -> void:
	if state.activity_space!="floor": return
	var area=preload("res://scripts/living_space.gd").bounds(Rect2(usable_screen()),"floor")
	var feet=Vector2(clampf(prop.feet_point().x,area.position.x,area.end.x),preload("res://scripts/living_space.gd").ground(Rect2(usable_screen())))
	# Generated desktop props are drawn on the authored y=86 baseline.
	prop.position=Vector2i(feet-Vector2(56,86)*prop.art_scale)

func set_activity_space(mode: String) -> void:
	mode=preload("res://scripts/living_space.gd").clean(mode)
	if state.activity_space==mode: return
	cancel_feeding()
	cancel_hunt()
	clear_falling_gifts()
	persist_layout()
	if is_instance_valid(furniture_room): furniture_room.save()
	state.activity_space=mode
	if is_instance_valid(pet):
		pet.motion.floor_space=mode=="floor"
		pet.motion.bounds=pet.activity_bounds(pet.desktop_bounds())
		pet.motion.move_to(pet.motion.feet)
	for id in props:
		if mode=="desktop" and state.layout.has(id):
			var at=state.layout[id]
			props[id].position=Vector2i(at[0],at[1])
		floor_prop(props[id])
	if is_instance_valid(furniture_room): furniture_room.apply_space()
	state.save_game()
	refresh_destinations()
	request_layer_order()
	if is_instance_valid(pet): pet.motion.say("아래쪽에서 함께할게" if mode=="floor" else "화면 전체를 산책할게")

func default_prop_position(index: int) -> Vector2i:
	var rect=usable_screen()
	if index==6: return rect.position+Vector2i(int(rect.size.x*.75)-56,int(rect.size.y*.62)-48)
	if index==7: return rect.position+Vector2i(int(rect.size.x*.43)-56,int(rect.size.y*.72)-48)
	return rect.position+Vector2i(int(rect.size.x*(.11+.13*index))-56,int(rect.size.y*.84)-48)

func build_props() -> void:
	for i in range(State.PROPS.size()):
		var id=State.PROPS[i]
		var prop=Prop.new()
		prop.prop_id=id
		prop.kind=id
		prop.start_visible=false
		prop.species=state.selected
		prop.palette=state.palette
		prop.position=default_prop_position(i)
		if state.layout.has(id):
			var saved=state.layout[id]
			var point=Vector2i(int(saved[0]),int(saved[1]))
			var found=false
			for monitor in range(DisplayServer.get_screen_count()):
				if DisplayServer.screen_get_usable_rect(monitor).encloses(Rect2i(point,prop.size)): found=true
			if found: prop.position=point
		prop.moved.connect(persist_layout)
		prop.layer_changed.connect(request_layer_order)
		prop.moved.connect(func(): state.reward_activity(state.selected,"decorate"))
		prop.recolored.connect(func(): activity(6))
		if id=="bowl": prop.food_picked.connect(pick_up_food)
		if id in ["plant","lamp"]: prop.activated.connect(use_species_prop)
		if id=="acorn": prop.activated.connect(use_common_toy)
		if id in ["cushion","shelter","water","basket"]: prop.activated.connect(use_desktop_prop)
		add_child(prop)
		props[id]=prop

func rabbit_hop_available(species: int,stage: int) -> bool:
	# v9 contains current baby and adult hop banks.
	return rabbit_pilot_mode and species==0 and preload("res://scripts/rabbit_pilot_art.gd").data().stages.has("baby" if stage==0 else "adult")

func choose_friend(species: int) -> void:
	if species<0 or species>=Catalog.IDS.size(): return
	if commerce_access!=null and not commerce_access.permits(species):
		commerce_access.show_account("선물받은 동물만 선택할 수 있어요.")
		return
	# Keep the visible pet and saved selection until every required byte is ready.
	if is_instance_valid(animal_packs):
		if not await animal_packs.ensure(species,not is_instance_valid(pet)): return
		if commerce_access!=null and not commerce_access.permits(species): return
	clear_falling_gifts()
	gift_notices.clear()
	gift_notice_gap=0.0
	if is_instance_valid(gift_notice):
		gift_notice.hide()
		gift_notice.queue_free()
	if decorating:
		decorating=false
		for prop in props.values():
			prop.editing=false
			prop.refresh()
	cancel_feeding()
	cancel_hunt()
	var first=not is_instance_valid(pet)
	if not first: persist_layout()
	var previous_position=Vector2.INF
	if is_instance_valid(pet):
		previous_position=pet.motion.feet
		pet.hide()
		pet.queue_free()
	state.selected=species
	preload("res://scripts/generated_species_art.gd").release_other_species(species)
	pet=Pet.new()
	pet.species=species
	pet.motion.rabbit_pilot=rabbit_hop_available(species,state.growth_stage(species))
	pet.motion.smooth_walk_enabled=species>=0
	pet.state=state
	pet.motion.behavior_points=state.home_points()
	if commerce_access!=null:
		pet.commerce_mode=true
		pet.available_species=commerce_access.allowed.duplicate()
	pet.theme=app_theme
	pet.decorating=decorating
	pet.returned.connect(shutdown)
	pet.companion_selected.connect(func(id): choose_friend.call_deferred(id))
	pet.activity_requested.connect(activity)
	pet.dropped_on_desktop.connect(on_pet_dropped)
	add_child(pet)
	pet.visibility_changed.connect(request_layer_order)
	request_layer_order()
	if commerce_access!=null:
		pet.menu.add_item("계정·이용권 확인",900)
	pet.menu.about_to_popup.connect(cancel_hunt)
	pet.motion.visited.connect(on_visit)
	pet.motion.activity_finished.connect(on_activity_finished)
	pet.motion.favorite_place="home_water" if FAVORITES[species]=="water" else ("home_sofa" if FAVORITES[species] in ["cushion","shelter"] else FAVORITES[species])
	if previous_position.is_finite(): pet.motion.move_to(previous_position)
	apply_personal_space(first)
	apply_growth()
	for prop in props.values(): floor_prop(prop)
	set_food(int(state.meals.get(str(species),Catalog.DEFAULT_MEALS[species])),false)
	apply_unlocks()
	refresh_destinations()
	state.save_game()
	pet.motion.react("greet",2.2 if pet.motion.affection>=18 else 1.6)
	pet.motion.speak()
	queue_welcome_tools()
	if not state.guide_seen: show_first_guide.call_deferred()
	friend_changed.emit(species)

func show_first_guide() -> void:
	if not is_instance_valid(pet): return
	show_info("우리 집에서 함께하는 하루","1. 집 꾸미기에서 식탁·소파·놀이 러그를 배치해요.\n2. 음식과 물은 식탁에서, 휴식은 소파와 침대에서 해요.\n3. 동물을 가구 위에 끌어 놓거나 가구를 클릭하면 이용해요.\n\n쓰다듬고 놀며 동물의 표정과 말풍선에 반응해 주세요.\n기본 돌보기와 교감 행동은 처음부터 함께할 수 있어요.\n\n모든 친구와 쌓은 교감으로 새 가구가 열려요.\n해금된 가구는 집 꾸미기에서 직접 배치할 수 있어요.\n생활 기록에서 다음 가구와 진행도를 확인하세요.")
	info.confirmed.connect(func(): state.guide_seen=true; state.save_game())

func apply_personal_space(first: bool) -> void:
	for id in ["bowl","plant","lamp"]:
		props[id].species=state.selected
		props[id].refresh()
	var places=state.personal_layout.get(str(state.selected),{})
	for id in ["cushion","shelter"]:
		var prop=props[id]
		prop.species=state.selected
		prop.title=(Profiles.BEDS[state.selected] if id=="cushion" else Profiles.RETREATS[state.selected])+" · 말랑친구"
		prop.resize_for_friend()
		if not first: prop.position=default_prop_position(State.PROPS.find(id))
		if places.has(id):
			var value=places[id]
			var point=Vector2i(int(value[0]),int(value[1]))
			for monitor in range(DisplayServer.get_screen_count()):
				if DisplayServer.screen_get_usable_rect(monitor).encloses(Rect2i(point,prop.size)):
					prop.position=point
					break
		prop.refresh()

func set_food(id: int, serve: bool=true) -> void:
	if serve and not state.unlocked(state.selected,"bowl"): return
	if serve and not state.food_available(state.selected,id): return
	if not serve and not state.food_available(state.selected,id): id=Catalog.DEFAULT_MEALS[state.selected]
	cancel_feeding()
	id=clampi(id,0,31)
	state.meals[str(state.selected)]=id
	pet.motion.food_id=id
	pet.motion.favorite_food=id==Profiles.FAVORITE_FOOD[state.selected]
	props.bowl.food_texture=Food.icon_for(state.selected,id)
	props.bowl.title=Food.title_for(state.selected,id)+" · 말랑친구"
	props.bowl.refresh()
	if serve:
		if decorating: activity(5)
		if is_instance_valid(furniture_room) and furniture_room.pieces.has("table"):
			furniture_room.use_piece("table","eat")
		else:
			furniture_room.open()
			pet.motion.say("식탁을 놓으면 함께 먹을 수 있어")
	state.save_game()
	refresh_destinations()

func ensure_prop_nearby(id: String) -> void:
	if id in State.RETIRED_PROPS: return
	if is_instance_valid(furniture_room) and furniture_room.replaces(id):
		return
	if not state.unlocked(state.selected,id): return
	delivery_queue.erase(id)
	delivery_seen["%d/%s"%[state.selected,id]]=true
	if falling_gifts.has(id): finish_unlock_fall(id,false)
	var prop=props[id]
	state.hidden.erase(id)
	focus_prop=id
	apply_prop_visibility()
	var point=prop.feet_point()
	if not pet.motion.bounds.has_point(point):
		point=(pet.motion.feet+Vector2(120,20)).clamp(pet.motion.bounds.position,pet.motion.bounds.end)
		prop.position=Vector2i(point-prop.anchor_offset())
	persist_layout()

func pet_dining_point(prop) -> Vector2:
	return prop.dining_point(pet.motion.bounds)

func basket_play_point() -> Vector2:
	var center=props.basket.feet_point()
	var space=props.basket.size.x*.5+32.0*pet.motion.growth_scale
	var side=-1.0 if center.x-pet.motion.bounds.position.x>space else 1.0
	return (center+Vector2(side*space,0)).clamp(pet.motion.bounds.position,pet.motion.bounds.end)

func advance_basket() -> void:
	if not is_instance_valid(pet) or not props.has("basket"): return
	var m=pet.motion
	var active=m.phase=="home_use" and m.visit_id=="basket"
	props.basket.set_wobbling(active and m.elapsed<2.2)
	if not active: return
	if not props.basket.visible or props.basket.dragging or decorating:
		m.cancel_play();return
	m.soft_scene_origin=props.basket.feet_point()+Vector2(0,-32*props.basket.art_scale)
	m.soft_toy_prop="toy_plush"

func use_desktop_prop(id: String) -> void:
	if id in State.RETIRED_PROPS:
		activity(34 if id=="water" else (35 if id=="bowl" else 11))
		return
	if is_instance_valid(furniture_room) and furniture_room.replaces(id):
		furniture_room.use_piece("table" if id=="water" else "sofa","drink" if id=="water" else "default")
		return
	if not is_instance_valid(pet) or not state.unlocked(state.selected,id): return
	if id not in ["cushion","shelter","water","basket"]: return
	cancel_hunt()
	cancel_feeding()
	if decorating: return
	ensure_prop_nearby(id)
	props[id].confirm_drop()
	var point=pet_dining_point(props[id]) if id=="water" else props[id].feet_point()
	if id=="basket": point=basket_play_point()
	pet.motion.visit(point,{"cushion":"doze","shelter":"relax","water":"drink","basket":"home_use"}[id],id,true)
	pet.motion.stay_after_visit=id=="cushion"

func on_activity_finished(id: String) -> void:
	if id=="home_wall_shelf": id="home_shelf"
	elif id=="home_fireplace": id="home_sofa"
	if id in ["home_toy_mouse","home_toy_ball"]: state.reward_activity(pet.species,"home_play")
	var home_care={"home_sofa":"home_rest","home_daybed":"home_rest","home_lamp":"home_rest","home_window_seat":"home_rest","home_tv":"home_rest","home_play_rug":"home_play","home_shelf":"home_read","home_reading_chair":"home_read","home_vanity":"home_groom","home_record_player":"home_music","home_turntable":"home_music","home_tea":"home_tea","home_bathtub":"home_groom","home_toy_plush":"home_play","home_toy_ball":"home_play","home_toy_mouse":"home_play"}
	if home_care.has(id): state.reward_activity(pet.species,home_care[id])
	var event=preload("res://scripts/context_reactions.gd").completed_event(id,pet.motion)
	if not event.is_empty(): pet.motion.context_reactions.queue(event)
	if id=="home_food": id="bowl"
	elif id=="home_water": id="water"
	if id=="basket": state.reward_activity(pet.species,"home_play")
	if id in ["bowl","water"]: state.reward_activity(pet.species,id)
	if id in ["meal","bowl","snack","hand_feed"] and pet.motion.favorite_food:
		pet.motion.joy_left=1.8
		if not state.favorite_foods.get(str(pet.species),false):
			state.favorite_foods[str(pet.species)]=true
			state.add_affection(pet.species)
	if id=="snack": cancel_hunt()

func refresh_destinations() -> void:
	if not is_instance_valid(pet): return
	pet.motion.destinations.clear()
	if decorating: return
	for id in props:
		var prop=props[id]
		if id in State.RETIRED_PROPS: continue
		if not prop.visible: continue
		if falling_gifts.has(id) or id in delivery_queue: continue
		var point=prop.feet_point()
		if id in ["bowl","water"]: point=pet_dining_point(prop)
		if id=="acorn": point=(point+Vector2(-48,0)).clamp(pet.motion.bounds.position,pet.motion.bounds.end)
		if id=="basket": point=basket_play_point()
		if state.activity_space=="floor": point=point.clamp(pet.motion.bounds.position,pet.motion.bounds.end)
		elif not pet.motion.bounds.has_point(point): continue
		var action={"cushion":"doze","bowl":Food.action(pet.motion.food_id),"water":"drink","basket":"home_use","plant":"prop_use","lamp":"prop_use","shelter":"relax","acorn":"prop_use"}[id]
		var destination={"point":point,"action":action,"id":id}
		pet.motion.destinations.append(destination)
	if is_instance_valid(furniture_room): pet.motion.destinations.append_array(furniture_room.destinations())

func persist_layout() -> void:
	var places: Dictionary={}
	for id in props:
		if not falling_gifts.has(id): floor_prop(props[id])
		var point: Vector2i=falling_gifts[id].target if falling_gifts.has(id) else props[id].position
		var saved_y=state.layout[id][1] if state.activity_space=="floor" and state.layout.has(id) else point.y
		state.layout[id]=[point.x,saved_y]
		if id in ["cushion","shelter"]: places[id]=[point.x,saved_y]
	state.personal_layout[str(state.selected)]=places
	state.save_game()
	refresh_destinations()

func on_visit(id: String) -> void:
	if id=="basket":
		pet.motion.facing=1 if props.basket.feet_point().x>=pet.motion.feet.x else -1
		pet.motion.say("바구니에서 인형을 꺼내자")
		advance_basket()
	if is_instance_valid(furniture_room) and id in furniture_room.HOME_IDS:
		furniture_room.on_visit(id)
		return
	if id in SMALL_TOOLS:
		pet.motion.last_destination=id
		pet.motion.tool_interest_left=pet.motion.rng.randf_range(10,16)
	if id in ["bowl","meal","snack","hand_feed","water"]:
		pet.motion.say("냠냠~" if pet.motion.phase=="eat" else "꿀꺽~")
	if id in ["plant","lamp","acorn"]: props[id].confirm_drop()
	if id=="acorn": pet.motion.react("surprised",1.1,"prop_use")
	if id in ["bowl","water"]:
		pet.motion.facing=1.0 if props[id].feet_point().x>=pet.motion.feet.x else -1.0
	if id==FAVORITES[pet.species] and not state.discoveries.has(str(pet.species)):
		state.discoveries[str(pet.species)]=id
		state.save_game()

func activity(id: int) -> void:
	if id==40 and is_instance_valid(behavior_panel):
		behavior_panel.open()
		return
	# Old action shortcuts are retired. Real input and placed objects trigger them.
	if id in [0,1,2,11,12,13,16,20,21,22,24,29,30,34,35,36,37] or (id>=400 and id<404): return
	if id==900 and commerce_access!=null:
		commerce_access.show_account("연결한 계정의 동물 이용권을 확인할 수 있어요.")
		return
	if commerce_access!=null and not commerce_access.permits(state.selected): return
	if id in [36,37]:
		if is_instance_valid(pet) and not pet.motion.held:
			if not pet.motion.slapstick.start(pet.motion,"stumble" if id==36 else "sneeze"):
				pet.motion.say("지금 하던 것부터 마칠게")
		return
	if is_instance_valid(furniture_room):
		if id in [11,12,13,34,35]:
			var target="table" if id in [34,35] else "sofa"
			if furniture_room.pieces.has(target): furniture_room.use_piece(target,"drink" if id==34 else ("eat" if id==35 else "default"))
			else:
				furniture_room.open()
				pet.motion.say("식탁을 배치해 주세요" if target=="table" else "소파를 배치해 주세요")
			return
	if not state.can_action(state.selected,id): return
	cancel_feeding()
	if id>=100 and id<132:
		set_food(id-100,false)
		pet.motion.say("식탁 메뉴를 준비했어")
		return
	if id>=400 and id<404:
		cancel_hunt()
		if decorating: activity(5)
		pet.motion.cancel_play()
		var kind=["surprised","happy","angry","sleepy"][id-400]
		pet.motion.react(kind,preload("res://scripts/expression_behavior.gd").duration(pet.species,kind))
		return
	match id:
		33:
			set_activity_space("desktop" if state.activity_space=="floor" else "floor")
		38:
			if is_instance_valid(furniture_room): furniture_room.open("toys")
		39:
			show_info("함께 놀아요","놀이감을 꺼내 클릭하거나 동물을 데려다 놓아 주세요.\n실뜨개 공은 굴리며 놀고, 생쥐 놀이감은 따라가며 톡톡 건드려요.\n마우스 따라오기로 커서를 따라 산책해요.\n동물을 클릭하면 쓰다듬고, 잡고 있으면 2초 뒤 버둥거려요.")
		32:
			if is_instance_valid(furniture_room): furniture_room.open()
		31:
			expanded_props=not expanded_props
			apply_prop_visibility()
			refresh_destinations()
		25: show_first_guide()
		26: show_info("함께할 목표",state.goal_text(state.selected)+"\n\n"+state.progress_text(state.selected))
		23,24:
			cancel_hunt()
			if decorating: activity(5)
			if not pet.motion.start_social("follow" if id==23 else "rub",true):
				show_info("부빌 곳이 필요해요","해금된 소품을 하나 이상 보이게 두어 주세요.")
		1:
			cancel_hunt()
			if decorating: activity(5)
			pet.motion.prepare_ball()
		16:
			cancel_hunt()
			if decorating: activity(5)
			pet.motion.start_personality(true)
		4: start_hunt()
		5:
			cancel_hunt()
			decorating=not decorating
			pet.decorating=decorating
			pet.motion.resting=decorating
			pet.motion.cancel_play()
			for prop in props.values():
				prop.editing=decorating
				prop.refresh()
			persist_layout()
			apply_prop_visibility()
			refresh_destinations()
		6:
			state.palette=(state.palette+1)%3
			state.reward_activity(state.selected,"decorate")
			for prop in props.values():
				prop.palette=state.palette
				prop.refresh()
			state.save_game()
		7:
			var hide_all=false
			for prop in props.values():
				if prop.visible: hide_all=true
			for key in State.PROPS:
				if not state.unlocked(state.selected,key): continue
				if hide_all and key not in state.hidden: state.hidden.append(key)
				elif not hide_all: state.hidden.erase(key)
			apply_unlocks()
			state.save_game()
			refresh_destinations()
		8:
			for i in range(State.PROPS.size()): props[State.PROPS[i]].position=default_prop_position(i)
			persist_layout()
		9:
			var favorite=state.discoveries.get(str(pet.species),"")
			var description="아직 알아가는 중이에요. 어디에서 오래 머무는지 지켜보세요." if favorite.is_empty() else "%s 근처를 좋아해요."%Prop.NAMES[favorite]
			description+="\n이 친구의 버릇: "+Profiles.HABITS[pet.species]
			description+="\n성격: "+pet.motion.Personality.TYPES[pet.species]+" · "+pet.motion.Personality.NAMES[pet.species]
			description+="\n"+pet.motion.Personality.DETAILS[pet.species]
			description+="\n침대: "+Profiles.BEDS[pet.species]+"\n쉼터: "+Profiles.RETREATS[pet.species]
			description+="\n좋아하는 음식: "+(Food.title_for(pet.species,Profiles.FAVORITE_FOOD[pet.species]) if state.favorite_foods.get(str(pet.species),false) else "함께 먹으며 알아가는 중")
			show_info("우리 친구의 취향",description)
		14: show_info("친밀도와 선물",state.progress_text(state.selected))
		19: show_info("전용 소품",Profiles.TOYS[state.selected]+" · "+preload("res://scripts/prop_interactions.gd").TOY_ACTIONS[state.selected]+"\n"+Profiles.COMFORTS[state.selected]+" · "+preload("res://scripts/prop_interactions.gd").COMFORT_ACTIONS[state.selected]+"\n\n소품 클릭 또는 동물 데려다 놓기 → 전용 동작\n동작 중 왼쪽 버튼을 잡고 움직이면 함께 놀아요.\n강아지 밧줄: 오른쪽으로 당기면 버티고, 놓으면 힘을 풀어요.\n우클릭으로 중단 · 사용하지 않을 때 소품 드래그로 배치")
		20: use_species_prop("plant")
		29: use_common_toy("acorn")
		21: use_species_prop("lamp")
		22:
			cancel_hunt()
			if decorating: activity(5)
			pet.motion.start_playful(true)
		18: show_info("우리 친구의 성장 기록",state.growth_text(state.selected))
		10: show_first_guide()
		11,12,13:
			if decorating: activity(5)
			var place="shelter" if id==12 else "cushion"
			ensure_prop_nearby(place)
			pet.motion.visit(props[place].feet_point(),"cuddle" if id==13 else ("doze" if id==11 else "relax"),place,true)
			pet.motion.stay_after_visit=id==11

func show_info(title_text: String, body: String) -> void:
	if is_instance_valid(info): info.queue_free()
	info=AcceptDialog.new()
	info.force_native=true
	info.theme=app_theme
	info.title=title_text
	info.dialog_text=body
	info.get_label().add_theme_color_override("font_color",Color("403d36"))
	info.get_label().add_theme_font_size_override("font_size",16)
	info.get_label().add_theme_constant_override("line_spacing",5)
	info.get_ok_button().text="알겠어요"
	info.confirmed.connect(info.queue_free)
	info.canceled.connect(info.queue_free)
	add_child(info)
	info.size=Vector2i(530,310)
	info.position=usable_screen().get_center()-info.size/2
	info.popup()

func start_hunt() -> void:
	if not state.unlocked(state.selected,"bowl"): return
	cancel_hunt()
	if decorating: activity(5)
	pet.motion.cancel_play()
	hunt_previous_resting=pet.motion.resting
	pet.motion.resting=true
	hidden_snack=randi_range(0,2)
	hunt_resolved=false
	var center=pet.motion.feet
	var spacing=minf(140,pet.motion.bounds.size.x*.5)
	var first_x=clampf(center.x-spacing,pet.motion.bounds.position.x,pet.motion.bounds.end.x-spacing*2)
	for i in range(3):
		var bowl=Prop.new()
		bowl.kind="bowl"
		bowl.prop_id="hunt%d"%i
		bowl.number=i+1
		bowl.interactive=true
		bowl.palette=state.palette
		bowl.food_texture=Food.icon_for(pet.species,pet.motion.food_id)
		var point=Vector2(first_x+i*spacing,clampf(center.y-40,pet.motion.bounds.position.y,pet.motion.bounds.end.y))
		bowl.position=Vector2i(point-Vector2(56,63))
		bowl.activated.connect(func(_id): choose_bowl(i))
		bowl.layer_changed.connect(request_layer_order)
		add_child(bowl)
		hunt.append(bowl)

func choose_bowl(index: int) -> void:
	if hunt_resolved or index>=hunt.size() or hunt[index].empty: return
	var bowl=hunt[index]
	var point=Vector2(bowl.position)+Vector2(56,63)
	if index==hidden_snack:
		hunt_resolved=true
		for item in hunt:
			item.interactive=false
			item.refresh()
		bowl.number=0
		bowl.refresh()
		pet.motion.visit(point,Food.action(pet.motion.food_id),"snack",true)
	else:
		bowl.empty=true
		bowl.refresh()
		pet.motion.visit(point,"sniff","empty")

func cancel_hunt() -> void:
	if not hunt.is_empty() and is_instance_valid(pet):
		pet.motion.resting=hunt_previous_resting
	for bowl in hunt:
		if is_instance_valid(bowl):
			bowl.hide()
			bowl.queue_free()
	hunt.clear()
	hunt_resolved=false

func shutdown() -> void:
	cancel_feeding()
	persist_layout()
	get_tree().quit()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST: shutdown()

func pick_up_food() -> void:
	if not state.unlocked(state.selected,"bowl"): return
	if decorating or not is_instance_valid(pet) or is_instance_valid(held_food): return
	if pet.motion.phase in ["eat","drink"]: return
	cancel_hunt()
	pet.motion.cancel_play()
	pet.feeding=true
	pet.motion.react("anticipate",1.3)
	pet.motion.ask_left=55
	pet.motion.held=true
	held_food_id=pet.motion.food_id
	props.bowl.food_lifted=true
	props.bowl.refresh()
	held_food=HeldFood.new()
	held_food.food=Food.icon_for(pet.species,held_food_id)
	held_food.position=DisplayServer.mouse_get_position()-Vector2i(40,40)
	add_child(held_food)

func food_in_reach(cursor: Vector2) -> bool:
	var height=Catalog.DISPLAY_HEIGHT*Catalog.HEIGHTS[pet.species]*pet.motion.growth_scale
	var mouth=pet.motion.feet+pet.view.mouth_offset()
	var offset=(cursor-mouth)/Vector2(maxf(32,height*.35),maxf(28,height*.30))
	return offset.length_squared()<=1

func nearby_drop_prop(point: Vector2) -> String:
	if decorating or not hunt.is_empty(): return ""
	var chosen=""
	var best=INF
	for id in props:
		var prop=props[id]
		if falling_gifts.has(id): continue
		if not prop.visible or not state.unlocked(state.selected,id): continue
		# Select the closest visible prop surface, including generous space around
		# small bowls. Large beds remain easy to target across their full artwork.
		var area=Rect2(Vector2(prop.position)+Vector2(5,8)*prop.art_scale,Vector2(102,80)*prop.art_scale)
		var distance=point.distance_to(point.clamp(area.position,area.end))
		if distance>38: continue
		var score=distance+point.distance_to(prop.feet_point())*.12
		if score<best:
			best=score
			chosen=id
	return chosen

func on_pet_dropped(point: Vector2) -> void:
	for prop in props.values(): prop.set_drop_hover(false)
	if is_instance_valid(furniture_room) and furniture_room.accept_drop(point,pet.pointer_desktop_position()):
		pet.furniture_drop_accepted=true
		return
	var id=nearby_drop_prop(point)
	if id.is_empty(): return
	var prop=props[id]
	prop.confirm_drop()
	request_layer_order()
	if id=="bowl" and pet.motion.satiety>=97 and Food.action(pet.motion.food_id)=="eat":
		pet.motion.react("full",2.2)
		return
	var action={"bowl":Food.action(pet.motion.food_id),"water":"drink","cushion":"doze","shelter":"pet","plant":"prop_use","lamp":"prop_use","basket":"home_use","acorn":"prop_use"}[id]
	var destination=pet_dining_point(prop) if id in ["bowl","water"] else prop.feet_point()
	if id=="basket": destination=basket_play_point()
	if id=="acorn": destination=(destination+Vector2(-48,0)).clamp(pet.motion.bounds.position,pet.motion.bounds.end)
	pet.motion.visit(destination,action,id,id not in ["bowl","water"])
	pet.motion.stay_after_visit=id=="cushion"

func _process(_delta: float) -> void:
	advance_basket()
	advance_gift_notices(_delta)
	advance_unlock_falls(_delta)
	try_gift_visit()
	advance_deliveries(_delta)
	# Furniture movement happens later in the scene's process order. Restore
	# after all nodes have moved their native windows, not before that movement.
	# Windows can finish native click/drag stacking after the first deferred
	# check. Briefly recheck; the native component does nothing if already right.
	if layers_dirty or Time.get_ticks_msec()<layer_settle_until: request_layer_order(false)
	for id in ["plant","lamp"]:
		if not props.has(id): continue
		var active=is_instance_valid(pet) and pet.motion.phase=="prop_use" and pet.motion.visit_id==id
		if active and (not props[id].visible or decorating):
			pet.motion.cancel_play()
			active=false
		props[id].set_in_use(active)
	if props.has("acorn"):
		var playing=is_instance_valid(pet) and pet.motion.phase=="prop_use" and pet.motion.visit_id=="acorn"
		if playing and (not props.acorn.visible or decorating):
			pet.motion.cancel_play()
			playing=false
		props.acorn.set_wobbling(playing)
		if playing:props.acorn.wobble_time=pet.motion.elapsed
	var hovered=""
	var furniture_hover=""
	if is_instance_valid(furniture_room):
		if is_instance_valid(pet) and pet.dragging and pet.motion.carried:
			furniture_hover=furniture_room.preview_drop(pet.motion.feet,pet.pointer_desktop_position())
		else: furniture_room.preview_drop()
	if is_instance_valid(pet) and pet.dragging and pet.motion.carried:
		if furniture_hover.is_empty(): hovered=nearby_drop_prop(pet.motion.feet)
	for id in props: props[id].set_drop_hover(id==hovered)
	if is_instance_valid(pet): pet.motion.cursor_position=Vector2(DisplayServer.mouse_get_position())
	if not is_instance_valid(held_food): return
	if not is_instance_valid(pet):
		cancel_feeding()
		return
	var cursor=Vector2(DisplayServer.mouse_get_position())
	var ready_to_feed=food_in_reach(cursor)
	held_food.follow_cursor(cursor,ready_to_feed)
	var buttons=DisplayServer.mouse_get_button_state()
	if buttons & MOUSE_BUTTON_MASK_RIGHT:
		cancel_feeding()
	elif not (buttons & MOUSE_BUTTON_MASK_LEFT):
		var meal=held_food_id
		cancel_feeding()
		if ready_to_feed:
			if pet.motion.satiety>=97 and Food.action(meal)=="eat":
				pet.motion.react("full",2.2)
				return
			pet.motion.food_id=meal
			pet.motion.favorite_food=meal==Profiles.FAVORITE_FOOD[pet.species]
			pet.motion.visit(pet.motion.feet,Food.action(meal),"hand_feed",true)

func cancel_feeding() -> void:
	if not is_instance_valid(held_food): return
	held_food.hide()
	held_food.queue_free()
	held_food=null
	held_food_id=-1
	if props.has("bowl"):
		props.bowl.food_lifted=false
		props.bowl.refresh()
	if is_instance_valid(pet):
		pet.feeding=false
		pet.motion.held=false
		pet.motion.cancel_play()
		pet.motion.rest_left=4

func apply_unlocks() -> void:
	apply_prop_visibility()
	if is_instance_valid(furniture_room): furniture_room.refresh_buttons()
	if is_instance_valid(pet):
		pet.refresh_unlock_menu()
		pet.motion.affection=int(state.play_affection.get(str(state.selected),0))
		pet.motion.can_ask_play=state.unlocked(state.selected,"basket")
		pet.motion.can_playful=state.unlocked(state.selected,"playful")
		pet.motion.can_personality=state.unlocked(state.selected,"personality")
		pet.motion.can_follow=state.unlocked(state.selected,"follow")
		pet.motion.can_rub=state.unlocked(state.selected,"rub")
	refresh_destinations()

func apply_prop_visibility() -> void:
	if focus_prop in ["cushion","shelter","lamp"]: preferred_rest=focus_prop
	if focus_prop in ["acorn","plant","basket"]: preferred_toy=focus_prop
	var eligible: Array=[]
	for id in props:
		if id not in State.RETIRED_PROPS and state.unlocked(state.selected,id) and id not in state.hidden: eligible.append(id)
	var selected=eligible if expanded_props or decorating else preload("res://scripts/desktop_clutter.gd").visible_ids(eligible,preferred_rest,preferred_toy)
	for id in props:
		props[id].visible=id in selected or (id in eligible and (falling_gifts.has(id) or pending_gift_visits.has(id)))
		if id in delivery_queue: props[id].visible=false
		if is_instance_valid(furniture_room) and furniture_room.replaces(id): props[id].visible=false

func on_affection_changed(species: int, gifts: Array) -> void:
	if species!=state.selected: return
	if is_instance_valid(pet) and not is_equal_approx(pet.motion.growth_scale,state.growth_scale(species)): apply_growth()
	for id in gifts: state.hidden.erase(id)
	if not gifts.is_empty(): state.save_game()
	apply_unlocks()
	for id in gifts:
		if props.has(id): queue_delivery(id)
	if not gifts.is_empty(): show_gift.call_deferred(species,gifts)

func clear_falling_gifts() -> void:
	for id in falling_gifts:
		if props.has(id):
			props[id].position=falling_gifts[id].target
			props[id].mouse_passthrough=false
	falling_gifts.clear()
	pending_gift_visits.clear()
	delivery_queue.clear()
	delivery_delay=3.0

func queue_delivery(id: String) -> void:
	if id in State.RETIRED_PROPS: return
	if not props.has(id) or id in delivery_queue or falling_gifts.has(id) or id in pending_gift_visits: return
	if not state.unlocked(state.selected,id) or id in state.hidden: return
	delivery_queue.append(id)
	apply_prop_visibility()
	refresh_destinations()

func queue_welcome_tools() -> void:
	for id in SMALL_TOOLS:
		if not delivery_seen.has("%d/%s"%[state.selected,id]): queue_delivery(id)

func delivery_paused() -> bool:
	if not is_instance_valid(pet) or decorating or is_instance_valid(held_food) or not hunt.is_empty(): return true
	var m=pet.motion
	return m.held or m.carried or m.resting or pet.menu.visible or objects_are_dragging()

func place_delivery_tool(id: String) -> void:
	if id not in SMALL_TOOLS or not is_instance_valid(pet): return
	var prop=props[id]
	var origin=pet.motion.feet
	# Keep nearby saved positions. A distant tool lands near the pet so its
	# first interaction does not require a minute-long desktop crossing.
	if state.layout.has(id) and origin.distance_to(prop.feet_point())<110: return
	var chosen=prop.position
	var best=INF
	for offset in [Vector2(100,0),Vector2(-100,0),Vector2(145,30),Vector2(-145,30),Vector2(100,-65),Vector2(-100,-65),Vector2(190,-35),Vector2(-190,-35)]:
		var margin=Vector2(52,0 if state.activity_space=="floor" else 10)
		var feet=(origin+offset).clamp(pet.motion.bounds.position+margin,pet.motion.bounds.end-margin)
		var point=Vector2i(feet-prop.anchor_offset())
		var area=Rect2i(point,prop.size).grow(12)
		var blocked=false
		for other in props:
			if other!=id and props[other].visible and area.intersects(Rect2i(props[other].position,props[other].size)): blocked=true
		if not blocked and origin.distance_to(feet)<best:
			best=origin.distance_to(feet)
			chosen=point
	prop.position=chosen

func advance_deliveries(delta: float) -> void:
	if is_instance_valid(furniture_room) and furniture_room.arrivals.busy(): return
	if delivery_queue.is_empty() or delivery_paused(): return
	if pet.motion.energy<35 or pet.motion.satiety<48 or pet.motion.hydration<45: return
	delivery_delay=maxf(0,delivery_delay-delta)
	# Reserve this short idle pause for the pending arrival. Otherwise the AI
	# can choose a long trip to a bowl before the first three-second delay ends.
	if pet.motion.phase=="idle" and falling_gifts.is_empty() and pending_gift_visits.is_empty():
		pet.motion.rest_left=maxf(pet.motion.rest_left,delivery_delay+.1)
	if delivery_delay>0 or not falling_gifts.is_empty() or not pending_gift_visits.is_empty(): return
	# Finish the approach, play and reaction before revealing another tool.
	if pet.motion.phase!="idle": return
	var id: String=delivery_queue.pop_front()
	if not props.has(id) or not state.unlocked(state.selected,id) or id in state.hidden:
		apply_prop_visibility()
		return
	place_delivery_tool(id)
	start_unlock_fall(id)
	delivery_delay=2.5

func start_unlock_fall(id: String) -> void:
	if not props.has(id) or falling_gifts.has(id): return
	delivery_seen["%d/%s"%[state.selected,id]]=true
	focus_prop=id
	apply_prop_visibility()
	var prop=props[id]
	var target: Vector2i=prop.position
	var screen=DisplayServer.get_screen_from_rect(Rect2i(target,prop.size))
	if screen<0: screen=DisplayServer.SCREEN_PRIMARY
	var usable=DisplayServer.screen_get_usable_rect(screen)
	var start=Vector2i(target.x,usable.position.y-prop.size.y-12)
	falling_gifts[id]={"start":start,"target":target,"time":0.0,"duration":1.25}
	prop.position=start
	prop.show()
	prop.mouse_passthrough=true
	if is_instance_valid(pet) and not pet.motion.held and pet.motion.phase=="idle":
		pet.motion.context_reactions.queue("gift")
	refresh_destinations()

func finish_unlock_fall(id: String,visit: bool=true) -> void:
	if not falling_gifts.has(id): return
	var target: Vector2i=falling_gifts[id].target
	falling_gifts.erase(id)
	if props.has(id):
		props[id].position=target
		props[id].mouse_passthrough=false
		props[id].confirm_drop()
	if visit and not pending_gift_visits.has(id): pending_gift_visits.append(id)
	refresh_destinations()

func advance_unlock_falls(delta: float) -> void:
	for id in falling_gifts.keys():
		if not props.has(id): continue
		var fall: Dictionary=falling_gifts[id]
		fall.time=float(fall.time)+delta
		var progress=clampf(float(fall.time)/float(fall.duration),0.0,1.0)
		var start: Vector2i=fall.start
		var target: Vector2i=fall.target
		var y: float
		if progress<.78:
			var descent=progress/.78
			y=lerpf(float(start.y),float(target.y),descent*descent)
		else:
			var bounce=(progress-.78)/.22
			y=float(target.y)-sin(bounce*PI)*20.0*(1.0-bounce)
		props[id].position=Vector2i(target.x,roundi(y))
		falling_gifts[id]=fall
		if progress>=1.0: finish_unlock_fall(id)

func try_gift_visit() -> void:
	if pending_gift_visits.is_empty() or not is_instance_valid(pet) or decorating: return
	if delivery_paused(): return
	if pet.motion.energy<35 or pet.motion.satiety<48 or pet.motion.hydration<45: return
	if pet.motion.held or pet.motion.carried or pet.motion.resting or pet.motion.phase!="idle": return
	if pet.menu.visible or is_instance_valid(held_food): return
	var id: String=pending_gift_visits.pop_front()
	if id in state.hidden: return
	focus_prop=id
	apply_prop_visibility()
	if not props.has(id) or not props[id].visible or not state.unlocked(state.selected,id): return
	var prop=props[id]
	var point=pet_dining_point(prop) if id in ["bowl","water"] else prop.feet_point()
	if id=="acorn": point+=Vector2(-48,0)
	point=point.clamp(pet.motion.bounds.position,pet.motion.bounds.end)
	var action={"bowl":"inspect","water":"inspect","basket":"inspect","cushion":"relax","shelter":"relax","plant":"prop_use","lamp":"prop_use","acorn":"prop_use"}.get(id,"inspect")
	pet.motion.visit(point,action,id,false)

func apply_growth() -> void:
	if not is_instance_valid(pet): return
	pet.motion.growth_scale=state.growth_scale(state.selected)
	pet.motion.growth_stage=state.growth_stage(state.selected)
	pet.motion.rabbit_pilot=rabbit_hop_available(state.selected,pet.motion.growth_stage)
	pet.view.prewarm_current_art()
	pet.title=Catalog.NAMES[state.selected]+" · "+State.GROWTH_NAMES[state.growth_stage(state.selected)]+" · 말랑친구"
	for prop in props.values():
		prop.growth_scale=pet.motion.growth_scale
		prop.refresh()
	refresh_destinations()

func on_growth_changed(species: int, stage: int) -> void:
	if species!=state.selected: return
	apply_growth()
	show_gift.call_deferred(species,[],stage)

func show_food_unlock(species: int,foods: Array) -> void:
	if species!=state.selected or foods.is_empty(): return
	gift_notices.append({"title":"식탁에 새 메뉴가 열렸어요","body":Food.title_for(species,foods[0])+(" 외 %d종"%(foods.size()-1) if foods.size()>1 else ""),"hint":"식탁 준비 → 식탁 메뉴 고르기에서 차려주세요"})

func show_gift(species: int, gifts: Array, growth_stage: int=-1) -> void:
	if species!=state.selected or not is_instance_valid(pet): return
	if gifts.is_empty() and growth_stage<0: return
	var names=PackedStringArray()
	for id in gifts.slice(0,2): names.append(state.gift_name(id))
	var body=" · ".join(names)
	if gifts.size()>2: body+=" 외 %d개"%(gifts.size()-2)
	var action=str(state.last_reward_action.get(str(species),""))
	var cause=State.ACTION_LABELS.get(action,"함께한 시간")
	gift_notices.append({"title":"새로운 생활이 열렸어요" if growth_stage<0 else "한 뼘 더 자랐어요","body":body if growth_stage<0 else State.GROWTH_NAMES[growth_stage]+"가 되었어요","hint":cause+"로 가까워졌어요 · 놀이감은 함께하기, 가구는 집 꾸미기에서 꺼내 주세요"})
	if gift_notices.size()>6: gift_notices.pop_front()

func advance_gift_notices(delta: float) -> void:
	gift_notice_gap=maxf(0,gift_notice_gap-delta)
	if gift_notices.is_empty() or is_instance_valid(gift_notice) or gift_notice_gap>0 or not is_instance_valid(pet): return
	if pet.motion.held or pet.motion.phase in ["drop","dizzy"] or pet.menu.visible or objects_are_dragging(): return
	var message: Dictionary=gift_notices.pop_front()
	pet.motion.context_reactions.queue("gift")
	var notice=Window.new()
	gift_notice=notice
	notice.visible=false
	notice.force_native=true
	notice.borderless=true
	notice.always_on_top=true
	notice.unfocusable=true
	notice.mouse_passthrough=true
	notice.size=Vector2i(390,124)
	notice.title="복슬복슬펫 · 새로운 생활"
	notice.theme=app_theme
	var panel=PanelContainer.new()
	panel.add_theme_stylebox_override("panel",preload("res://scripts/cozy_ui.gd").box("f1f4ec",12))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notice.add_child(panel)
	var column=VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	panel.add_child(column)
	for key in ["title","body","hint"]:
		var label=Label.new()
		label.text=message[key]
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size",12 if key=="hint" else 14)
		label.add_theme_color_override("font_color",Color("817d73" if key=="hint" else "4d6045"))
		column.add_child(label)
	add_child(notice)
	var area=Rect2i(pet.desktop_bounds())
	notice.position=Vector2i((pet.motion.feet+Vector2(-195,-275)).clamp(Vector2(area.position),Vector2((area.end-notice.size).max(area.position))))
	notice.show()
	NativeMouse.apply(notice,true,true)
	gift_notice_gap=7.0
	var notice_ref: WeakRef=weakref(notice)
	get_tree().create_timer(5).timeout.connect(func():
		var active_notice=notice_ref.get_ref()
		if is_instance_valid(active_notice): active_notice.queue_free())

func use_species_prop(id: String) -> void:
	if not is_instance_valid(pet) or id not in ["plant","lamp"]: return
	if id in State.RETIRED_PROPS:
		var target="toy_plush" if id=="plant" else "sofa"
		if furniture_room.pieces.has(target): furniture_room.use_piece(target)
		else: furniture_room.open("toys" if id=="plant" else "home")
		return
	if not state.unlocked(state.selected,id): return
	cancel_hunt()
	if decorating: activity(5)
	ensure_prop_nearby(id)
	props[id].confirm_drop()
	pet.motion.visit(props[id].feet_point(),"prop_use",id,true)

func use_common_toy(id: String) -> void:
	if not is_instance_valid(pet) or id!="acorn": return
	if not state.unlocked(state.selected,id): return
	cancel_hunt()
	if decorating: activity(5)
	ensure_prop_nearby(id)
	props[id].confirm_drop()
	var point=(props[id].feet_point()+Vector2(-48,0)).clamp(pet.motion.bounds.position,pet.motion.bounds.end)
	pet.motion.visit(point,"prop_use",id,true)

func set_prop_visible(id: String,value: bool) -> void:
	if not props.has(id): return
	if value:
		state.hidden.erase(id)
		preferred_toy=id
		focus_prop=id
		ensure_prop_nearby(id)
		floor_prop(props[id])
	else:
		if id not in state.hidden: state.hidden.append(id)
		if pet.motion.visit_id==id: pet.motion.cancel_play()
		props[id].set_wobbling(false)
	state.save_game()
	apply_prop_visibility()
	refresh_destinations()
	request_layer_order()
	if is_instance_valid(furniture_room): furniture_room.refresh_buttons()

func set_acorn_visible(value: bool) -> void:
	set_prop_visible("acorn",value)
