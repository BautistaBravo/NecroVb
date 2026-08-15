class_name GameStateDAO
extends RefCounted

const SAVE_PATH: String = "user://save_game.json"

static func save_state(model: GameStateModel) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return false
		
	var active_serialized: Array[Dictionary] = []
	for inst in model.active_units:
		active_serialized.append(_serialize_instance(inst))
		
	var fallen_serialized: Array[Dictionary] = []
	for inst in model.fallen_units:
		fallen_serialized.append(_serialize_instance(inst))
		
	var formation_serialized := {}
	for pos in model.formation_grid.keys():
		var inst: SkeletonUnitInstance = model.formation_grid[pos]
		var pos_key = "%d,%d" % [pos.x, pos.y]
		formation_serialized[pos_key] = inst.uid
		
	var data := {
		"souls": model.souls,
		"current_day": model.current_day,
		"max_units": model.max_units,
		"active_units": active_serialized,
		"fallen_units": fallen_serialized,
		"formation_grid": formation_serialized
	}
	
	file.store_string(JSON.stringify(data, "\t"))
	return true

static func load_state() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		return json.data
	return {}

static func _serialize_instance(inst: SkeletonUnitInstance) -> Dictionary:
	return {
		"uid": inst.uid,
		"type_id": inst.type_data.id if inst.type_data else "skeleton_t1",
		"level": inst.level,
		"current_exp": inst.current_exp,
		"total_kills": inst.total_kills,
		"total_damage_dealt": inst.total_damage_dealt
	}
