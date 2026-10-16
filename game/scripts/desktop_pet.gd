extends Window

signal returned
signal companion_selected(species: int)
signal activity_requested(id: int)
signal dropped_on_desktop(point: Vector2)
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const View=preload("res://scripts/desktop_pet_view.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
const Food=preload("res://scripts/food_catalog.gd")
const Profiles=preload("res://scripts/companion_profiles.gd")
const Outfits=preload("res://scripts/outfit_catalog.gd")
const Outline=preload("res://scripts/animation_outline.gd")
const NativeMouse=preload("res://scripts/native_mouse.gd")
var species=0
var commerce_mode=false
var available_species=PackedStringArray()
var state
var motion=Motion.new()
var view
var ball_window: Window
var ball_view
var menu
var press_screen=Vector2.ZERO
var press_feet=Vector2.ZERO
var dragging=false
var furniture_drop_accepted=false
var carry_surface=false
var gesture=preload("res://scripts/pointer_gesture.gd").new()
var hover_cooldown=0.0
var hover_age=0.0
var was_hovered=false
var monitor_timer=0.0
var mask_key=""
var masks: Dictionary={}
var decorating=false
var feeding=false
var ball_dragging=false
var ball_grab_offset=Vector2.ZERO
var ball_samples: Array=[]
var hint="클릭: 쓰다듬기 · 드래그: 이동"

func _init() -> void:
	visible=false
	force_native=true
	borderless=true
	transparent=true
	transparent_bg=true
	always_on_top=true
	unfocusable=true
	unresizable=true
	transient=false
	exclusive=false
	gui_embed_subwindows=false
	size=Vector2i(View.WINDOW_SIZE)
	name="DesktopPet"

func _ready() -> void:
	title=Catalog.NAMES[species]+" · 말랑친구 v2"
	motion.species=species
	motion.growth_scale=state.growth_scale(species) if state else 1.0
	motion.growth_stage=state.growth_stage(species) if state else 2
	motion.outfit_style=int(state.outfits.get(str(species),0)) if state else 0
	motion.outfit_color=int(state.outfit_colors.get(str(species),0)) if state else 0
	var screen=desktop_bounds()
	motion.configure(screen,screen.position+Vector2(screen.size.x*.5,screen.size.y*.78))
	motion.floor_space=state!=null and state.activity_space=="floor"
	motion.bounds=activity_bounds(screen)
	motion.move_to(motion.feet)
	if stable_surface():
		# Allocate once, before showing. Recentring a small native window while
		# walking exposes compositor resize/move frames even with a stable sprite.
		var surface=pointer_surface_rect()
		size=surface.size
		position=surface.position
	view=View.new()
	view.motion=motion
	if stable_surface(): view.position=motion.feet-View.FEET-Vector2(position)
	add_child(view)
	ball_window=Window.new()
	ball_window.visible=false
	ball_window.force_native=true
	ball_window.borderless=true
	ball_window.transparent=true
	ball_window.transparent_bg=true
	ball_window.always_on_top=true
	ball_window.unfocusable=true
	ball_window.unresizable=true
	ball_window.mouse_passthrough=false
	ball_window.size=Vector2i(32,32)
	ball_window.title="바탕화면 친구 · 공"
	add_child(ball_window)
	ball_window.window_input.connect(handle_ball_input)
	ball_view=View.new()
	ball_view.ball_only=true
	ball_window.add_child(ball_view)
	menu=preload("res://scripts/friend_menu.gd").new()
	menu.force_native=true
	menu.add_item("가구 고르기 · 배치",32)
	menu.add_item("놀이감 꺼내기",38)
	menu.add_item("마우스 따라오기",23)
	menu.add_item("함께 놀기 안내",39)
	menu.add_item("다양한 행동 · 직접 골라보기",40)
	menu.add_check_item("활동 공간 · 화면 전체로 넓히기",33)
	menu.add_item("발견한 취향",9)
	menu.add_item("사용법",10)
	menu.add_item("첫 만남 가이드",25)
	menu.add_item("함께할 목표",26)
	menu.add_item("우리 집 교감과 가구",14)
	menu.add_item("성장 기록 · 새끼 → 중간 → 성체",18)
	var foods=PopupMenu.new()
	foods.name="Foods"
	foods.force_native=true
	for s in range(4):
		var group=PopupMenu.new()
		group.name="Species%d"%s
		group.force_native=true
		for p in range(8):
			var id=p*4+s
			group.add_item(Food.title_for(species,id)+( " ★" if id==Profiles.FAVORITE_FOOD[species] and state.favorite_foods.get(str(species),false) else ""),100+id)
		group.id_pressed.connect(func(id): activity_requested.emit(id))
		foods.add_child(group)
		foods.add_submenu_item(["기본 요리","든든한 한 끼","간식과 차","별미와 음료"][s],group.name)
	menu.add_child(foods)
	menu.add_submenu_item("식탁 메뉴 고르기","Foods",15)
	var outfits=PopupMenu.new()
	outfits.name="Outfits"
	outfits.force_native=true
	for style in range(4):
		outfits.add_radio_check_item(Outfits.style_name(species,style),300+style)
	outfits.id_pressed.connect(menu_action)
	menu.add_child(outfits)
	menu.add_submenu_item("옷 입히기 · "+Outfits.style_name(species,motion.outfit_style),"Outfits",27)
	var outfit_colors=PopupMenu.new()
	outfit_colors.name="OutfitColors"
	outfit_colors.force_native=true
	for color in range(Outfits.COLOR_NAMES.size()):
		outfit_colors.add_radio_check_item(Outfits.color_name(color),320+color)
	outfit_colors.id_pressed.connect(menu_action)
	menu.add_child(outfit_colors)
	menu.add_submenu_item("옷 색상 · "+Outfits.color_name(motion.outfit_color),"OutfitColors",28)
	var friends=PopupMenu.new()
	friends.name="Friends"
	friends.force_native=true
	for i in range(Catalog.NAMES.size()):
		if commerce_mode and not available_species.has(Catalog.IDS[i]): continue
		friends.add_radio_check_item(Catalog.NAMES[i],i)
		friends.set_item_checked(friends.item_count-1,i==species)
	friends.id_pressed.connect(func(id): companion_selected.emit(id))
	menu.add_child(friends)
	menu.add_submenu_item("친구 바꾸기","Friends",17)
	menu.add_separator()
	menu.add_item("종료",3)
	menu.id_pressed.connect(menu_action)
	menu.popup_hide.connect(func(): motion.held=false)
	add_child(menu)
	menu.set_friend_count(friends.item_count)
	refresh_unlock_menu()
	motion.bonded.connect(func():
		if state: state.reward_activity(species,"pet"))
	motion.activity_bonded.connect(func(action):
		if state: state.reward_activity(species,action))
	window_input.connect(handle_input)
	close_requested.connect(close_companion)
	_process(0)
	show()
	if stable_surface():
		# Windows initially places an oversized shown window at (0, 0).
		# Apply the desktop origin before its first presented frame, not at
		# the two-second monitor poll while the pet is already walking.
		position=pointer_surface_rect().position
		view.position=motion.feet-View.FEET-Vector2(position)
		view.refresh(0)
		update_mouse_region()

	call_deferred("reveal_native_surface")

func reveal_native_surface() -> void:
	if not visible or DisplayServer.get_name()=="headless": return
	# STARTF_USESHOWWINDOW from a hidden launcher can suppress the first show.
	# Re-show once at startup, without resizing the steady animation canvas.
	hide()
	show()
	if stable_surface():
		position=pointer_surface_rect().position
		view.position=motion.feet-View.FEET-Vector2(position)
	view.refresh(0)
	update_mouse_region()
	NativeMouse.apply(self,NativeMouse.enabled(self),true)

func set_available_species(ids: PackedStringArray) -> void:
	commerce_mode=true
	available_species=ids.duplicate()
	if menu==null: return
	var friends: PopupMenu=menu.get_node("Friends")
	friends.clear()
	for i in range(Catalog.NAMES.size()):
		if not available_species.has(Catalog.IDS[i]): continue
		friends.add_radio_check_item(Catalog.NAMES[i],i)
		friends.set_item_checked(friends.item_count-1,i==species)
	menu.set_friend_count(friends.item_count)
	if menu.visible: menu.rebuild()

func activity_bounds(screen: Rect2) -> Rect2:
	return preload("res://scripts/living_space.gd").bounds(screen,state.activity_space if state else "desktop")

func desktop_bounds() -> Rect2:
	if DisplayServer.get_name()=="headless": return Rect2(0,0,1280,720)
	# The rendering surface spans monitors; gameplay belongs to the pet's monitor.
	var screen=DisplayServer.get_screen_from_rect(Rect2i(Vector2i(motion.feet),Vector2i.ONE)) if visible else DisplayServer.SCREEN_OF_MAIN_WINDOW
	if screen<0: screen=DisplayServer.SCREEN_OF_MAIN_WINDOW
	return Rect2(DisplayServer.screen_get_usable_rect(screen))

func handle_input(event: InputEvent) -> void:
	if feeding: return
	if motion.phase=="prop_use" and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed and view.accepts_prop_grab(event.position-view.position):
			motion.begin_prop_drag(Vector2(position)+event.position)
			return
		elif not event.pressed and motion.prop_dragging:
			motion.release_prop_drag()
			return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			open_menu()
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				# The press event retains the actual grab point even when a rapid
				# press/move/release arrives together after a delayed render frame.
				begin_pointer(Vector2(position)+event.position)
			else:
				if motion.pointer_grab and motion.held: move_pointer(Vector2(DisplayServer.mouse_get_position()),0.0)
				release_pointer()
	# Queued local mouse events describe the OLD native window position.
	# Read desktop coordinates even for motion events. Sampling these as well
	# as each frame preserves quick drags that finish between render frames.
	elif event is InputEventMouseMotion and motion.pointer_grab and motion.held:
		move_pointer(Vector2(DisplayServer.mouse_get_position()),0.0)

func begin_pointer(screen_point: Vector2) -> void:
	if motion.pointer_grab and motion.held: return
	var pressed_cel: Dictionary=view.generated_sample.duplicate()
	# Furniture seating lifts the complete sprite above the motion root.
	# Preserve that actual pose while deciding between a stroke and a lift.
	pressed_cel.anchor=(View.FEET-view.sprite.position)/view.sprite.scale
	pressed_cel.home_animation=false
	pressed_cel.life_animation=false
	var grab_point: Vector2=view.sprite.transform.affine_inverse()*(screen_point-Vector2(position)-view.position)
	motion.cancel_play()
	motion.soft_touch_sample=pressed_cel
	motion.soft_grab_point=grab_point
	motion.held=true
	motion.pointer_grab=true
	dragging=false
	gesture.reset()
	if view: view.dizzy_effects.burst("sparkle",(screen_point-Vector2(position)-view.position).clamp(Vector2(12,12),Vector2(244,210)),4)
	press_screen=screen_point
	press_feet=motion.feet

func move_pointer(screen_point: Vector2, delta: float=1.0/60.0) -> void:
	var displacement=screen_point-press_screen
	var kind=gesture.sample(displacement,delta)
	if kind=="stroke" and gesture.stroke_distance>=14 and view:
		gesture.stroke_distance=0
		view.dizzy_effects.burst("heart",(screen_point-Vector2(position)-view.position).clamp(Vector2(16,20),Vector2(240,200)),2)
		motion.joy_left=.8
	if (kind=="drag" or gesture.age>=motion.STRUGGLE_HOLD_SECONDS) and not dragging:
		dragging=true
		motion.carried=true
		motion.carry_started_at=motion.carry_elapsed
		# The pet stayed still while distinguishing a rub from a lift. Do not
		# apply that entire dead zone as a one-frame teleport when lifting starts.
		# Remove only the recognition threshold, not the entire first motion;
		# otherwise a quick drag completed in one input batch loses its travel.
		press_screen+=gesture.drag_offset if kind=="drag" else displacement
		var carry_height: float=float(preload("res://scripts/v2_interaction_art.gd").data(motion.species).reference_height)
		var carry_factor: float=Catalog.DISPLAY_HEIGHT*Catalog.HEIGHTS[motion.species]*motion.growth_scale/carry_height
		var grip_offset: Vector2=(motion.soft_grab_point-Vector2(128,232))*Vector2(carry_factor*motion.facing,carry_factor)
		press_feet=press_screen-grip_offset
		displacement=screen_point-press_screen
	if dragging:
		# Allow a dragged pet to move to another monitor, then keep it visible there.
		if DisplayServer.get_name()!="headless":
			var screen=DisplayServer.get_screen_from_rect(Rect2i(Vector2i(screen_point),Vector2i.ONE))
			if screen>=0:
				var rect=Rect2(DisplayServer.screen_get_usable_rect(screen))
				motion.bounds=activity_bounds(rect)
		# Walking bounds must not change the grabbed offset at screen edges or
		# on a monitor crossing. The cursor owns translation until release.
		motion.feet=press_feet+displacement
		motion.target=motion.feet

func pointer_surface_rect() -> Rect2i:
	var rect=Rect2i(0,0,1280,720)
	if DisplayServer.get_name()!="headless":
		for screen in range(DisplayServer.get_screen_count()):
			var next=Rect2i(DisplayServer.screen_get_position(screen),DisplayServer.screen_get_size(screen))
			rect=next if screen==0 else rect.merge(next)
	# One stationary canvas for the whole drag, including monitor crossings.
	# Padding preserves ears/feet when the grabbed point reaches an edge.
	return rect.grow(256)

func stable_surface() -> bool:
	# A stationary transparent surface also protects legacy animals from
	# Windows compositor flicker when crossing desktop pixels.
	return true

func sync_position() -> void:
	if stable_surface():
		carry_surface=(motion.pointer_grab and motion.held) or motion.phase in ["drop","dizzy"]
		# Movement and pickup only update view.position, never the native window.
		return
	var next_position=Vector2i(motion.feet-View.FEET)
	if position!=next_position: position=next_position

func release_pointer() -> void:
	if not motion.held or menu.visible: return
	motion.capture_hold_release()
	if not motion.hold_release.is_empty() and view: motion.hold_release.angle=view.sprite.rotation
	motion.held=false
	motion.pointer_grab=false
	if not dragging:
		motion.pet()
		view.dizzy_effects.burst("heart",view.dizzy_effects.orbit_layout().center+Vector2(0,18),6)
	else:
		var floor_y: float=motion.bounds.get_center().y if motion.floor_space else motion.bounds.end.y
		var release_height: float=maxf(0,floor_y-motion.feet.y)
		var falling=motion.should_drop_on_release() or release_height>45.0
		var release_event="held_long" if motion.carry_elapsed>=motion.STRUGGLE_HOLD_SECONDS else "set_down"
		motion.carried=false
		motion.rest_left=4
		furniture_drop_accepted=false
		dropped_on_desktop.emit(motion.feet)
		if furniture_drop_accepted and motion.feet.y<motion.target.y-2:
			# Land vertically before approaching the furniture; never walk in air.
			motion.begin_drop(false)
		elif not furniture_drop_accepted and (falling or release_height>2): motion.begin_drop(falling)
		else:
			motion.landing_left=0.0
			motion.soft_recover_left=.65
			if view: view.dizzy_effects.burst("sparkle",View.FEET-Vector2(0,12),3)
		if not furniture_drop_accepted: motion.context_reactions.queue(release_event)
	dragging=false

func pointer_desktop_position() -> Vector2:
	# Preserve the exact grab point instead of assuming the cursor is at the feet.
	return motion.feet+press_screen-press_feet

func open_menu() -> void:
	refresh_unlock_menu()
	motion.cancel_play()
	motion.held=true
	dragging=false
	menu.set_item_checked(menu.get_item_index(2),motion.resting)
	menu.set_item_checked(menu.get_item_index(5),decorating)
	menu.set_item_checked(menu.get_item_index(33),state.activity_space=="desktop")
	var foods=menu.get_node("Foods")
	for s in range(4):
		var group=foods.get_node("Species%d"%s)
		for p in range(8):
			var id=p*4+s
			group.set_item_text(p,Food.title_for(species,id)+( " ★" if id==Profiles.FAVORITE_FOOD[species] and state.favorite_foods.get(str(species),false) else ""))
	menu.set_item_text(menu.get_item_index(0),"쓰다듬기 · 교감 %d"%int(state.play_affection.get(str(species),0)))
	menu.set_item_text(menu.get_item_index(18),"성장 기록 · %s · 경험치 %d"%[state.GROWTH_NAMES[state.growth_stage(species)],int(state.growth.get(str(species),0))])
	menu.position=position+Vector2i(view.position)+Vector2i(0,32)
	menu.popup()

func menu_action(id: int) -> void:
	motion.held=false
	if id>=300 and id<304:
		motion.outfit_style=id-300
		state.outfits[str(species)]=motion.outfit_style
		state.save_game()
		refresh_unlock_menu()
		view.prewarm_current_art()
		view.refresh()
		return
	if id>=320 and id<320+Outfits.COLOR_NAMES.size():
		motion.outfit_color=id-320
		state.outfit_colors[str(species)]=motion.outfit_color
		state.save_game()
		refresh_unlock_menu()
		view.prewarm_current_art()
		view.refresh()
		return
	if not state.can_action(species,id): return
	match id:
		0: motion.pet()
		1:
			activity_requested.emit(1)
		2:
			motion.resting=not motion.resting
			motion.cancel_play()
		3: close_companion()
		_: activity_requested.emit(id)

func close_companion() -> void:
	returned.emit()
	hide()
	queue_free()

func handle_ball_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or motion.phase!="ball_ready": return
	if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		ball_dragging=false
		motion.held=false
		motion.cancel_play()
	elif event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		ball_dragging=true
		motion.held=true
		ball_grab_offset=motion.ball_position-Vector2(DisplayServer.mouse_get_position())
		ball_samples=[{"point":motion.ball_position,"time":Time.get_ticks_msec()/1000.0}]

func update_ball_drag() -> void:
	var point=Vector2(DisplayServer.mouse_get_position())+ball_grab_offset
	var now=Time.get_ticks_msec()/1000.0
	motion.ball_position=point.clamp(motion.bounds.position,motion.bounds.end)
	ball_samples.append({"point":motion.ball_position,"time":now})
	while ball_samples.size()>2 and now-ball_samples[0].time>.12:
		ball_samples.pop_front()
	if not (DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_LEFT):
		var first: Dictionary=ball_samples[0]
		var velocity=(motion.ball_position-first.point)/maxf(.016,now-first.time)
		ball_dragging=false
		motion.release_ball(motion.ball_position,velocity)
		ball_samples.clear()

func refresh_unlock_menu() -> void:
	if menu==null: return
	for id in [36,37]: menu.set_item_disabled(menu.get_item_index(id),not preload("res://scripts/slapstick.gd").available(motion))
	var outfit_menu=menu.get_node("Outfits")
	for style in range(4): outfit_menu.set_item_checked(outfit_menu.get_item_index(300+style),style==motion.outfit_style)
	var color_menu=menu.get_node("OutfitColors")
	for color in range(Outfits.COLOR_NAMES.size()): color_menu.set_item_checked(color_menu.get_item_index(320+color),color==motion.outfit_color)
	menu.set_item_text(menu.get_item_index(27),"옷 입히기 · "+Outfits.style_name(species,motion.outfit_style))
	menu.set_item_text(menu.get_item_index(28),"옷 색상 · "+Outfits.color_name(motion.outfit_color))
	menu.set_item_text(menu.get_item_index(14),state.next_gift(species))

func _process(delta: float) -> void:
	if view==null: return
	if motion.prop_dragging and DisplayServer.get_name()!="headless":
		if DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_LEFT:
			motion.drag_prop(Vector2(DisplayServer.mouse_get_position()))
		else: motion.release_prop_drag()
	if ball_dragging:
		if not motion.ball_visible:
			ball_dragging=false
			motion.held=false
		else:
			update_ball_drag()
	# NO_FOCUS preserves the user's typing focus; poll only while dragging so a
	# release outside the shaped window cannot leave the pet stuck to the cursor.
	if motion.held and not ball_dragging and not feeding and not menu.visible and DisplayServer.get_name()!="headless":
		if DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_LEFT:
			move_pointer(Vector2(DisplayServer.mouse_get_position()),delta)
		else: release_pointer()
	advance_frame(delta)

func advance_frame(delta: float) -> void:
	# Shared with native replay reviews: the same motion, rendering, fitting
	# and hit-region update runs whether input came from Windows or a replay.
	monitor_timer+=delta
	if monitor_timer>=2 and not motion.held and not carry_surface:
		monitor_timer=0
		var surface=pointer_surface_rect()
		# Reallocate only for an actual monitor layout change.
		if size!=surface.size: size=surface.size
		if position!=surface.position: position=surface.position
		var screen=desktop_bounds()
		var new_bounds=activity_bounds(screen)
		if new_bounds!=motion.bounds:
			motion.bounds=new_bounds
			motion.move_to(motion.feet)
	motion.advance(delta)
	if stable_surface(): sync_position()
	var window_origin=motion.feet-View.FEET
	view.position=window_origin-Vector2(position) if stable_surface() else Vector2.ZERO
	view.window_subpixel=Vector2.ZERO if stable_surface() else window_origin-Vector2(Vector2i(window_origin))
	view.refresh(delta)
	# Reserve canvas space instead of shrinking the animal to fit each pose.
	update_mouse_region()
	update_hover(delta)
	if motion.ball_visible:
		ball_window.position=Vector2i(motion.ball_position-Vector2(16,16+motion.ball_height))
		ball_window.mouse_passthrough=motion.phase!="ball_ready"
		if not ball_window.visible: ball_window.show()
		NativeMouse.apply(ball_window,ball_window.mouse_passthrough)
		ball_view.queue_redraw()
	elif ball_window.visible: ball_window.hide()

func update_hover(delta: float) -> void:
	if DisplayServer.get_name()=="headless": return
	hover_cooldown=maxf(0,hover_cooldown-delta)
	var hovered=not NativeMouse.enabled(self) and not motion.held and not menu.visible
	hover_age=hover_age+delta if hovered else 0.0
	if hovered and not was_hovered and hover_cooldown<=0 and motion.phase in ["idle","look"]:
		view.dizzy_effects.hover_left=1.2
		motion.context_reactions.queue("hello")
		hover_cooldown=5.0
	if hovered and hover_age>.35 and motion.phase in ["idle","look"]:
		var dx=float(DisplayServer.mouse_get_position().x)-motion.feet.x
		if absf(dx)>22: motion.facing=signf(dx)
	was_hovered=hovered

func update_mouse_region() -> void:
	# Never change the Win32 drawing region during animation. SetWindowRgn
	# invalidates the moving OpenGL surface and can expose a white erase frame.
	# Keep alpha rendering intact and independently decide whether to accept input.
	if DisplayServer.get_name()=="headless": return
	var accept_input=motion.held or motion.prop_dragging or dragging
	if not accept_input:
		var cursor=Vector2(DisplayServer.mouse_get_position())-Vector2(position)
		var points=Outline.blended_points(view.sprite)
		if points.size()>=3:
			accept_input=Geometry2D.is_point_in_polygon(cursor,Geometry2D.convex_hull(points))
	# A small exit margin avoids repeated native style changes when a moving
	# paw/ear edge passes under a stationary cursor.
		if not accept_input and not NativeMouse.enabled(self):
			accept_input=view.visible_pet_bounds().grow(6).has_point(cursor-view.position)
	var pass_through=not accept_input
	NativeMouse.apply(self,pass_through)
