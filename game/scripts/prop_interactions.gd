extends RefCounted
const Keyed=preload("res://scripts/keyed_art.gd")
const TOY_ACTIONS=["당근을 잡고 오독오독 씹기","조약돌을 집어 쌓고 균형 잡기","도토리 퍼즐 구멍에서 꺼내기","잎 터널에 들어갔다 나오기","조개를 물에 담가 씻기","매달린 잎을 덮쳐 앞발로 잡기","벌집 구멍을 더듬고 돌려 보기","깃털을 날개로 톡톡 건드리기","양 앞발로 번갈아 긁기","밧줄을 물고 버티며 당기기","쳇바퀴 안에서 발을 바꿔 달리기","앞발로 대나무 롤러 밀기","통나무 발판을 짚고 올라가기","풀 언덕을 올라 폴짝 뛰기","가지에 매달려 올라가기","얼음 경사면에서 배로 미끄러지기"]
const COMFORT_ACTIONS=["클로버 아래에 몸을 낮추고 웅크리기","돌 위에 올라 팔을 펴고 기대기","도토리를 넣고 뚜껑 닫기","마른 잎 아래 파고들어 얼굴 내밀기","체크 담요를 꾹꾹 누르고 눕기","잎 그늘에서 꼬리를 감고 눕기","나무에 등을 대고 좌우로 비비기","횃대에 올라 날개 접고 졸기","상자에 들어가 얼굴 내밀기","담요를 앞발로 정리하고 코 묻기","모래를 파고 몸을 좌우로 굴리기","대나무 그늘 아래 다리 펴고 쉬기","단풍잎을 건드린 뒤 아래에 웅크리기","양털 쿠션을 누르고 파묻히기","그늘 기둥을 안고 기대어 졸기","눈 위에서 배를 깔고 날개 접기"]
const SPEEDS=[3.1,2.2,2.5,2.0,3.3,3.7,2.0,2.7,4.2,2.5,6.0,3.8,2.3,3.6,1.8,3.0]
static var sheets: Dictionary={}
static var bounds: Dictionary={}

static func frames(species: int, baby: bool, kind: String) -> Array:
	var key=("baby" if baby else "adult")+"-"+str(species/4)
	if not sheets.has(key):
		var path="res://assets/interactions/"+key+".png"
		if not FileAccess.file_exists(path): return []
		sheets[key]=Keyed.AnimationRegions.frames(path,Keyed.pixels(path))
	var offset=(species%4)*8+(4 if kind=="lamp" else 0)
	var sequence: Array=sheets[key].slice(offset,offset+4)
	# The final squirrel pose omitted its puzzle box. Keep contact and
	# the box visible by returning through the preceding complete pose.
	if species==2 and kind=="plant" and sequence.size()==4: sequence[3]=sequence[1]
	# The baby owl's third drawing omitted the mobile stand.
	if species==7 and baby and kind=="plant" and sequence.size()==4: sequence[2]=sequence[1]
	return sequence

static func sequence_bounds(sequence: Array) -> Rect2i:
	var area=Rect2i()
	for texture in sequence:
		var used=texture.get_image().get_used_rect()
		area=area.merge(used) if area.has_area() else used
	return area

static func description(species: int, kind: String) -> String:
	return TOY_ACTIONS[species] if kind=="plant" else COMFORT_ACTIONS[species]

static func pose(motion) -> int:
	if motion.species==9 and motion.visit_id=="plant":
		return clampi(roundi(motion.prop_strength*3),0,3) if motion.prop_dragging else 0
	var time=motion.prop_progress
	# The final resting pose holds; play sequences repeat deliberately.
	if motion.visit_id=="lamp":
		if motion.species in [2,3,6,8,10,12]: return int(time*.65)%4
		return mini(3,int(time*.65))
	return int(time)%4
