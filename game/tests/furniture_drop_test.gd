extends SceneTree
const Main=preload("res://scripts/main.gd")
const Room=preload("res://scripts/furniture_room.gd")
const Piece=preload("res://scripts/furniture_window.gd")
const Pet=preload("res://scripts/desktop_pet.gd")
class TestState extends "res://scripts/pet_state.gd":
	func save_game() -> void: pass
var failures=[]
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label)
func _initialize() -> void:
	if not preload("res://tests/pack_fixture.gd").mount(): quit(1);return
	call_deferred("run")
func run() -> void:
	var app=Main.new()
	app.state=TestState.new()
	var room=Room.new()
	room.app=app
	app.furniture_room=room
	var picture=Image.create(100,80,false,Image.FORMAT_RGBA8)
	picture.fill(Color.WHITE)
	var texture=ImageTexture.create_from_image(picture)
	for id in room.Catalog.ITEMS:
		var piece=Piece.new()
		piece.item_id=id
		piece.sprite=Sprite2D.new()
		piece.sprite.texture=texture
		piece.sprite.position=Vector2(6,6)
		piece.add_child(piece.sprite)
		piece.menu=PopupMenu.new()
		piece.menu.visible=false
		piece.add_child(piece.menu)
		piece.position=Vector2i(600,500)
		piece.size=Vector2i(112,92)
		room.pieces[id]=piece
	var count=0
	for species in range(16):
		var pet=Pet.new()
		app.pet=pet
		pet.menu=PopupMenu.new()
		pet.menu.visible=false
		pet.add_child(pet.menu)
		pet.dropped_on_desktop.connect(app.on_pet_dropped)
		var m=pet.motion
		m.species=species
		m.autonomy=false
		m.configure(Rect2(0,0,1920,1080),Vector2(650,560))
		for stage in [0,2]:
			m.growth_stage=stage
			m.growth_scale=.93 if stage==0 else 1
			for id in room.pieces:
				for other in room.pieces: room.pieces[other].visible=other==id
				for hold_seconds in [.3,4.0]:
					m.cancel_play()
					m.feet=Vector2(650,565)
					m.held=true
					m.pointer_grab=true
					m.carried=true
					m.carry_elapsed=hold_seconds
					pet.dragging=true
					pet.press_feet=m.feet
					pet.press_screen=m.feet-Vector2(0,45)
					check(room.preview_drop(m.feet,pet.pointer_desktop_position())==id,"wrong highlight "+id)
					check(room.pieces[id].drop_hover,"missing highlight "+id)
					var before=m.feet
					pet.release_pointer()
					var key="home_tea" if id=="table" else "home_"+id
					check(pet.furniture_drop_accepted and m.phase in ["visit","drop"] and m.visit_id==key,"drop not routed %s/%s/%s"%[species,stage,id])
					check(m.feet==before,"release teleported "+id)
					check(not room.pieces[id].drop_hover,"stale highlight "+id)
					for tick in range(1200):
						if m.phase not in ["visit","drop"]: break
						m.advance(1.0/60)
					check(m.phase==m.visit_action,"never reached furniture "+id)
					count+=1
		# A drop accepted by furniture must fall vertically, then walk on ground.
		for other in room.pieces: room.pieces[other].visible=other=="sofa"
		m.floor_space=true;m.bounds=Rect2(100,580,1500,1)
		m.cancel_play();m.feet=Vector2(650,470);m.held=true;m.carried=true;m.pointer_grab=true
		pet.dragging=true;pet.press_feet=m.feet;pet.press_screen=Vector2(650,530)
		pet.release_pointer()
		check(m.phase=="drop" and pet.furniture_drop_accepted,"elevated furniture release did not fall")
		var release_x=m.feet.x
		for tick in range(120):
			if m.phase!="drop": break
			m.advance(1.0/60)
			check(is_equal_approx(m.feet.x,release_x),"walked sideways in air")
		check(m.phase=="visit" and m.bounds.has_point(m.feet),"furniture landing did not restore floor")
		m.floor_space=false;m.configure(Rect2(0,0,1920,1080),Vector2(650,560))
		# A long release on empty desktop must still use the existing fall.
		m.move_to(Vector2(1100,400))
		m.held=true
		m.carried=true
		m.pointer_grab=true
		m.carry_elapsed=4
		pet.dragging=true
		pet.press_feet=m.feet
		pet.press_screen=m.feet-Vector2(0,45)
		pet.release_pointer()
		check(m.phase=="drop" and not pet.furniture_drop_accepted,"empty floor did not fall")
		if species==0:
			for other in room.pieces: room.pieces[other].visible=other=="window_seat"
			var p=room.pieces.window_seat
			check(room.drop_candidate(Vector2(650,650),Vector2(650,550))=="window_seat","head grab not accepted")
			p.dragging=true
			check(room.drop_candidate(Vector2(650,550)).is_empty(),"moving furniture accepted")
			p.dragging=false
			p.hide()
			check(room.drop_candidate(Vector2(650,550)).is_empty(),"hidden furniture accepted")
			p.show()
			app.decorating=true
			check(room.drop_candidate(Vector2(650,550)).is_empty(),"decorating accepted")
			app.decorating=false
		pet.free()
	for p in room.pieces.values(): p.free()
	room.free()
	app.free()
	print("FURNITURE_DROP cases=",count," failures=",failures)
	quit(0 if failures.is_empty() else 1)
