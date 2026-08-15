class_name SkeletonView
extends CharacterBody2D

signal clicked(view: SkeletonView)

@onready var sprite: Sprite2D = $Sprite2D
@onready var selection_outline: Line2D = get_node_or_null("SelectionOutline")
@onready var hp_bar: ProgressBar = get_node_or_null("HPBar")
@onready var level_label: Label = get_node_or_null("LevelLabel")

var instance: SkeletonUnitInstance
var is_selected: bool = false
var movement_bounds: Rect2
var move_timer: Timer

func _ready() -> void:
	input_pickable = true
	_refresh_visuals()
	set_selected(false)

	move_timer = Timer.new()
	move_timer.one_shot = true
	move_timer.timeout.connect(_on_move_timer_timeout)
	add_child(move_timer)
	_start_random_timer()

func _start_random_timer() -> void:
	move_timer.start(randf_range(4.0, 5.0))

func _on_move_timer_timeout() -> void:
	_start_random_timer() # Restart the timer for the next cycle

	# Random chance to move or stay still (e.g., 50% chance)
	if randf() > 0.5:
		return

	# Move to a random position nearby (e.g., within 50 pixels radius)
	var random_offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
	var target_pos = global_position + random_offset

	# Clamp to boundaries if they are set
	if movement_bounds.size.x > 0 and movement_bounds.size.y > 0:
		target_pos.x = clamp(target_pos.x, movement_bounds.position.x, movement_bounds.position.x + movement_bounds.size.x)
		target_pos.y = clamp(target_pos.y, movement_bounds.position.y, movement_bounds.position.y + movement_bounds.size.y)

	var tween = create_tween()
	# Random duration for the slow movement between 1 and 2 seconds
	var move_duration = randf_range(1.0, 2.0)
	tween.tween_property(self, "global_position", target_pos, move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func setup(new_instance: SkeletonUnitInstance, bounds: Rect2 = Rect2(), current_hp: int = -1) -> void:
	instance = new_instance
	movement_bounds = bounds
	if is_inside_tree():
		_refresh_visuals(current_hp)

func _refresh_visuals(current_hp: int = -1) -> void:
	if not instance or not instance.type_data:
		return

	if not sprite:
		sprite = get_node_or_null("Sprite2D")

	if sprite and instance.type_data.sprite_texture:
		sprite.texture = instance.type_data.sprite_texture
		sprite.scale = Vector2.ONE * instance.type_data.scale_multiplier

	if not hp_bar:
		hp_bar = get_node_or_null("HPBar")
	if hp_bar:
		hp_bar.max_value = instance.get_max_hp()
		hp_bar.value = instance.get_max_hp() if current_hp == -1 else current_hp

	if not level_label:
		level_label = get_node_or_null("LevelLabel")
	if level_label:
		level_label.text = "Nv. %d" % instance.level

func update_hp(current_hp: int) -> void:
	if hp_bar:
		hp_bar.value = max(0, current_hp)

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selection_outline:
		selection_outline.visible = selected
	else:
		modulate = Color(1.3, 1.3, 0.4, 1.0) if selected else Color(1, 1, 1, 1)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)
