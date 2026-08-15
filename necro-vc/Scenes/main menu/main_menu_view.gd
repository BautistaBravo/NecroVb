class_name MainMenuView
extends Control

@onready var new_game_btn: Button = $VBoxContainer/NewGameButton
@onready var load_game_btn: Button = $VBoxContainer/LoadGameButton

func _ready() -> void:
	new_game_btn.pressed.connect(_on_new_game_pressed)
	load_game_btn.pressed.connect(_on_load_game_pressed)
	load_game_btn.disabled = not FileAccess.file_exists(GameStateDAO.SAVE_PATH)

func _on_new_game_pressed() -> void:
	GameManagerGlobal.init_new_game()
	get_tree().change_scene_to_file("res://Scenes/guarida/guarida.tscn")

func _on_load_game_pressed() -> void:
	if GameManagerGlobal.load_game():
		get_tree().change_scene_to_file("res://Scenes/guarida/guarida.tscn")
