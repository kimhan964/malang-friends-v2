extends Window
signal moved
signal activated(id: String)
signal recolored
signal food_picked
signal layer_changed
const NAMES={"cushion":"전용 침대","bowl":"음식 그릇","water":"작은 연못","basket":"장난감 바구니","plant":"전용 놀이 소품","lamp":"전용 휴식 소품","shelter":"전용 쉼터","acorn":"도토리 오뚝이"}
const Profiles=preload("res://scripts/companion_profiles.gd")
const Decor=preload("res://scripts/decor_art.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
var art_scale=1.0
var growth_scale=1.0
var species=0
var start_visible=true
var food_texture: Texture2D
var food_lifted=false
var prop_id="cushion"
var kind="cushion"
var palette=0
var editing=false
var interactive=false
var empty=false
var number=0
var dragging=false
var drag_button=MOUSE_BUTTON_LEFT
var drag_moved=false
var press_screen=Vector2.ZERO
var press_position=Vector2.ZERO
var drawing
var drop_hover=false
var drop_flash=0.0
var glow_time=0.0
var in_use=false
var wobbling=false
var wobble_time=0.0
const WOBBLE_ANGLE=.19

func set_wobbling(value: bool) -> void:
	if wobbling==value: return
	wobbling=value
	if drawing: drawing.queue_redraw()

func set_in_use(value: bool) -> void:
	if in_use==value: return
	in_use=value
	if drawing: drawing.visible=not value
	mouse_passthrough=value

func set_drop_hover(value: bool) -> void:
	if drop_hover==value: return
	drop_hover=value
	if drawing: drawing.queue_redraw()

func confirm_drop() -> void:
	drop_hover=false
	drop_flash=1.0
	if drawing: drawing.queue_redraw()

class PropDrawing extends Node2D:
	var prop
	func oval(at: Vector2, extent: Vector2, color: Color) -> void:
		draw_set_transform(at,0,extent)
		draw_circle(Vector2.ZERO,1,color)
		draw_set_transform(Vector2.ZERO)
	func _draw() -> void:
		if prop.drop_hover or prop.drop_flash>0:
			var pulse=.65+.25*sin(prop.glow_time*6)
			oval(Vector2(56,71),Vector2(51,22),Color(.96,.79,.37,.18+pulse*.13))
			for i in range(3):
				var at=Vector2(16+i*40,25+sin(prop.glow_time*4+i)*5)
				draw_line(at-Vector2(4,0),at+Vector2(4,0),Color(1,.88,.52,.85),2,true)
				draw_line(at-Vector2(0,4),at+Vector2(0,4),Color(1,.88,.52,.85),2,true)
		var artwork=Decor.icon(prop.kind,prop.species)
		if artwork:
			draw_artwork(artwork)
			return
		var tone=Color(["b8c79b","d5ada0","a7b9d1"][prop.palette])
		var edge=tone.darkened(.25)
		oval(Vector2(56,77),Vector2(43,8),Color(0,0,0,.09))
		match prop.kind:
			"cushion":
				draw_bed(tone)
			"shelter":
				draw_shelter(tone)
			"bowl","water":
				var shell=PackedVector2Array([Vector2(22,53),Vector2(90,53),Vector2(80,77),Vector2(32,77)])
				draw_colored_polygon(shell,tone)
				oval(Vector2(56,53),Vector2(34,12),edge)
				oval(Vector2(56,52),Vector2(28,8),Color("9dcbd2") if prop.kind=="water" else Color("f0ddae"))
				if prop.kind=="bowl" and prop.number==0:
					if prop.food_texture and not prop.food_lifted:
						var dimensions=prop.food_texture.get_size()
						dimensions*=minf(76.0/dimensions.x,66.0/dimensions.y)
						draw_texture_rect(prop.food_texture,Rect2(Vector2(56,75)-Vector2(dimensions.x*.5,dimensions.y),dimensions),false)
					else:
						for x in [42,54,66]: draw_circle(Vector2(x,51),4,Color("af7b4f"))
				if prop.number>0:
					draw_circle(Vector2(56,32),12,Color("fff4d6"))
					draw_string(ThemeDB.fallback_font,Vector2(51,38),"×" if prop.empty else str(prop.number),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("755a41"))
			"basket":
				draw_arc(Vector2(56,41),23,PI,TAU,32,Color("997459"),5,true)
				draw_circle(Vector2(43,48),12,Color("cc8c75"))
				draw_circle(Vector2(67,43),10,tone)
				draw_colored_polygon(PackedVector2Array([Vector2(21,48),Vector2(91,48),Vector2(82,78),Vector2(30,78)]),Color("bf9973"))
				for x in range(33,83,12): draw_line(Vector2(x,51),Vector2(x,75),Color("a8815b"),2)
				for y in [58,68]: draw_line(Vector2(28,y),Vector2(84,y),Color("d8b58b"),2)
			"plant":
				draw_line(Vector2(56,63),Vector2(56,25),Color("7b9b67"),4)
				oval(Vector2(44,34),Vector2(16,8),Color("91ad79"))
				oval(Vector2(68,23),Vector2(15,9),Color("7e9b66"))
				draw_colored_polygon(PackedVector2Array([Vector2(34,52),Vector2(78,52),Vector2(70,80),Vector2(42,80)]),tone)
				oval(Vector2(56,52),Vector2(23,6),edge)
			"lamp":
				draw_circle(Vector2(56,38),29,Color(1,.84,.45,.12))
				draw_line(Vector2(56,42),Vector2(56,77),Color("a78359"),5)
				oval(Vector2(56,77),Vector2(20,5),edge)
				draw_colored_polygon(PackedVector2Array([Vector2(42,20),Vector2(70,20),Vector2(86,50),Vector2(26,50)]),tone)
				oval(Vector2(56,50),Vector2(30,5),Color("f4dc9d"))
		if prop.editing:
			draw_rect(Rect2(4,4,104,87),Color("e5cd87"),false,2)
			for point in [Vector2(4,4),Vector2(108,4),Vector2(4,91),Vector2(108,91)]: draw_circle(point,3,Color("fff3c4"))

	func draw_artwork(artwork: Texture2D) -> void:
		var dimensions=artwork.get_size()
		var limit=Vector2(47,57) if prop.kind=="acorn" else Vector2(108,82)
		dimensions*=minf(limit.x/dimensions.x,limit.y/dimensions.y)
		var tint=[Color.WHITE,Color(1,.93,.90),Color(.90,.95,1)][prop.palette]
		if prop.kind in ["acorn","basket"]:
			var amplitude=prop.WOBBLE_ANGLE if prop.kind=="acorn" else .025
			var angle=sin(prop.wobble_time*TAU*(.8 if prop.kind=="acorn" else 1.8))*amplitude if prop.wobbling else 0.0
			draw_set_transform(Vector2(56,86),angle,Vector2.ONE)
			draw_texture_rect(artwork,Rect2(Vector2(-dimensions.x*.5,-dimensions.y),dimensions),false,tint)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture_rect(artwork,Rect2(Vector2(56,86)-Vector2(dimensions.x*.5,dimensions.y),dimensions),false,tint)
		if prop.kind=="bowl" and prop.number==0 and prop.food_texture and not prop.food_lifted:
			var meal_size=prop.food_texture.get_size()
			meal_size*=minf(76.0/meal_size.x,57.0/meal_size.y)
			draw_texture_rect(prop.food_texture,Rect2(Vector2(56,59)-Vector2(meal_size.x*.5,meal_size.y),meal_size),false)
		if prop.number>0:
			draw_circle(Vector2(56,22),12,Color("fff4d6"))
			draw_string(ThemeDB.fallback_font,Vector2(51,28),"×" if prop.empty else str(prop.number),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("755a41"))
		if prop.editing:
			draw_rect(Rect2(4,4,104,87),Color("e5cd87"),false,2)
			for point in [Vector2(4,4),Vector2(108,4),Vector2(4,91),Vector2(108,91)]: draw_circle(point,3,Color("fff3c4"))

	func draw_bed(tone: Color) -> void:
		var c=Color(Profiles.COLORS[prop.species]).lerp(tone,.25)
		oval(Vector2(56,69),Vector2(46,17),c.darkened(.25))
		match prop.species:
			0:
				for x in [30,49,69,83]: oval(Vector2(x,57),Vector2(18,14),c)
				draw_line(Vector2(24,61),Vector2(85,65),c.darkened(.3),2)
			1:
				for y in [52,61,70]:
					draw_line(Vector2(17,y),Vector2(95,y),Color("b49370"),8,true)
				for x in [33,78]: draw_line(Vector2(x,47),Vector2(x,76),Color("735c46"),2)
			2:
				oval(Vector2(56,53),Vector2(44,25),Color("93673f"))
				oval(Vector2(56,53),Vector2(33,15),Color("dcc294"))
			3:
				for i in range(9): oval(Vector2(25+i*7,56+sin(i)*8),Vector2(17,11),c.lightened(float(i%3)*.1))
			4:
				draw_rect(Rect2(17,44,78,29),c)
				for x in range(25,94,13): draw_line(Vector2(x,45),Vector2(x,72),c.lightened(.25),5)
				for y in [49,64]: draw_line(Vector2(17,y),Vector2(94,y),c.darkened(.2),4)
			5:
				for i in range(9):
					var at=Vector2(56,54)+Vector2(cos(i*TAU/9)*32,sin(i*TAU/9)*17)
					oval(at,Vector2(17,12),c)
			6:
				draw_rect(Rect2(13,40,86,31),Color("99734e"))
				for x in [16,94]: oval(Vector2(x,55),Vector2(8,17),Color("d2ac75"))
			7:
				for i in range(7): draw_arc(Vector2(56,54+i*2),38,0,PI,32,c.darkened(.25),2,true)
		oval(Vector2(56,57),Vector2(29,11),c.lightened(.25))
		oval(Vector2(36,51),Vector2(12,7),Color("fff0d7"))
		if prop.species==7:
			draw_circle(Vector2(85,31),11,Color("f3da92"))
			draw_circle(Vector2(89,27),8,c)

	func draw_shelter(tone: Color) -> void:
		var c=Color(Profiles.COLORS[prop.species]).lerp(tone,.2)
		match prop.species:
			1:
				oval(Vector2(56,63),Vector2(42,18),Color("9bc6cd"))
				for x in [28,48,73]: oval(Vector2(x,52),Vector2(18,13),Color("a6aba0"))
			2,6:
				draw_rect(Rect2(24,29,64,49),Color("a17a55"))
				oval(Vector2(56,27),Vector2(34,12),c)
				oval(Vector2(56,57),Vector2(17,22),Color("5d493a"))
			3:
				oval(Vector2(56,53),Vector2(43,29),c)
				oval(Vector2(56,63),Vector2(19,16),Color("604c40"))
			4:
				draw_colored_polygon(PackedVector2Array([Vector2(56,15),Vector2(12,79),Vector2(100,79)]),c)
				draw_colored_polygon(PackedVector2Array([Vector2(56,40),Vector2(39,79),Vector2(74,79)]),Color("647561"))
			7:
				draw_line(Vector2(78,80),Vector2(78,20),Color("9a7958"),9)
				draw_line(Vector2(23,49),Vector2(79,49),Color("9a7958"),6)
				draw_circle(Vector2(35,22),8,Color("f8e1a2"))
				draw_circle(Vector2(60,14),3,Color("f8e1a2"))
			_:
				draw_arc(Vector2(56,57),35,PI,TAU,40,c.darkened(.25),6,true)
				for i in range(7):
					var at=Vector2(56,57)+Vector2(cos(PI+i*PI/6),sin(PI+i*PI/6))*35
					draw_circle(at,9,c)
					if prop.species==5: draw_circle(at,3,Color("ffe3a1"))
		oval(Vector2(56,76),Vector2(30,5),c.lightened(.25))

func _init() -> void:
	visible=false
	force_native=true
	borderless=true
	transparent=true
	transparent_bg=true
	always_on_top=true
	unfocusable=true
	unresizable=true
	size=Vector2i(112,96)
	transient=false
	exclusive=false

func _ready() -> void:
	title=NAMES.get(kind,"간식 찾기")+" · 바탕화면 친구"
	drawing=PropDrawing.new()
	drawing.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	drawing.prop=self
	add_child(drawing)
	window_input.connect(handle_input)
	visibility_changed.connect(func(): layer_changed.emit())
	refresh()
	if start_visible: show()

func refresh() -> void:
	if kind in ["plant","lamp"]: title=(Profiles.TOYS[species] if kind=="plant" else Profiles.COMFORTS[species])+" · 클릭하면 친구가 찾아와요"
	if kind=="acorn": title="도토리 오뚝이 · 클릭하면 함께 놀아요"
	resize_for_friend()
	mouse_passthrough=in_use
	var polygon=input_polygon()
	if mouse_passthrough_polygon!=polygon: mouse_passthrough_polygon=polygon
	if drawing: drawing.queue_redraw()
	layer_changed.emit()

func input_polygon() -> PackedVector2Array:
	var artwork=Decor.icon(kind,species)
	if not artwork or editing:
		return Transform2D.IDENTITY.scaled(Vector2.ONE*art_scale)*PackedVector2Array([Vector2(1,1),Vector2(111,1),Vector2(111,95),Vector2(1,95)])
	var limit=Vector2(47,57) if kind=="acorn" else Vector2(108,82)
	var factor=minf(limit.x/artwork.get_width(),limit.y/artwork.get_height())
	var dimensions=artwork.get_size()*factor
	var origin=Vector2(56,86)-Vector2(dimensions.x*.5,dimensions.y)
	var points=PackedVector2Array()
	if kind=="acorn":
		# On Windows this polygon also clips the rendered native surface.
		# Keep one mask covering the ENTIRE wobble, not the upright silhouette.
		# Changing a native region every frame would reintroduce flicker.
		var local_hull=preload("res://scripts/animation_outline.gd").local_hull(artwork)
		for step in range(17):
			var angle=lerpf(-WOBBLE_ANGLE,WOBBLE_ANGLE,step/16.0)
			for point in local_hull:
				var rotated=Vector2(56,86)+(point*factor-Vector2(dimensions.x*.5,dimensions.y)).rotated(angle)
				for margin in [Vector2(-2,-2),Vector2(2,-2),Vector2(2,2),Vector2(-2,2)]:
					points.append((rotated+margin)*art_scale)
		# Reserve the existing landing/hover effects without changing the mask
		# when those effects appear. These bounds remain within the small window.
		for corner in [Vector2(5,16),Vector2(107,16),Vector2(107,95),Vector2(5,95)]:
			points.append(corner*art_scale)
		return Geometry2D.convex_hull(points)
	for point in preload("res://scripts/animation_outline.gd").local_hull(artwork):
		points.append((origin+point*factor)*art_scale)
	if kind=="bowl" and food_texture and not food_lifted:
		var meal_size=food_texture.get_size()
		meal_size*=minf(76.0/meal_size.x,57.0/meal_size.y)
		var meal=Rect2(Vector2(56,59)-Vector2(meal_size.x*.5,meal_size.y),meal_size)
		for point in [meal.position,Vector2(meal.end.x,meal.position.y),meal.end,Vector2(meal.position.x,meal.end.y)]: points.append(point*art_scale)
	return Geometry2D.convex_hull(points)

func anchor_offset() -> Vector2:
	return Vector2(56,75 if kind in ["cushion","shelter"] else (86 if kind=="acorn" else 63))*art_scale

func feet_point() -> Vector2:
	return Vector2(position)+anchor_offset()

func drinking_surface_point(facing: float) -> Vector2:
	# A point inside the water near the bank, in the prop's authored 112x96 view.
	return Vector2(position)+Vector2(33 if facing>0 else 79,60)*art_scale

func dining_point(animal_bounds: Rect2) -> Vector2:
	# Stand beside the native prop window, not underneath its artwork.
	var width=Catalog.DISPLAY_HEIGHT*Catalog.HEIGHTS[species]*Catalog.PROP_ASPECT[species]
	width*=growth_scale
	var center=feet_point()
	var spacing=width*.5+54*art_scale+8
	var left=center+Vector2(-spacing,8*art_scale)
	var right=center+Vector2(spacing,8*art_scale)
	if animal_bounds.has_point(left): return left
	if animal_bounds.has_point(right): return right
	return (center+Vector2(0,width*.5+48*art_scale+12)).clamp(animal_bounds.position,animal_bounds.end)

func resize_for_friend() -> void:
	var factor=1.0
	if kind in ["bowl","water"] and number==0:
		var width=Catalog.DISPLAY_HEIGHT*Catalog.HEIGHTS[species]*Catalog.PROP_ASPECT[species]
		factor=(clampf(width*growth_scale*1.12,88,124) if kind=="water" else clampf(width*growth_scale*.70,66,88))/108.0
	if kind in ["cushion","shelter"]:
		var height=Catalog.DISPLAY_HEIGHT*Catalog.HEIGHTS[species]
		var width=height*Catalog.PROP_ASPECT[species]
		var artwork=Decor.icon(kind,species)
		var base_size=artwork.get_size() if artwork else Vector2(108,82)
		base_size*=minf(108.0/base_size.x,82.0/base_size.y)
		factor=maxf(height*1.8/base_size.y,width*2.15/base_size.x) if kind=="shelter" else maxf(height*.85/base_size.y,width*1.45/base_size.x)
	if kind in ["plant","lamp"]: factor=clampf(Catalog.DISPLAY_HEIGHT*Catalog.HEIGHTS[species]/100.0,.5,1.3)
	if kind in ["cushion","shelter","plant","lamp"]: factor*=growth_scale
	factor=preload("res://scripts/desktop_clutter.gd").capped_scale(kind,factor)
	if not is_equal_approx(factor,art_scale):
		var anchor=feet_point()
		art_scale=factor
		size=Vector2i(Vector2(112,96)*factor)
		position=Vector2i(anchor-anchor_offset())
	if drawing: drawing.scale=Vector2.ONE*factor
	var screen=DisplayServer.get_screen_from_rect(Rect2i(position,size))
	if screen<0: screen=DisplayServer.SCREEN_PRIMARY
	var usable=DisplayServer.screen_get_usable_rect(screen)
	position=Vector2i(Vector2(position).clamp(Vector2(usable.position),Vector2((usable.end-size).max(usable.position))))

func finish_drag() -> void:
	if not dragging: return
	dragging=false
	if drag_moved:
		moved.emit()
	elif (interactive or kind in ["plant","lamp","acorn","cushion","shelter","water","basket"]) and not editing and drag_button==MOUSE_BUTTON_LEFT:
		activated.emit(prop_id)
	layer_changed.emit()

func handle_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton: return
	if event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]: return
	if not event.pressed:
		if event.button_index==drag_button: finish_drag()
		return
	if event.button_index==MOUSE_BUTTON_RIGHT and editing:
		recolored.emit()
		return
	# Left dragging food still feeds the animal. Right dragging moves its dish.
	if event.button_index==MOUSE_BUTTON_LEFT and not editing and not interactive and kind=="bowl" and food_texture and not food_lifted:
		food_picked.emit()
		return
	dragging=true
	drag_moved=false
	drag_button=event.button_index
	press_screen=Vector2(DisplayServer.mouse_get_position())
	press_position=Vector2(position)
	layer_changed.emit()

