extends SceneTree
const Main=preload("res://scripts/main.gd")
const Room=preload("res://scripts/furniture_room.gd")
const Pet=preload("res://scripts/desktop_pet.gd")
const State=preload("res://scripts/pet_state.gd")
class MemoryState extends State:
	func save_game() -> void: pass
var failures=[]
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app=Main.new()
	app.state=MemoryState.new()
	app.state.play_affection={"0":70}
	var pet=Pet.new()
	app.pet=pet
	pet.motion.configure(Rect2(app.usable_screen()),Vector2(500,650))
	pet.motion.autonomy=false
	var room=Room.new()
	room.app=app
	app.furniture_room=room
	root.add_child(room)
	room.set_process(false)
	for id in Room.Catalog.ITEMS:
		room.place(id,Vector2(600,450),false)
		var p=room.pieces[id]
		var original=p.position
		p.nudge(24)
		check(p.position==original+Vector2i(24,0),"right nudge "+id)
		p.nudge(-24)
		check(p.position==original,"left nudge "+id)
		p.press_position=Vector2(p.position)
		p.press_cursor=Vector2(650,500)
		p.move_dragged_to(Vector2(690,200))
		check(p.position.y==original.y and p.position.x==original.x+40,"floor drag "+id)
		var contact=p.art_point(Vector2(.2,.4))
		var dimensions=p.sprite.texture.get_size()*p.sprite.scale
		p.set_mirrored(true,true)
		var reflected=p.art_point(Vector2(.2,.4))
		check(is_equal_approx(reflected.x-contact.x,dimensions.x*.6),"mirrored contact "+id)
		check(p.sprite.flip_h and p.hit_polygon.size()>=3,"sprite/input mirror "+id)
		check(app.state.furniture[id].size()==3 and app.state.furniture[id][2]==true,"mirror save "+id)
		var key="home_tea" if id=="table" else "home_"+id
		check(room.use_piece(id),"use reflected furniture "+id)
		pet.motion.feet=room.destination_point(key)
		room.on_visit(key)
		check(pet.motion.facing==-1,"pet facing "+id)
		p.set_mirrored(false,true)
		check(app.state.furniture[id].size()==2,"unmirror save "+id)
		p.floor_locked=false
		p.press_position=Vector2(p.position)
		p.move_dragged_to(Vector2(690,400))
		check(p.position.y!=original.y,"full-space drag locked "+id)
	room.pieces.tv.position.x=24
	var tv_point=room.destination_point("home_tv")
	check(tv_point.x>room.pieces.tv.art_point(Vector2(.5,.94)).x,"edge TV approach")
	var state=State.new()
	state.load_furniture({"sofa":[100,200],"tv":[400,500,true],"turntable":[700,500,false]})
	check(state.furniture.sofa.size()==2 and state.furniture.sofa[0]==100 and state.furniture.tv.size()==3 and state.furniture.tv[2]==true and state.furniture.turntable.size()==2,"legacy save migration")
	state.save_path="user://furniture-mirror-test.json"
	state.save_game()
	var restored=State.new()
	restored.save_path=state.save_path
	restored.load_game()
	check(restored.furniture==state.furniture,"persist orientation")
	DirAccess.remove_absolute(state.save_path)
	room.free()
	pet.free()
	app.free()
	print("FURNITURE_PLACEMENT items=12 failures=",failures)
	quit(0 if failures.is_empty() else 1)
