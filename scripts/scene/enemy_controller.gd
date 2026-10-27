class_name EnemyController
extends Node3D


class EnemyInstance:
	extends RefCounted
	var id: int
	var root: RigidBody3D
	var parts: Array[MeshInstance3D] = []
	var body_mat: StandardMaterial3D
	var visor_mat: StandardMaterial3D
	var horn_mat: StandardMaterial3D
	var hp: float
	var state: String = "ALIVE"
	var stagger_timer: float = 0.0
	var flash_timer: float = 0.0
	var despawn_timer: float = 0.0
	var jump_cooldown: float = 1.0
	var stuck_timer: float = 0.0
	var groan_timer: float = 3.0
	var prev_position: Vector3 = Vector3.ZERO
	var last_applied_impulse: Vector3 = Vector3.ZERO
	var on_apply_impulse: Callable

	func apply_world_impulse(impulse: Vector3, world_point: Vector3) -> void:
		last_applied_impulse = impulse
		if on_apply_impulse.is_valid():
			on_apply_impulse.call(impulse, world_point)
		var offset := world_point - root.global_position
		root.apply_impulse(impulse, offset)


var enemies: Dictionary = {}
var layout: Dictionary = {}
var spawn_points: Array[Vector3] = []
var _next_id: int = 1
var _spawn_index: int = 0

var max_hp: float = 100.0
var base_move_speed: float = 5.5
var contact_distance: float = 1.45
var contact_damage: float = 15.0

var on_enemy_groan: Callable
var _iron_texture: Texture2D


func _init(parent_scene: Node3D = null, spawn_source: Variant = null) -> void:
	name = "EnemyController"
	_iron_texture = load("res://assets/textures/rusted_iron.png")
	if spawn_source is Array:
		for pt in spawn_source:
			if pt is Vector3:
				spawn_points.append(pt)
	elif spawn_source is Dictionary:
		layout = spawn_source
	if parent_scene != null:
		parent_scene.add_child(self)


func set_layout(new_layout: Dictionary) -> void:
	layout = new_layout


