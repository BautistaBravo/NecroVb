class_name SkeletonUnitInstance
extends RefCounted

signal leveled_up(new_level: int, unit_instance: SkeletonUnitInstance)
signal exp_gained(amount: int, current_exp: int, max_exp: int)

var uid: String
var type_data: SkeletonData

var level: int = 1
var current_exp: int = 0
var total_kills: int = 0
var total_damage_dealt: int = 0

func _init(p_type_data: SkeletonData = null, p_level: int = 1) -> void:
	uid = str(ResourceUID.create_id())
	type_data = p_type_data
	level = p_level

## HP Máximo dinámico según nivel y crecimiento del tipo
func get_max_hp() -> int:
	if not type_data: return 10
	return type_data.base_max_hp + (level - 1) * type_data.hp_growth_per_level

## Poder de Ataque dinámico
func get_attack_power() -> int:
	if not type_data: return 5
	return type_data.base_attack + (level - 1) * type_data.attack_growth_per_level

## Velocidad dinámica
func get_speed() -> int:
	if not type_data: return 10
	return type_data.base_speed + int((level - 1) * type_data.speed_growth_per_level)

## EXP necesaria para alcanzar el siguiente nivel
func get_exp_to_next_level() -> int:
	if not type_data: return 50
	return int(type_data.base_exp_required * pow(type_data.exp_growth_multiplier, level - 1))

## Añadir experiencia y gestionar subida de nivel
func add_exp(amount: int) -> bool:
	if amount <= 0: return false
	current_exp += amount
	var has_leveled: bool = false
	
	var needed = get_exp_to_next_level()
	while current_exp >= needed:
		current_exp -= needed
		level += 1
		has_leveled = true
		leveled_up.emit(level, self)
		needed = get_exp_to_next_level()
		
	exp_gained.emit(amount, current_exp, needed)
	return has_leveled

## Registro de combate
func record_damage(dmg: int) -> void:
	total_damage_dealt += dmg
	var exp_gained_val = dmg * (type_data.exp_per_damage_point if type_data else 1)
	add_exp(exp_gained_val)

func record_kill(enemy_exp_reward: int = 0) -> void:
	total_kills += 1
	var total_reward = (type_data.kill_bonus_exp if type_data else 10) + enemy_exp_reward
	add_exp(total_reward)
