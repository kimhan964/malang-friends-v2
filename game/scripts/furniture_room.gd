extends Node
const Catalog=preload("res://scripts/furniture_catalog.gd")
const Piece=preload("res://scripts/furniture_window.gd")
var app
var pieces: Dictionary={}
var panel: Window
var item_rows: Dictionary={}
var panel_heading: Label
var panel_hint: Label
var panel_icon: TextureRect
var panel_column: VBoxContainer
var panel_scroll: ScrollContainer
var panel_done: Button
const TOY_IDS=["acorn","toy_ball","toy_mouse","toy_plush"]
var acorn_button: Button
var buttons: Dictionary={}
var previews: Dictionary={}
var status_labels: Dictionary={}
var home_delay=8.0
var last_home=""
var drop_target=""
var space_picker: OptionButton
var alarm_time=-1.0
var alarm_species=-1
const HOME_IDS={"home_food":"table","home_water":"table","home_tea":"table","home_sofa":"sofa","home_shelf":"shelf","home_lamp":"lamp","home_reading_chair":"reading_chair","home_daybed":"daybed","home_vanity":"vanity","home_record_player":"record_player","home_play_rug":"play_rug","home_window_seat":"window_seat","home_tv":"tv","home_turntable":"turntable","home_wall_clock":"wall_clock","home_wall_shelf":"wall_shelf","home_plant_stand":"plant_stand","home_dresser":"dresser","home_fireplace":"fireplace","home_aquarium":"aquarium","home_alarm_clock":"alarm_clock","home_toy_ball":"toy_ball","home_toy_mouse":"toy_mouse","home_toy_plush":"toy_plush","home_bathtub":"bathtub"}
const Home=preload("res://scripts/home_animation.gd")
const FRONT_GAP=18.0
var arrivals=preload("res://scripts/furniture_arrivals.gd").new()
var toy_play=preload("res://scripts/toy_play.gd").new()
var mouse_roam=preload("res://scripts/mouse_roam.gd").new()
func _ready() -> void:
	for id in app.state.furniture:
		var at=app.state.furniture[id]
		place(id,Vector2(at[0],at[1]),false)
		if pieces.has(id): pieces[id].set_mirrored(at.size()>2 and at[2]==true)
		if pieces.has(id):
			pieces[id].stack_order=int(at[4]) if at.size()>4 else 0
			pieces[id].set_user_scale(float(at[3]) if at.size()>3 else 1.0)
			floor_piece(pieces[id])
	if not app.state.home_initialized or app.state.starter_layout_version<1:
		for id in ["table","sofa","play_rug"]: place(id,Vector2.INF,false)
		app.state.home_initialized=true
		app.state.starter_layout_version=1
		save()
	# Introduce the actual bath once in existing homes as well as new homes.
	# Remember ownership so deliberately putting it away remains respected.
	if not app.state.home_owned.has("bathtub"):
		place("bathtub",Vector2.INF,false)
		if pieces.has("bathtub"):
			app.state.home_owned.bathtub=true
			save()
