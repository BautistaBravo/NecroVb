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
	available_units_list.item_selected.connect(func(idx): selected_unit_index = idx)
	_setup_grid_buttons()
	_populate_available_units()
	_refresh_ui()

func _setup_grid_buttons() -> void:
	grid_container.columns = GRID_SIZE.x
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var pos := Vector2i(x, y)
			var slot_btn := Button.new()
			slot_btn.custom_minimum_size = Vector2(64, 64)
			slot_btn.expand_icon = true
			slot_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot_btn.add_theme_constant_override("icon_max_width", 64)

			if x < 3:
				slot_btn.modulate = Color(1.0, 0.5, 0.5) # Rojo (Zona enemiga)
			else:
				slot_btn.modulate = Color(0.5, 1.0, 0.5) # Verde (Zona jugador)

			slot_btn.pressed.connect(func(): _on_slot_clicked(pos))
			grid_container.add_child(slot_btn)

func _refresh_ui() -> void:
	_refresh_grid_buttons()
	_update_available_units()

func _refresh_grid_buttons() -> void:
	var idx = 0
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var pos := Vector2i(x, y)
			var btn: Button = grid_container.get_child(idx)

			if state.formation_grid.has(pos):
				var inst: SkeletonUnitInstance = state.formation_grid[pos]
				btn.text = ""
				btn.icon = inst.type_data.sprite_texture
			else:
				btn.icon = null
				if pos.x < 3:
					btn.text = "Enemigo"
				else:
					btn.text = "[ %d,%d ]" % [pos.x, pos.y]
			idx += 1

func _populate_available_units() -> void:
	available_units_list.clear()
	for i in range(state.active_units.size()):
		var inst: SkeletonUnitInstance = state.active_units[i]
		var base_text = "%s (T%d, Nv.%d)" % [inst.type_data.name, inst.type_data.tier, inst.level]
		available_units_list.add_item(base_text)
		if inst.type_data.sprite_texture:
			available_units_list.set_item_icon(i, inst.type_data.sprite_texture)

func _update_available_units() -> void:
	if available_units_list.item_count != state.active_units.size():
		_populate_available_units()

	var placed_units = state.formation_grid.values()

	for i in range(state.active_units.size()):
		var inst: SkeletonUnitInstance = state.active_units[i]
		var base_text = "%s (T%d, Nv.%d)" % [inst.type_data.name, inst.type_data.tier, inst.level]

		if inst in placed_units:
			available_units_list.set_item_text(i, base_text + " (Colocado)")
			available_units_list.set_item_disabled(i, true)
			available_units_list.set_item_custom_fg_color(i, Color(0.5, 0.5, 0.5))
		else:
			available_units_list.set_item_text(i, base_text)
			available_units_list.set_item_disabled(i, false)
			available_units_list.set_item_custom_fg_color(i, Color(1, 1, 1))

func _on_slot_clicked(pos: Vector2i) -> void:
	if pos.x < 3:
		print("DEBUG: No puedes colocar unidades en la zona enemiga (x < 3).")
		return

	# Si cliqueamos una celda y no hay unidad válida seleccionada en la lista, quitamos la de la celda
	if selected_unit_index < 0 or selected_unit_index >= state.active_units.size() or available_units_list.is_item_disabled(selected_unit_index):
		if state.formation_grid.has(pos):
			print("DEBUG: Removiendo unidad de la posición ", pos)
		state.set_formation_slot(pos, null)
	else:
		var inst: SkeletonUnitInstance = state.active_units[selected_unit_index]
		print("DEBUG: Colocando unidad ", inst.type_data.name, " en la posición ", pos)
		state.set_formation_slot(pos, inst)
		# Deseleccionamos automáticamente después de colocar
		available_units_list.deselect_all()
		selected_unit_index = -1

	_refresh_ui()

func _on_back_pressed() -> void:
	GameStateDAO.save_state(state)
	get_tree().change_scene_to_file("res://Scenes/guarida/guarida.tscn")
