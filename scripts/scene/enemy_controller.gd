class_name EnemyController
extends Node3D


class EnemyInstance:
	extends RefCounted
	var id: int
	var root: RigidBody3D
	var hitbox_area: Area3D
	var parts: Array[MeshInstance3D] = []
	var body_parts: Array[MeshInstance3D] = []
	var shadow_parts: Array[MeshInstance3D] = []
	var eye_visor: MeshInstance3D
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
var _shared_body_mat: StandardMaterial3D
var _shared_flash_body_mat: StandardMaterial3D
var _shared_dead_body_mat: StandardMaterial3D
var _shared_horn_mat: StandardMaterial3D
var _shared_visor_mat: StandardMaterial3D
var _shared_dead_visor_mat: StandardMaterial3D
var _shared_phys_mat: PhysicsMaterial
var _shared_capsule_shape: CapsuleShape3D
var _current_graphics_quality: String = "MEDIUM"
var _enemy_pool: Array[EnemyInstance] = []
var _box_mesh_cache: Dictionary = {}
var _box_shape_cache: Dictionary = {}
var _cyl_mesh_cache: Dictionary = {}
var _cyl_shape_cache: Dictionary = {}


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
	_shared_body_mat = StandardMaterial3D.new()
	_shared_body_mat.resource_name = "enemySharedBodyMat"
	_shared_body_mat.albedo_texture = _iron_texture
	_shared_body_mat.albedo_color = Color(0.58, 0.52, 0.48)
	_shared_body_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_shared_body_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	_shared_body_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_shared_body_mat.roughness = 0.9
	_shared_body_mat.metallic_specular = 0.1

	_shared_flash_body_mat = StandardMaterial3D.new()
	_shared_flash_body_mat.resource_name = "enemySharedFlashBodyMat"
	_shared_flash_body_mat.albedo_texture = _iron_texture
	_shared_flash_body_mat.albedo_color = Color(0.58, 0.52, 0.48)
	_shared_flash_body_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_shared_flash_body_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	_shared_flash_body_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_shared_flash_body_mat.roughness = 0.9
	_shared_flash_body_mat.metallic_specular = 0.1
	_shared_flash_body_mat.emission_enabled = true
	_shared_flash_body_mat.emission = Color(0.85, 0.85, 0.85)

	_shared_dead_body_mat = StandardMaterial3D.new()
	_shared_dead_body_mat.resource_name = "enemySharedDeadBodyMat"
	_shared_dead_body_mat.albedo_texture = _iron_texture
	_shared_dead_body_mat.albedo_color = Color(0.24, 0.22, 0.2)
	_shared_dead_body_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_shared_dead_body_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	_shared_dead_body_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_shared_dead_body_mat.roughness = 0.9
	_shared_dead_body_mat.metallic_specular = 0.1
	_shared_dead_body_mat.emission_enabled = true
	_shared_dead_body_mat.emission = Color(0.12, 0.03, 0.02)

	_shared_horn_mat = StandardMaterial3D.new()
	_shared_horn_mat.resource_name = "enemySharedHornMat"
	_shared_horn_mat.albedo_color = Color(0.38, 0.35, 0.28)
	_shared_horn_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	_shared_horn_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_shared_horn_mat.roughness = 0.95
	_shared_horn_mat.metallic_specular = 0.04

	_shared_visor_mat = StandardMaterial3D.new()
	_shared_visor_mat.resource_name = "enemySharedVisorMat"
	_shared_visor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shared_visor_mat.albedo_color = Color(1.0, 0.18, 0.02)

	_shared_dead_visor_mat = StandardMaterial3D.new()
	_shared_dead_visor_mat.resource_name = "enemySharedDeadVisorMat"
	_shared_dead_visor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shared_dead_visor_mat.albedo_color = Color(0.15, 0.15, 0.15)

	_shared_phys_mat = PhysicsMaterial.new()
	_shared_phys_mat.friction = 0.45
	_shared_phys_mat.bounce = 0.2

	_shared_capsule_shape = CapsuleShape3D.new()
	_shared_capsule_shape.height = 1.8
	_shared_capsule_shape.radius = 0.42


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

	var body_mat := _shared_body_mat
	var horn_mat := _shared_horn_mat
	var visor_mat := _shared_visor_mat
	var allow_shadows := (_current_graphics_quality != "LOW")
	var allow_limb_shadows := (_current_graphics_quality == "HIGH")

	var initial_yaw := 0.0
	if player_pos is Vector3:
		var dir_x: float = player_pos.x - spawn_pt.x
		var dir_z: float = player_pos.z - spawn_pt.z
		initial_yaw = atan2(dir_x, dir_z)

	while not _enemy_pool.is_empty():
		var pooled: EnemyInstance = _enemy_pool.pop_back()
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

			for part in pooled.parts:
				if is_instance_valid(part):
					part.set_meta("enemy_id", id)
			for bp in pooled.body_parts:
				if is_instance_valid(bp):
					bp.material_override = body_mat
			if is_instance_valid(pooled.eye_visor):
				pooled.eye_visor.material_override = visor_mat

			for idx in range(pooled.shadow_parts.size()):
				var sp := pooled.shadow_parts[idx]
				if is_instance_valid(sp):
					var is_core_torso := (idx == 0 or idx == 3)
					var should_cast := allow_shadows if is_core_torso else allow_limb_shadows
					sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if should_cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

			pooled.body_mat = body_mat
			pooled.visor_mat = visor_mat
			pooled.horn_mat = horn_mat
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

	var parts: Array[MeshInstance3D] = []
	var body_parts: Array[MeshInstance3D] = []
	var shadow_parts: Array[MeshInstance3D] = []

	# 2. Heavy Angular Torso (Upper Cuirass, Midsection Vertebrae, Pelvis)
	var chest_plate := _add_box_part(
		"enemyChest_%d" % id,
		Vector3(0.74, 0.48, 0.54),
		Vector3(0.0, 0.22, 0.1),
		Vector3(0.22, 0.0, -0.03),
		body_mat,
		root,
		id,
		allow_shadows
	)
	parts.append(chest_plate)
	body_parts.append(chest_plate)
	shadow_parts.append(chest_plate)

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
	body_parts.append(mid_spine)

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
	body_parts.append(pelvis)

	# 3. Segmented Brawny Legs with Heavy Iron Greaves & Pointed Sabatons
	var thigh_l := _add_box_part(
		"enemyThighL_%d" % id,
		Vector3(0.22, 0.38, 0.26),
		Vector3(-0.2, -0.48, 0.04),
		Vector3(0.12, 0.0, 0.0),
		body_mat,
		root,
		id,
		allow_limb_shadows
	)
	parts.append(thigh_l)
	body_parts.append(thigh_l)
	shadow_parts.append(thigh_l)

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
	body_parts.append(shin_l)

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
	body_parts.append(sabaton_l)

	var thigh_r := _add_box_part(
		"enemyThighR_%d" % id,
		Vector3(0.22, 0.38, 0.26),
		Vector3(0.2, -0.48, -0.02),
		Vector3(-0.08, 0.0, 0.0),
		body_mat,
		root,
		id,
		allow_limb_shadows
	)
	parts.append(thigh_r)
	body_parts.append(thigh_r)
	shadow_parts.append(thigh_r)

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
	body_parts.append(shin_r)

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
	body_parts.append(sabaton_r)

	# 4. Hunched Upper Back Mantle & Sunken Skull Helm
	var hunch_mantle := _add_box_part(
		"enemyHunch_%d" % id,
		Vector3(0.72, 0.44, 0.58),
		Vector3(0.0, 0.46, -0.02),
		Vector3(0.28, 0.0, 0.0),
		body_mat,
		root,
		id,
		allow_shadows
	)
	parts.append(hunch_mantle)
	body_parts.append(hunch_mantle)
	shadow_parts.append(hunch_mantle)

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
	body_parts.append(skull_helm)

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
		allow_limb_shadows
	)
	parts.append(pauldron_left)
	body_parts.append(pauldron_left)
	shadow_parts.append(pauldron_left)

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
		allow_limb_shadows
	)
	parts.append(pauldron_right)
	body_parts.append(pauldron_right)
	shadow_parts.append(pauldron_right)

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
	body_parts.append(bicep_l)

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
	body_parts.append(forearm_l)

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
	body_parts.append(bicep_r)

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
	body_parts.append(forearm_r)

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
	instance.hitbox_area = hitbox_area
	instance.parts = parts
	instance.body_parts = body_parts
	instance.shadow_parts = shadow_parts
	instance.eye_visor = eye_visor
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
	instance.current_yaw = initial_yaw
	instance.prev_position = spawn_pt

	enemies[id] = instance
	return instance