func _process(_delta: float) -> void:
	preload("res://scripts/native_mouse.gd").apply(self,mouse_passthrough)
	if wobbling:
		wobble_time+=_delta
		if drawing: drawing.queue_redraw()
	if drop_hover or drop_flash>0:
		glow_time+=_delta
		drop_flash=maxf(0,drop_flash-_delta)
		if drawing: drawing.queue_redraw()
	if not dragging: return
	var mask=MOUSE_BUTTON_MASK_LEFT if drag_button==MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	if not (DisplayServer.mouse_get_button_state() & mask):
		finish_drag()
		return
	var cursor=DisplayServer.mouse_get_position()
	if not drag_moved and Vector2(cursor).distance_to(press_screen)<5: return
	drag_moved=true
	var screen=DisplayServer.get_screen_from_rect(Rect2i(cursor,Vector2i.ONE))
	if screen<0: screen=DisplayServer.SCREEN_PRIMARY
	var rect=DisplayServer.screen_get_usable_rect(screen)
	move_dragged_to(Vector2(cursor),rect)

func move_dragged_to(cursor: Vector2, rect: Rect2i) -> void:
	var point=press_position+cursor-press_screen
	var target=Vector2i(point.clamp(Vector2(rect.position),Vector2((rect.end-size).max(rect.position))))
	if position!=target: position=target
