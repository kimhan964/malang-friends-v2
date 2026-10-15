extends SceneTree
const Space=preload("res://scripts/living_space.gd")
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const Pet=preload("res://scripts/desktop_pet.gd")
const Main=preload("res://scripts/main.gd")
const Room=preload("res://scripts/furniture_room.gd")
const Piece=preload("res://scripts/furniture_window.gd")
class TestState extends "res://scripts/pet_state.gd":
	func save_game() -> void: pass
var failures=[]
func check(ok: bool,label: String) -> void:
	if not ok and label not in failures: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(Space.clean(null)=="floor" and Space.clean("invalid")=="floor","default/migration")
	for screen in [Rect2(0,0,1920,1040),Rect2(-1920,120,1920,1080),Rect2(0,0,1280,720)]:
		for species in range(16):
			for stage in [0,2]:
				var m=Motion.new()
				m.configure(screen,screen.get_center())
				m.species=species
				m.growth_stage=stage
				m.floor_space=true
				m.bounds=Space.bounds(screen,"floor")
				m.move_to(screen.get_center())
				m.smooth_walk_enabled=true
				m.rabbit_pilot=species==0 and stage==2
				m.rng.seed=7+species
				for direction in [-1,1]:
					m.visit(m.feet+Vector2(direction*200,-300),"relax")
					for tick in range(900):
						m.advance(1.0/60)
						check(absf(m.feet.y-Space.ground(screen))<=.51,"lane escaped %d/%d"%[species,stage])
				m.cancel_play()
				m.feet=screen.get_center()
				m.begin_drop(false)
				for tick in range(120): m.advance(1.0/60)
				check(absf(m.feet.y-Space.ground(screen))<=.51 and m.phase!="dizzy","short drop landing")
				m.feet=screen.get_center()
				m.begin_drop(true)
				for tick in range(90): m.advance(1.0/60)
				check(m.phase=="dizzy","long drop keeps recovery")
	var app=Main.new()
	app.state=TestState.new()
	app.state.activity_space="desktop"
	var pet=Pet.new()
	pet.state=app.state
	app.pet=pet
	pet.motion.configure(Rect2(app.usable_screen()),Vector2(600,450))
	var room=Room.new()
	app.furniture_room=room
	room.app=app
	var p=Piece.new()
	p.size=Vector2i(112,92)
	p.sprite=Sprite2D.new()
	var img=Image.create(100,80,false,Image.FORMAT_RGBA8)
	p.sprite.texture=ImageTexture.create_from_image(img)
	p.add_child(p.sprite)
	p.position=Vector2i(600,420)
	room.pieces.sofa=p
	room.save()
	app.set_activity_space("floor")
	check(absf(p.art_point(Vector2(.5,.94)).y-Space.ground(Rect2(app.usable_screen())))<1,"furniture ground")
	check(app.state.furniture.sofa==[600,420],"original layout lost")
	app.set_activity_space("desktop")
	check(p.position==Vector2i(600,420),"layout restore")
	check(pet.motion.bounds.size.y>100 and not pet.motion.floor_space,"full desktop not restored")
	pet.motion.visit(Vector2(600,300),"relax")
	check(pet.motion.target.y==300,"full desktop vertical travel")
	p.free()
	room.free()
	pet.free()
	app.free()
	# Verify the real save format, without touching the user's save.
	var state=preload("res://scripts/pet_state.gd").new()
	state.save_path="user://living-space-test.json"
	state.activity_space="desktop"
	state.save_game()
	var restored=preload("res://scripts/pet_state.gd").new()
	restored.save_path=state.save_path
	restored.load_game()
	check(restored.activity_space=="desktop","persist setting")
	DirAccess.remove_absolute(state.save_path)
	print("LIVING_SPACE species=16 ages=2 monitors=3 failures=",failures)
	quit(0 if failures.is_empty() else 1)
