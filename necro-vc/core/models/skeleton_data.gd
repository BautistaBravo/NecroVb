class_name SkeletonData
extends Resource

enum AttackType {
	MELEE_SHORT,  ## Corta distancia (1 casilla)
	MELEE_MEDIUM, ## Media distancia (2 casillas)
	RANGED        ## Larga distancia (3-4 casillas)
}

@export_group("Identificación")
@export var id: String = "skeleton_t1"
@export var name: String = "Esqueleto Básico"
@export var tier: int = 1

@export_group("Economía")
@export var summon_cost: int = 10
@export var souls_per_day: int = 2
@export var merge_bonus_souls: int = 5

@export_group("Estadísticas Base (Nivel 1)")
@export var base_max_hp: int = 20
@export var base_attack: int = 5
@export var base_speed: int = 10
@export var attack_type: AttackType = AttackType.MELEE_SHORT
@export var min_attack_range: int = 1
@export var max_attack_range: int = 1
@export var move_range: int = 1

@export_group("Crecimiento de Estadísticas (Por Nivel)")
@export var hp_growth_per_level: int = 4       ## HP adicional por nivel
@export var attack_growth_per_level: int = 2   ## Ataque adicional por nivel
@export var speed_growth_per_level: int = 1    ## Velocidad adicional cada N niveles

@export_group("Curva de Experiencia")
@export var base_exp_required: int = 50        ## EXP requerida para Nivel 2
@export var exp_growth_multiplier: float = 1.3  ## Multiplicador de EXP por nivel (ej. 50 -> 65 -> 84)
@export var exp_per_damage_point: int = 1      ## EXP ganada por cada punto de daño infligido
@export var kill_bonus_exp: int = 10           ## EXP extra fija por eliminar un enemigo

@export_group("Visual")
@export var sprite_texture: Texture2D
@export var scale_multiplier: float = 1.0

@export_group("Evolución")
@export var next_evolution: SkeletonData

func get_revive_cost() -> int:
	return int(summon_cost / 2.0)

func can_merge_with(other: SkeletonData) -> bool:
	if not other:
		return false
	return self.tier == other.tier and self.next_evolution != null

func get_next_tier() -> SkeletonData:
	return next_evolution