func _get_box_mesh(size: Vector3) -> BoxMesh:
	var key := "%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
	if not _box_mesh_cache.has(key):
		var box := BoxMesh.new()
		box.size = size
		_box_mesh_cache[key] = box
	return _box_mesh_cache[key]


func _get_box_shape(size: Vector3) -> BoxShape3D:
	var key := "%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
	if not _box_shape_cache.has(key):
		var shape := BoxShape3D.new()
		shape.size = size
		_box_shape_cache[key] = shape
	return _box_shape_cache[key]


func _get_cyl_mesh(d_top: float, d_bot: float, h: float, segs: int) -> CylinderMesh:
	var key := "%.3f_%.3f_%.3f_%d" % [d_top, d_bot, h, segs]
	if not _cyl_mesh_cache.has(key):
		var cyl := CylinderMesh.new()
		cyl.top_radius = d_top / 2.0
		cyl.bottom_radius = d_bot / 2.0
		cyl.height = h
		cyl.radial_segments = maxi(4, segs)
		cyl.rings = 1
		_cyl_mesh_cache[key] = cyl
	return _cyl_mesh_cache[key]


func _get_cyl_shape(d_top: float, d_bot: float, h: float) -> CylinderShape3D:
	var key := "%.3f_%.3f_%.3f" % [d_top, d_bot, h]
	if not _cyl_shape_cache.has(key):
		var shape := CylinderShape3D.new()
		shape.height = h
		shape.radius = maxf(d_top, d_bot) / 2.0
		_cyl_shape_cache[key] = shape
	return _cyl_shape_cache[key]


