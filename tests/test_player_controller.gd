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


func test_can_jump_onto_barricade_but_not_tall_megalith() -> void:
	# Place a 1.9m-tall barricade ahead of the player (+Z)
	var barricade := StaticBody3D.new()
	barricade.collision_layer = 1
	barricade.collision_mask = 0
	barricade.position = Vector3(0.0, 0.95, 2.2)
	var b_col := CollisionShape3D.new()
	var b_box := BoxShape3D.new()
	b_box.size = Vector3(4.0, 1.9, 1.4)
	b_col.shape = b_box
	barricade.add_child(b_col)
	_root.add_child(barricade)
	await scene_tree.physics_frame

	_player.position = Vector3(0.0, 0.9, 0.0)
	_player.yaw = 0.0
	_player.keys["KeyW"] = true
	_player.keys["Space"] = true

	for frame in range(55):
		if frame == 1:
			_player.keys.erase("Space")
		if _player.position.z > 2.0:
			_player.keys.erase("KeyW")
		_player.update(0.016)
		await scene_tree.physics_frame

	# Player should land on top of the 1.9m barricade (center y ~= 2.8)
	assert_gt(_player.position.y, 2.7)
	assert_lt(_player.position.y, 3.1)
	assert_true(_player.is_grounded)

	# Verify jump apex from flat ground cannot reach a 4.4m megalith (feet must stay < 3.5m -> center < 4.4m)
	_player.reset()
	_player.position = Vector3(0.0, 0.9, -6.0)
	_player.keys["Space"] = true
	_player.update(0.016)
	_player.keys.erase("Space")
	var peak_y := _player.position.y
	for frame in range(60):
		_player.update(0.016)
		peak_y = maxf(peak_y, _player.position.y)
	assert_gt(peak_y, 2.95)
	assert_lt(peak_y, 3.6)
