class_name EnemyController
extends Node3D


class EnemyInstance:
	extends RefCounted
	var id: int
	var root: RigidBody3D
	var hitbox_area: Area3D
	var rig: EnemyRigBuilder.Rig
	var parts: Array[MeshInstance3D] = []
	var body_parts: Array[MeshInstance3D] = []
	var eye_visor: MeshInstance3D
	var body_mat: StandardMaterial3D
	var accent_mat: StandardMaterial3D
	var visor_mat: StandardMaterial3D
	var horn_mat: StandardMaterial3D
	var personality: String = EnemyBehavior.RUSHER
	var behavior: EnemyBehavior.State = EnemyBehavior.State.new()
	var anim_state: EnemyAnimator.State = EnemyAnimator.State.new()
	var hp: float
	var state: String = "ALIVE"
	var stagger_timer: float = 0.0
	var flash_timer: float = 0.0
	var despawn_timer: float = 0.0
	var jump_cooldown: float = 1.0
	var stuck_timer: float = 0.0
	var groan_timer: float = 3.0
	var current_yaw: float = 0.0
	var prev_position: Vector3 = Vector3.ZERO
	var last_applied_impulse: Vector3 = Vector3.ZERO
	var on_apply_impulse: Callable

	func apply_world_impulse(impulse: Vector3, world_point: Vector3) -> void:
		last_applied_impulse = impulse
		if on_apply_impulse.is_valid():
			on_apply_impulse.call(impulse, world_point)
		var offset := world_point - root.global_position
		root.apply_impulse(impulse, offset)


const MAX_POOL_PER_ARCHETYPE: int = 8

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
var _archetype_materials: Dictionary = {}
var _shared_flash_body_mat: StandardMaterial3D
var _shared_dead_body_mat: StandardMaterial3D
var _shared_lunge_windup_visor_mat: StandardMaterial3D
var _shared_dead_visor_mat: StandardMaterial3D
var _shared_phys_mat: PhysicsMaterial
var _shared_capsule_shape: CapsuleShape3D
var _ground_ray_query: PhysicsRayQueryParameters3D
var _current_graphics_quality: String = "MEDIUM"
var _enemy_pools: Dictionary = {}
var _rig_builder: EnemyRigBuilder = EnemyRigBuilder.new()
var _alive_positions_scratch: Array[Vector2] = []
var _alive_index_scratch: Dictionary = {}
var _behavior_result_scratch: EnemyBehavior.StepResult = EnemyBehavior.StepResult.new()
var _pose_scratch: EnemyAnimator.Pose = EnemyAnimator.Pose.new()


func _init(parent_scene: Node3D = null, spawn_source: Variant = null) -> void:
	name = "EnemyController"
	_iron_texture = load("res://assets/textures/rusted_iron.png")
	_init_shared_resources()
	if spawn_source is Array:
		for pt in spawn_source:
			if pt is Vector3:
				spawn_points.append(pt)
	elif spawn_source is Dictionary:
		layout = spawn_source
	if parent_scene != null:
		parent_scene.add_child(self)


