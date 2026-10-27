class_name ArenaBuilder
extends Node3D

var world_environment: WorldEnvironment
var directional_light: DirectionalLight3D
var brazier_lights: Array[OmniLight3D] = []
var spawn_points: Array[Vector3] = [
	Vector3(-42.0, 1.1, -42.0),
	Vector3(42.0, 1.1, -42.0),
	Vector3(-42.0, 1.1, 42.0),
	Vector3(42.0, 1.1, 42.0),
]

var _dynamic_nodes: Array[Node3D] = []
var _static_container: Node3D
var _dynamic_container: Node3D

var floor_mat: StandardMaterial3D
var wall_mat: StandardMaterial3D
var crypt_mat: StandardMaterial3D
var iron_mat: StandardMaterial3D
var ember_mat: StandardMaterial3D


func _init() -> void:
	name = "ArenaBuilder"
	_static_container = Node3D.new()
	_static_container.name = "StaticPerimeter"
	add_child(_static_container)

	_dynamic_container = Node3D.new()
	_dynamic_container.name = "DynamicLayout"
	add_child(_dynamic_container)

	_init_atmosphere()
	_init_materials()
	_build_static_perimeter()


func _init_atmosphere() -> void:
	var fog_ash_grey := Color(0.24, 0.25, 0.27, 1.0)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = fog_ash_grey
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.44, 0.46)
	env.ambient_light_energy = 0.65
	env.fog_enabled = true
	env.fog_light_color = Color(0.24, 0.25, 0.27)
	env.fog_light_energy = 1.0
	env.fog_density = 0.054

	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = env
	add_child(world_environment)

	directional_light = DirectionalLight3D.new()
	directional_light.name = "diffuseSun"
	directional_light.position = Vector3(35.0, 45.0, 30.0)
	directional_light.basis = Basis.looking_at(Vector3(-0.4, -1.0, -0.3).normalized(), Vector3.UP)
	directional_light.light_color = Color(0.75, 0.76, 0.78)
	directional_light.light_energy = 0.45
	directional_light.shadow_enabled = true
	directional_light.shadow_blur = 1.5
	add_child(directional_light)


func _init_materials() -> void:
	var floor_tex: Texture2D = load("res://assets/textures/stone_floor.png")
	floor_mat = StandardMaterial3D.new()
	floor_mat.resource_name = "retroFloorMat"
	floor_mat.albedo_texture = floor_tex
	floor_mat.uv1_scale = Vector3(40.0, 40.0, 1.0)
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	floor_mat.roughness = 0.98
	floor_mat.metallic_specular = 0.01
	floor_mat.set_meta("max_simultaneous_lights", 10)

	var wall_tex: Texture2D = load("res://assets/textures/dungeon_wall.png")
	wall_mat = StandardMaterial3D.new()
	wall_mat.resource_name = "retroWallMat"
	wall_mat.albedo_texture = wall_tex
	wall_mat.uv1_scale = Vector3(8.0, 2.5, 1.0)
	wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	wall_mat.roughness = 0.98
	wall_mat.metallic_specular = 0.01
	wall_mat.set_meta("max_simultaneous_lights", 10)

	var crypt_tex: Texture2D = load("res://assets/textures/crypt_stone.png")
	crypt_mat = StandardMaterial3D.new()
	crypt_mat.resource_name = "retroCryptMat"
	crypt_mat.albedo_texture = crypt_tex
	crypt_mat.uv1_scale = Vector3(3.0, 3.0, 1.0)
	crypt_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	crypt_mat.roughness = 0.98
	crypt_mat.metallic_specular = 0.01
	crypt_mat.set_meta("max_simultaneous_lights", 10)

	var iron_tex: Texture2D = load("res://assets/textures/rusted_iron.png")
	iron_mat = StandardMaterial3D.new()
	iron_mat.resource_name = "retroIronMat"
	iron_mat.albedo_texture = iron_tex
	iron_mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
	iron_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	iron_mat.roughness = 0.88
	iron_mat.metallic_specular = 0.12
	iron_mat.set_meta("max_simultaneous_lights", 10)

	ember_mat = StandardMaterial3D.new()
	ember_mat.resource_name = "brazierEmberMat"
	ember_mat.albedo_color = Color(1.0, 0.55, 0.1)
	ember_mat.emission_enabled = true
	ember_mat.emission = Color(1.0, 0.45, 0.05)
	ember_mat.emission_energy_multiplier = 1.5


