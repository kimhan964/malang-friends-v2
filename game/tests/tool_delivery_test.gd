extends SceneTree
const Main=preload("res://scripts/main.gd")
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const Prop=preload("res://scripts/desktop_prop.gd")
class TestState extends "res://scripts/pet_state.gd":
	func save_game() -> void: pass
	func test_unlocks() -> bool: return false
class FakePet extends Node:
	var species=1
	var motion=Motion.new()
	var menu=PopupMenu.new()
var failures=[]
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app=Main.new()
	app.state=TestState.new()
	app.state.selected=1
	app.state.play_affection={"1":70}
	var pet=FakePet.new()
	app.pet=pet
	var m=pet.motion
	m.species=1
	m.configure(Rect2(120,180,1500,750),Vector2(700,650))
	m.rng.seed=24
	m.smooth_walk_enabled=true
	m.growth_stage=2
	m.visited.connect(app.on_visit)
	m.activity_finished.connect(app.on_activity_finished)
	for i in range(3):
		var prop=Prop.new()
		var id=app.SMALL_TOOLS[i]
		prop.kind=id
		prop.prop_id=id
		prop.position=Vector2i(600+i*130,650)
		app.props[id]=prop
	app.queue_welcome_tools()
	app.queue_welcome_tools()
	check(app.delivery_queue.size()==3,"duplicate deliveries")
	check(m.destinations.is_empty(),"queued tool was usable")
	m.held=true
	app.advance_deliveries(20)
	check(app.falling_gifts.is_empty(),"delivered while held")
	m.held=false
	m.energy=20
	app.advance_deliveries(20)
	check(app.falling_gifts.is_empty(),"delivered while exhausted")
	m.energy=65
	var order=[]
	var visits=[]
	m.visited.connect(func(id): visits.append(id))
	var max_step=0.0
	for tick in range(60*100):
		var old=m.feet
		var before=app.delivery_seen.size()
		app.advance_unlock_falls(1.0/60)
		app.try_gift_visit()
		app.advance_deliveries(1.0/60)
		if app.delivery_seen.size()>before: order.append(app.falling_gifts.keys()[0])
		check(app.falling_gifts.size()<=1,"simultaneous falls")
		for d in m.destinations:
			check(not app.falling_gifts.has(d.id) and d.id not in app.delivery_queue,"airborne destination")
		m.advance(1.0/60)
		max_step=maxf(max_step,m.feet.distance_to(old))
	check(order==["acorn","basket","plant"],"wrong order or stalled queue "+str(order))
	check(app.delivery_queue.is_empty() and app.pending_gift_visits.is_empty(),"undelivered tools")
	check("acorn" in visits and "plant" in visits,"no real toy contact "+str(visits))
	check(max_step<4,"teleporting approach")
	app.queue_welcome_tools()
	check(app.delivery_queue.is_empty(),"welcome repeated")
	# Hiding and species change cannot resurrect queued gifts.
	app.delivery_seen.clear()
	app.state.hidden=["basket"]
	app.queue_welcome_tools()
	check("basket" not in app.delivery_queue,"hidden tool queued")
	app.clear_falling_gifts()
	check(app.delivery_queue.is_empty(),"switch left stale queue")
	app.state.play_affection={"1":0}
	app.queue_welcome_tools()
	check(app.delivery_queue==["acorn"],"locked tools leaked")
	# Every animal seeks a visible toy through visit(), never by moving feet.
	for species in range(16):
		var animal=Motion.new()
		animal.species=species
		animal.configure(Rect2(100,100,1200,700),Vector2(500,500))
		animal.tool_interest_left=0
		animal.destinations=[{"id":"acorn","action":"prop_use","point":Vector2(620,500)}]
		check(animal.try_tool_interest(),"no initiative %d"%species)
		check(animal.phase=="visit" and animal.feet==Vector2(500,500),"initiative teleported")
		animal.cancel_play()
		animal.tool_interest_left=0
		animal.satiety=20
		check(not animal.try_tool_interest(),"play ignored hunger")
	for prop in app.props.values(): prop.free()
	pet.menu.free()
	pet.free()
	app.free()
	print("TOOL_DELIVERY order=",order," visits=",visits," max_step=",max_step," failures=",failures.slice(0,12))
	quit(0 if failures.is_empty() else 1)
