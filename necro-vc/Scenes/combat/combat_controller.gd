
class_name CombatController
extends Node2D

const GRID_SIZE: Vector2i = Vector2i(6, 6)

enum CombatPhase { PLANNING, EXECUTING, FINISHED }
enum InputMode { NONE, SELECTING_MOVE, SELECTING_ATTACK }

class CombatEntity:
	var unit_instance: SkeletonUnitInstance # Si es jugador
	var enemy_data: EnemyData               # Si es enemigo
	var is_player: bool
	var current_hp: int
	var grid_pos: Vector2i
	var speed: int
	# Acciones planificadas
	var planned_move_pos: Vector2i = Vector2i(-1, -1)
	var planned_attack_target: CombatEntity = null

	func get_name() -> String:
		if is_player and unit_instance and unit_instance.type_data:
			return "%s (Nv.%d)" % [unit_instance.type_data.name, unit_instance.level]
		elif enemy_data:
			return enemy_data.name
		return "Unidad"

	func get_max_hp() -> int:
		if is_player and unit_instance:
			return unit_instance.get_max_hp()
		elif enemy_data:
			return enemy_data.max_hp
		return 10

	func get_attack_power() -> int:
		if is_player and unit_instance:
			return unit_instance.get_attack_power()
		elif enemy_data:
			return enemy_data.attack_power
		return 5

	func get_min_range() -> int:
		if is_player and unit_instance and unit_instance.type_data:
			return unit_instance.type_data.min_attack_range
		elif enemy_data:
			return enemy_data.min_attack_range
		return 1

	func get_max_range() -> int:
		if is_player and unit_instance and unit_instance.type_data:
			return unit_instance.type_data.max_attack_range
		elif enemy_data:
			return enemy_data.max_attack_range
		return 1

	func get_move_range() -> int:
		if is_player and unit_instance and unit_instance.type_data:
			return unit_instance.type_data.move_range
		elif enemy_data:
			return enemy_data.move_range
		return 1

@export var day_encounters: Array[DayEncounterData] = []
@export var default_enemy_pool: Array[EnemyData] = []

@onready var log_label: Label = $CanvasLayer/LogLabel
@onready var current_unit_label: Label = $CanvasLayer/CurrentUnitLabel
@onready var move_btn: Button = $CanvasLayer/CommandPanel/MoveButton
@onready var attack_btn: Button = $CanvasLayer/CommandPanel/AttackButton
@onready var next_or_execute_btn: Button = $CanvasLayer/CommandPanel/NextOrExecuteButton
@onready var grid_container: GridContainer = $CanvasLayer/GridPanel/GridContainer

var state: GameStateModel
var entities: Array[CombatEntity] = []
var turn_order: Array[CombatEntity] = []
var current_player_unit_idx: int = 0
var current_phase: CombatPhase = CombatPhase.PLANNING
var current_input_mode: InputMode = InputMode.NONE
var round_number: int = 1

func _ready() -> void:
	state = GameManagerGlobal.state
	move_btn.pressed.connect(_on_move_btn_pressed)
	attack_btn.pressed.connect(_on_attack_btn_pressed)
	next_or_execute_btn.pressed.connect(_on_next_or_execute_pressed)
	_setup_grid_ui()
	_initialize_combat()

func _setup_grid_ui() -> void:
	grid_container.columns = GRID_SIZE.x
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var pos := Vector2i(x, y)
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(56, 56)
			btn.pressed.connect(func(): _on_grid_tile_clicked(pos))
			grid_container.add_child(btn)

func _initialize_combat() -> void:
	entities.clear()
	# 1. Cargar formación de instancias del jugador
	for pos in state.formation_grid.keys():
		var instance = state.formation_grid[pos]
		var ent := CombatEntity.new()
		ent.unit_instance = instance
		ent.is_player = true
		ent.current_hp = instance.get_max_hp()
		ent.grid_pos = pos
		ent.speed = instance.get_speed()
		entities.append(ent)
		
	# 2. Generar enemigos
	_spawn_daily_enemies()
	_start_new_round()

