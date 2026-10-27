class_name WeaponController
extends Node3D

var camera: Camera3D
var gun_rig: Node3D
var muzzle_node: Node3D
var muzzle_flash_mesh: MeshInstance3D
var muzzle_light: OmniLight3D

# In Godot Camera3D local space, -Z is forward
var rest_position: Vector3 = Vector3(0.32, -0.28, -0.62)
var _recoil_offset_z: float = 0.0
var _recoil_pitch: float = 0.0
var _reload_tilt: float = 0.0
var _muzzle_flash_timer: float = 0.0

var _tracer_mesh_instance: MeshInstance3D
var _tracer_immediate_mesh: ImmediateMesh
var _tracer_mat: StandardMaterial3D
var _tracer_timer: float = 0.0


func _init(target_camera: Camera3D = null) -> void:
	name = "WeaponController"
	if target_camera != null:
		setup(target_camera)


func setup(target_camera: Camera3D) -> void:
	camera = target_camera
	gun_rig = Node3D.new()
	gun_rig.name = "weaponRig"
	camera.add_child(gun_rig)
	gun_rig.position = rest_position

	var iron_tex: Texture2D = load("res://assets/textures/rusted_iron.png")
	var dark_iron_mat := StandardMaterial3D.new()
	dark_iron_mat.resource_name = "gunIronMat"
	dark_iron_mat.albedo_texture = iron_tex
	dark_iron_mat.albedo_color = Color(0.7, 0.68, 0.68)
	dark_iron_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	dark_iron_mat.roughness = 0.78
	dark_iron_mat.metallic_specular = 0.2

	var aged_wood_mat := StandardMaterial3D.new()
	aged_wood_mat.resource_name = "gunWoodMat"
	aged_wood_mat.albedo_color = Color(0.24, 0.16, 0.1)
	aged_wood_mat.roughness = 0.92
	aged_wood_mat.metallic_specular = 0.08

	var brass_mat := StandardMaterial3D.new()
	brass_mat.resource_name = "gunBrassMat"
	brass_mat.albedo_color = Color(0.68, 0.52, 0.22)
	brass_mat.roughness = 0.55
	brass_mat.metallic_specular = 0.45

	# 1. Heavy Blackened Iron Receiver
	_add_gun_box("gunReceiver", Vector3(0.12, 0.15, 0.46), Vector3.ZERO, Vector3.ZERO, dark_iron_mat)

	# 2. Heavy Octagonal Iron Barrel (extending forward along -Z)
	_add_gun_cylinder("gunBarrel", 0.088, 0.088, 0.42, 8, Vector3(0.0, 0.03, -0.38), Vector3(PI / 2.0, 0.0, 0.0), dark_iron_mat)

	# 3. Flanged Iron Muzzle Ring
	_add_gun_cylinder("gunMuzzleRing", 0.115, 0.115, 0.06, 8, Vector3(0.0, 0.03, -0.58), Vector3(PI / 2.0, 0.0, 0.0), dark_iron_mat)

	# 4. Tarnished Brass Clamping Band & Heat Vent
	_add_gun_box("gunBand", Vector3(0.13, 0.16, 0.06), Vector3(0.0, 0.01, -0.14), Vector3.ZERO, brass_mat)

	# Brass heat shroud atop barrel
	_add_gun_box("gunHeatShroud", Vector3(0.095, 0.04, 0.24), Vector3(0.0, 0.075, -0.32), Vector3.ZERO, brass_mat)

	# Welded side iron plate (asymmetrical battle repair)
	_add_gun_box("gunSidePlate", Vector3(0.025, 0.11, 0.26), Vector3(-0.068, 0.01, -0.04), Vector3(0.0, 0.0, 0.04), dark_iron_mat)

	# Jagged cocking lever on right side
	_add_gun_cylinder("gunCockingLever", 0.024, 0.024, 0.08, 5, Vector3(0.08, 0.04, 0.05), Vector3(0.0, 0.0, PI / 2.0), dark_iron_mat)

	# Crooked front iron sight notch
	_add_gun_box("gunFrontSight", Vector3(0.016, 0.038, 0.04), Vector3(0.0, 0.096, -0.54), Vector3(0.0, -0.05, 0.0), dark_iron_mat)

	# 5. Aged Oak Stock / Handle
	_add_gun_box("gunGrip", Vector3(0.09, 0.18, 0.16), Vector3(0.0, -0.12, 0.14), Vector3(0.32, 0.0, 0.0), aged_wood_mat)

	# Muzzle Node for flash, tracers, and dynamic flash light
	muzzle_node = Node3D.new()
	muzzle_node.name = "gunMuzzleNode"
	gun_rig.add_child(muzzle_node)
	muzzle_node.position = Vector3(0.0, 0.03, -0.62)

	var flash_mat := StandardMaterial3D.new()
	flash_mat.resource_name = "muzzleFlashMat"
	flash_mat.albedo_color = Color(1.0, 0.65, 0.15)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.55, 0.05)
	flash_mat.emission_energy_multiplier = 2.0

	muzzle_flash_mesh = MeshInstance3D.new()
	muzzle_flash_mesh.name = "muzzleFlashMesh"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.11
	cone.bottom_radius = 0.02
	cone.height = 0.3
	cone.radial_segments = 6
	muzzle_flash_mesh.mesh = cone
	muzzle_flash_mesh.material_override = flash_mat
	muzzle_flash_mesh.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	muzzle_flash_mesh.position = Vector3(0.0, 0.0, -0.14)
	muzzle_flash_mesh.visible = false
	muzzle_flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle_node.add_child(muzzle_flash_mesh)

	muzzle_light = OmniLight3D.new()
	muzzle_light.name = "gunMuzzleLight"
	muzzle_light.light_color = Color(1.0, 0.65, 0.2)
	muzzle_light.omni_range = 14.0
	muzzle_light.light_energy = 0.0
	muzzle_node.add_child(muzzle_light)

	_tracer_mat = StandardMaterial3D.new()
	_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_mat.albedo_color = Color(1.0, 0.72, 0.22)
	_tracer_immediate_mesh = ImmediateMesh.new()
	_tracer_mesh_instance = MeshInstance3D.new()
	_tracer_mesh_instance.name = "shotTracer"
	_tracer_mesh_instance.mesh = _tracer_immediate_mesh
	_tracer_mesh_instance.material_override = _tracer_mat
	_tracer_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tracer_mesh_instance.top_level = true
	_tracer_mesh_instance.visible = false
	gun_rig.add_child(_tracer_mesh_instance)