func place(id: String,at=Vector2.INF,persist: bool=true) -> void:
	if not Catalog.ITEMS.has(id) or not app.state.furniture_available(id) or Catalog.texture(id)==null: return
	if pieces.has(id): return
	var piece=Piece.new()
	piece.item_id=id
	piece.appearance=Catalog.normalize_style(app.state.furniture_styles.get(id,{}))
	add_child(piece)
	if not at.is_finite():
		var rect=app.usable_screen()
		var slot=Catalog.ITEMS.keys().find(id)
		at=Vector2(rect.position)+Vector2(rect.size.x*.5-300+(slot%5)*155,rect.size.y*.78-(slot/5)*155)-Vector2(piece.size.x*.5,piece.size.y)
		if Catalog.is_wall(id): at.y=preload("res://scripts/living_space.gd").ground(Rect2(rect))-260-piece.size.y
		if app.state.activity_space=="floor":
			# Prefer an unused horizontal slot for a newly added decoration.
			for x in range(rect.position.x+160,rect.end.x-piece.size.x-160,24):
				var occupied=false
				for other in pieces.values():
					if x<other.position.x+other.size.x+12 and x+piece.size.x+12>other.position.x: occupied=true
				if not occupied:
					at.x=x
					break
	piece.position=piece.clamp_position(at)
	floor_piece(piece)
	piece.moved.connect(func():
		save()
		if is_instance_valid(app.pet) and HOME_IDS.get(app.pet.motion.visit_id,"")==id: use_piece(id))
	piece.layer_changed.connect(app.request_layer_order)
	piece.stack_requested.connect(func(direction): change_stack(id,direction))
	piece.toy_launched.connect(func(velocity): toy_play.launch_user(self,id,velocity))
	piece.visibility_changed.connect(app.request_layer_order)
	piece.removed.connect(func(): remove_piece(id))
	piece.activated.connect(func(action): use_piece(id,action))
	pieces[id]=piece
	app.request_layer_order()
	if persist:
		if id in arrivals.ITEMS: app.state.arrival_seen[id]=true
		app.state.home_owned[id]=true
		app.state.reward_activity(app.state.selected,"decorate")
		save()
	refresh_world()
	refresh_buttons()
	call_deferred("keep_panel_front")
func keep_panel_front() -> void:
	if is_instance_valid(panel) and panel.visible and DisplayServer.get_name()!="headless":
		DisplayServer.window_move_to_foreground(panel.get_window_id())
func remove_piece(id: String) -> void:
	if not pieces.has(id): return
	if is_instance_valid(app.pet) and HOME_IDS.get(app.pet.motion.visit_id,"")==id: app.pet.motion.cancel_play()
	pieces[id].hide()
	pieces[id].queue_free()
	pieces.erase(id)
	save()
	refresh_world()
	refresh_buttons()
func save() -> void:
	var previous=app.state.furniture.duplicate(true)
	app.state.furniture.clear()
	for id in pieces:
		floor_piece(pieces[id])
		var at: Vector2i=arrivals.fall.target if pieces[id].arriving and not arrivals.fall.is_empty() else pieces[id].position
		var saved_y=previous[id][1] if app.state.activity_space=="floor" and not Catalog.is_wall(id) and previous.has(id) else at.y
		app.state.furniture[id]=[at.x,saved_y,pieces[id].mirrored,pieces[id].user_scale,pieces[id].stack_order]
		app.state.furniture_styles[id]=pieces[id].appearance.duplicate()
	app.state.save_game()
	app.request_layer_order()
	refresh_world()
	refresh_buttons()
func ordered_pieces() -> Array:
	var ordered=pieces.values()
	ordered.sort_custom(func(a,b):
		if a.item_id=="play_rug" or b.item_id=="play_rug": return a.item_id=="play_rug" and b.item_id!="play_rug"
		return a.stack_order<b.stack_order if a.stack_order!=b.stack_order else a.item_id<b.item_id)
	return ordered
func change_stack(id: String,direction: int) -> void:
	if not pieces.has(id): return
	var edge=pieces[id].stack_order
	for piece in pieces.values():
		edge=maxi(edge,piece.stack_order) if direction>0 else mini(edge,piece.stack_order)
	pieces[id].stack_order=edge+(1 if direction>0 else -1)
	save()
func floor_piece(piece) -> void:
	if piece.arriving: return
	piece.floor_locked=app.state.activity_space=="floor" and not Catalog.is_wall(piece.item_id)
	if Catalog.is_wall(piece.item_id):
		# Keep the decoration above the walking lane even when dragged low.
		if is_instance_valid(app.pet):
			var excess=piece.art_point(Vector2(.5,.94)).y+FRONT_GAP+100-app.pet.motion.bounds.end.y
			if excess>0: piece.position.y-=ceili(excess)
		return
	if app.state.activity_space!="floor":
		if is_instance_valid(app.pet):
			var excess=piece.ground_point().y-app.pet.motion.bounds.end.y
			if excess>0: piece.position.y-=ceili(excess)
		return
	var floor_y=preload("res://scripts/living_space.gd").ground(Rect2(app.usable_screen()))
	var at=Vector2(piece.position)
	var anchor=piece.art_point(Vector2(.5,.64)) if piece.item_id=="play_rug" else piece.ground_point()
	at.y+=floor_y-anchor.y
	piece.position=piece.clamp_position(at)
	piece.floor_top=piece.position.y
