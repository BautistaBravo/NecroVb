class_name FormationController
extends Node2D

const GRID_SIZE: Vector2i = Vector2i(6, 6)

@onready var grid_container: GridContainer = $CanvasLayer/FormationPanel/GridContainer
@onready var available_units_list: ItemList = $CanvasLayer/FormationPanel/AvailableUnitsList
@onready var back_btn: Button = $CanvasLayer/FormationPanel/BackButton

var state: GameStateModel
var selected_unit_index: int = -1

func _ready() -> void:
	state = GameManagerGlobal.state
	back_btn.pressed.connect(_on_back_pressed)
	_setup_grid_buttons()
	_render_available_units()

func _setup_grid_buttons() -> void:
	grid_container.columns = GRID_SIZE.x
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var pos := Vector2i(x, y)
			var slot_btn := Button.new()
			slot_btn.custom_minimum_size = Vector2(64, 64)
			_update_slot_text(slot_btn, pos)
			slot_btn.pressed.connect(func(): _on_slot_clicked(slot_btn, pos))
			grid_container.add_child(slot_btn)

func _update_slot_text(btn: Button, pos: Vector2i) -> void:
	if state.formation_grid.has(pos):
		var inst: SkeletonUnitInstance = state.formation_grid[pos]
		btn.text = "%s\nNv.%d" % [inst.type_data.name, inst.level]
	else:
		btn.text = "[ %d,%d ]" % [pos.x, pos.y]

func _render_available_units() -> void:
	available_units_list.clear()
	for i in range(state.active_units.size()):
		var inst: SkeletonUnitInstance = state.active_units[i]
		available_units_list.add_item("%s (T%d, Nv.%d)" % [inst.type_data.name, inst.type_data.tier, inst.level])
	available_units_list.item_selected.connect(func(idx): selected_unit_index = idx)

func _on_slot_clicked(btn: Button, pos: Vector2i) -> void:
	if selected_unit_index >= 0 and selected_unit_index < state.active_units.size():
		var inst: SkeletonUnitInstance = state.active_units[selected_unit_index]
		state.set_formation_slot(pos, inst)
	else:
		state.set_formation_slot(pos, null)
	_update_slot_text(btn, pos)

func _on_back_pressed() -> void:
	GameStateDAO.save_state(state)
	get_tree().change_scene_to_file("res://scenes/guarida/lair_scene.tscn")
