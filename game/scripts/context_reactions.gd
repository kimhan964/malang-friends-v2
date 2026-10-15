extends RefCounted
## One short, expiring response at a safe action boundary. No reaction backlog.
const Behavior=preload("res://scripts/expression_behavior.gd")
const EVENTS={
	"pet":{"kind":"happy","words":["손길이 좋아","조금만 더"],"strength":.55},
	"meal":{"kind":"happy","words":["잘 먹었어","맛있었어"],"strength":.45},
	"favorite_meal":{"kind":"happy","words":["내가 좋아하는 맛이야","이거 또 먹고 싶어"],"strength":.95},
	"hand_feed":{"kind":"happy","words":["챙겨줘서 고마워","한 입 잘 먹었어"],"strength":.65},
	"water":{"kind":"happy","words":["이제 시원해","목이 촉촉해졌어"],"strength":.25},
	"toy":{"kind":"happy","words":["한 번 더 놀까","재밌었어"],"strength":.9},
	"ball":{"kind":"happy","words":["잡아 왔어","다시 던져줄래"],"strength":.85},
	"gift":{"kind":"surprised","words":["새로운 게 왔네","나한테 온 걸까"],"strength":.65,"priority":2},
	"empty":{"kind":"surprised","words":["여기는 비었네","다른 데 찾아볼까"],"strength":.35},
	"rest":{"kind":"happy","words":["포근해서 좋아","여기가 편안해"],"strength":.2},
	"tea":{"kind":"happy","words":["따뜻한 한 모금","여유로워서 좋아"],"strength":.2},
	"read":{"kind":"happy","words":["다음 장도 궁금해","재밌는 이야기였어"],"strength":.25},
	"groom":{"kind":"happy","words":["단정해졌지","준비 끝"],"strength":.45},
	"music":{"kind":"happy","words":["이 노래 좋아","흥얼흥얼"],"strength":.55},
	"garden":{"kind":"happy","words":["초록 향이 좋아","잘 자라고 있네"],"strength":.3},
	"wake":{"kind":"happy","words":["푹 쉬었어","조금 개운해졌어"],"strength":.25},
	"tired":{"kind":"sleepy","words":["잠깐 눈 좀 붙일까","조금 쉬고 싶어"],"strength":.65,"cooldown":65.0},
	"held_long":{"kind":"angry","words":["다음엔 조금만 안아줘","발을 땅에 두고 싶어"],"strength":.4,"priority":3},
	"set_down":{"kind":"happy","words":["살며시 내려줘서 고마워","여기서 놀게"],"strength":.2,"cooldown":18.0},
	"hello":{"kind":"happy","words":["옆에 있었네","같이 있을까"],"strength":.3,"cooldown":40.0}
}
const PLAY_WORDS=["한 번 더 폴짝","한 번 더 굴려볼까","살금살금 잡았어","조금씩 놀아볼까","꼬리도 신났어","두 손으로 잡았어","천천히 한 번 더","조용히 놀아볼까","내가 찾아냈어","굴려 보니 재밌네","같이 놀아서 좋아","데굴데굴 재밌어","통통 튀어서 좋아","이번에도 잡았어","느긋하게 한 번 더","뒤뚱뒤뚱 따라갈게"]
var clock=0.0
var next_allowed=0.0
var last: Dictionary={}
var pending: Dictionary={}

func clear() -> void:
	pending.clear()
func tick(delta: float) -> void:
	clock+=maxf(0,delta)
	if not pending.is_empty() and clock>pending.expires: pending.clear()
func queue(event: String) -> bool:
	if not EVENTS.has(event): return false
	if not pending.is_empty() and pending.event==event: return false
	var spec=EVENTS[event]
	if clock-float(last.get(event,-1000.0))<float(spec.get("cooldown",12.0)): return false
	if not pending.is_empty() and int(EVENTS[pending.event].get("priority",1))>int(spec.get("priority",1)): return false
	pending={"event":event,"expires":clock+10.0,"ready":clock+.22}
	return true
func advance(m) -> bool:
	if pending.is_empty() or clock<next_allowed or clock<pending.ready: return false
	if m.held or m.carried or m.personality_active or not m.social_kind.is_empty(): return false
	if m.phase not in ["idle","ball_ready"]: return false
	var event: String=pending.event
	pending.clear()
	play(m,event,m.phase)
	return true
func play(m,event: String,followup: String="idle") -> void:
	var spec=EVENTS[event]
	var keep_ball=m.ball_visible
	m.react(spec.kind,Behavior.duration(m.species,spec.kind)*.8,followup)
	if followup=="ball_ready": m.ball_visible=keep_ball
	m.reaction_context=event
	m.reaction_strength=spec.strength
	m.reaction_words=PLAY_WORDS[m.species] if event=="toy" else spec.words[m.rng.randi_range(0,spec.words.size()-1)]
	last[event]=clock
	next_allowed=clock+m.reaction_duration+3.0

static func completed_event(id: String,m) -> String:
	if id in ["meal","bowl","snack","home_food"]: return "favorite_meal" if m.favorite_food else "meal"
	if id=="hand_feed": return "favorite_meal" if m.favorite_food else "hand_feed"
	if id in ["water","home_water"]: return "water"
	if id in ["acorn","home_play_rug","home_toy_ball","home_toy_mouse"]: return "toy"
	if id in ["cushion","home_daybed","home_lamp","doze"]: return "wake"
	if id in ["shelter","home_sofa","home_window_seat","home_tv","relax","stretch"]: return "rest"
	if id in ["home_shelf","home_reading_chair"]: return "read"
	return {"home_tea":"tea","home_vanity":"groom","groom":"groom","home_record_player":"music","home_turntable":"music","plant":"garden","lamp":"tired","empty":"empty"}.get(id,"")