func apply_space() -> void:
	for id in pieces:
		if app.state.activity_space=="desktop" and app.state.furniture.has(id):
			var at=app.state.furniture[id]
			pieces[id].position=pieces[id].clamp_position(Vector2(at[0],at[1]))
		floor_piece(pieces[id])
	refresh_buttons()
func refresh_world() -> void:
	if not is_instance_valid(app.pet): return
	app.apply_prop_visibility()
	app.refresh_destinations()
func replaces(id: String) -> bool:
	return id in app.state.RETIRED_PROPS or (pieces.has("table") and id in ["bowl","water"]) or (pieces.has("sofa") and id in ["cushion","shelter"]) or (pieces.has("lamp") and id=="lamp")
func destinations() -> Array:
	var result=[]
	if not is_instance_valid(app.pet): return result
	for id in HOME_IDS:
		var piece_id: String=HOME_IDS[id]
		if not pieces.has(piece_id) or not pieces[piece_id].visible or pieces[piece_id].dragging or pieces[piece_id].arriving: continue
		if id=="home_food" and not app.state.unlocked(app.state.selected,"bowl"): continue
		if id=="home_water" and not app.state.unlocked(app.state.selected,"water"): continue
		var action="home_use" if Home.KINDS.has(id) and Home.available(app.pet.motion) else {"home_food":"eat","home_water":"drink","home_tea":"drink","home_sofa":"relax","home_shelf":"sniff","home_lamp":"doze","home_reading_chair":"relax","home_daybed":"doze","home_vanity":"groom","home_record_player":"look","home_play_rug":"playful","home_window_seat":"relax","home_tv":"relax","home_turntable":"look","home_wall_clock":"look","home_wall_shelf":"relax","home_plant_stand":"look","home_dresser":"groom","home_fireplace":"relax","home_aquarium":"look","home_alarm_clock":"look","home_toy_ball":"playful","home_toy_mouse":"sniff"}.get(id,"look")
		result.append({"point":destination_point(id),"action":action,"id":id})
	return result
func destination_point(id: String) -> Vector2:
	var p=pieces[HOME_IDS[id]]
	var m=app.pet.motion
	# One open lane in front of every piece. Furniture is scenery, not a wall.
	var x=.4 if id=="home_water" else (.6 if id in ["home_food","home_tea"] else .5)
	var point=p.art_point(Vector2(x,Catalog.ground_contact(p.sprite.texture)))
	if p.item_id=="play_rug": point=p.art_point(Vector2(.5,.64))
	if p.item_id in ["sofa","daybed"]: point.x+=(-1 if not p.mirrored else 1)*p.sprite.texture.get_width()*p.sprite.scale.x*.13
	if p.item_id in ["plant_stand","shelf","dresser","vanity","aquarium","lamp","tv","record_player","turntable"]:
		# Keep the face and paws in an open space next to tall scenery.
		var half_width=p.sprite.texture.get_width()*absf(p.sprite.scale.x)*.5
		var clearance=half_width+38.0*maxf(.8,m.growth_scale)
		var side=-1.0 if not p.mirrored else 1.0
		if point.x+side*clearance<m.bounds.position.x or point.x+side*clearance>m.bounds.end.x: side=-side
		point.x+=side*clearance
	if p.item_id in arrivals.ITEMS: point.x+=(-1 if not p.mirrored else 1)*(42 if p.item_id!="alarm_clock" else 62)
	if Catalog.is_wall(p.item_id): point.y=m.bounds.get_center().y if app.state.activity_space=="floor" else minf(m.bounds.end.y,point.y+100)
	return point.clamp(m.bounds.position,m.bounds.end)
