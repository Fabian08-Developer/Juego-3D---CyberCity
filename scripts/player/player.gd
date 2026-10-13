class_name Player
extends CharacterBody3D
## Jugador con cámara en primera y tercera persona (SpringArm3D evita que la cámara atraviese paredes).

var model := Person.new()
var camera := Camera3D.new()
var first_person := false
var speed_multiplier := 1.0
var current_interactable: Interactable = null
var horizontal_speed := 0.0

var _yaw_node := Node3D.new()
var _pitch_node := Node3D.new()
var _spring := SpringArm3D.new()
var _yaw := 0.0
var _pitch := -0.2
var _distance := Config.THIRD_PERSON_DISTANCE
var _facing := PI
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	add_to_group("player")
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.9
	add_child(cs)

	model.setup({"skin": "#e0ac69", "shirt": "#0f172a", "pants": "#334155", "hair": "#1b1b1b"}, true)
	add_child(model)

	add_child(_yaw_node)
	_yaw_node.add_child(_pitch_node)
	_pitch_node.add_child(_spring)
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	_spring.shape = probe
	_spring.margin = 0.15
	_spring.add_excluded_object(get_rid())
	_spring.add_child(camera)
	camera.fov = 72.0
	camera.far = 900.0
	camera.current = true

	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	_apply_camera_mode()


func spawn(pos: Vector3, yaw: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_yaw = yaw
	_facing = yaw + PI
	model.rotation.y = _facing


func get_yaw() -> float:
	return _yaw


func toggle_camera() -> void:
	first_person = not first_person
	_apply_camera_mode()


func _apply_camera_mode() -> void:
	if first_person:
		_yaw_node.position = Vector3(0, 1.65, 0)
		_spring.position = Vector3.ZERO
		_spring.spring_length = 0.0
	else:
		_yaw_node.position = Vector3(0, 1.6, 0)
		_spring.position = Vector3(0.45, 0, 0)
		_spring.spring_length = _distance
	model.set_shadow_only(first_person)


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * Config.MOUSE_SENSITIVITY
		_pitch -= event.relative.y * Config.MOUSE_SENSITIVITY
		_pitch = clampf(_pitch, -1.35, 1.35 if first_person else 0.55)
	elif event is InputEventMouseButton and event.pressed and not first_person:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance - 0.5, 1.5, 8.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance + 0.5, 1.5, 8.0)
		_spring.spring_length = _distance
	elif event.is_action_pressed("toggle_camera"):
		toggle_camera()


func _physics_process(delta: float) -> void:
	_yaw_node.rotation.y = _yaw
	_pitch_node.rotation.x = _pitch

	if not is_on_floor():
		velocity.y -= _gravity * delta
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := Vector3(-sin(_yaw), 0, -cos(_yaw))
	var right := Vector3(cos(_yaw), 0, -sin(_yaw))
	var dir := right * input.x - forward * input.y
	if dir.length() > 1.0:
		dir = dir.normalized()
	var running := Input.is_action_pressed("sprint")
	var speed := (Config.RUN_SPEED if running else Config.WALK_SPEED) * speed_multiplier
	var target := dir * speed
	var accel := 14.0 if is_on_floor() else 4.0
	velocity.x = move_toward(velocity.x, target.x, accel * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * speed * delta)
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = Config.JUMP_VELOCITY

	_step_up(Vector3(velocity.x, 0, velocity.z) * delta)
	move_and_slide()

	horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if dir.length() > 0.1:
		_facing = lerp_angle(_facing, atan2(dir.x, dir.z), minf(1.0, 12.0 * delta))
	model.rotation.y = _facing
	model.animate(delta, horizontal_speed if is_on_floor() else 0.0)
	_find_interactable()
	if current_interactable != null and Input.is_action_just_pressed("interact"):
		current_interactable.used.emit()


## Sube bordillos y escalones bajos (CharacterBody3D no lo hace por sí solo).
func _step_up(motion: Vector3) -> void:
	if not is_on_floor() or motion.length() < 0.0005:
		return
	var probe := motion.normalized() * maxf(motion.length(), 0.12)
	if not test_move(global_transform, probe):
		return
	var up := Vector3.UP * Config.STEP_HEIGHT
	if test_move(global_transform, up):
		return
	if not test_move(global_transform.translated(up), probe):
		global_position.y += Config.STEP_HEIGHT


func _find_interactable() -> void:
	var best: Interactable = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("interactables"):
		var it := node as Interactable
		if it == null or not it.is_visible_in_tree():
			continue
		var p := it.global_position
		if absf(p.y - global_position.y) > 2.5:
			continue
		var d := Vector2(p.x - global_position.x, p.z - global_position.z).length()
		if d < it.radius and d < best_d:
			best = it
			best_d = d
	current_interactable = best