func _spawn_daily_enemies() -> void:
	var encounter: DayEncounterData = null
	for enc in day_encounters:
		if enc.day_number == state.current_day:
			encounter = enc
			break
			
	if encounter and not encounter.enemies.is_empty():
		for i in range(encounter.enemies.size()):
			var enemy_data = encounter.enemies[i]
			var ent := CombatEntity.new()
			ent.enemy_data = enemy_data
			ent.is_player = false
			ent.current_hp = enemy_data.max_hp
			ent.speed = enemy_data.speed
			ent.grid_pos = encounter.spawn_positions[i] if i < encounter.spawn_positions.size() else Vector2i(randi_range(3, 5), randi_range(0, 5))
			entities.append(ent)
	else:
		var count = min(6, state.current_day + 1)
		for i in range(count):
			if default_enemy_pool.is_empty(): break
			var enemy_data = default_enemy_pool.pick_random()
			var ent := CombatEntity.new()
			ent.enemy_data = enemy_data
			ent.is_player = false
			ent.current_hp = enemy_data.max_hp
			ent.speed = enemy_data.speed
			ent.grid_pos = Vector2i(randi_range(3, 5), randi_range(0, 5))
			entities.append(ent)

func _start_new_round() -> void:
	current_phase = CombatPhase.PLANNING
	turn_order = entities.filter(func(e): return e.current_hp > 0)
	turn_order.shuffle()
	turn_order.sort_custom(func(a, b): return a.speed > b.speed)
	
	for ent in turn_order:
		ent.planned_move_pos = ent.grid_pos
		ent.planned_attack_target = null
		
	current_player_unit_idx = 0
	_select_current_player_unit_for_planning()
	_update_grid_ui_display()
	_update_log("--- Ronda %d: Planificación ---" % round_number)

func _get_alive_player_units() -> Array[CombatEntity]:
	return turn_order.filter(func(e): return e.is_player and e.current_hp > 0)

func _select_current_player_unit_for_planning() -> void:
	var player_units = _get_alive_player_units()
	if player_units.is_empty():
		_check_battle_outcome()
		return
		
	if current_player_unit_idx >= player_units.size():
		current_unit_label.text = "Todas las unidades planificadas."
		next_or_execute_btn.text = "Realizar Turno"
		move_btn.disabled = true
		attack_btn.disabled = true
		return
		
	var active_unit = player_units[current_player_unit_idx]
	current_unit_label.text = "Unidad: %s (Vel: %d, HP: %d/%d, EXP: %d/%d)" % [
		active_unit.get_name(), active_unit.speed, active_unit.current_hp, active_unit.get_max_hp(),
		active_unit.unit_instance.current_exp, active_unit.unit_instance.get_exp_to_next_level()
	]
	move_btn.disabled = false
	attack_btn.disabled = false
	next_or_execute_btn.text = "Siguiente Unidad" if current_player_unit_idx < player_units.size() - 1 else "Listo para Realizar Turno"

func _on_move_btn_pressed() -> void:
	current_input_mode = InputMode.SELECTING_MOVE
	_update_log("Selecciona una casilla para moverte o embestir.")

func _on_attack_btn_pressed() -> void:
	current_input_mode = InputMode.SELECTING_ATTACK
	_update_log("Selecciona un enemigo para atacar.")

func _on_next_or_execute_pressed() -> void:
	var player_units = _get_alive_player_units()
	if current_player_unit_idx < player_units.size() - 1:
		current_player_unit_idx += 1
		_select_current_player_unit_for_planning()
	elif current_player_unit_idx == player_units.size() - 1 and next_or_execute_btn.text != "Realizar Turno":
		current_player_unit_idx += 1
		_select_current_player_unit_for_planning()
	else:
		_execute_turn_phase()

func _on_grid_tile_clicked(pos: Vector2i) -> void:
	var player_units = _get_alive_player_units()
	if current_player_unit_idx >= player_units.size(): return
	var active_unit = player_units[current_player_unit_idx]
	
	if current_input_mode == InputMode.SELECTING_MOVE:
		var dist = _get_grid_distance(active_unit.grid_pos, pos)
		if dist <= active_unit.get_move_range() and _is_in_bounds(pos):
			var occupant = _get_entity_at(pos)
			if occupant and occupant != active_unit and occupant.is_player:
				_update_log("No puedes moverte a la casilla de un aliado.")
				return
			active_unit.planned_move_pos = pos
			current_input_mode = InputMode.NONE
			_update_grid_ui_display()
			_update_log("%s se moverá a (%d, %d)" % [active_unit.get_name(), pos.x, pos.y])
	elif current_input_mode == InputMode.SELECTING_ATTACK:
		var target = _get_entity_at(pos)
		if target and not target.is_player and target.current_hp > 0:
			var from_pos = active_unit.planned_move_pos if active_unit.planned_move_pos != Vector2i(-1, -1) else active_unit.grid_pos
			var dist = _get_grid_distance(from_pos, target.grid_pos)
			if dist >= active_unit.get_min_range() and dist <= active_unit.get_max_range():
				active_unit.planned_attack_target = target
				current_input_mode = InputMode.NONE
				_update_grid_ui_display()
				_update_log("%s atacará a %s" % [active_unit.get_name(), target.get_name()])
			else:
				_update_log("Objetivo fuera de rango de ataque.")
		else:
			_update_log("Selecciona un enemigo vivo.")