func drop_candidate(feet: Vector2,cursor: Vector2=Vector2.INF) -> String:
	if not is_instance_valid(app.pet) or app.decorating or not app.hunt.is_empty(): return ""
	if app.commerce_access!=null and not app.commerce_access.permits(app.state.selected): return ""
	var chosen=""
	var best=INF
	for id in pieces:
		var piece=pieces[id]
		if not piece.visible or piece.dragging or piece.menu.visible or piece.arriving: continue
		var area=Rect2(Vector2(piece.position)+piece.sprite.position,piece.sprite.texture.get_size()*piece.sprite.scale)
		var distance=feet.distance_to(feet.clamp(area.position,area.end))
		var score=distance+feet.distance_to(area.get_center())*.12
		# Also accept the grabbed point over the furniture, especially when the
		# animal was picked up by its ears/head. Prefer actual foot contact.
		if cursor.is_finite():
			var cursor_distance=cursor.distance_to(cursor.clamp(area.position,area.end))
			if cursor_distance<=12:
				score=minf(score,cursor_distance+cursor.distance_to(area.get_center())*.12+8)
				distance=minf(distance,cursor_distance)
		if distance<=28 and score<best:
			chosen=id
			best=score
	return chosen
func preview_drop(feet: Vector2=Vector2.INF,cursor: Vector2=Vector2.INF) -> String:
	drop_target=drop_candidate(feet,cursor) if feet.is_finite() else ""
	for id in pieces: pieces[id].set_drop_hover(id==drop_target)
	return drop_target
func accept_drop(feet: Vector2,cursor: Vector2=Vector2.INF) -> bool:
	# Re-evaluate at release: the furniture may have moved or been removed.
	var id=drop_candidate(feet,cursor)
	preview_drop()
	if id.is_empty(): return false
	return use_piece(id)
func use_piece(id: String,action: String="default") -> bool:
	if not is_instance_valid(app.pet) or not pieces.has(id) or app.decorating: return false
	if app.commerce_access!=null and not app.commerce_access.permits(app.state.selected): return false
	var key="home_"+id
	if id=="table": key="home_water" if action=="drink" else ("home_food" if action=="eat" else "home_tea")
	for destination in destinations():
		if destination.id!=key: continue
		app.cancel_feeding()
		app.cancel_hunt()
		toy_play.cancel()
		app.pet.motion.visit(destination.point,destination.action,key,true)
		app.request_layer_order()
		home_delay=18.0
		last_home=key
		return true
	app.pet.motion.say("조금 더 친해지면 함께할 수 있어")
	return false
func on_visit(id: String) -> void:
	if not HOME_IDS.has(id) or not pieces.has(HOME_IDS[id]): return
	app.request_layer_order()
	if toy_play.arrived(self,id): return
	var m=app.pet.motion
	m.facing=1 if pieces[HOME_IDS[id]].art_point(Vector2(.5,.5)).x>=m.feet.x else -1
	if id in ["home_tv","home_turntable"]:
		m.facing=1 if pieces[HOME_IDS[id]].art_point(Vector2(.5,.94)).x>=m.feet.x else -1
	m.say({"home_food":"잘 먹을게","home_water":"시원해","home_tea":"차 한 잔","home_sofa":"포근해","home_shelf":"한 장 더","home_lamp":"잠깐 쉬자","home_reading_chair":"책 읽는 시간","home_daybed":"조금만 잘게","home_vanity":"단정하게","home_record_player":"좋은 노래","home_play_rug":"같이 놀자","home_window_seat":"느긋한 오후","home_tv":"같이 볼까","home_turntable":"이 곡 좋아","home_wall_clock":"몇 시일까","home_wall_shelf":"여기서 한 장 더","home_plant_stand":"잎이 싱그럽네","home_dresser":"보송하게 정리","home_fireplace":"따뜻하고 포근해","home_aquarium":"물고기가 헤엄쳐","home_alarm_clock":"아직은 여유 있어","home_toy_ball":"데굴데굴 굴려볼까","home_toy_mouse":"살짝 톡 건드려볼까","home_bathtub":"보글보글, 보송해지자","home_toy_plush":"꼬옥, 내 인형"}.get(id,"함께 쉬자"))
	if id=="home_alarm_clock":
		alarm_time=0.0
		alarm_species=m.species
		m.action_left=8.0
		m.react("surprised",1.1,"look")
		m.say("어, 무슨 소리지?")
	last_home=id
	home_delay=18
