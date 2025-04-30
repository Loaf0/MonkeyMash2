extends Node3D

@onready var skin_input: OptionButton = $Menu/MainContainer/MainMenu/VBoxContainer/Option2/OptionButton
@onready var nick_input: LineEdit = $Menu/MainContainer/MainMenu/VBoxContainer/Option1/NickInput
@onready var address_input: LineEdit = $Menu/MainContainer/MainMenu/VBoxContainer/Option3/AddressInput
@onready var port_input : LineEdit = $Menu/MainContainer/MainMenu/VBoxContainer/Option4/PortInput

@onready var seeker_spawn = $Environment/Map/SeekerSpawn
@onready var hider_spawn = $Environment/Map/HiderSpawn

@onready var players_container: Node3D = $PlayersContainer
@onready var menu: Control = $Menu
@export var player_scene: PackedScene

# UI elements
@onready var player_list = $"UI/Player List"
@onready var player_list_label = $"UI/Player List/List"

# Hiders Left
@onready var hiders_left: Label = $UI/HidersLeft

# multiplayer chat
@onready var message: LineEdit = $UI/Chat/HBoxContainer/Message
@onready var send: Button = $UI/Chat/HBoxContainer/Send
@onready var chat: TextEdit = $UI/Chat/Chat
@onready var multiplayer_chat = $UI/Chat
var chat_visible = false
var local_id


func _ready():
	multiplayer_chat.modulate.a = 0.3
	menu.show()
	multiplayer_chat.set_process_input(true)
	local_id = multiplayer.get_unique_id()

	if not multiplayer.is_server():
		return
		
	Network.connect("player_connected", Callable(self, "_on_player_connected"))
	multiplayer.peer_disconnected.connect(_remove_player)

func _process(_delta: float) -> void:
	if Input.is_action_pressed("show_player_list"):
		player_list.show()
	else:
		player_list.hide()

func _on_player_connected(peer_id, player_info):
	for id in Network.players.keys():
		var player_data = Network.players[id]
		if id != peer_id:
			rpc_id(peer_id, "sync_player_skin", id, player_data["skin"])
			rpc_id(peer_id, "sync_player_name", id, player_data["nick"])
			rpc_id(peer_id, "sync_player_team", id, player_data["team"])
	_add_player(peer_id, player_info)

func _on_host_pressed():
	var port = int(port_input.text)
	menu.hide()
	Network.start_host(port)
	$UI/HostCommands.show()
	$PlayersContainer/Camera.queue_free()

func _on_join_pressed():
	menu.hide()
	var skin_color = "blue"
	if skin_input and skin_input.selected >= 0: 
		skin_color = skin_input.get_item_text(skin_input.selected).strip_edges().to_lower()
	Network.join_game(nick_input.text.strip_edges(), skin_color, address_input.text.strip_edges(), int(port_input.text))

func _add_player(id: int, player_info : Dictionary):
	if players_container.has_node(str(id)) or not multiplayer.is_server() or id == 1:
		return

	var player = player_scene.instantiate()
	player.name = str(id)

	var team = player_info["team"]
	player.set_team(team)
	player.position = get_spawn_point(team)
	players_container.add_child(player, true)

	rpc("sync_player_name", id, player_info["nick"])
	rpc("sync_player_skin", id, player_info["skin"])
	rpc("sync_player_position", id, player.position)
	rpc("sync_player_team", id, team)
	
	update_hiders_left()
	update_player_list_label()

func get_spawn_point(team: String) -> Vector3:
	if team == "seeker":
		return seeker_spawn.global_position
	else:
		return hider_spawn.global_position
	
func _remove_player(id):
	if not multiplayer.is_server() or not players_container.has_node(str(id)):
		return
	var player_node = players_container.get_node(str(id))
	if player_node:
		player_node.queue_free()

@rpc("any_peer", "call_local")
func sync_player_team(id: int, team_name: String):
	if id == 1: return
	var player = players_container.get_node(str(id))
	if player:
		player.set_team(team_name)
		player.position = get_spawn_point(team_name)

		if id == multiplayer.get_unique_id():
			Global.local_player_team = team_name
		
	update_hiders_left()
	update_player_list_label()

@rpc("any_peer", "call_local")
func sync_player_name(id: int, nickname: String):
	if id == 1: return # ignore host
	var player = players_container.get_node(str(id))
	if player:
		player.change_nick(nickname)