func _execute_turn_phase() -> void:
	current_phase = CombatPhase.EXECUTING
	move_btn.disabled = true
	attack_btn.disabled = true
	next_or_execute_btn.disabled = true
	_update_log("¡Ejecutando acciones por orden de velocidad!")
	
	for ent in turn_order:
		if ent.current_hp <= 0: continue
		if ent.is_player:
			if ent.planned_move_pos != Vector2i(-1, -1) and ent.planned_move_pos != ent.grid_pos:
				_handle_movement_or_collision(ent, ent.planned_move_pos)
			if ent.current_hp > 0 and ent.planned_attack_target and ent.planned_attack_target.current_hp > 0:
				var dist = _get_grid_distance(ent.grid_pos, ent.planned_attack_target.grid_pos)
				if dist >= ent.get_min_range() and dist <= ent.get_max_range():
					_perform_attack(ent, ent.planned_attack_target)
		else:
			var target = _get_closest_target(ent, true)
			if target:
				_enemy_ai_turn(ent, target)
				
		_update_grid_ui_display()
		if _check_battle_outcome(): return
		
	round_number += 1
	next_or_execute_btn.disabled = false
	_start_new_round()

func _handle_movement_or_collision(mover: CombatEntity, target_pos: Vector2i) -> void:
	if mover.current_hp <= 0: return
	var occupant = _get_entity_at(target_pos)
	if occupant == null:
		mover.grid_pos = target_pos
		return
	if occupant == mover: return
	if occupant.is_player == mover.is_player:
		return
		
	var hp_mover: int = mover.current_hp
	var hp_occupant: int = occupant.current_hp
	var diff: int = abs(hp_mover - hp_occupant)
	var collision_dmg: int = int(diff * 0.10)
	
	if hp_mover < hp_occupant:
		mover.current_hp -= collision_dmg
		if mover.current_hp <= 0 and mover.is_player:
			state.register_fallen_unit(mover.unit_instance)
	elif hp_occupant < hp_mover:
		occupant.current_hp -= collision_dmg
		if mover.is_player:
			mover.unit_instance.record_damage(collision_dmg)
		if occupant.current_hp <= 0:
			if occupant.is_player:
				state.register_fallen_unit(occupant.unit_instance)
			else:
				if mover.is_player:
					mover.unit_instance.record_kill(occupant.enemy_data.exp_reward)
			mover.grid_pos = target_pos

func _enemy_ai_turn(enemy: CombatEntity, target: CombatEntity) -> void:
	var dist = _get_grid_distance(enemy.grid_pos, target.grid_pos)
	var min_r = enemy.get_min_range()
	var max_r = enemy.get_max_range()
	
	var is_ranged = max_r > 1
	var moved = false

	if is_ranged:
		# Lógica de Rango: Si está cuerpo a cuerpo (dist = 1), huye.
		if dist == 1:
			var diff = enemy.grid_pos - target.grid_pos # Hacia el lado opuesto
			var step = Vector2i(clampi(diff.x, -1, 1), clampi(diff.y, -1, 1))

			# Si diff es 0 (ej están ocupando el mismo tile por error), movemos aleatoriamente
			if step == Vector2i.ZERO:
				step = Vector2i(1, 0) if randf() > 0.5 else Vector2i(0, 1)

			var new_pos = enemy.grid_pos + step
			if _is_in_bounds(new_pos):
				_handle_movement_or_collision(enemy, new_pos)
				moved = true
		elif dist > max_r:
			# Si está fuera de rango máximo, no hace nada (según las reglas pedidas: "no se muevan a menos que...")
			# Solo se quedan quietos si no están en rango.
			# Si quisieras que se acerquen para disparar, aquí haríamos un paso. Pero la instrucción fue:
			# "los de rango no se muevan a menos que tengan a un esqueleto al lado"
			pass
	else:
		# Lógica de Melee: Se acerca si no está en rango.
		if dist > max_r or dist < min_r:
			var diff = target.grid_pos - enemy.grid_pos
			var step = Vector2i(clampi(diff.x, -1, 1), clampi(diff.y, -1, 1))
			var new_pos = enemy.grid_pos + step
			if _is_in_bounds(new_pos):
				_handle_movement_or_collision(enemy, new_pos)
				moved = true

	if moved:
		dist = _get_grid_distance(enemy.grid_pos, target.grid_pos)
		
	if enemy.current_hp > 0 and target.current_hp > 0 and dist >= min_r and dist <= max_r:
		_perform_attack(enemy, target)

