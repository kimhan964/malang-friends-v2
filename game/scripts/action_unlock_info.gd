extends RefCounted
const ROUTES={"basic/eat":"home_table","life/bed":"home_daybed","life/sofa":"home_sofa","life/bath":"home_bathtub","life/play":"home_toy_plush"}
const HOW={"basic/idle":"잠시 아무것도 하지 않으면 편안히 쉬어요.","walk/walk":"자유롭게 돌아다니거나 가구를 이용하러 갈 때 걸어요.","basic/pet":"펫을 짧게 클릭해 쓰다듬어 주세요.","basic/sleep":"피곤할 때 스스로 잠들어요. 침대를 이용해도 돼요.","basic/eat":"집 꾸미기에서 식탁 배치 → 식탁 우클릭 → 선택한 음식 차리기.","interaction/carry":"펫을 잡아 위로 들어 올려 주세요.","interaction/struggle":"들어 올린 채 2초 이상 잡고 있으면 버둥거려요.","interaction/landing":"들어 올렸다 놓으면 바닥에 착지해요.","interaction/dizzy":"높이 들어 올렸다 놓으면 착지 뒤 잠시 해롱거려요.","interaction/recover":"착지·해롱거림이 끝나면 스스로 일어나요."}
static func details(spec: Dictionary,state,species: int) -> Dictionary:
	var route=str(spec.get("route",ROUTES.get(spec.key,"")))
	var points=int(state.home_points())
	var threshold=0
	var ready=true
	var title="처음부터 가능"
	var how=HOW.get(spec.key,"우클릭 → 함께하기 → 다양한 행동에서 직접 골라 주세요.")
	var trigger=""
	if route.begins_with("home_"):
		threshold=int(state.UNLOCKS.get(route,0))
		ready=state.unlocked(species,route)
		var piece=route.trim_prefix("home_")
		var name=state.gift_name(route)
		title="처음부터 가능 · "+name if threshold==0 else ("해금 완료 · "+name if ready else "잠김 · "+name+" 필요")
		how="우클릭 → 집 꾸미기 → %s 배치 → 가구를 클릭하거나 펫을 끌어 놓으세요."%name
		if piece.begins_with("toy_"): how="우클릭 → 함께하기 → 놀이감 꺼내기 → %s를 꺼내고 클릭해 주세요."%name
	elif route=="basket":
		title="처음부터 가능 · 장난감 바구니"
		how="장난감이 담긴 바구니를 클릭하거나 펫을 끌어 놓으세요. 옆에 서서 인형을 꺼내 안고 다시 돌려놓아요."
	elif spec.bank=="adventure":
		threshold=int(preload("res://scripts/behavior_unlocks.gd").THRESHOLDS.get(spec.action,0))
		ready=preload("res://scripts/behavior_unlocks.gd").available(points,spec.action)
		title="해금 완료" if ready else "잠김 · 교감을 더 쌓아 주세요"
	if spec.key=="daily/pajama": trigger="자동으로 보기: 밤 9시 이후 편안히 쉴 때. 직접 선택은 언제나 가능해요."
	elif spec.bank=="daily" and spec.action in ["sing","study","work","fight","peek"]: trigger="자동으로 보기: 다양한 행동 창에서 ‘스스로 하기’를 켜고 편안히 쉬게 해 주세요."
	elif spec.bank in ["run","locomotion"] and spec.action=="run": trigger="자동으로 보기: 다양한 행동 창에서 ‘빠른 타자 반응’을 켜 주세요."
	var progress="처음부터 이용할 수 있어요."
	if threshold>0: progress="우리 집 교감 %d / %d"%[points,threshold]+(" · 해금 완료" if ready else " · %d 더 모으면 열려요"%maxi(0,threshold-points))
	if ready and points<threshold: progress="이미 받은 가구 · 계속 이용할 수 있어요 (기본 해금: 교감 %d)"%threshold
	return {"open":ready,"threshold":threshold,"points":points,"ratio":1.0 if ready else clampf(float(points)/maxi(1,threshold),0,1),"status":title,"progress":progress,"how":how,"trigger":trigger,"route":route,"earn":"쓰다듬기·마우스 따라오기 +1, 직접 먹이기·공놀이 +2. 같은 교감은 8초, 식사·가구 이용은 45초 간격으로 쌓여요. 모든 친구의 교감을 합산해요."}