func _add_gun_box(part_name: String, size: Vector3, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gun_rig.add_child(mi)
	return mi


func _add_gun_cylinder(part_name: String, d_top: float, d_bot: float, h: float, segs: int, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = d_top / 2.0
	cyl.bottom_radius = d_bot / 2.0
	cyl.height = h
	cyl.radial_segments = segs
	cyl.rings = 1
	mi.mesh = cyl
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gun_rig.add_child(mi)
	return mi


func fire_raycast() -> Dictionary:
	_recoil_offset_z = 0.14
	_recoil_pitch = 0.18
	_muzzle_flash_timer = 0.05
	muzzle_flash_mesh.visible = true
	var s := 0.85 + randf() * 0.4
	muzzle_flash_mesh.scale = Vector3(s, s, s)
	muzzle_light.light_energy = 1.7

	var origin := camera.global_position
	var forward := (-camera.global_transform.basis.z).normalized()
	var ray_end := origin + forward * 49.2

	var hit_point := origin + forward * 40.7
	var enemy_id: Variant = null

	var world := camera.get_world_3d()
	if world != null and world.direct_space_state != null:
		var query := PhysicsRayQueryParameters3D.create(origin, ray_end, 1 | 8)
		query.collide_with_bodies = true
		query.collide_with_areas = true
		var result := world.direct_space_state.intersect_ray(query)
		if not result.is_empty():
			hit_point = result["position"]
			var collider: Object = result["collider"]
			if collider != null and collider.has_meta("enemy_id"):
				enemy_id = int(collider.get_meta("enemy_id"))

	_spawn_tracer(muzzle_node.global_position, hit_point)

	return {
		"enemy_id": enemy_id,
		"hit_point": hit_point,
		"ray_direction": forward,
	}


func _spawn_tracer(start_pt: Vector3, end_pt: Vector3) -> void:
	_tracer_immediate_mesh.clear_surfaces()
	_tracer_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_tracer_immediate_mesh.surface_add_vertex(start_pt)
	_tracer_immediate_mesh.surface_add_vertex(end_pt)
	_tracer_immediate_mesh.surface_end()
	_tracer_mesh_instance.visible = true
	_tracer_timer = 0.055


func update(dt: float, is_reloading: bool) -> void:
	_recoil_offset_z = maxf(0.0, _recoil_offset_z - dt * 0.95)
	_recoil_pitch = maxf(0.0, _recoil_pitch - dt * 1.2)

	var target_reload_tilt := -0.45 if is_reloading else 0.0
	_reload_tilt += (target_reload_tilt - _reload_tilt) * minf(1.0, dt * 12.0)

	gun_rig.position = Vector3(
		rest_position.x,
		rest_position.y + _reload_tilt * 0.18,
		rest_position.z + _recoil_offset_z
	)
	gun_rig.rotation = Vector3(
		_recoil_pitch + _reload_tilt,
		0.0,
		-0.35 if is_reloading else 0.0
	)

	if _muzzle_flash_timer > 0.0:
		_muzzle_flash_timer -= dt
		if _muzzle_flash_timer <= 0.0:
			muzzle_flash_mesh.visible = false
			muzzle_light.light_energy = 0.0

	if _tracer_timer > 0.0:
		_tracer_timer -= dt
		if _tracer_timer <= 0.0:
			_tracer_mesh_instance.visible = false
