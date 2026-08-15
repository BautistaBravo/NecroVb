extends Node

var state: GameStateModel

func _ready() -> void:
	init_new_game()

func init_new_game() -> void:
	state = GameStateModel.new()

func load_game() -> bool:
	var data = GameStateDAO.load_state()
	if data.is_empty():
		return false
	state = GameStateModel.new()
	state.souls = data.get("souls", 50)
	state.current_day = data.get("current_day", 1)
	state.max_units = data.get("max_units", 12)
	return true