func _create_box_mesh_node(
	node_name: String,
	size: Vector3,
	pos: Vector3,
	rot: Vector3,
	mat: Material,
	parent: Node3D,
	with_collision: bool,
	is_pickable: bool,
	cast_shadow: bool = true
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mi.mesh = box_mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("check_collisions", with_collision)
	mi.set_meta("is_pickable", is_pickable)

	if with_collision or is_pickable:
		var body := StaticBody3D.new()
		body.name = "StaticBody3D"
		body.collision_layer = 1
		body.collision_mask = 0
		var col := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		col.shape = box_shape
		body.add_child(col)
		mi.add_child(body)
		mi.set_meta("physics_body", body)

	parent.add_child(mi)
	return mi


func _create_cylinder_mesh_node(
	node_name: String,
	diam_top: float,
	diam_bottom: float,
	height: float,
	tessellation: int,
	pos: Vector3,
	rot: Vector3,
	mat: Material,
	parent: Node3D,
	with_collision: bool,
	is_pickable: bool,
	cast_shadow: bool = true
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var cyl_mesh := CylinderMesh.new()
	cyl_mesh.top_radius = diam_top / 2.0
	cyl_mesh.bottom_radius = diam_bottom / 2.0
	cyl_mesh.height = height
	cyl_mesh.radial_segments = maxi(4, tessellation)
	cyl_mesh.rings = 1
	mi.mesh = cyl_mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("check_collisions", with_collision)
	mi.set_meta("is_pickable", is_pickable)

	if with_collision or is_pickable:
		var body := StaticBody3D.new()
		body.name = "StaticBody3D"
		body.collision_layer = 1
		body.collision_mask = 0
		var col := CollisionShape3D.new()
		var cyl_shape := CylinderShape3D.new()
		cyl_shape.height = height
		cyl_shape.radius = maxf(diam_top, diam_bottom) / 2.0
		col.shape = cyl_shape
		body.add_child(col)
		mi.add_child(body)
		mi.set_meta("physics_body", body)

	parent.add_child(mi)
	return mi


func _build_static_perimeter() -> void:
	var arena_size := 100.0
	_create_box_mesh_node(
		"arenaFloor",
		Vector3(arena_size, 1.0, arena_size),
		Vector3(0.0, -0.5, 0.0),
		Vector3.ZERO,
		floor_mat,
		_static_container,
		true,
		true,
		false
	)

	var parapet_height := 1.5
	var parapet_thickness := 0.8
	var half := arena_size / 2.0

	var wall_configs: Array[Dictionary] = [
		{
			"name": "parapetNorth",
			"w": arena_size + parapet_thickness * 2.0,
			"d": parapet_thickness,
			"x": 0.0,
			"z": half + parapet_thickness / 2.0,
			"is_along_x": true,
		},
		{
			"name": "parapetSouth",
			"w": arena_size + parapet_thickness * 2.0,
			"d": parapet_thickness,
			"x": 0.0,
			"z": -(half + parapet_thickness / 2.0),
			"is_along_x": true,
		},
		{
			"name": "parapetEast",
			"w": parapet_thickness,
			"d": arena_size,
			"x": half + parapet_thickness / 2.0,
			"z": 0.0,
			"is_along_x": false,
		},
		{
			"name": "parapetWest",
			"w": parapet_thickness,
			"d": arena_size,
			"x": -(half + parapet_thickness / 2.0),
			"z": 0.0,
			"is_along_x": false,
		},
	]

	for cfg in wall_configs:
		var w_name: String = cfg["name"]
		var w_width: float = float(cfg["w"])
		var w_depth: float = float(cfg["d"])
		var w_x: float = float(cfg["x"])
		var w_z: float = float(cfg["z"])
		var is_along_x: bool = bool(cfg["is_along_x"])

		_create_box_mesh_node(
			w_name,
			Vector3(w_width, parapet_height, w_depth),
			Vector3(w_x, parapet_height / 2.0, w_z),
			Vector3.ZERO,
			wall_mat,
			_static_container,
			true,
			true,
			true
		)

		var inv_wall := _create_box_mesh_node(
			"%s_invisibleBound" % w_name,
			Vector3(w_width, 6.0, w_depth),
			Vector3(w_x, 3.0 + parapet_height, w_z),
			Vector3.ZERO,
			wall_mat,
			_static_container,
			true,
			false,
			false
		)
		inv_wall.visible = false

		var spike_count := 36
		var step := arena_size / float(spike_count)
		for i in range(-spike_count / 2, spike_count / 2 + 1):
			var tilt_z := sin(float(i) * 3.7 + w_x * 2.1) * 0.18
			var tilt_x := cos(float(i) * 2.9 + w_z * 1.7) * 0.18
			var spike_h := 0.65 + absf(sin(float(i) * 1.9 + w_x)) * 0.32
			var spike_pos := Vector3(
				float(i) * step if is_along_x else w_x,
				parapet_height + spike_h / 2.0,
				w_z if is_along_x else float(i) * step
			)
			_create_cylinder_mesh_node(
				"%s_spike_%d" % [w_name, i],
				0.02,
				0.12,
				spike_h,
				5,
				spike_pos,
				Vector3(tilt_x, 0.0, tilt_z),
				iron_mat,
				_static_container,
				false,
				false,
				false
			)


func rebuild_dynamic_layout(layout: Dictionary) -> Array[OmniLight3D]:
	for light in brazier_lights:
		if is_instance_valid(light):
			if light.get_parent() != null:
				light.get_parent().remove_child(light)
			light.free()
	brazier_lights.clear()

	for node in _dynamic_nodes:
		if is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.free()
	_dynamic_nodes.clear()

	# 1. Build Megaliths
	var megaliths: Array = layout.get("megaliths", [])
	for idx in range(megaliths.size()):
		var obs: Dictionary = megaliths[idx]
		var ox: float = float(obs["x"])
		var oz: float = float(obs["z"])
		var ow: float = float(obs["width"])
		var oh: float = float(obs["height"])
		var od: float = float(obs["depth"])
		var rot_y: float = float(obs["rotation_y"])
		var cap_angle: float = float(obs.get("cap_angle", float(idx) * 0.9))

		var pillar := _create_box_mesh_node(
			"gothicMegalith_%d" % idx,
			Vector3(ow, oh, od),
			Vector3(ox, oh / 2.0, oz),
			Vector3(0.0, rot_y, 0.0),
			crypt_mat,
			_dynamic_container,
			true,
			true,
			true
		)
		_dynamic_nodes.append(pillar)

		var cap := _create_cylinder_mesh_node(
			"megalithCap_%d" % idx,
			ow * 0.78,
			ow * 1.04,
			0.8,
			5,
			Vector3(ox + 0.06, oh + 0.38, oz - 0.05),
			Vector3(0.08, cap_angle, -0.06),
			crypt_mat,
			_dynamic_container,
			false,
			true,
			true
		)
		_dynamic_nodes.append(cap)

		var rubble_offset: Dictionary = obs.get("rubble_offset", {
			"x": 2.2 if idx % 2 == 0 else -2.2,
			"z": 2.1 if idx > 1 else -2.1,
		})
		var rubble := _create_box_mesh_node(
			"megalithRubble_%d" % idx,
			Vector3(1.2, 0.55, 1.0),
			Vector3(ox + float(rubble_offset["x"]), 0.28, oz + float(rubble_offset["z"])),
			Vector3(0.14, float(idx) * 1.3, -0.18),
			crypt_mat,
			_dynamic_container,
			true,
			true,
			true
		)
		_dynamic_nodes.append(rubble)

		for band_y in [oh * 0.35, oh * 0.75]:
			var band := _create_box_mesh_node(
				"pillarBand_%d_%.1f" % [idx, band_y],
				Vector3(ow + 0.14, 0.26, od + 0.14),
				Vector3(ox, band_y, oz),
				Vector3(0.0, rot_y, 0.03 if idx % 2 == 0 else -0.03),
				iron_mat,
				_dynamic_container,
				false,
				false,
				false
			)
			_dynamic_nodes.append(band)

	# 2. Build Crypt Barricades
	var barricades: Array = layout.get("barricades", [])
	for idx in range(barricades.size()):
		var obs: Dictionary = barricades[idx]
		var ox: float = float(obs["x"])
		var oz: float = float(obs["z"])
		var ow: float = float(obs["width"])
		var oh: float = float(obs["height"])
		var od: float = float(obs["depth"])
		var rot_y: float = float(obs["rotation_y"])

		var slab := _create_box_mesh_node(
			"cryptBarricade_%d" % idx,
			Vector3(ow, oh, od),
			Vector3(ox, oh / 2.0, oz),
			Vector3(0.0, rot_y, 0.0),
			wall_mat,
			_dynamic_container,
			true,
			true,
			true
		)
		_dynamic_nodes.append(slab)

		var iron_cap := _create_box_mesh_node(
			"barricadeCap_%d" % idx,
			Vector3(ow + 0.08, 0.14, od + 0.08),
			Vector3(ox, oh + 0.07, oz),
			Vector3(0.015, rot_y, 0.02 if idx % 2 == 0 else -0.02),
			iron_mat,
			_dynamic_container,
			false,
			false,
			false
		)
		_dynamic_nodes.append(iron_cap)

		var frag := _create_box_mesh_node(
			"barricadeFrag_%d" % idx,
			Vector3(0.8, 0.4, 0.7),
			Vector3(
				ox + (ow / 2.0 + 0.5 if ow > od else 0.0),
				0.2,
				oz + (od / 2.0 + 0.5 if od > ow else 0.0)
			),
			Vector3(-0.1, float(idx) * 0.8, 0.15),
			wall_mat,
			_dynamic_container,
			true,
			true,
			true
		)
		_dynamic_nodes.append(frag)

	# 3. Build Braziers
	var braziers: Array = layout.get("braziers", [])
	var leg_angles: Array[float] = [0.0, (2.0 * PI) / 3.0, (4.0 * PI) / 3.0]
	for idx in range(braziers.size()):
		var pos: Dictionary = braziers[idx]
		var bx: float = float(pos["x"])
		var bz: float = float(pos["z"])

		for leg_idx in range(leg_angles.size()):
			var ang := leg_angles[leg_idx]
			var leg_dist := 0.35
			var leg := _create_cylinder_mesh_node(
				"brazierLeg_%d_%d" % [idx, leg_idx],
				0.08,
				0.08,
				1.6,
				5,
				Vector3(bx + cos(ang) * leg_dist, 0.75, bz + sin(ang) * leg_dist),
				Vector3(sin(ang) * 0.22, 0.0, -cos(ang) * 0.22),
				iron_mat,
				_dynamic_container,
				false,
				true,
				true
			)
			_dynamic_nodes.append(leg)

		var pedestal := _create_cylinder_mesh_node(
			"brazierPedestal_%d" % idx,
			0.45,
			0.7,
			1.4,
			6,
			Vector3(bx, 0.7, bz),
			Vector3.ZERO,
			iron_mat,
			_dynamic_container,
			true,
			true,
			true
		)
		_dynamic_nodes.append(pedestal)

		var bowl := _create_cylinder_mesh_node(
			"brazierBowl_%d" % idx,
			1.35,
			0.6,
			0.48,
			7,
			Vector3(bx, 1.62, bz),
			Vector3(0.0, float(idx) * 0.4, 0.0),
			iron_mat,
			_dynamic_container,
			true,
			true,
			true
		)
		_dynamic_nodes.append(bowl)

		var embers := MeshInstance3D.new()
		embers.name = "brazierEmbers_%d" % idx
		var sphere := SphereMesh.new()
		sphere.radius = 0.425
		sphere.height = 0.85
		sphere.radial_segments = 6
		sphere.rings = 4
		embers.mesh = sphere
		embers.material_override = ember_mat
		embers.position = Vector3(bx, 1.82, bz)
		embers.set_meta("check_collisions", false)
		embers.set_meta("is_pickable", false)
		_dynamic_container.add_child(embers)
		_dynamic_nodes.append(embers)

		var fire_light := OmniLight3D.new()
		fire_light.name = "brazierLight_%d" % idx
		fire_light.position = Vector3(bx, 2.3, bz)
		fire_light.light_color = Color(1.0, 0.62, 0.22)
		fire_light.light_energy = 0.95
		fire_light.omni_range = 22.0
		_dynamic_container.add_child(fire_light)
		brazier_lights.append(fire_light)

	return brazier_lights


func update_brazier_resanctification(wave: int) -> void:
	var wave_progress := clampf(float(wave - 1) / 9.0, 0.0, 1.0)
	var r := 1.0
	var g := 0.62 + wave_progress * 0.23
	var b := 0.22 + wave_progress * 0.18
	for light in brazier_lights:
		if is_instance_valid(light):
			light.light_color = Color(r, g, b)
			light.omni_range = 22.0 + wave_progress * 8.0


func get_mesh_by_name(mesh_name: String) -> MeshInstance3D:
	var found := find_child(mesh_name, true, false)
	if found is MeshInstance3D:
		return found as MeshInstance3D
	return null


static func build(parent_scene: Node3D, layout: Variant = null) -> Dictionary:
	var builder := ArenaBuilder.new()
	parent_scene.add_child(builder)
	var active_layout: Dictionary = layout if typeof(layout) == TYPE_DICTIONARY else ArenaLayoutGenerator.generate(1)
	var lights := builder.rebuild_dynamic_layout(active_layout)
	return {
		"shadow_generator": builder.directional_light,
		"brazier_lights": lights,
		"builder": builder,
		"spawn_points": builder.spawn_points,
	}
