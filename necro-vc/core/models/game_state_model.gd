class_name GameStateModel
extends RefCounted

signal souls_changed(new_amount: int)
signal day_advanced(new_day: int)
signal unit_list_changed(current_count: int, max_limit: int)
signal fallen_units_changed(fallen_count: int)
signal formation_changed

var souls: int = 50:
	set(value):
		souls = max(0, value)
		souls_changed.emit(souls)

var current_day: int = 1:
	set(value):
		current_day = max(1, value)
		day_advanced.emit(current_day)

var max_units: int = 12:
	set(value):
		max_units = max(1, value)
		unit_list_changed.emit(active_units.size(), max_units)

# Lista de instancias individuales de esqueletos vivos
var active_units: Array[SkeletonUnitInstance] = []

# Lista de instancias de esqueletos caídos en combate
var fallen_units: Array[SkeletonUnitInstance] = []

# Cuadrícula de formación 6x6: Dictionary[Vector2i, SkeletonUnitInstance]
var formation_grid: Dictionary = {}

func add_unit(unit_instance: SkeletonUnitInstance) -> bool:
	if active_units.size() >= max_units:
		return false
	active_units.append(unit_instance)
	unit_list_changed.emit(active_units.size(), max_units)
	return true

func remove_unit(unit_instance: SkeletonUnitInstance) -> bool:
	var idx = active_units.find(unit_instance)
	if idx != -1:
		active_units.remove_at(idx)
		for pos in formation_grid.keys():
			if formation_grid[pos] == unit_instance:
				formation_grid.erase(pos)
				formation_changed.emit()
				break
		unit_list_changed.emit(active_units.size(), max_units)
		return true
	return false

func register_fallen_unit(unit_instance: SkeletonUnitInstance) -> void:
	remove_unit(unit_instance)
	fallen_units.append(unit_instance)
	fallen_units_changed.emit(fallen_units.size())

func revive_fallen_unit(unit_instance: SkeletonUnitInstance) -> bool:
	var cost = unit_instance.type_data.get_revive_cost()
	if souls < cost or active_units.size() >= max_units:
		return false
	var idx = fallen_units.find(unit_instance)
	if idx != -1:
		souls -= cost
		fallen_units.remove_at(idx)
		add_unit(unit_instance)
		fallen_units_changed.emit(fallen_units.size())
		return true
	return false

func set_formation_slot(grid_pos: Vector2i, unit_instance: SkeletonUnitInstance) -> bool:
	if grid_pos.x < 0 or grid_pos.x >= 6 or grid_pos.y < 0 or grid_pos.y >= 6:
		return false
	if unit_instance == null:
		formation_grid.erase(grid_pos)
	else:
		for pos in formation_grid.keys():
			if formation_grid[pos] == unit_instance:
				formation_grid.erase(pos)
		formation_grid[grid_pos] = unit_instance
	formation_changed.emit()
	return true