func spawn_enemy(wave_number: int = 1, player_pos: Variant = null) -> EnemyInstance:
	var id := _next_id
	_next_id += 1
	var spawn_pt: Vector3

	if not layout.is_empty():
		var p2d := Vector2(player_pos.x, player_pos.z) if player_pos is Vector3 else Vector2.ZERO
		var fog_pos := ArenaLayoutGenerator.find_fog_spawn_point(p2d, layout)
		spawn_pt = Vector3(fog_pos.x, 1.1, fog_pos.y)
	elif not spawn_points.is_empty():
		spawn_pt = spawn_points[_spawn_index % spawn_points.size()]
		_spawn_index += 1
		spawn_pt.x += (randf() - 0.5) * 1.2
		spawn_pt.z += (randf() - 0.5) * 1.2
	else:
		spawn_pt = Vector3(38.0, 1.1, 38.0)

	var body_mat := StandardMaterial3D.new()
	body_mat.resource_name = "enemyBodyMat_%d" % id
	body_mat.albedo_texture = _iron_texture
	body_mat.albedo_color = Color(0.58, 0.52, 0.48)
	body_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	body_mat.roughness = 0.9
	body_mat.metallic_specular = 0.1

	var horn_mat := StandardMaterial3D.new()
	horn_mat.resource_name = "enemyHornMat_%d" % id
	horn_mat.albedo_color = Color(0.38, 0.35, 0.28)
	horn_mat.roughness = 0.95
	horn_mat.metallic_specular = 0.04

	var visor_mat := StandardMaterial3D.new()
	visor_mat.resource_name = "enemyVisorMat_%d" % id
	visor_mat.albedo_color = Color(1.0, 0.18, 0.02)
	visor_mat.emission_enabled = true
	visor_mat.emission = Color(1.0, 0.24, 0.04)
	visor_mat.emission_energy_multiplier = 1.5

	# 1. INVISIBLE Physics Root Capsule
	var root := RigidBody3D.new()
	root.name = "enemyRoot_%d" % id
	root.collision_layer = 4
	root.collision_mask = 1 | 4
	root.mass = 1.5
	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = 0.45
	phys_mat.bounce = 0.2
	root.physics_material_override = phys_mat
	root.axis_lock_angular_x = true
	root.axis_lock_angular_y = true
	root.axis_lock_angular_z = true
	root.linear_damp = 0.8
	root.can_sleep = false
	root.position = spawn_pt

	var root_col := CollisionShape3D.new()
	root_col.name = "RootCapsuleCollider"
	var cap_shape := CapsuleShape3D.new()
	cap_shape.height = 1.8
	cap_shape.radius = 0.42
	root_col.shape = cap_shape
	root.add_child(root_col)

	if player_pos is Vector3:
		var dir_x: float = player_pos.x - spawn_pt.x
		var dir_z: float = player_pos.z - spawn_pt.z
		var initial_yaw := atan2(dir_x, dir_z)
		root.rotation = Vector3(0.0, initial_yaw, 0.0)

	var parts: Array[MeshInstance3D] = []

	# 2. Heavy Angular Torso (Upper Cuirass, Midsection Vertebrae, Pelvis)
	var chest_plate := _add_box_part(
		"enemyChest_%d" % id,
		Vector3(0.74, 0.48, 0.54),
		Vector3(0.0, 0.22, 0.1),
		Vector3(0.22, 0.0, -0.03),
		body_mat,
		root,
		id,
		true
	)
	parts.append(chest_plate)

	var mid_spine := _add_box_part(
		"enemyMidSpine_%d" % id,
		Vector3(0.52, 0.26, 0.38),
		Vector3(0.0, -0.06, 0.05),
		Vector3(0.1, 0.0, 0.0),
		body_mat,
		root,
		id,
		false
	)
	parts.append(mid_spine)

	var pelvis := _add_box_part(
		"enemyPelvis_%d" % id,
		Vector3(0.62, 0.22, 0.44),
		Vector3(0.0, -0.24, 0.02),
		Vector3.ZERO,
		body_mat,
		root,
		id,
		false
	)
	parts.append(pelvis)

	# 3. Segmented Brawny Legs with Heavy Iron Greaves & Pointed Sabatons
	var thigh_l := _add_box_part(
		"enemyThighL_%d" % id,
		Vector3(0.22, 0.38, 0.26),
		Vector3(-0.2, -0.48, 0.04),
		Vector3(0.12, 0.0, 0.0),
		body_mat,
		root,
		id,
		true
	)
	parts.append(thigh_l)

	var shin_l := _add_box_part(
		"enemyShinL_%d" % id,
		Vector3(0.18, 0.42, 0.22),
		Vector3(-0.2, -0.78, -0.02),
		Vector3(-0.14, 0.0, 0.0),
		body_mat,
		root,
		id,
		false
	)
	parts.append(shin_l)

	var sabaton_l := _add_box_part(
		"enemySabatonL_%d" % id,
		Vector3(0.2, 0.14, 0.36),
		Vector3(-0.2, -0.96, 0.08),
		Vector3.ZERO,
		body_mat,
		root,
		id,
		false
	)
	parts.append(sabaton_l)

	var thigh_r := _add_box_part(
		"enemyThighR_%d" % id,
		Vector3(0.22, 0.38, 0.26),
		Vector3(0.2, -0.48, -0.02),
		Vector3(-0.08, 0.0, 0.0),
		body_mat,
		root,
		id,
		true
	)
	parts.append(thigh_r)

	var shin_r := _add_box_part(
		"enemyShinR_%d" % id,
		Vector3(0.18, 0.42, 0.22),
		Vector3(0.2, -0.78, 0.04),
		Vector3(0.1, 0.0, 0.0),
		body_mat,
		root,
		id,
		false
	)
	parts.append(shin_r)

	var sabaton_r := _add_box_part(
		"enemySabatonR_%d" % id,
		Vector3(0.2, 0.14, 0.36),
		Vector3(0.2, -0.96, 0.14),
		Vector3.ZERO,
		body_mat,
		root,
		id,
		false
	)
	parts.append(sabaton_r)

	# 4. Hunched Upper Back Mantle & Sunken Skull Helm
	var hunch_mantle := _add_box_part(
		"enemyHunch_%d" % id,
		Vector3(0.72, 0.44, 0.58),
		Vector3(0.0, 0.46, -0.02),
		Vector3(0.28, 0.0, 0.0),
		body_mat,
		root,
		id,
		true
	)
	parts.append(hunch_mantle)

	var skull_helm := _add_box_part(
		"enemySkull_%d" % id,
		Vector3(0.36, 0.38, 0.44),
		Vector3(0.0, 0.66, 0.24),
		Vector3(0.22, 0.0, 0.0),
		body_mat,
		root,
		id,
		false
	)
	parts.append(skull_helm)

	# Asymmetrical Horns: Long curved left horn + broken shattered right stump
	var horn_left := _add_cylinder_part(
		"enemyHornL_%d" % id,
		0.02,
		0.11,
		0.54,
		5,
		Vector3(-0.16, 0.24, 0.02),
		Vector3(-0.45, 0.15, -0.38),
		horn_mat,
		skull_helm,
		id,
		false
	)
	parts.append(horn_left)

	var horn_right := _add_cylinder_part(
		"enemyHornR_%d" % id,
		0.08,
		0.11,
		0.18,
		5,
		Vector3(0.16, 0.15, 0.02),
		Vector3(-0.2, -0.1, 0.32),
		horn_mat,
		skull_helm,
		id,
		false
	)
	parts.append(horn_right)

	# Glowing Demonic Eye Slits
	var eye_visor := _add_box_part(
		"enemyEyes_%d" % id,
		Vector3(0.3, 0.07, 0.16),
		Vector3(0.0, 0.01, 0.2),
		Vector3.ZERO,
		visor_mat,
		skull_helm,
		id,
		false
	)
	parts.append(eye_visor)

	# 5. Asymmetrical Shoulders: Spiked Left Pauldron + Dented Right Guard
	var pauldron_left := _add_box_part(
		"enemyPauldronL_%d" % id,
		Vector3(0.36, 0.32, 0.42),
		Vector3(-0.46, 0.42, 0.06),
		Vector3(0.15, 0.05, -0.32),
		body_mat,
		root,
		id,
		true
	)
	parts.append(pauldron_left)

	var spike_l1 := _add_cylinder_part(
		"enemySpikeL1_%d" % id,
		0.02,
		0.09,
		0.36,
		5,
		Vector3(-0.08, 0.2, 0.06),
		Vector3(0.1, 0.0, -0.35),
		horn_mat,
		pauldron_left,
		id,
		false
	)
	parts.append(spike_l1)

	var pauldron_right := _add_box_part(
		"enemyPauldronR_%d" % id,
		Vector3(0.3, 0.26, 0.36),
		Vector3(0.44, 0.38, 0.04),
		Vector3(0.1, -0.05, 0.24),
		body_mat,
		root,
		id,
		true
	)
	parts.append(pauldron_right)

	# 6. Reaching Segmented Arms (Upper Arm + Forearm + Claws)
	var bicep_l := _add_box_part(
		"enemyBicepL_%d" % id,
		Vector3(0.18, 0.32, 0.2),
		Vector3(-0.45, 0.26, 0.08),
		Vector3(0.24, 0.0, -0.18),
		body_mat,
		root,
		id,
		false
	)
	parts.append(bicep_l)

	var forearm_l := _add_box_part(
		"enemyForearmL_%d" % id,
		Vector3(0.19, 0.18, 0.44),
		Vector3(-0.48, 0.08, 0.3),
		Vector3(-0.42, 0.14, -0.05),
		body_mat,
		root,
		id,
		false
	)
	parts.append(forearm_l)

	var claws_l := _add_cylinder_part(
		"enemyClawsL_%d" % id,
		0.01,
		0.08,
		0.22,
		4,
		Vector3(0.0, 0.0, 0.26),
		Vector3(PI / 2.0, 0.0, 0.0),
		horn_mat,
		forearm_l,
		id,
		false
	)
	parts.append(claws_l)

	var bicep_r := _add_box_part(
		"enemyBicepR_%d" % id,
		Vector3(0.18, 0.32, 0.2),
		Vector3(0.44, 0.24, 0.06),
		Vector3(0.18, 0.0, 0.16),
		body_mat,
		root,
		id,
		false
	)
	parts.append(bicep_r)

	var forearm_r := _add_box_part(
		"enemyForearmR_%d" % id,
		Vector3(0.19, 0.18, 0.44),
		Vector3(0.46, 0.06, 0.26),
		Vector3(-0.35, -0.12, 0.05),
		body_mat,
		root,
		id,
		false
	)
	parts.append(forearm_r)

	var claws_r := _add_cylinder_part(
		"enemyClawsR_%d" % id,
		0.01,
		0.08,
		0.22,
		4,
		Vector3(0.0, 0.0, 0.26),
		Vector3(PI / 2.0, 0.0, 0.0),
		horn_mat,
		forearm_r,
		id,
		false
	)
	parts.append(claws_r)

	add_child(root)

	var instance := EnemyInstance.new()
	instance.id = id
	instance.root = root
	instance.parts = parts
	instance.body_mat = body_mat
	instance.visor_mat = visor_mat
	instance.horn_mat = horn_mat
	instance.hp = max_hp + minf(40.0, float(wave_number - 1) * 10.0)
	instance.state = "ALIVE"
	instance.stagger_timer = 0.0
	instance.flash_timer = 0.0
	instance.despawn_timer = 0.0
	instance.jump_cooldown = 0.8 + randf() * 0.4
	instance.stuck_timer = 0.0
	instance.groan_timer = 2.0 + randf() * 4.5
	instance.prev_position = spawn_pt

	enemies[id] = instance
	return instance