@rpc("any_peer", "call_local")
func sync_player_position(id: int, new_position: Vector3):
	var player = players_container.get_node(str(id))
	if player:
		player.position = new_position
		
@rpc("any_peer", "call_local")
func sync_player_skin(id: int, skin_name: String):
	if id == 1: return # ignore host
	var player = players_container.get_node(str(id))
	if player:
		player.set_player_skin(skin_name)
		
func _on_quit_pressed() -> void:
	get_tree().quit()
	
# ---------- MULTIPLAYER CHAT ----------
func toggle_chat():
	if menu.visible:
		return

	chat_visible = !chat_visible
	if chat_visible:
		multiplayer_chat.modulate.a = 1.0
		message.grab_focus()
	else:
		multiplayer_chat.modulate.a = 0.3
		message.release_focus()
		get_viewport().set_input_as_handled()

func is_chat_visible() -> bool:
	return chat_visible

func _input(event):
	if event.is_action_pressed("toggle_chat"):
		toggle_chat()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.keycode == KEY_ENTER:
		if chat_visible and message.has_focus():
			_on_send_pressed()

func _on_send_pressed() -> void:
	var trimmed_message = message.text.strip_edges()
	if trimmed_message == "":
		return # do not send empty messages

	var nick = Network.players[multiplayer.get_unique_id()]["nick"]

	rpc("msg_rpc", nick, trimmed_message)
	message.text = ""
	message.grab_focus()


func _get_random_peer() -> int:
	var peer_ids = []
	for id in Network.players.keys():
		if id != 1:
			peer_ids.append(id)
	
	if peer_ids.size() == 0:
		return -1
	
	return peer_ids[randi() % peer_ids.size()]

@rpc("any_peer", "call_local")
func msg_rpc(nick, msg):
	var new_line = str(nick, " : ", msg)

	var lines = chat.text.split("\n", false)
	lines.append(new_line)

	if lines.size() > 10:
		lines.remove_at(0)

	chat.text = "\n".join(lines)

func _on_reset_game():
	if multiplayer.get_unique_id() != 1:
		return
	
	var random_peer_id = _get_random_peer()
	if random_peer_id == -1:
		return

	# Assign seeker
	Network.players[random_peer_id]["team"] = "seeker"
	rpc_id(random_peer_id, "sync_player_team", random_peer_id, "seeker")
	
	var seeker_nick = Network.players[random_peer_id]["nick"]
	rpc("msg_rpc", "Server", "Player " + seeker_nick + " has been assigned to Seeker!")

	# Assign everyone else to hider
	for id in Network.players.keys():
		if id != 1 and id != random_peer_id:
			Network.players[id]["team"] = "hider"
			rpc_id(id, "sync_player_team", id, "hider")
	update_hiders_left()
	update_player_list_label()

@rpc("any_peer", "call_local")
func tag_hider(seeker_id: String, hider_id: String):
	var hider = players_container.get_node_or_null(hider_id)
	if not hider:
		return

	if seeker_id != "server":
		var seeker = players_container.get_node_or_null(seeker_id)
		if not seeker or seeker.team != "seeker":
			return

	if hider.team == "seeker":
		return

	hider.team = "seeker"
	hider.position = get_spawn_point("seeker")
	rpc("sync_player_team", int(hider_id), "seeker")
	rpc("msg_rpc", "Server", "Player " + Network.players[int(hider_id)]["nick"] + " is now a Seeker!")
	
	update_hiders_left()
	update_player_list_label()

func update_hiders_left():
	var hiders = 0
	var seekers = 0
	for player in players_container.get_children():
		if player.has_method("get_team"):
			if player.get_team() == "hider":
				hiders += 1
			else:
				seekers += 1
	hiders_left.text = "Hiders : " + str(hiders) + "\nSeekers : " + str(seekers)

func update_player_list_label():
	var text = ""
	for id in Network.players:
		var player = Network.players[id]
		if id != 1:
			text += "  %s (%s) (%s)\n" % [player["nick"].strip_edges(), player["team"].capitalize(), player["skin"].capitalize()]
	player_list_label.text = text

func _on_recalculate_timeout() -> void:
	# update as backup if it ever gets desynced
	update_hiders_left()
	update_player_list_label()

func _on_restart_pressed() -> void:
	if multiplayer.get_unique_id() == 1:
		_on_reset_game()
