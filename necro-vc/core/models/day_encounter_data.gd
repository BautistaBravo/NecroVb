class_name DayEncounterData
extends Resource

@export_group("Configuración del Día")
@export var day_number: int = 1
@export var completion_soul_bonus: int = 25

@export_group("Enemigos del Encuentro")
## Lista de tipos de enemigos que aparecen este día
@export var enemies: Array[EnemyData] = []

## Posiciones fijas opcionales en la cuadrícula 6x6 (X: 3..5, Y: 0..5)
## Si está vacío, se posicionan aleatoriamente en el lado derecho
@export var spawn_positions: Array[Vector2i] = []