func _compute_transform_relative_to_root(node: Node3D, root_node: Node3D) -> Transform3D:
	var xform := node.transform
	var p := node.get_parent()
	while p is Node3D and p != root_node:
		xform = (p as Node3D).transform * xform
		p = p.get_parent()
	return xform


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
	mi.mesh = _get_box_mesh(size)
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("enemy_id", enemy_id)
	parent.add_child(mi)

	var root_node := parent if parent is RigidBody3D else parent.get_parent() as Node3D
	var hit_area := root_node.get_node_or_null("HitboxCompoundArea") as Area3D
	if hit_area != null:
		var col := CollisionShape3D.new()
		col.shape = _get_box_shape(size)
		col.transform = _compute_transform_relative_to_root(mi, root_node)
		hit_area.add_child(col)

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
	mi.mesh = _get_cyl_mesh(d_top, d_bot, h, segs)
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("enemy_id", enemy_id)
	parent.add_child(mi)

	var root_node := parent if parent is RigidBody3D else parent.get_parent() as Node3D
	var hit_area := root_node.get_node_or_null("HitboxCompoundArea") as Area3D
	if hit_area != null:
		var col := CollisionShape3D.new()
		col.shape = _get_cyl_shape(d_top, d_bot, h)
		col.transform = _compute_transform_relative_to_root(mi, root_node)
		hit_area.add_child(col)

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
		enemy.body_mat = _shared_flash_body_mat
		for bp in enemy.body_parts:
			if is_instance_valid(bp):
				bp.material_override = _shared_flash_body_mat

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
	enemy.body_mat = _shared_dead_body_mat
	enemy.visor_mat = _shared_dead_visor_mat
	for bp in enemy.body_parts:
		if is_instance_valid(bp):
			bp.material_override = _shared_dead_body_mat
	if is_instance_valid(enemy.eye_visor):
		enemy.eye_visor.material_override = _shared_dead_visor_mat
	for part in enemy.parts:
		if is_instance_valid(part):
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
				enemy.body_mat = _shared_body_mat
				for bp in enemy.body_parts:
					if is_instance_valid(bp):
						bp.material_override = _shared_body_mat

		if enemy.state == "KNOCKED_DOWN":
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
			if absf(angle_difference(enemy.current_yaw, target_yaw)) > 0.025:
				enemy.current_yaw = target_yaw
				enemy.root.rotation = Vector3(0.0, target_yaw, 0.0)
		else:
			enemy.stuck_timer = 0.0

		# Clamp within arena bounds (±49.2m)
		if absf(pos.x) > 49.2 or absf(pos.z) > 49.2:
			enemy.root.position = Vector3(
				clampf(pos.x, -49.2, 49.2),
				pos.y,
				clampf(pos.z, -49.2, 49.2)
			)

	return contact_damage_triggered


func apply_graphics_quality(quality: String) -> void:
	_current_graphics_quality = GameSettings._normalize_quality(quality)
	var allow_shadows := (_current_graphics_quality != "LOW")
	var allow_limb_shadows := (_current_graphics_quality == "HIGH")
	for id in enemies.keys():
		var enemy: EnemyInstance = enemies[id]
		if enemy == null or enemy.state != "ALIVE":
			continue
		for idx in range(enemy.shadow_parts.size()):
			var sp := enemy.shadow_parts[idx]
			if not is_instance_valid(sp):
				continue
			var is_core_torso := (idx == 0 or idx == 3)
			var should_cast := allow_shadows if is_core_torso else allow_limb_shadows
			sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if should_cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func get_pooled_count() -> int:
	return _enemy_pool.size()


func _dispose_enemy(id: int, enemy: EnemyInstance, pool_for_reuse: bool = true) -> void:
	if is_instance_valid(enemy.root):
		if enemy.root.get_parent() != null:
			enemy.root.get_parent().remove_child(enemy.root)
		if pool_for_reuse and _enemy_pool.size() < 24:
			_enemy_pool.append(enemy)
		else:
			enemy.root.free()
	enemies.erase(id)


func _free_pool() -> void:
	for pooled in _enemy_pool:
		if pooled != null and is_instance_valid(pooled.root):
			if pooled.root.get_parent() != null:
				pooled.root.get_parent().remove_child(pooled.root)
			pooled.root.free()
	_enemy_pool.clear()


func _exit_tree() -> void:
	_free_pool()


func clear_all() -> void:
	var ids := enemies.keys()
	for id in ids:
		_dispose_enemy(id, enemies[id], false)
	_free_pool()
