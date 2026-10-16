extends Node
const Data=preload("res://scripts/action_codex_data.gd")
const Images=preload("res://scripts/asset_images.gd")
var panel: Window
var selector: OptionButton
var rows: VBoxContainer
var scroll: ScrollContainer
var preview: TextureRect
var heading: Label
var condition: Label
var summary: Label
var play: Button
var species=0
var selected: Dictionary={}
var atlas: AtlasTexture
var clock=0.0
var paused=false
var flipped=false
var buttons: Array=[]
var shown_actions=0
var state
var unlock_label: Label
var unlock_progress: ProgressBar
var progress_hint: Label
var unlock_cards=[]
var last_points=-1
var thumbnail_index: Dictionary={}

func label(text: String,size: int=14) -> Label:
	var out=Label.new();out.text=text;out.add_theme_font_size_override("font_size",size)
	out.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return out
func paper(color: String) -> StyleBoxFlat:
	var style=StyleBoxFlat.new();style.bg_color=Color(color);style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	return style
func open(initial: int,allowed: Array=[]) -> void:
	if state==null: state=preload("res://scripts/pet_state.gd").new()
	if not is_instance_valid(panel): build()
	selector.clear()
	for id in range(16):
		if not allowed.is_empty() and id not in allowed: continue
		selector.add_item(Data.Catalog.NAMES[id],id)
	species=initial
	var selected_index=selector.get_item_index(initial)
	if selected_index<0: selected_index=0;species=selector.get_item_id(0)
	selector.select(selected_index)
	rebuild()
	var screen=DisplayServer.screen_get_usable_rect()
	panel.size=Vector2i(mini(820,screen.size.x-32),mini(760,screen.size.y-48))
	panel.position=screen.position+(screen.size-panel.size)/2
	panel.show()
	reveal.call_deferred()

func reveal() -> void:
	if not is_instance_valid(panel) or not panel.visible: return
	preload("res://scripts/native_mouse.gd").apply(panel,false,true)
	panel.grab_focus()
	var app=get_tree().current_scene
	if app!=null and app.has_method("request_layer_order"): app.request_layer_order()

func build() -> void:
	var index_path="res://assets/codex-thumbs/index.json"
	if FileAccess.file_exists(index_path): thumbnail_index=JSON.parse_string(FileAccess.get_file_as_string(index_path))
	panel=Window.new();panel.visible=false;panel.force_native=true;panel.always_on_top=true
	panel.title="말랑친구 · 행동 도감";panel.size=Vector2i(820,760);panel.min_size=Vector2i(600,500)
	panel.theme=preload("res://scripts/cozy_ui.gd").theme()
	panel.close_requested.connect(panel.hide);add_child(panel)
	var background=PanelContainer.new();background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel",paper("faf8f3"));panel.add_child(background)
	var col=VBoxContainer.new();col.add_theme_constant_override("separation",10);background.add_child(col)
	var top=HBoxContainer.new();top.add_theme_constant_override("separation",12);col.add_child(top)
	var title=label("작은 친구의 행동 도감",20);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(title)
	selector=OptionButton.new();selector.custom_minimum_size=Vector2(190,38)
	selector.item_selected.connect(func(index): species=selector.get_item_id(index);rebuild());top.add_child(selector)
	var stage=PanelContainer.new();stage.add_theme_stylebox_override("panel",paper("f0eee5"));col.add_child(stage)
	var stage_row=HBoxContainer.new();stage_row.add_theme_constant_override("separation",20);stage.add_child(stage_row)
	var holder=Control.new();holder.custom_minimum_size=Vector2(124,124);stage_row.add_child(holder)
	preview=TextureRect.new();preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;holder.add_child(preview)
	var info=VBoxContainer.new();info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;info.add_theme_constant_override("separation",8);stage_row.add_child(info)
	heading=label("",18);info.add_child(heading)
	unlock_label=label("",14);info.add_child(unlock_label)
	unlock_progress=ProgressBar.new();unlock_progress.max_value=1;unlock_progress.show_percentage=false;unlock_progress.custom_minimum_size.y=9;info.add_child(unlock_progress)
	progress_hint=label("",12);info.add_child(progress_hint)
	condition=label("",13);info.add_child(condition)
	var controls=HBoxContainer.new();controls.add_theme_constant_override("separation",8);info.add_child(controls)
	play=Button.new();play.text="일시 정지";play.custom_minimum_size=Vector2(100,34)
	play.pressed.connect(func(): paused=not paused;play.text="재생" if paused else "일시 정지");controls.add_child(play)
	var flip=Button.new();flip.text="방향 바꾸기";flip.custom_minimum_size=Vector2(110,34)
	flip.pressed.connect(func(): flipped=not flipped;preview.flip_h=flipped);controls.add_child(flip)
	summary=label("",12);col.add_child(summary)
	scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;col.add_child(scroll)
	rows=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rows.add_theme_constant_override("separation",6);scroll.add_child(rows)
	var close=Button.new();close.text="도감 닫기";close.custom_minimum_size.y=38;close.pressed.connect(panel.hide);col.add_child(close)