func _init_shared_resources() -> void:
	for archetype_id in EnemyArchetypes.get_all_ids():
		var spec := EnemyArchetypes.get_spec(archetype_id)
		_archetype_materials[archetype_id] = {
			"body": _make_iron_mat("enemyBodyMat_%s" % archetype_id, spec.body_color),
			"accent": _make_iron_mat("enemyAccentMat_%s" % archetype_id, spec.accent_color),
			"horn": _make_horn_mat("enemyHornMat_%s" % archetype_id, spec.horn_color),
			"visor": _make_visor_mat("enemyVisorMat_%s" % archetype_id, spec.visor_color),
		}
		_enemy_pools[archetype_id] = []

	_shared_flash_body_mat = _make_iron_mat("enemySharedFlashBodyMat", Color(0.62, 0.56, 0.52))
	_shared_flash_body_mat.emission_enabled = true
	_shared_flash_body_mat.emission = Color(0.85, 0.85, 0.85)

	_shared_dead_body_mat = _make_iron_mat("enemySharedDeadBodyMat", Color(0.24, 0.22, 0.20))
	_shared_dead_body_mat.emission_enabled = true
	_shared_dead_body_mat.emission = Color(0.12, 0.03, 0.02)

	_shared_lunge_windup_visor_mat = _make_visor_mat(
		"enemySharedLungeWindupVisorMat",
		EnemyBehavior.LUNGE_WINDUP_VISOR_COLOR
	)

	_shared_dead_visor_mat = _make_visor_mat(
		"enemySharedDeadVisorMat",
		Color(0.15, 0.15, 0.15)
	)

	_shared_phys_mat = PhysicsMaterial.new()
	_shared_phys_mat.friction = 0.45
	_shared_phys_mat.bounce = 0.2

	_shared_capsule_shape = CapsuleShape3D.new()
	_shared_capsule_shape.height = 1.8
	_shared_capsule_shape.radius = 0.42

	_ground_ray_query = PhysicsRayQueryParameters3D.new()
	_ground_ray_query.collision_mask = 1
	_ground_ray_query.collide_with_bodies = true
	_ground_ray_query.collide_with_areas = false


