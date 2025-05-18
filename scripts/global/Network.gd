extends Node

const SERVER_ADDRESS: String = "127.0.0.1"
var SERVER_PORT: int = 8080
const MAX_PLAYERS : int = 12

var players = {}
var player_info = {
	"nick" : "host",
	"skin" : "blue",
	"team" : "hider"
}

signal player_connected(peer_id, player_info)
signal server_disconnected

func _process(_delta):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit(0)
		
func _ready() -> void:
	multiplayer.server_disconnected.connect(_on_connection_failed)
	multiplayer.connection_failed.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.connected_to_server.connect(_on_connected_ok)

func start_host(input_port: int = SERVER_PORT):
	var peer = ENetMultiplayerPeer.new()
	var port = int(input_port)
	if port == 0:
		port = SERVER_PORT
	var error = peer.create_server(port, MAX_PLAYERS)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	
	players[1] = player_info
	player_connected.emit(1, player_info)
	
func join_game(nickname: String, skin_color: String, address: String = SERVER_ADDRESS, input_port: int = SERVER_PORT):
	var peer = ENetMultiplayerPeer.new()
	var port = int(input_port)
	if port == 0:
		port = SERVER_PORT
	var error = peer.create_client(address, port)
	if error:
		return error

	multiplayer.multiplayer_peer = peer
	if !nickname:
		nickname = "Player_" + str(multiplayer.get_unique_id())
	if !skin_color or skin_color.is_empty():
		skin_color = "blue"
	player_info["nick"] = nickname
	player_info["skin"] = skin_color
	player_info["team"] = "hider"
	
func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)
	
func _on_player_connected(id):
	_register_player.rpc_id(id, player_info)
	
@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)
	#print("debug function _register_player on Network.gd: ", players, "\n")
	
func _on_player_disconnected(id):
	players.erase(id)
	
func _on_connection_failed():
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()
	