func rebuild() -> void:
	selected={};atlas=null;preview.texture=null;buttons.clear();unlock_cards.clear();shown_actions=0;clock=0
	selector.grab_focus()
	for child in rows.get_children(): rows.remove_child(child);child.queue_free()
	for row in Data.ROWS:
		var card=PanelContainer.new();card.add_theme_stylebox_override("panel",paper("fffdf8"));rows.add_child(card)
		var line=HBoxContainer.new();line.add_theme_constant_override("separation",12);card.add_child(line)
		var text_col=VBoxContainer.new();text_col.custom_minimum_size.x=170;line.add_child(text_col)
		text_col.add_child(label(row[0],14))
		var hint=label(row[1],12);hint.custom_minimum_size.x=170;text_col.add_child(hint)
		var variants=HFlowContainer.new();variants.size_flags_horizontal=Control.SIZE_EXPAND_FILL;variants.add_theme_constant_override("h_separation",8);variants.add_theme_constant_override("v_separation",6);line.add_child(variants)
		var count=0
		for item in row[2]:
			var spec=Data.descriptor(species,item[0],item[1])
			if spec.is_empty(): continue
			if item.size()>3: spec.route=item[3]
			var image=Image.new()
			var thumbnail_path: String=thumbnail_index.get(spec.path,"")
			var small=not thumbnail_path.is_empty()
			if Images.decode_into(image,thumbnail_path if small else spec.path)!=OK: continue
			var stamp_count=3 if row[2].size()==1 else 1
			var button=Button.new();button.custom_minimum_size=Vector2(224 if stamp_count==3 else 132,112)
			button.add_theme_stylebox_override("normal",paper("faf8f3"))
			button.tooltip_text=item[2]
			var inside=VBoxContainer.new();inside.mouse_filter=Control.MOUSE_FILTER_IGNORE;inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);button.add_child(inside)
			var strip=HBoxContainer.new();strip.alignment=BoxContainer.ALIGNMENT_CENTER;strip.mouse_filter=Control.MOUSE_FILTER_IGNORE;inside.add_child(strip)
			for stamp in range(stamp_count):
				var cell=int(spec.get("cell",256))
				var index=Data.index_at(spec,spec.seconds*float(stamp)/3.0)
				var thumb=image.get_region(Rect2i(stamp*64,0,64,64) if small else Rect2i(index%spec.columns*cell,int(index/spec.columns)*cell,cell,cell))
				if not small: thumb.resize(64,64,Image.INTERPOLATE_LANCZOS)
				var picture=TextureRect.new();picture.texture=ImageTexture.create_from_image(thumb);picture.custom_minimum_size=Vector2(64,64);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;strip.add_child(picture)
			var name_label=label(item[2],12);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;inside.add_child(name_label)
			var badge=label("",11);badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;inside.add_child(badge)
			unlock_cards.append({"label":badge,"spec":spec})
			button.pressed.connect(func(): select_action(spec,item[2],row[1],button))
			variants.add_child(button);buttons.append(button);count+=1;shown_actions+=1
			if selected.is_empty(): select_action(spec,item[2],row[1],button)
		if count==0:
			var pending=label("전용 동작 준비 중",12);pending.custom_minimum_size=Vector2(200,52);pending.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;variants.add_child(pending)
	refresh_unlocks()
	scroll.set_deferred("scroll_vertical",0)

