class_name PlayerController
extends CharacterBody3D

var camera: Camera3D
var collision_shape: CollisionShape3D
var keys: Dictionary = {}

var yaw: float = 0.0
var pitch: float = 0.0
var recoil_pitch_offset: float = 0.0
var vertical_velocity: float = 0.0
var is_grounded: bool = true

var walk_speed: float = 7.2
var sprint_speed: float = 12.0
var jump_speed: float = 7.8
var gravity: float = -20.0
var mouse_sensitivity: float = 0.0022
var max_pitch: float = deg_to_rad(82.0)

var _move_dir: Vector3 = Vector3.ZERO
var _displacement: Vector3 = Vector3.ZERO
var _footstep_timer: float = 0.0

var on_footstep: Callable


func _init() -> void:
	name = "PlayerController"
	collision_layer = 2
	collision_mask = 1
	position = Vector3(0.0, 0.9, 0.0)

	collision_shape = CollisionShape3D.new()
	collision_shape.name = "PlayerCollisionShape"
	var cyl := CylinderShape3D.new()
	cyl.height = 1.8
	cyl.radius = 0.45
	collision_shape.shape = cyl
	add_child(collision_shape)

	camera = Camera3D.new()
	camera.name = "playerCamera"
	camera.position = Vector3(0.0, 0.68, 0.0)
	camera.near = 0.1
	camera.far = 49.2
	camera.fov = rad_to_deg(1.1)
	camera.current = true
	add_child(camera)

	_sync_camera_transform()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		var code := _keycode_to_code(ke.physical_keycode if ke.physical_keycode != KEY_NONE else ke.keycode)
		if code != "":
			if ke.pressed:
				keys[code] = true
			else:
				keys.erase(code)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		apply_mouse_delta(mm.relative.x, mm.relative.y)


func apply_mouse_delta(delta_x: float, delta_y: float) -> void:
	yaw -= delta_x * mouse_sensitivity
	pitch = clampf(pitch + delta_y * mouse_sensitivity, -max_pitch, max_pitch)
	_sync_camera_transform()


static func _keycode_to_code(keycode: Key) -> String:
	match keycode:
		KEY_W:
			return "KeyW"
		KEY_S:
			return "KeyS"
		KEY_A:
			return "KeyA"
		KEY_D:
			return "KeyD"
		KEY_UP:
			return "ArrowUp"
		KEY_DOWN:
			return "ArrowDown"
		KEY_LEFT:
			return "ArrowLeft"
		KEY_RIGHT:
			return "ArrowRight"
		KEY_SPACE:
			return "Space"
		KEY_SHIFT:
			return "ShiftLeft"
		KEY_R:
			return "KeyR"
		_:
			return ""


func has_key(code: String) -> bool:
	return bool(keys.get(code, false))


func add_camera_recoil(pitch_kick_radians: float) -> void:
	recoil_pitch_offset = minf(0.14, recoil_pitch_offset + pitch_kick_radians)


func is_pressing_reload() -> bool:
	return has_key("KeyR")


func update(dt: float) -> void:
	if recoil_pitch_offset > 0.0:
		recoil_pitch_offset = maxf(0.0, recoil_pitch_offset - dt * 0.45)

	var forward_input: float = 0.0
	var right_input: float = 0.0
	if has_key("KeyW") or has_key("ArrowUp"):
		forward_input += 1.0
	if has_key("KeyS") or has_key("ArrowDown"):
		forward_input -= 1.0
	if has_key("KeyD") or has_key("ArrowRight"):
		right_input += 1.0
	if has_key("KeyA") or has_key("ArrowLeft"):
		right_input -= 1.0

	var sin_yaw := sin(yaw)
	var cos_yaw := cos(yaw)
	# Forward vector along (sin(yaw), 0, cos(yaw)), right vector in right-handed Y-up space (-cos(yaw), 0, sin(yaw))
	_move_dir = Vector3(
		sin_yaw * forward_input - cos_yaw * right_input,
		0.0,
		cos_yaw * forward_input + sin_yaw * right_input
	)
	if _move_dir.length_squared() > 0.0001:
		_move_dir = _move_dir.normalized()

	var is_sprinting := has_key("ShiftLeft") or has_key("ShiftRight")
	var speed := sprint_speed if is_sprinting else walk_speed

	if has_key("Space") and is_grounded:
		vertical_velocity = jump_speed
		is_grounded = false

	vertical_velocity += gravity * dt

	_displacement = Vector3(
		_move_dir.x * speed * dt,
		vertical_velocity * dt,
		_move_dir.z * speed * dt
	)

	var prev_y := position.y

	# 1. Horizontal collision move & slide
	var horiz_motion := Vector3(_displacement.x, 0.0, _displacement.z)
	if horiz_motion.length_squared() > 0.0000001:
		var col_h := move_and_collide(horiz_motion)
		if col_h != null:
			var rem := col_h.get_remainder()
			var n := col_h.get_normal()
			n.y = 0.0
			if n.length_squared() > 0.0001:
				n = n.normalized()
				move_and_collide(rem.slide(n))

	# 2. Vertical collision move
	var vert_motion := Vector3(0.0, _displacement.y, 0.0)
	var col_v := move_and_collide(vert_motion)

	# Floor clamp / grounded check (only clamp downward/resting velocity)
	if vertical_velocity <= 0.0 and position.y <= 0.91:
		position.y = 0.9
		vertical_velocity = 0.0
		is_grounded = true
	elif vertical_velocity < 0.0 and (col_v != null or absf(position.y - prev_y) < 0.0005):
		vertical_velocity = 0.0
		is_grounded = true

	# Clamp player within arena bounds (±49.2m)
	position.x = clampf(position.x, -49.2, 49.2)
	position.z = clampf(position.z, -49.2, 49.2)

	# Footstep cadence when moving and grounded
	if is_grounded and _move_dir.length_squared() > 0.001:
		_footstep_timer -= dt
		if _footstep_timer <= 0.0:
			_footstep_timer = 0.32 if is_sprinting else 0.44
			if on_footstep.is_valid():
				on_footstep.call()
	else:
		_footstep_timer = minf(_footstep_timer, 0.1)

	_sync_camera_transform()


func _sync_camera_transform() -> void:
	camera.position = Vector3(0.0, 0.68, 0.0)
	var eff_pitch := clampf(pitch - recoil_pitch_offset, -max_pitch, max_pitch)
	var look_dir := Vector3(
		sin(yaw) * cos(eff_pitch),
		-sin(eff_pitch),
		cos(yaw) * cos(eff_pitch)
	).normalized()
	camera.basis = Basis.looking_at(look_dir, Vector3.UP)


func reset() -> void:
	position = Vector3(0.0, 0.9, 0.0)
	yaw = 0.0
	pitch = 0.0
	recoil_pitch_offset = 0.0
	vertical_velocity = 0.0
	is_grounded = true
	_footstep_timer = 0.0
	keys.clear()
	_sync_camera_transform()