func _process(delta: float) -> void:
	arrivals.advance(self,delta)
	mouse_roam.advance(self,delta)
	toy_play.advance(self,delta)
	if not is_instance_valid(app.pet): return
	var m=app.pet.motion
	if alarm_time>=0:
		if m.visit_id!="home_alarm_clock" or m.species!=alarm_species or m.held or m.carried or not pieces.has("alarm_clock") or pieces.alarm_clock.dragging:
			alarm_time=-1.0
		else:
			var previous=alarm_time
			alarm_time+=delta
			m.action_left=maxf(m.action_left,2.0)
			if previous<1.2 and alarm_time>=1.2:
				m.phase="sniff"
				m.elapsed=0.0
				m.facing=1 if pieces.alarm_clock.art_point(Vector2(.5,.5)).x>=m.feet.x else -1
				m.say("작은 시계였네")
			if alarm_time>=3.0:
				m.react("happy",1.0,"interaction_done")
				m.say("이제 조용해졌어")
				alarm_time=-1.0
	for id in pieces:
		pieces[id].set_active(HOME_IDS.get(m.visit_id,"")==id and m.phase not in ["visit","drop","dizzy","idle"] and not m.held and not m.carried)
		if id in ["sofa","daybed","bathtub"] and HOME_IDS.get(m.visit_id,"")==id:
			var seat: float={"sofa":.76,"daybed":.64,"bathtub":.70}[id]
			m.soft_scene_lift=(Catalog.ground_contact(pieces[id].sprite.texture)-seat)*pieces[id].sprite.texture.get_height()*pieces[id].sprite.scale.y
		if id=="bathtub" and m.visit_id=="home_bathtub":
			m.soft_scene_origin=Vector2(pieces[id].position)+pieces[id].art_origin
			m.soft_scene_scale=pieces[id].sprite.scale
			m.soft_scene_mirrored=pieces[id].mirrored
			m.soft_scene_style=pieces[id].appearance
		if pieces[id].dragging and HOME_IDS.get(m.visit_id,"")==id: m.cancel_play()
	if pieces.has("table"):
		var amount=1.0
		if m.visit_id=="home_food" and m.phase=="eat": amount=1.0-smoothstep(.7,3.5,m.elapsed)
		pieces.table.set_food(preload("res://scripts/food_catalog.gd").icon_for(m.species,m.food_id),amount)
	# Furniture is part of normal autonomous life, with a quiet pause between visits.
	if m.held or m.resting or not m.autonomy or app.decorating or app.objects_are_dragging() or app.pet.menu.visible: return
	home_delay=maxf(0,home_delay-delta)
	if home_delay>0 or m.phase!="idle" or not app.falling_gifts.is_empty() or arrivals.busy() or toy_play.busy(): return
	var choices=destinations().filter(func(d): return d.id!=last_home)
	if choices.is_empty(): return
	var choice=choices[m.rng.randi_range(0,choices.size()-1)]
	for d in choices:
		if (m.hydration<55 and d.id=="home_water") or (m.satiety<55 and d.id=="home_food") or (m.energy<35 and d.id=="home_sofa"): choice=d
	m.visit(choice.point,choice.action,choice.id,true)
	home_delay=18
	last_home=choice.id