func _add_box_part(
	part_name: String,
	size: Vector3,
	pos: Vector3,
	rot: Vector3,
	mat: Material,
	parent: Node3D,
	enemy_id: int,
	cast_shadow: bool
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("enemy_id", enemy_id)

	var hit_area := Area3D.new()
	hit_area.name = "HitboxArea"
	hit_area.collision_layer = 8
	hit_area.collision_mask = 0
	hit_area.monitoring = false
	hit_area.monitorable = false
	hit_area.set_meta("enemy_id", enemy_id)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	hit_area.add_child(col)
	mi.add_child(hit_area)

	parent.add_child(mi)
	return mi


func _add_cylinder_part(
	part_name: String,
	d_top: float,
	d_bot: float,
	h: float,
	segs: int,
	pos: Vector3,
	rot: Vector3,
	mat: Material,
	parent: Node3D,
	enemy_id: int,
	cast_shadow: bool
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = d_top / 2.0
	cyl.bottom_radius = d_bot / 2.0
	cyl.height = h
	cyl.radial_segments = maxi(4, segs)
	cyl.rings = 1
	mi.mesh = cyl
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("enemy_id", enemy_id)

	var hit_area := Area3D.new()
	hit_area.name = "HitboxArea"
	hit_area.collision_layer = 8
	hit_area.collision_mask = 0
	hit_area.monitoring = false
	hit_area.monitorable = false
	hit_area.set_meta("enemy_id", enemy_id)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.height = h
	shape.radius = maxf(d_top, d_bot) / 2.0
	col.shape = shape
	hit_area.add_child(col)
	mi.add_child(hit_area)

	parent.add_child(mi)
	return mi


func apply_hit(
	enemy_id: int,
	damage: float,
	hit_point: Vector3,
	ray_direction: Vector3
) -> String:
	if not enemies.has(enemy_id):
		return "NONE"
	var enemy: EnemyInstance = enemies[enemy_id]
	if enemy == null or enemy.state != "ALIVE":
		return "NONE"

	enemy.hp -= damage
	var flat_dir := Vector3(ray_direction.x, 0.0, ray_direction.z)
	if flat_dir.length_squared() > 0.0001:
		flat_dir = flat_dir.normalized()
	else:
		flat_dir = Vector3(0.0, 0.0, 1.0)

	if enemy.hp > 0.0:
		enemy.stagger_timer = 0.26
		enemy.stuck_timer = 0.0
		enemy.flash_timer = 0.11
		enemy.body_mat.emission_enabled = true
		enemy.body_mat.emission = Color(0.85, 0.85, 0.85)

		var stagger_impulse := Vector3(
			flat_dir.x * 11.5,
			2.6,
			flat_dir.z * 11.5
		)
		enemy.root.linear_velocity = Vector3.ZERO
		enemy.apply_world_impulse(stagger_impulse, enemy.root.global_position)
		return "HIT"

	# Fatal hit: unlock rotational inertia and launch/topple enemy backward
	enemy.state = "KNOCKED_DOWN"
	enemy.despawn_timer = 2.6
	enemy.flash_timer = 0.0
	enemy.body_mat.albedo_color = Color(0.24, 0.22, 0.2)
	enemy.body_mat.emission_enabled = true
	enemy.body_mat.emission = Color(0.12, 0.03, 0.02)
	enemy.visor_mat.emission = Color(0.04, 0.04, 0.04)
	enemy.visor_mat.albedo_color = Color(0.15, 0.15, 0.15)

	enemy.root.axis_lock_angular_x = false
	enemy.root.axis_lock_angular_y = false
	enemy.root.axis_lock_angular_z = false
	enemy.root.mass = 1.2
	enemy.root.linear_damp = 0.25
	enemy.root.angular_damp = 0.25

	var impact_point := hit_point
	if impact_point.y < enemy.root.position.y + 0.45:
		impact_point.y = enemy.root.position.y + 0.65

	var knockdown_impulse := Vector3(
		flat_dir.x * 21.0,
		6.5,
		flat_dir.z * 21.0
	)
	enemy.apply_world_impulse(knockdown_impulse, impact_point)

	var spin_axis := Vector3.UP.cross(flat_dir)
	enemy.root.angular_velocity = spin_axis * 7.5

	return "KILLED"


func update(dt: float, player_position: Vector3, wave_number: int = 1) -> float:
	var contact_damage_triggered := 0.0
	var chase_speed := base_move_speed + minf(2.2, float(wave_number - 1) * 0.25)

	var ids := enemies.keys()
	for id in ids:
		if not enemies.has(id):
			continue
		var enemy: EnemyInstance = enemies[id]
		if not is_instance_valid(enemy.root):
			enemies.erase(id)
			continue

		if enemy.flash_timer > 0.0:
			enemy.flash_timer -= dt
			if enemy.flash_timer <= 0.0 and enemy.state == "ALIVE":
				enemy.body_mat.emission_enabled = false
				enemy.body_mat.emission = Color.BLACK

		if enemy.state == "KNOCKED_DOWN":
			enemy.despawn_timer -= dt
			if enemy.despawn_timer <= 0.0:
				_dispose_enemy(id, enemy)
			continue

		# Alive enemy logic
		enemy.groan_timer -= dt
		if enemy.groan_timer <= 0.0:
			enemy.groan_timer = 4.5 + randf() * 6.0
			if on_enemy_groan.is_valid():
				on_enemy_groan.call(enemy.root.position)

		if enemy.stagger_timer > 0.0:
			enemy.stagger_timer -= dt
			continue

		if enemy.jump_cooldown > 0.0:
			enemy.jump_cooldown -= dt

		var actual_dist := enemy.root.position.distance_to(enemy.prev_position)
		enemy.prev_position = enemy.root.position

		var to_player := player_position - enemy.root.position
		var vertical_diff := player_position.y - enemy.root.position.y
		var horizontal_vec := Vector3(to_player.x, 0.0, to_player.z)
		var horizontal_dist := horizontal_vec.length()

		if horizontal_dist <= contact_distance and absf(vertical_diff) <= 1.4:
			contact_damage_triggered = maxf(contact_damage_triggered, contact_damage)

		var move_dir := Vector3(0.0, 0.0, 1.0)
		if horizontal_dist > 0.0001:
			move_dir = horizontal_vec / horizontal_dist

		if horizontal_dist > 0.9:
			var expected_dist := chase_speed * dt
			if actual_dist < expected_dist * 0.45:
				enemy.stuck_timer += dt
			else:
				enemy.stuck_timer = 0.0

			var current_vel := enemy.root.linear_velocity
			var is_grounded := absf(current_vel.y) < 0.8
			var did_jump := false

			if enemy.jump_cooldown <= 0.0 and is_grounded:
				if vertical_diff > 0.6 and horizontal_dist <= 5.2:
					# Case A: Vertical Pursuit Leap (player is perched above)
					var mass := 1.5
					var jump_speed_y := 8.2
					var forward_push := 6.0
					var jump_impulse := Vector3(
						move_dir.x * forward_push * mass,
						jump_speed_y * mass,
						move_dir.z * forward_push * mass
					)
					enemy.apply_world_impulse(jump_impulse, enemy.root.global_position)
					enemy.jump_cooldown = 1.6
					enemy.stuck_timer = 0.0
					did_jump = true
				elif enemy.stuck_timer >= 0.28 and horizontal_dist > 1.2:
					# Case B: Obstacle Vault Leap (enemy is blocked while chasing)
					var mass := 1.5
					var jump_speed_y := 6.8
					var forward_push := 5.0
					var jump_impulse := Vector3(
						move_dir.x * forward_push * mass,
						jump_speed_y * mass,
						move_dir.z * forward_push * mass
					)
					enemy.apply_world_impulse(jump_impulse, enemy.root.global_position)
					enemy.jump_cooldown = 1.4
					enemy.stuck_timer = 0.0
					did_jump = true

			if not did_jump:
				enemy.root.linear_velocity = Vector3(
					move_dir.x * chase_speed,
					current_vel.y,
					move_dir.z * chase_speed
				)

			var target_yaw := atan2(move_dir.x, move_dir.z)
			enemy.root.rotation = Vector3(0.0, target_yaw, 0.0)
		else:
			enemy.stuck_timer = 0.0

		# Clamp within arena bounds (±49.2m)
		if absf(enemy.root.position.x) > 49.2 or absf(enemy.root.position.z) > 49.2:
			enemy.root.position.x = clampf(enemy.root.position.x, -49.2, 49.2)
			enemy.root.position.z = clampf(enemy.root.position.z, -49.2, 49.2)

	return contact_damage_triggered


func _dispose_enemy(id: int, enemy: EnemyInstance) -> void:
	if is_instance_valid(enemy.root):
		if enemy.root.get_parent() != null:
			enemy.root.get_parent().remove_child(enemy.root)
		enemy.root.free()
	enemies.erase(id)


func clear_all() -> void:
	var ids := enemies.keys()
	for id in ids:
		_dispose_enemy(id, enemies[id])