func _make_iron_mat(mat_name: String, tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = mat_name
	mat.albedo_texture = _iron_texture
	mat.albedo_color = tint
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 0.92
	mat.metallic_specular = 0.08
	return mat


func _make_horn_mat(mat_name: String, tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = mat_name
	mat.albedo_color = tint
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 0.95
	mat.metallic_specular = 0.04
	return mat


func _make_visor_mat(mat_name: String, color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = mat_name
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat


func get_archetype_materials(personality: String) -> Dictionary:
	var key := EnemyBehavior.normalize_personality(personality)
	return _archetype_materials[key]


func get_archetype_visor_mat(personality: String) -> StandardMaterial3D:
	var mats := get_archetype_materials(personality)
	return mats["visor"]


func set_layout(new_layout: Dictionary) -> void:
	layout = new_layout


func spawn_enemy(wave_number: int = 1, player_pos: Variant = null, forced_personality: String = "") -> EnemyInstance:
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

	var chosen_personality := (
		EnemyBehavior.normalize_personality(forced_personality)
		if forced_personality != ""
		else EnemyBehavior.pick_personality(wave_number, randf())
	)
	var mats := get_archetype_materials(chosen_personality)
	var body_mat: StandardMaterial3D = mats["body"]
	var accent_mat: StandardMaterial3D = mats["accent"]
	var horn_mat: StandardMaterial3D = mats["horn"]
	var visor_mat: StandardMaterial3D = mats["visor"]
	var allow_shadows := (_current_graphics_quality != "LOW")
	var allow_limb_shadows := (_current_graphics_quality == "HIGH")

	var initial_yaw := 0.0
	if player_pos is Vector3:
		var dir_x: float = player_pos.x - spawn_pt.x
		var dir_z: float = player_pos.z - spawn_pt.z
		initial_yaw = atan2(dir_x, dir_z)

	var pool: Array = _enemy_pools[chosen_personality]
	while not pool.is_empty():
		var pooled: EnemyInstance = pool.pop_back()
		if pooled != null and is_instance_valid(pooled.root):
			pooled.id = id
			pooled.root.name = "enemyRoot_%d" % id
			pooled.root.collision_layer = 4
			pooled.root.collision_mask = 1 | 4
			pooled.root.mass = 1.5
			pooled.root.linear_damp = 0.8
			pooled.root.angular_damp = 0.0
			pooled.root.axis_lock_angular_x = true
			pooled.root.axis_lock_angular_y = true
			pooled.root.axis_lock_angular_z = true
			pooled.root.linear_velocity = Vector3.ZERO
			pooled.root.angular_velocity = Vector3.ZERO
			pooled.root.position = spawn_pt
			pooled.root.rotation = Vector3(0.0, initial_yaw, 0.0)
			pooled.root.set_meta("enemy_id", id)

			if is_instance_valid(pooled.hitbox_area):
				pooled.hitbox_area.collision_layer = 8
				pooled.hitbox_area.set_meta("enemy_id", id)

			pooled.rig.set_enemy_id_meta(id)
			pooled.rig.apply_body_materials(body_mat, accent_mat)
			pooled.rig.apply_visor_material(visor_mat)
			pooled.rig.apply_shadow_quality(allow_shadows, allow_limb_shadows)

			pooled.body_mat = body_mat
			pooled.accent_mat = accent_mat
			pooled.visor_mat = visor_mat
			pooled.horn_mat = horn_mat
			pooled.personality = chosen_personality
			pooled.behavior.reset(chosen_personality, randf(), randf(), randf())
			pooled.anim_state.reset(chosen_personality, randf())
			var init_pose := EnemyAnimator.step(pooled.anim_state, 0.0, 0.0, 0.0, true, false, false, false, false, _pose_scratch)
			pooled.rig.apply_pose(init_pose)

			pooled.hp = max_hp + minf(40.0, float(wave_number - 1) * 10.0)
			pooled.state = "ALIVE"
			pooled.stagger_timer = 0.0
			pooled.flash_timer = 0.0
			pooled.despawn_timer = 0.0
			pooled.jump_cooldown = 0.8 + randf() * 0.4
			pooled.stuck_timer = 0.0
			pooled.groan_timer = 2.0 + randf() * 4.5
			pooled.current_yaw = initial_yaw
			pooled.prev_position = spawn_pt
			pooled.last_applied_impulse = Vector3.ZERO

			add_child(pooled.root)
			enemies[id] = pooled
			return pooled

	# 1. INVISIBLE Physics Root Capsule
	var root := RigidBody3D.new()
	root.name = "enemyRoot_%d" % id
	root.collision_layer = 4
	root.collision_mask = 1 | 4
	root.mass = 1.5
	root.physics_material_override = _shared_phys_mat
	root.axis_lock_angular_x = true
	root.axis_lock_angular_y = true
	root.axis_lock_angular_z = true
	root.linear_damp = 0.8
	root.can_sleep = false
	root.position = spawn_pt
	root.set_meta("enemy_id", id)

	var hitbox_area := Area3D.new()
	hitbox_area.name = "HitboxCompoundArea"
	hitbox_area.collision_layer = 8
	hitbox_area.collision_mask = 0
	hitbox_area.monitoring = false
	hitbox_area.monitorable = false
	hitbox_area.set_meta("enemy_id", id)
	root.add_child(hitbox_area)

	var root_col := CollisionShape3D.new()
	root_col.name = "RootCapsuleCollider"
	root_col.shape = _shared_capsule_shape
	root.add_child(root_col)

	if player_pos is Vector3:
		root.rotation = Vector3(0.0, initial_yaw, 0.0)

	# 2. Build articulated low-poly gothic rig for this archetype
	var rig := _rig_builder.build_rig(
		chosen_personality,
		root,
		hitbox_area,
		id,
		mats,
		allow_shadows,
		allow_limb_shadows
	)

	add_child(root)

	var instance := EnemyInstance.new()
	instance.id = id
	instance.root = root
	instance.hitbox_area = hitbox_area
	instance.rig = rig
	instance.parts = rig.parts
	instance.body_parts = rig.body_parts
	instance.eye_visor = rig.eye_visor
	instance.body_mat = body_mat
	instance.accent_mat = accent_mat
	instance.visor_mat = visor_mat
	instance.horn_mat = horn_mat
	instance.personality = chosen_personality
	instance.behavior.reset(chosen_personality, randf(), randf(), randf())
	instance.anim_state.reset(chosen_personality, randf())
	var initial_pose := EnemyAnimator.step(instance.anim_state, 0.0, 0.0, 0.0, true, false, false, false, false, _pose_scratch)
	rig.apply_pose(initial_pose)

	instance.hp = max_hp + minf(40.0, float(wave_number - 1) * 10.0)
	instance.state = "ALIVE"
	instance.stagger_timer = 0.0
	instance.flash_timer = 0.0
	instance.despawn_timer = 0.0
	instance.jump_cooldown = 0.8 + randf() * 0.4
	instance.stuck_timer = 0.0
	instance.groan_timer = 2.0 + randf() * 4.5
	instance.current_yaw = initial_yaw
	instance.prev_position = spawn_pt

	enemies[id] = instance
	return instance


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

	var archetype_visor := get_archetype_visor_mat(enemy.personality)

	if enemy.hp > 0.0:
		enemy.stagger_timer = 0.26
		enemy.stuck_timer = 0.0
		enemy.flash_timer = 0.11
		enemy.behavior.on_stagger()
		enemy.body_mat = _shared_flash_body_mat
		enemy.rig.apply_body_materials(_shared_flash_body_mat, _shared_flash_body_mat)
		if enemy.visor_mat != archetype_visor:
			enemy.visor_mat = archetype_visor
			enemy.rig.apply_visor_material(archetype_visor)

		var stagger_impulse := Vector3(
			flat_dir.x * 11.5,
			2.6,
			flat_dir.z * 11.5
		)
		enemy.root.linear_velocity = Vector3.ZERO
		enemy.apply_world_impulse(stagger_impulse, enemy.root.global_position)
		return "HIT"

	# Fatal hit: unlock rotational inertia and launch/topple enemy backward
	enemy.behavior.on_stagger()
	enemy.state = "KNOCKED_DOWN"
	enemy.despawn_timer = 2.6
	enemy.flash_timer = 0.0
	enemy.body_mat = _shared_dead_body_mat
	enemy.visor_mat = _shared_dead_visor_mat
	enemy.rig.apply_body_materials(_shared_dead_body_mat, _shared_dead_body_mat)
	enemy.rig.apply_visor_material(_shared_dead_visor_mat)
	enemy.rig.disable_all_shadows()
	if is_instance_valid(enemy.hitbox_area):
		enemy.hitbox_area.collision_layer = 0

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
	_alive_positions_scratch.clear()
	_alive_index_scratch.clear()
	for id in ids:
		if not enemies.has(id):
			continue
		var e: EnemyInstance = enemies[id]
		if e != null and e.state == "ALIVE" and is_instance_valid(e.root):
			_alive_index_scratch[id] = _alive_positions_scratch.size()
			_alive_positions_scratch.append(Vector2(e.root.position.x, e.root.position.z))

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
				var mats := get_archetype_materials(enemy.personality)
				enemy.body_mat = mats["body"]
				enemy.accent_mat = mats["accent"]
				enemy.rig.apply_body_materials(enemy.body_mat, enemy.accent_mat)

		if enemy.state == "KNOCKED_DOWN":
			var death_pose := EnemyAnimator.step(
				enemy.anim_state,
				dt,
				0.0,
				0.0,
				false,
				false,
				false,
				true,
				false,
				_pose_scratch
			)
			enemy.rig.apply_pose(death_pose)
			enemy.despawn_timer -= dt
			if enemy.despawn_timer <= 0.0:
				_dispose_enemy(id, enemy)
			continue

		var pos := enemy.root.position

		# Alive enemy logic
		enemy.groan_timer -= dt
		if enemy.groan_timer <= 0.0:
			enemy.groan_timer = 4.5 + randf() * 6.0
			if on_enemy_groan.is_valid():
				on_enemy_groan.call(pos)

		if enemy.stagger_timer > 0.0:
			enemy.stagger_timer -= dt
			var stagger_pose := EnemyAnimator.step(
				enemy.anim_state,
				dt,
				0.0,
				0.0,
				true,
				false,
				true,
				false,
				false,
				_pose_scratch
			)
			enemy.rig.apply_pose(stagger_pose)
			continue

		if enemy.jump_cooldown > 0.0:
			enemy.jump_cooldown -= dt

		var actual_dist := pos.distance_to(enemy.prev_position)
		enemy.prev_position = pos

		var to_player := player_position - pos
		var vertical_diff := player_position.y - pos.y
		var horizontal_vec := Vector3(to_player.x, 0.0, to_player.z)
		var horizontal_dist := horizontal_vec.length()

		if horizontal_dist <= contact_distance and absf(vertical_diff) <= 1.4:
			contact_damage_triggered = maxf(contact_damage_triggered, contact_damage)

		var move_dir := Vector3(0.0, 0.0, 1.0)
		if horizontal_dist > 0.0001:
			move_dir = horizontal_vec / horizontal_dist

		var current_vel := enemy.root.linear_velocity
		var is_grounded := _is_enemy_grounded(enemy, pos, current_vel)
		var is_winding_up := false
		var archetype_visor := get_archetype_visor_mat(enemy.personality)

		if horizontal_dist > 0.9:
			var alive_idx := int(_alive_index_scratch.get(id, -1))
			var separation_xz := (
				EnemyBehavior.compute_separation(Vector2(pos.x, pos.z), _alive_positions_scratch, alive_idx)
				if alive_idx >= 0
				else Vector2.ZERO
			)
			var bres := EnemyBehavior.step(
				enemy.behavior,
				dt,
				pos,
				player_position,
				chase_speed,
				is_grounded,
				separation_xz,
				_behavior_result_scratch
			)
			is_winding_up = bres.is_winding_up

			if bres.started_windup and on_enemy_groan.is_valid():
				on_enemy_groan.call(pos)

			var target_visor := _shared_lunge_windup_visor_mat if bres.is_winding_up else archetype_visor
			if enemy.visor_mat != target_visor:
				enemy.visor_mat = target_visor
				enemy.rig.apply_visor_material(target_visor)

			if bres.suppress_stuck_timer:
				enemy.stuck_timer = 0.0
			else:
				var expected_dist := chase_speed * dt
				if actual_dist < expected_dist * 0.45:
					enemy.stuck_timer += dt
				else:
					enemy.stuck_timer = 0.0

			var did_jump := false
			if bres.lunge_launch_velocity.length_squared() > 0.001:
				var mass := enemy.root.mass
				enemy.root.linear_velocity = Vector3(0.0, current_vel.y, 0.0)
				enemy.apply_world_impulse(bres.lunge_launch_velocity * mass, enemy.root.global_position)
				enemy.stuck_timer = 0.0
				did_jump = true
			elif (
				not bres.is_winding_up
				and not bres.preserve_airborne_velocity
				and enemy.jump_cooldown <= 0.0
				and is_grounded
			):
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

			if not did_jump and not bres.preserve_airborne_velocity:
				enemy.root.linear_velocity = Vector3(
					bres.velocity_xz.x,
					current_vel.y,
					bres.velocity_xz.y
				)

			var target_yaw := atan2(bres.facing_dir_xz.x, bres.facing_dir_xz.y)
			if absf(angle_difference(enemy.current_yaw, target_yaw)) > 0.025:
				enemy.current_yaw = target_yaw
				enemy.root.rotation = Vector3(0.0, target_yaw, 0.0)

			if did_jump or bres.preserve_airborne_velocity:
				is_grounded = false
		else:
			enemy.stuck_timer = 0.0
			if enemy.behavior.lunge_state == EnemyBehavior.LUNGE_WINDUP:
				enemy.behavior.lunge_state = EnemyBehavior.LUNGE_CHASE
				enemy.behavior.lunge_timer = 0.0
			if enemy.visor_mat != archetype_visor:
				enemy.visor_mat = archetype_visor
				enemy.rig.apply_visor_material(archetype_visor)

		# Update procedural limb animation
		var vel_after := enemy.root.linear_velocity
		var horiz_speed := Vector2(vel_after.x, vel_after.z).length()
		var right_x := cos(enemy.current_yaw)
		var right_z := -sin(enemy.current_yaw)
		var lateral_speed := vel_after.x * right_x + vel_after.z * right_z
		var in_slash_range := (horizontal_dist <= contact_distance + 0.55 and absf(vertical_diff) <= 1.5)
		var pose := EnemyAnimator.step(
			enemy.anim_state,
			dt,
			horiz_speed,
			lateral_speed,
			is_grounded,
			is_winding_up,
			false,
			false,
			in_slash_range,
			_pose_scratch
		)
		enemy.rig.apply_pose(pose)

		# Clamp within arena bounds (±49.2m)
		if absf(pos.x) > 49.2 or absf(pos.z) > 49.2:
			enemy.root.position = Vector3(
				clampf(pos.x, -49.2, 49.2),
				pos.y,
				clampf(pos.z, -49.2, 49.2)
			)

	return contact_damage_triggered


func _is_enemy_grounded(enemy: EnemyInstance, pos: Vector3, current_vel: Vector3) -> bool:
	if absf(current_vel.y) >= 0.8:
		return false
	# Capsule half-height is 0.9m; within 0.15m of arena floor (y = 0) counts as grounded
	if pos.y <= 1.05:
		return true
	var world := get_world_3d()
	if world == null:
		return false
	var space_state := world.direct_space_state
	if space_state == null:
		return false
	var origin := enemy.root.global_position
	_ground_ray_query.from = origin
	_ground_ray_query.to = origin + Vector3(0.0, -1.08, 0.0)
	return not space_state.intersect_ray(_ground_ray_query).is_empty()


func apply_graphics_quality(quality: String) -> void:
	_current_graphics_quality = GameSettings._normalize_quality(quality)
	var allow_shadows := (_current_graphics_quality != "LOW")
	var allow_limb_shadows := (_current_graphics_quality == "HIGH")
	for id in enemies.keys():
		var enemy: EnemyInstance = enemies[id]
		if enemy == null or enemy.state != "ALIVE" or enemy.rig == null:
			continue
		enemy.rig.apply_shadow_quality(allow_shadows, allow_limb_shadows)


func get_pooled_count() -> int:
	var total := 0
	for pool_val in _enemy_pools.values():
		var pool := pool_val as Array
		total += pool.size()
	return total


func get_pooled_count_for(personality: String) -> int:
	var key := EnemyBehavior.normalize_personality(personality)
	if not _enemy_pools.has(key):
		return 0
	return (_enemy_pools[key] as Array).size()


func _dispose_enemy(id: int, enemy: EnemyInstance, pool_for_reuse: bool = true) -> void:
	if is_instance_valid(enemy.root):
		if enemy.root.get_parent() != null:
			enemy.root.get_parent().remove_child(enemy.root)
		var key := EnemyBehavior.normalize_personality(enemy.personality)
		var pool: Array = _enemy_pools[key]
		if pool_for_reuse and pool.size() < MAX_POOL_PER_ARCHETYPE:
			pool.append(enemy)
		else:
			enemy.root.free()
	enemies.erase(id)


func _free_pool() -> void:
	for pool_val in _enemy_pools.values():
		var pool := pool_val as Array
		for pooled in pool:
			if pooled != null and is_instance_valid(pooled.root):
				if pooled.root.get_parent() != null:
					pooled.root.get_parent().remove_child(pooled.root)
				pooled.root.free()
		pool.clear()


func _exit_tree() -> void:
	_free_pool()


func clear_all() -> void:
	var ids := enemies.keys()
	for id in ids:
		_dispose_enemy(id, enemies[id], false)
	_free_pool()