func _perform_attack(attacker: CombatEntity, defender: CombatEntity) -> void:
	var dmg: int = attacker.get_attack_power()
	defender.current_hp -= dmg
	_update_log("%s atacó a %s causando %d daño (HP: %d)" % [attacker.get_name(), defender.get_name(), dmg, max(0, defender.current_hp)])
	
	# Otorgar EXP al jugador por daño realizado
	if attacker.is_player and attacker.unit_instance:
		var old_level = attacker.unit_instance.level
		attacker.unit_instance.record_damage(dmg)
		if attacker.unit_instance.level > old_level:
			_update_log("★ ¡%s subió al Nivel %d! HP Max: %d, Ataque: %d" % [
				attacker.get_name(), attacker.unit_instance.level, attacker.get_max_hp(), attacker.get_attack_power()
			])
			
	if defender.current_hp <= 0:
		_update_log("¡%s cayó en combate!" % defender.get_name())
		if defender.is_player:
			state.register_fallen_unit(defender.unit_instance)
		else:
			# Recompensa de kill al atacante
			if attacker.is_player and attacker.unit_instance:
				attacker.unit_instance.record_kill(defender.enemy_data.exp_reward)

func _get_grid_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(abs(a.x - b.x), abs(a.y - b.y))

func _is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_SIZE.x and pos.y >= 0 and pos.y < GRID_SIZE.y

func _get_entity_at(pos: Vector2i) -> CombatEntity:
	for ent in entities:
		if ent.current_hp > 0 and ent.grid_pos == pos: return ent
	return null

func _get_closest_target(unit: CombatEntity, seek_player: bool) -> CombatEntity:
	var valid = entities.filter(func(e): return e.is_player == seek_player and e.current_hp > 0)
	var closest: CombatEntity = null
	var min_d: int = 999
	for t in valid:
		var d = _get_grid_distance(unit.grid_pos, t.grid_pos)
		if d < min_d:
			min_d = d
			closest = t
	return closest

func _update_grid_ui_display() -> void:
	var buttons = grid_container.get_children()
	for i in range(buttons.size()):
		var x = i % GRID_SIZE.x
		var y = i / GRID_SIZE.x
		var pos = Vector2i(x, y)
		var btn: Button = buttons[i]
		var ent = _get_entity_at(pos)
		if ent:
			var tag = "[P]" if ent.is_player else "[E]"
			btn.text = "%s %s\nHP:%d/%d" % [tag, ent.get_name(), ent.current_hp, ent.get_max_hp()]
		else:
			btn.text = "[ %d,%d ]" % [x, y]

func _check_battle_outcome() -> bool:
	var alive_p = entities.filter(func(e): return e.is_player and e.current_hp > 0)
	var alive_e = entities.filter(func(e): return not e.is_player and e.current_hp > 0)
	if alive_e.is_empty():
		current_phase = CombatPhase.FINISHED
		var reward = state.current_day * 20
		state.souls += reward
		_update_log("¡Victoria! Ganaste %d almas. Volviendo a la Guarida..." % reward)
		_return_to_lair()
		return true
	elif alive_p.is_empty():
		current_phase = CombatPhase.FINISHED
		_update_log("Derrota. Todos los esqueletos cayeron. Volviendo a la Guarida...")
		_return_to_lair()
		return true
	return false

func _return_to_lair() -> void:
	state.current_day += 1
	GameStateDAO.save_state(state)
	get_tree().create_timer(2.5).timeout.connect(func():
		get_tree().change_scene_to_file("res://Scenes/guarida/guarida.tscn")
	)

func _update_log(msg: String) -> void:
	if log_label:
		log_label.text = msg