func refresh_buttons() -> void:
	if is_instance_valid(acorn_button): acorn_button.text="치우기" if app.props.has("acorn") and app.props.acorn.visible else "꺼내기"
	if is_instance_valid(space_picker): space_picker.select(0 if app.state.activity_space=="floor" else 1)
	for id in buttons:
		var available=app.state.furniture_available(id)
		buttons[id].disabled=not available
		buttons[id].text="치우기" if pieces.has(id) else ("배치" if available else "잠김")
		buttons[id].tooltip_text=app.state.route_hint(app.state.selected,"home_"+id) if not available else ""
	for id in previews:
		var appearance=Catalog.normalize_style(app.state.furniture_styles.get(id,{}))
		previews[id].texture=Catalog.texture(id,appearance.design)
		Catalog.apply_style(previews[id].material,appearance,id)
		status_labels[id].text="기본 제공" if app.state.UNLOCKS["home_"+id]==0 else ("해금 완료" if app.state.furniture_available(id) else app.state.route_hint(app.state.selected,"home_"+id))
func open(kind: String="home") -> void:
	if not is_instance_valid(panel): build_panel()
	var toys=kind=="toys"
	panel.set_deferred("size",Vector2i(470,440 if toys else 560))
	panel_column.set_deferred("size",Vector2(426,400 if toys else 520))
	panel_scroll.custom_minimum_size.y=160 if toys else 320
	panel_icon.texture=preload("res://scripts/ui_icons.gd").texture("together" if toys else "home")
	panel_done.text="닫기" if toys else "배치 마치기"
	panel.title="함께하기 · 놀이감" if toys else "집 꾸미기 · 가구 배치"
	panel_heading.text="함께 놀아요" if toys else "나의 작은 공간"
	panel_hint.text="꺼낸 놀이감을 클릭하거나 동물을 데려다 놓아 주세요.\n드래그로 옮기거나 던지면 함께 따라가며 놀아요." if toys else "배치 후 드래그로 이동 · 우클릭으로 좌우 반전\n가구를 클릭하거나 동물을 놓으면 함께 이용해요."
	space_picker.visible=not toys
	for id in item_rows: item_rows[id].visible=(id in TOY_IDS)==toys
	refresh_buttons()
	var rect=app.usable_screen()
	panel.position=rect.position+(rect.size-panel.size)/2
	panel.show()
	call_deferred("reveal_panel")
	if DisplayServer.get_name()!="headless": DisplayServer.window_move_to_foreground(panel.get_window_id())
func reveal_panel() -> void:
	if not is_instance_valid(panel) or not panel.visible: return
	# A hidden launcher can suppress the first native ShowWindow invocation.
	panel.hide()
	panel.show()
	if DisplayServer.get_name()!="headless": DisplayServer.window_move_to_foreground(panel.get_window_id())
