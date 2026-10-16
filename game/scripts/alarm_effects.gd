extends Node2D
var piece
func _process(_delta: float) -> void:queue_redraw()
func _draw() -> void:
	if not is_instance_valid(piece) or not piece.active or piece.effect_time>2.6:return
	var fade=smoothstep(0,.12,piece.effect_time)*(1-smoothstep(1.8,2.6,piece.effect_time))
	var center=piece.art_origin+piece.sprite.texture.get_size()*piece.sprite.scale*.5
	var size=piece.sprite.texture.get_size()*piece.sprite.scale
	for side in [-1,1]:
		for ring in range(2):
			var at=center+Vector2(side*(size.x*.5+4+ring*5),-size.y*.26)
			var angle=0.0 if side>0 else PI
			draw_arc(at,4+ring*2,angle-.8,angle+.8,10,Color(.76,.44,.37,fade*(.8-ring*.2)),1.7,true)
