extends TestCase

var _root: Node3D
var _player: PlayerController


func before_each() -> void:
	_root = Node3D.new()
	scene_tree.root.add_child(_root)

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	col.shape = box
	floor_body.add_child(col)
	_root.add_child(floor_body)

	_player = PlayerController.new()
	_root.add_child(_player)
	await scene_tree.physics_frame
	await scene_tree.physics_frame


func after_each() -> void:
	if is_instance_valid(_root):
		_root.get_parent().remove_child(_root)
		_root.free()


func test_jumps_when_grounded_and_space_is_pressed() -> void:
	assert_near(_player.position.y, 0.9)

	_player.keys["Space"] = true
	_player.update(0.016)

	assert_gt(_player.position.y, 0.95)
	assert_gt(_player.vertical_velocity, 6.0)
	assert_false(_player.is_grounded)


func test_completes_full_jump_trajectory_and_lands_cleanly() -> void:
	_player.keys["Space"] = true
	_player.update(0.016)
	_player.keys.erase("Space")

	var max_apex := _player.position.y

	for frame in range(60):
		_player.update(0.016)
		if _player.position.y > max_apex:
			max_apex = _player.position.y

	assert_gt(max_apex, 2.0)
	assert_near(_player.position.y, 0.9, 0.01)
	assert_near(_player.vertical_velocity, 0.0)
	assert_true(_player.is_grounded)


func test_does_not_allow_double_jumping_in_mid_air() -> void:
	_player.keys["Space"] = true
	_player.update(0.016)

	var vel_after_jump1 := _player.vertical_velocity
	assert_false(_player.is_grounded)

	for i in range(5):
		_player.update(0.016)

	var vel_mid_air_before := _player.vertical_velocity

	_player.keys["Space"] = true
	_player.update(0.016)

	var vel_mid_air_after := _player.vertical_velocity

	assert_lt(vel_mid_air_after, vel_mid_air_before)
	assert_lt(vel_mid_air_after, vel_after_jump1)


func test_clamps_player_within_100m_arena_boundary() -> void:
	_player.position = Vector3(60.0, 0.9, -60.0)
	_player.update(0.016)
	assert_near(_player.position.x, 49.2)
	assert_near(_player.position.z, -49.2)


func test_restricts_camera_far_below_50m_to_prevent_seeing_arena_bounds() -> void:
	assert_lt(_player.camera.far, 50.0)
	assert_near(_player.camera.far, 49.2, 0.1)
