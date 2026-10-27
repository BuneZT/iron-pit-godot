extends TestCase

var _root: Node3D
var _arena: Dictionary
var _builder: ArenaBuilder
var _player: PlayerController


func before_each() -> void:
	_root = Node3D.new()
	scene_tree.root.add_child(_root)
	_arena = ArenaBuilder.build(_root)
	_builder = _arena["builder"]
	_player = PlayerController.new()
	_root.add_child(_player)
	await scene_tree.physics_frame
	await scene_tree.physics_frame


func after_each() -> void:
	if is_instance_valid(_root):
		_root.get_parent().remove_child(_root)
		_root.free()


func test_enables_collision_on_brazier_lamp_meshes() -> void:
	for i in range(4):
		var pedestal := _builder.get_mesh_by_name("brazierPedestal_%d" % i)
		var bowl := _builder.get_mesh_by_name("brazierBowl_%d" % i)
		assert_not_null(pedestal)
		assert_not_null(bowl)
		assert_true(bool(pedestal.get_meta("check_collisions")))
		assert_true(bool(bowl.get_meta("check_collisions")))
		assert_true(bool(pedestal.get_meta("is_pickable")))
		assert_true(bool(bowl.get_meta("is_pickable")))
		assert_not_null(pedestal.get_meta("physics_body"))
		assert_not_null(bowl.get_meta("physics_body"))


func test_stops_player_from_falling_through_brazier_bowl_when_standing_on_it() -> void:
	var pedestal := _builder.get_mesh_by_name("brazierPedestal_0")
	assert_not_null(pedestal)

	_player.position = Vector3(pedestal.position.x, 3.5, pedestal.position.z)

	for i in range(40):
		_player.update(0.016)
		await scene_tree.physics_frame

	assert_gt(_player.position.y, 2.5)


func test_collides_player_with_brazier_lamp_when_moving_into_it() -> void:
	var pedestal := _builder.get_mesh_by_name("brazierPedestal_0")
	assert_not_null(pedestal)

	_player.position = Vector3(pedestal.position.x + 2.0, 0.9, pedestal.position.z)
	_player.yaw = -PI / 2.0
	_player.keys["KeyW"] = true

	for i in range(30):
		_player.update(0.016)
		await scene_tree.physics_frame

	assert_gt(_player.position.x, pedestal.position.x + 0.4)


func test_cleanly_rebuilds_dynamic_layout_on_run_reset() -> void:
	var old_pillar := _builder.get_mesh_by_name("gothicMegalith_0")
	assert_not_null(old_pillar)

	var new_layout := ArenaLayoutGenerator.generate(999)
	_builder.rebuild_dynamic_layout(new_layout)

	var new_pillar := _builder.get_mesh_by_name("gothicMegalith_0")
	assert_not_null(new_pillar)
	assert_not_null(new_pillar.material_override)
	var mat := new_pillar.material_override as StandardMaterial3D
	assert_not_null(mat.albedo_texture)
	assert_near(new_pillar.position.x, float(new_layout["megaliths"][0]["x"]))
	assert_false(is_instance_valid(old_pillar))


func test_configures_materials_to_support_simultaneous_lights_and_nearest_filter() -> void:
	var floor_mesh := _builder.get_mesh_by_name("arenaFloor")
	assert_not_null(floor_mesh)
	var mat := floor_mesh.material_override as StandardMaterial3D
	assert_not_null(mat)
	assert_eq(mat.texture_filter, BaseMaterial3D.TEXTURE_FILTER_NEAREST)
	assert_gte(int(mat.get_meta("max_simultaneous_lights")), 8)
