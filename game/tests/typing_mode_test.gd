extends SceneTree
const State=preload("res://scripts/pet_state.gd")
const Bridge=preload("res://scripts/typing_input.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var state=State.new()
	state.load_play_mode({})
	assert(state.play_mode=="living" and state.typing_corner==3 and state.typing_size==1)
	state.load_play_mode({"play_mode":"invalid","typing_corner":-90,"typing_size":100})
	assert(state.play_mode=="living" and state.typing_corner==0 and state.typing_size==2)
	state.play_mode="typing"
	state.typing_corner=2
	state.typing_size=0
	state.furniture={"sofa":[123,456,true]}
	state.growth={"0":36}
	state.save_path="user://typing-mode-test.json"
	state.save_game()
	var loaded=State.new()
	loaded.save_path=state.save_path
	loaded.load_game()
	assert(loaded.play_mode=="typing" and loaded.typing_corner==2 and loaded.typing_size==0)
	assert(loaded.furniture.sofa[0]==123 and loaded.furniture.sofa[1]==456 and loaded.furniture.sofa[2]==true and loaded.growth["0"]==36)
	DirAccess.remove_absolute(state.save_path)
	var bridge=Bridge.new()
	bridge.socket=PacketPeerUDP.new()
	assert(bridge.socket.bind(0,"127.0.0.1")==OK)
	bridge.token="0123456789abcdef0123456789abcdef"
	var sender=PacketPeerUDP.new()
	sender.set_dest_address("127.0.0.1",bridge.socket.get_local_port())
	for packet in ["wrong:400",bridge.token+":2",bridge.token+":2",bridge.token+":1",bridge.token+":no"]:
		sender.put_packet(packet.to_ascii_buffer())
	await create_timer(.1).timeout
	assert(bridge.poll()==2 and bridge.connected,"Token, duplicate and monotonic checks")
	sender.put_packet((bridge.token+":102").to_ascii_buffer())
	await create_timer(.1).timeout
	assert(bridge.poll()==100,"A packet with many presses preserves the count")
	bridge.stop()
	sender.close()
	assert(bridge.socket==null and not bridge.connected)
	print("TYPING_STATE_AND_TRANSPORT_PASS")
	quit()
