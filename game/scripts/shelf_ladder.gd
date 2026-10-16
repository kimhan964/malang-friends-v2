extends RefCounted
const UP=3.2
const TAKE=1.0
const END=7.4
var window: Window
var sprite: Sprite2D
static func active(m) -> bool:
	return m.phase=="home_use" and m.visit_id=="home_wall_shelf" and m.soft_climb_height>0 and m.elapsed<END
static func lift(m) -> float:
	if m.elapsed<UP:return m.soft_climb_height*smoothstep(0,UP,m.elapsed)
	if m.elapsed<UP+TAKE:return m.soft_climb_height
	return m.soft_climb_height*(1-smoothstep(UP+TAKE,END,m.elapsed))
static func sample(m) -> Dictionary:
	var cels=preload("res://scripts/v2_interaction_art.gd").frames(m.species,"carry")
	var index=int(fposmod(m.elapsed/.86,1)*cels.size())
	return {"texture":cels[index],"next_texture":cels[index],"frame_mix":0.0,"action":"climb","bank":"shelf-climb","index":index,"height":float(preload("res://scripts/v2_interaction_art.gd").data(m.species).reference_height),"hand":Vector2(154,172),"mouth":Vector2(156,125),"anchor":Vector2(128,232),"fixed_cels":true,"soft_roster":true,"ladder_animation":true,"climb_lift":lift(m),"has_book":m.elapsed>=UP+TAKE*.45}
func begin(room) -> void:
	var m=room.app.pet.motion;var shelf=room.pieces.wall_shelf
	var top=shelf.art_point(Vector2(.5,.9));var height=clampf(m.feet.y-top.y,72,380)
	m.soft_climb_height=maxf(36,height-preload("res://scripts/animal_catalog.gd").DISPLAY_HEIGHT*preload("res://scripts/animal_catalog.gd").HEIGHTS[m.species]*m.growth_scale*.55)
	if not is_instance_valid(window):
		window=Window.new();window.visible=false;window.force_native=true;window.borderless=true;window.transparent=true;window.transparent_bg=true;window.unfocusable=true;window.always_on_top=true;window.unresizable=true
		window.title="벽 책장 · 작은 사다리";room.add_child(window)
		sprite=Sprite2D.new();sprite.centered=false;sprite.texture=preload("res://scripts/v2_shared_art.gd").texture("library-ladder");window.add_child(sprite)
	var scale=height/sprite.texture.get_height();sprite.scale=Vector2.ONE*scale
	window.size=Vector2i(sprite.texture.get_size()*scale)+Vector2i(4,4);sprite.position=Vector2(2,2)
	window.position=Vector2i(m.feet-Vector2(window.size.x*.5,height))
	window.show();preload("res://scripts/native_mouse.gd").apply(window,true,true);room.app.request_layer_order()
	m.say("사다리 타고, 한 권만 꺼내자")
func advance(room) -> void:
	if not is_instance_valid(window) or not window.visible:return
	var m=room.app.pet.motion
	if m.visit_id!="home_wall_shelf" or m.phase!="home_use" or m.held or not room.pieces.has("wall_shelf") or m.elapsed>=END:
		window.hide();m.soft_climb_height=0;room.app.request_layer_order()
