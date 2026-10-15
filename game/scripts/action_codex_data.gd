extends RefCounted
const Catalog=preload("res://scripts/animal_catalog.gd")
const ROWS=[
	["기본","잠시 쉬고 있을 때",[["basic","idle","편안한 대기"]]],
	["걷기","자유롭게 돌아다니거나 가구로 갈 때",[["walk","walk","산책"]]],
	["달리기","신나게 뛰거나 다양한 행동에서 골라볼 때",[["locomotion","run","가볍게 통통 달리기"]]],
	["점프","쉬는 동안 기분이 좋아 폴짝 뛸 때",[["locomotion","jump","제자리 폴짝"]]],
	["기쁨","쓰다듬거나 기분이 좋아졌을 때",[["basic","pet","기분 좋은 반응"],["daily","sing","흥얼흥얼"]]],
	["슬픔·토라짐","다양한 행동 메뉴에서 직접 골라볼 수 있어요",[["daily","sad","잠깐 토라지기"]]],
	["잠","졸리거나 침대에서 쉴 때",[["basic","sleep","꾸벅꾸벅"],["life","bed","침대에서 잠들기"],["daily","pajama","포근한 잠옷"]]],
	["굴리기·비행","우리 집 교감으로 새로운 놀이를 열어요",[["adventure","roll","데굴데굴 굴러가기"],["adventure","fly","대나무 프로펠러 비행"]]],
	["빼꼼","주변이 궁금할 때",[["daily","peek","궁금해서 빼꼼"]]],
	["먹기·마시기","식탁을 준비하고 클릭하거나 데려다 놓아요",[["basic","eat","오물오물 먹기"],["daily","drink","차 한 모금"]]],
	["함께 놀기","놀이감을 클릭하거나 동물을 데려다 놓아요",[["life","play","인형·공과 놀기"],["daily","fight","나뭇잎 놀이"]]],
	["장난감 해금","놀이감마다 필요한 교감이 달라요",[["life","play","공 따라잡기","home_toy_ball"],["life","play","생쥐 따라잡기","home_toy_mouse"]]],
	["장난감 바구니","바구니 옆에서 인형을 꺼내 안았다가 돌려놓아요",[["life","play","바구니에서 인형 꺼내기","basket"]]],
	["가구 행동 해금","가구를 해금하고 배치하면 함께 이용해요",[["daily","study","책장 곁 독서","home_shelf"],["daily","study","독서 의자","home_reading_chair"],["daily","sing","음악 감상","home_record_player"]]],
	["집에서 쉬기","해당 가구를 클릭하거나 동물을 데려다 놓아요",[["life","sofa","소파에 앉기"],["life","bath","보송보송 목욕"],["daily","study","책 읽기"],["daily","work","새싹 돌보기"]]],
	["들기·버둥","들어 올린 뒤 2초가 지나면 버둥거려요",[["interaction","carry","살짝 들기"],["interaction","struggle","내려 주세요"]]],
	["착지·회복","높게 떨어졌을 때 착지하고 다시 일어나요",[["interaction","landing","착지하기"],["interaction","dizzy","해롱해롱"],["interaction","recover","다시 일어서기"]]]
]
const HINTS={
	"daily/sing":"쉬는 동안 가끔 흥얼거려요. 다양한 행동 메뉴에서도 볼 수 있어요.",
	"daily/peek":"쉬는 동안 주변을 둘러봐요. 화면 가장자리로 이동하는 동작은 아니에요.",
	"daily/drink":"물 식탁을 이용할 때, 또는 다양한 행동 메뉴에서 차 한 모금을 고를 때예요.",
	"daily/study":"쉬는 동안 스스로 책을 읽거나, 다양한 행동 메뉴에서 골라볼 수 있어요.",
	"daily/work":"쉬는 동안 새싹을 돌보거나, 다양한 행동 메뉴에서 골라볼 수 있어요.",
	"daily/pajama":"밤 9시 이후 쉬는 동안 가끔 보여요. 다양한 행동 메뉴에서도 볼 수 있어요.",
	"daily/fight":"쉬는 동안 가끔 나뭇잎 놀이를 해요. 다양한 행동 메뉴에서도 볼 수 있어요."
}
static func descriptor(species: int,bank: String,action: String) -> Dictionary:
	if bank=="locomotion" and not preload("res://scripts/run_hop_art.gd").has_action(species,action):
		var fallback=descriptor(species,"walk" if action=="run" else "basic","walk" if action=="run" else "pet")
		if fallback.is_empty(): return fallback
		fallback.key="locomotion/"+action;fallback.bank=bank;fallback.action=action
		fallback.seconds=float(fallback.seconds)/1.65 if action=="run" else 1.25
		if action=="jump": fallback.lift=15;fallback.launch=.12;fallback.land=.84
		return fallback
	var root="res://assets/"
	var manifest="manifest.json"
	match bank:
		"basic":
			root+="soft-hedgehog/" if species==3 else "v2-basics/"+Catalog.IDS[species]+"/"
			if species==3: manifest="basic-manifest.json"
		"walk": root+="soft-roster-v2/"+Catalog.IDS[species]+"/"
		"life": root+="v2-life/"+Catalog.IDS[species]+"/"
		"interaction": root+="v2-interactions/"+Catalog.IDS[species]+"/"
		"locomotion": root+="v2-run-hop/"+Catalog.IDS[species]+"/"
		"adventure": root+="v2-adventure/"+Catalog.IDS[species]+"/"
		"daily": root+="v2-daily/"+Catalog.IDS[species]+"/"
	if not FileAccess.file_exists(root+manifest): return {}
	var data=JSON.parse_string(FileAccess.get_file_as_string(root+manifest))
	if not data is Dictionary: return {}
	var spec: Dictionary=data.get("stages",{}).get("adult",{}) if bank=="walk" else data.get("sequences",{}).get(action,{})
	if spec.is_empty(): return {}
	var seconds=float(spec.get("duration",2.4))
	if bank=="walk": seconds=float(spec.get("playback_seconds",1.6))*(Catalog.DISPLAY_HEIGHT/110.0)/Catalog.WORLD_SPEED_MULTIPLIER
	return {"path":root+str(spec.file),"count":int(spec.count),"columns":int(spec.get("columns",8)),"cell":int(spec.get("cell",256)),"seconds":seconds,"curve":spec.get("phase_curve",[]),"key":bank+"/"+action,"bank":bank,"action":action,"lift":spec.get("lift",0),"launch":spec.get("launch",0),"land":spec.get("land",1),"loop":spec.get("loop",true)}

static func index_at(spec: Dictionary,seconds: float) -> int:
	var phase=fposmod(seconds/maxf(.01,spec.seconds),1.0)
	var curve: Array=spec.curve
	for i in range(maxi(0,curve.size()-1)):
		if phase<=float(curve[i+1][0]):
			phase=lerpf(float(curve[i][1]),float(curve[i+1][1]),inverse_lerp(float(curve[i][0]),float(curve[i+1][0]),phase))
			break
	return clampi(int(phase*(spec.count if spec.get("loop",true) else spec.count-1)),0,spec.count-1)