func select_action(spec: Dictionary,title: String,hint: String,button: Button=null) -> void:
	var image=Image.new()
	if Images.decode_into(image,spec.path)!=OK: return
	selected=spec;clock=0;paused=false;play.text="일시 정지"
	atlas=AtlasTexture.new();atlas.atlas=ImageTexture.create_from_image(image);atlas.region=Rect2(0,0,int(spec.get("cell",256)),int(spec.get("cell",256)))
	preview.texture=atlas;preview.flip_h=flipped;heading.text=title;refresh_requirements()
	for other in buttons: other.add_theme_stylebox_override("normal",paper("e5eadd" if other==button else "faf8f3"))
	update_frame()
func update_frame() -> void:
	if selected.is_empty() or atlas==null: return
	preview.rotation=0;preview.position=Vector2.ZERO
	if selected.bank=="trip":
		var pose=preload("res://scripts/trip_art.gd").at(species,fposmod(clock,2.8))
		preview.texture=pose.texture;preview.pivot_offset=preview.size*.5;preview.rotation=pose.trip_angle
		return
	preview.texture=atlas
	var phase=fposmod(clock/maxf(.01,selected.seconds),1.0)
	if selected.get("hop_twice",false):phase=fposmod(phase*2,1)
	var air=clampf(inverse_lerp(float(selected.get("launch",0)),float(selected.get("land",1)),phase),0,1)
	preview.position.y=-sin(air*PI)*float(selected.get("lift",0))*minf(preview.size.x,preview.size.y)/256.0
	var index=Data.index_at(selected,clock)
	var cell=int(selected.get("cell",256))
	atlas.region=Rect2((index%selected.columns)*cell,int(index/selected.columns)*cell,cell,cell)
func _process(delta: float) -> void:
	if not is_instance_valid(panel) or not panel.visible or paused or selected.is_empty(): return
	clock+=delta;update_frame()
	if state!=null and state.home_points()!=last_points: refresh_unlocks()

func refresh_requirements() -> void:
	if selected.is_empty() or state==null: return
	var entry=preload("res://scripts/action_unlock_info.gd").details(selected,state,species)
	unlock_label.text=entry.status
	unlock_label.add_theme_color_override("font_color",Color("5c7651") if entry.open else Color("a77548"))
	unlock_progress.value=entry.ratio
	progress_hint.text=entry.progress
	condition.text="이렇게 해보세요: "+entry.how+("\n"+entry.trigger if not entry.trigger.is_empty() else "")
	if not entry.open: condition.text+="\n교감 쌓기: "+entry.earn
func refresh_unlocks() -> void:
	if state==null: return
	last_points=state.home_points()
	var opened=0
	for card in unlock_cards:
		var entry=preload("res://scripts/action_unlock_info.gd").details(card.spec,state,species)
		card.label.text=("가능" if entry.open else "잠김")+(" · 교감 %d/%d"%[mini(entry.points,entry.threshold),entry.threshold] if entry.threshold>0 else " · 처음부터")
		card.label.add_theme_color_override("font_color",Color("5c7651") if entry.open else Color("a77548"))
		if entry.open: opened+=1
	summary.text="해금 %d / %d · 우리 집 교감 %d (모든 친구 합산)\n잠긴 그림도 미리 볼 수 있어요. 카드를 누르면 해금 조건과 실행 방법이 나와요."%[opened,shown_actions,last_points]
	refresh_requirements()
