extends RefCounted
# Fictional character direction, not a personality assessment.
const TYPES=["ENFP","ESFP","ISTJ","ISFJ","ESTJ","ENTP","ISFP","INTJ","ISTP","ESFJ","ENTJ","INFJ","ESTP","ENFJ","INTP","INFP"]
const NAMES=["호기심 지그재그","작은 환영 공연","꼼꼼한 순찰","수줍은 안부","정해진 길 점검","장난스러운 밀당","나만의 느긋한 자리","멀리서 관찰하기","혼자 탐색하기","다가와 인사하기","앞장서서 안내하기","조용히 곁 지키기","재빠른 도전","함께 놀자 응원","생각에 잠긴 탐구","수줍게 마음 전하기"]
const DETAILS=["좌우로 새 길을 탐색하고 놀자는 손짓을 해요.","앞으로 나와 인사와 기쁜 몸짓으로 짧은 공연을 해요.","같은 두 지점을 차례로 살핀 뒤 출발 자리로 돌아와요.","조심스럽게 다가와 안부를 전하고 한 걸음 물러나요.","네모난 경로를 따라 주변을 점검하고 만족해요.","다가와 놀자고 하다가 살짝 물러나 다시 손짓해요.","옆으로 조용히 이동해 자리를 다듬고 편안해해요.","먼저 양쪽을 관찰한 뒤 한 지점을 정해 살펴봐요.","커서 반대편을 탐색하고 고개를 돌려 주변을 살펴요.","커서 가까이 다가와 인사하고 다정하게 기대요.","앞장서서 이동한 뒤 돌아보며 따라오라는 손짓을 해요.","커서 근처의 적당한 거리에 자리 잡고 조용히 함께해요.","좌우로 빠르게 달려갔다 돌아와 놀자고 해요.","다가와 손짓하고 함께 놀기를 기다리며 응원해요.","양쪽을 번갈아 살피고 작은 거리를 옮겨 다시 관찰해요.","조금씩 다가와 기쁜 마음을 표현하고 수줍게 물러나요."]

static func walk(offset: Vector2, speed: float=1.0) -> Dictionary:
	return {"offset":offset,"speed":speed}

static func pose(kind: String, duration: float=1.5) -> Dictionary:
	return {"pose":kind,"duration":duration}

static func sequence(species: int, feet: Vector2, cursor: Vector2, facing: float) -> Array:
	var toward=(cursor-feet).limit_length(90)
	if toward.length()<24: toward=Vector2(facing*35,0)
	var x=facing
	match species:
		0: return [walk(Vector2(45*x,-20)),pose("gift",1.1),walk(Vector2(-35*x,20)),walk(Vector2(55*x,0)),pose("askplay")]
		1: return [walk(toward*.5),pose("greet"),pose("yum",1.8),pose("greet",1.1)]
		2: return [walk(Vector2(60*x,0)),pose("inspect"),walk(Vector2(60*x,-35)),pose("inspect"),walk(Vector2.ZERO),pose("yum",1.1)]
		3: return [walk(toward*.55,.7),pose("greet",1.2),pose("pet",1.8),walk(toward*.25,.7)]
		4: return [walk(Vector2(65*x,0)),walk(Vector2(65*x,-40)),pose("inspect",1),walk(Vector2(0,-40)),walk(Vector2.ZERO),pose("yum")]
		5: return [walk(toward),pose("askplay",1.2),walk(-toward*.4,1.2),pose("askplay",1.8)]
		6: return [walk(Vector2(-45*x,20),.65),pose("nest",2.4),pose("pet",2.3)]
		7: return [pose("inspect",2.8),walk(Vector2(50*x,-30),.8),pose("inspect",2.2),pose("gift",1.2)]
		8: return [walk(-toward,1.1),pose("inspect",1.8),walk(-toward+Vector2(0,-30)),pose("inspect",1.4)]
		9: return [walk(toward,1.15),pose("greet",1.6),pose("pet",2.2)]
		10: return [walk(Vector2(75*x,-15),1.2),pose("askplay"),walk(Vector2(100*x,10)),pose("greet")]
		11: return [walk(toward*.65,.65),pose("greet",1.1),pose("pet",3.5)]
		12: return [walk(Vector2(75*x,-20),1.5),walk(Vector2(-45*x,15),1.5),walk(Vector2.ZERO,1.4),pose("askplay",1.8)]
		13: return [walk(toward*.7),pose("askplay",1.8),pose("greet",1.4),pose("yum",1.6)]
		14: return [pose("inspect",3),walk(Vector2(25*x,-15),.7),pose("inspect",2.5),pose("gift",1.4)]
		15: return [walk(toward*.3,.7),pose("greet",1.2),walk(toward*.65,.7),pose("gift",2),walk(toward*.35,.7)]
	return []