func build_panel() -> void:
	panel=Window.new()
	panel.visible=false
	panel.force_native=true
	panel.transient=false
	panel.exclusive=false
	panel.unfocusable=false
	panel.mouse_passthrough=false
	panel.title="집 꾸미기 · 가구 배치"
	panel.size=Vector2i(470,560)
	panel.unresizable=true
	panel.always_on_top=true
	panel.theme=app.app_theme
	panel.close_requested.connect(func(): panel.hide())
	add_child(panel)
	var background=ColorRect.new()
	background.color=Color("faf8f3")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(background)
	var column=VBoxContainer.new()
	panel_column=column
	column.position=Vector2(22,18)
	column.size=Vector2(426,520)
	column.add_theme_constant_override("separation",10)
	panel.add_child(column)
	var heading=Label.new()
	panel_heading=heading
	heading.text="나의 작은 공간"
	preload("res://scripts/cozy_ui.gd").label(heading,"title")
	heading.add_theme_color_override("font_color",Color("59564f"))
	column.add_child(heading)
	var home_icon=TextureRect.new()
	panel_icon=home_icon
	home_icon.texture=preload("res://scripts/ui_icons.gd").texture("home")
	home_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	home_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	home_icon.position=Vector2(354,0)
	home_icon.size=Vector2(56,56)
	background.add_child(home_icon)
	var hint=Label.new()
	panel_hint=hint
	hint.text="배치 후 드래그로 이동 · 우클릭으로 좌우 반전\n가구를 클릭하거나 동물을 놓으면 함께 이용해요."
	preload("res://scripts/cozy_ui.gd").label(hint,"caption")
	hint.add_theme_color_override("font_color",Color("777167"))
	column.add_child(hint)
	space_picker=OptionButton.new()
	space_picker.add_item("활동 공간: 아래쪽 바닥 (기본)")
	space_picker.add_item("활동 공간: 화면 전체")
	style_button(space_picker)
	space_picker.selected=0 if app.state.activity_space=="floor" else 1
	space_picker.item_selected.connect(func(index): app.set_activity_space("floor" if index==0 else "desktop"))
	column.add_child(space_picker)
	var scroll=ScrollContainer.new()
	panel_scroll=scroll
	scroll.custom_minimum_size=Vector2(426,320)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var rows=VBoxContainer.new()
	rows.add_theme_constant_override("separation",10)
	rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var acorn_row=HBoxContainer.new()
	acorn_row.add_theme_constant_override("separation",12)
	rows.add_child(acorn_row)
	item_rows.acorn=acorn_row
	var acorn_icon=TextureRect.new()
	acorn_icon.texture=preload("res://scripts/decor_art.gd").icon("acorn")
	acorn_icon.custom_minimum_size=Vector2(64,68)
	acorn_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	acorn_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	acorn_row.add_child(acorn_icon)
	var acorn_text=Label.new()
	acorn_text.text="도토리 오뚝이\n기본 제공 · 클릭하면 흔들흔들"
	acorn_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	acorn_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	preload("res://scripts/cozy_ui.gd").label(acorn_text)
	acorn_row.add_child(acorn_text)
	acorn_button=Button.new()
	acorn_button.custom_minimum_size=Vector2(96,40)
	acorn_button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	style_button(acorn_button)
	acorn_button.pressed.connect(func(): app.set_acorn_visible(not app.props.acorn.visible))
	acorn_row.add_child(acorn_button)
	var ordered=Catalog.ITEMS.keys()
	ordered.sort_custom(func(a,b):
		var ta=app.state.UNLOCKS["home_"+a]
		var tb=app.state.UNLOCKS["home_"+b]
		return ta<tb if ta!=tb else Catalog.ITEMS.keys().find(a)<Catalog.ITEMS.keys().find(b))
	for id in ordered:
		var item=VBoxContainer.new()
		rows.add_child(item)
		item_rows[id]=item
		var row=HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		item.add_child(row)
		var preview=TextureRect.new()
		var appearance=Catalog.normalize_style(app.state.furniture_styles.get(id,{}))
		preview.texture=Catalog.texture(id,appearance.design)
		preview.material=Catalog.material()
		Catalog.apply_style(preview.material,appearance,id)
		preview.custom_minimum_size=Vector2(64,68)
		preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(preview)
		previews[id]=preview
		var text_column=VBoxContainer.new()
		text_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		text_column.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		text_column.add_theme_constant_override("separation",4)
		row.add_child(text_column)
		var label=Label.new()
		label.text=Catalog.ITEMS[id].name
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		preload("res://scripts/cozy_ui.gd").label(label)
		text_column.add_child(label)
		var status=Label.new()
		preload("res://scripts/cozy_ui.gd").label(status,"caption")
		status.add_theme_color_override("font_color",Color("777167"))
		text_column.add_child(status)
		status_labels[id]=status
		var button=Button.new()
		button.custom_minimum_size=Vector2(96,40)
		button.name="Place_"+id
		button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		style_button(button)
		button.pressed.connect(func():
			if pieces.has(id): remove_piece(id)
			else: place(id))
		row.add_child(button)
		buttons[id]=button
	var done=Button.new()
	panel_done=done
	done.text="배치 마치기"
	style_button(done)
	done.pressed.connect(func(): save(); panel.hide())
	column.add_child(done)
func style_button(button: Button) -> void:
	# All states, padding and typography come from the shared game theme.
	preload("res://scripts/cozy_ui.gd").button(button)
	button.custom_minimum_size.y=maxf(button.custom_minimum_size.y,40)
