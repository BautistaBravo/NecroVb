class_name EnemyData
extends Resource

enum AttackType {
	MELEE_SHORT,  ## 1 casilla
	MELEE_MEDIUM, ## 2 casillas
	RANGED        ## 3-4 casillas
}

@export var id: String = "peasant_t1"
@export var name: String = "Aldeano"
@export var max_hp: int = 15
@export var attack_power: int = 4
@export var speed: int = 8
@export var attack_type: AttackType = AttackType.MELEE_SHORT
@export var min_attack_range: int = 1
@export var max_attack_range: int = 1
@export var move_range: int = 1
@export var soul_reward: int = 15
@export var exp_reward: int = 25              ## Experiencia otorgada al esqueleto que le dé el último golpe
@export var sprite_texture: Texture2D
