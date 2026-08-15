class_name LairController
extends Node2D

@export var default_skeleton: SkeletonData
@onready var spawn_area_rect: ReferenceRect = $SpawnAreaRect
var skeleton_view_scene: PackedScene = preload("res://Scenes/entities/skeleton_view.tscn")

@onready var souls_label: Label = $CanvasLayer/HUD/SoulsLabel
@onready var units_label: Label = $CanvasLayer/HUD/UnitsLabel
@onready var day_label: Label = $CanvasLayer/HUD/DayLabel
@onready var fallen_container: VBoxContainer = $CanvasLayer/GraveyardPanel/FallenList
@onready var summon_btn: Button = $CanvasLayer/HUD/SummonButton
@onready var formation_btn: Button = $CanvasLayer/HUD/FormationButton
@onready var next_day_btn: Button = $CanvasLayer/HUD/NextDayButton
@onready var entities_container: Node2D = $EntitiesContainer

var state: GameStateModel
var selected_view: SkeletonView = null

func _ready() -> void:
	state = GameManagerGlobal.state
	_bind_ui()
	_refresh_all_views()
	_spawn_existing_active_units()

func _bind_ui() -> void:
	summon_btn.pressed.connect(_on_summon_pressed)
	formation_btn.pressed.connect(_on_formation_pressed)
	next_day_btn.pressed.connect(_on_next_day_pressed)

	state.souls_changed.connect(func(val): souls_label.text = "Almas: %d" % val)
	state.unit_list_changed.connect(func(c, m): units_label.text = "Esqueletos: %d / %d" % [c, m])
	state.day_advanced.connect(func(d): day_label.text = "Día: %d" % d)
	state.fallen_units_changed.connect(func(_c): _render_fallen_list())

func _refresh_all_views() -> void:
	souls_label.text = "Almas: %d" % state.souls
	units_label.text = "Esqueletos: %d / %d" % [state.active_units.size(), state.max_units]
	day_label.text = "Día: %d" % state.current_day
	_render_fallen_list()

func _spawn_existing_active_units() -> void:
	for child in entities_container.get_children():
		child.queue_free()
	for instance in state.active_units:
		_spawn_skeleton_view(instance)

func _on_summon_pressed() -> void:
	if not default_skeleton:
		print("ERROR: default_skeleton no asignado en LairController.")
		return

	if state.active_units.size() >= state.max_units or state.souls < default_skeleton.summon_cost:
		print("No alcanzan las almas o se llegó al límite de unidades.")
		return

	state.souls -= default_skeleton.summon_cost
	var new_instance = SkeletonUnitInstance.new(default_skeleton, 1)
	state.add_unit(new_instance)
	_spawn_skeleton_view(new_instance)

func _spawn_skeleton_view(instance: SkeletonUnitInstance) -> void:
	if not skeleton_view_scene:
		print("ERROR: skeleton_view_scene no asignado en el Inspector de LairController.")
		return

	var view: SkeletonView = skeleton_view_scene.instantiate()

	# Calcular posición dentro del ReferenceRect o posición central por defecto
	var spawn_pos := Vector2(400, 300)
	var bounds_rect := Rect2()
	if spawn_area_rect and spawn_area_rect.size.x > 0 and spawn_area_rect.size.y > 0:
		bounds_rect = spawn_area_rect.get_global_rect()
		spawn_pos = Vector2(
			randf_range(bounds_rect.position.x, bounds_rect.position.x + bounds_rect.size.x),
			randf_range(bounds_rect.position.y, bounds_rect.position.y + bounds_rect.size.y)
		)

	view.global_position = spawn_pos
	view.clicked.connect(_on_skeleton_clicked)

	# Agregar al árbol primero y luego llamar setup
	entities_container.add_child(view)
	view.setup(instance, bounds_rect)

func _on_skeleton_clicked(clicked_view: SkeletonView) -> void:
	if selected_view == null:
		selected_view = clicked_view
		selected_view.set_selected(true)
	elif selected_view == clicked_view:
		selected_view.set_selected(false)
		selected_view = null
	else:
		if selected_view.instance.type_data.can_merge_with(clicked_view.instance.type_data):
			_merge_skeletons(selected_view, clicked_view)
		else:
			print("DEBUG: Falló la fusión. Tipos incompatibles. Intento de fusionar: Tier %d (%s) con Tier %d (%s)" % [
				selected_view.instance.type_data.tier,
				selected_view.instance.type_data.name,
				clicked_view.instance.type_data.tier,
				clicked_view.instance.type_data.name
			])
			selected_view.set_selected(false)
			selected_view = clicked_view
			selected_view.set_selected(true)

func _merge_skeletons(view_a: SkeletonView, view_b: SkeletonView) -> void:
	var inst_a = view_a.instance
	var inst_b = view_b.instance
	var evolved_type: SkeletonData = inst_a.type_data.get_next_tier()

	var new_level: int = maxi(inst_a.level, inst_b.level)
	var evolved_instance = SkeletonUnitInstance.new(evolved_type, new_level)

	print("DEBUG: Fusión exitosa. Fusionado Tier %d (%s) con Tier %d (%s). Resultado: Tier %d (%s)" % [
		inst_a.type_data.tier,
		inst_a.type_data.name,
		inst_b.type_data.tier,
		inst_b.type_data.name,
		evolved_type.tier,
		evolved_type.name
	])

	state.remove_unit(inst_a)
	state.remove_unit(inst_b)
	state.add_unit(evolved_instance)
	state.souls += inst_a.type_data.merge_bonus_souls

	var mid_pos: Vector2 = (view_a.global_position + view_b.global_position) * 0.5
	view_b.queue_free()

	view_a.global_position = mid_pos
	# Pasamos los boundaries de vuelta usando los existentes en view_a
	view_a.setup(evolved_instance, view_a.movement_bounds)
	view_a.set_selected(false)
	selected_view = null

func _on_formation_pressed() -> void:
	GameStateDAO.save_state(state)
	get_tree().change_scene_to_file("res://Scenes/formation/formation_scene.tscn")

func _on_next_day_pressed() -> void:
	var income: int = 0
	for inst in state.active_units:
		income += inst.type_data.souls_per_day
	state.souls += income
	# Eliminado state.current_day += 1; se incrementará después de la batalla.
	GameStateDAO.save_state(state)
	get_tree().change_scene_to_file("res://Scenes/combat/combat_scene.tscn")

func _render_fallen_list() -> void:
	for child in fallen_container.get_children():
		child.queue_free()
	for inst in state.fallen_units:
		var btn = Button.new()
		var cost = inst.type_data.get_revive_cost()
		btn.text = "Revivir %s Nv.%d (%d Almas)" % [inst.type_data.name, inst.level, cost]
		btn.pressed.connect(func():
			if state.revive_fallen_unit(inst):
				_spawn_skeleton_view(inst)
		)
		fallen_container.add_child(btn)
