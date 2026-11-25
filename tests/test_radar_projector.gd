extends TestCase


func test_projects_enemy_directly_ahead_at_yaw_zero_to_top_of_radar() -> void:
	var enemies := PackedVector3Array([Vector3(0.0, 0.9, 19.0)])
	var blips := RadarProjector.project(Vector3.ZERO, 0.0, enemies, 38.0)

	assert_eq(blips.size(), 1)
	assert_near(blips[0].x, 0.0, 0.001)
	assert_near(blips[0].y, -0.5, 0.001)
	assert_near(blips[0].z, 0.5, 0.001)


func test_projects_right_left_and_behind_at_yaw_zero() -> void:
	# At yaw=0: forward=(0,0,1), right=(-1,0,0)
	var enemies := PackedVector3Array([
		Vector3(-19.0, 0.9, 0.0),   # Right
		Vector3(19.0, 0.9, 0.0),    # Left
		Vector3(0.0, 0.9, -19.0),   # Behind
	])
	var blips := RadarProjector.project(Vector3.ZERO, 0.0, enemies, 38.0)

	assert_eq(blips.size(), 3)
	assert_near(blips[0].x, 0.5, 0.001)
	assert_near(blips[0].y, 0.0, 0.001)

	assert_near(blips[1].x, -0.5, 0.001)
	assert_near(blips[1].y, 0.0, 0.001)

	assert_near(blips[2].x, 0.0, 0.001)
	assert_near(blips[2].y, 0.5, 0.001)


func test_rotates_blips_with_player_yaw() -> void:
	# At yaw = PI/2: forward=(1,0,0), right=(0,0,1)
	var enemies := PackedVector3Array([
		Vector3(19.0, 0.9, 0.0),   # Ahead
		Vector3(0.0, 0.9, 19.0),   # Right
	])
	var blips := RadarProjector.project(Vector3.ZERO, PI * 0.5, enemies, 38.0)

	assert_near(blips[0].x, 0.0, 0.001)
	assert_near(blips[0].y, -0.5, 0.001)

	assert_near(blips[1].x, 0.5, 0.001)
	assert_near(blips[1].y, 0.0, 0.001)


func test_clamps_out_of_range_enemies_onto_unit_rim_with_ratio_gt_one() -> void:
	var enemies := PackedVector3Array([
		Vector3(0.0, 0.9, -76.0),   # 2x scan_radius directly behind
		Vector3(-57.0, 0.9, 57.0),  # Diagonal front-right well past range
	])
	var blips := RadarProjector.project(Vector3.ZERO, 0.0, enemies, 38.0)

	assert_near(blips[0].x, 0.0, 0.001)
	assert_near(blips[0].y, 1.0, 0.001)
	assert_near(blips[0].z, 2.0, 0.001)

	var diag_len := Vector2(blips[1].x, blips[1].y).length()
	assert_near(diag_len, 1.0, 0.001)
	assert_gt(blips[1].x, 0.0)
	assert_lt(blips[1].y, 0.0)
	assert_gt(blips[1].z, 1.0)


func test_handles_empty_enemy_list() -> void:
	var blips := RadarProjector.project(Vector3(10.0, 0.0, -5.0), 1.2, PackedVector3Array(), 38.0)
	assert_eq(blips.size(), 0)
