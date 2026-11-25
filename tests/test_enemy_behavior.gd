extends TestCase


func test_wave_ramp_unlocks_personalities_progressively() -> void:
	# Wave 1: Rusher (65%) + Flanker (35%) only
	assert_eq(EnemyBehavior.pick_personality(1, 0.0), EnemyBehavior.RUSHER)
	assert_eq(EnemyBehavior.pick_personality(1, 0.64), EnemyBehavior.RUSHER)
	assert_eq(EnemyBehavior.pick_personality(1, 0.66), EnemyBehavior.FLANKER)
	assert_eq(EnemyBehavior.pick_personality(1, 0.99), EnemyBehavior.FLANKER)

	# Wave 2: introduces Weaver
	assert_eq(EnemyBehavior.pick_personality(2, 0.10), EnemyBehavior.RUSHER)
	assert_eq(EnemyBehavior.pick_personality(2, 0.50), EnemyBehavior.FLANKER)
	assert_eq(EnemyBehavior.pick_personality(2, 0.80), EnemyBehavior.WEAVER)

	# Wave 3+: all four personalities including Lunger
	assert_eq(EnemyBehavior.pick_personality(3, 0.10), EnemyBehavior.RUSHER)
	assert_eq(EnemyBehavior.pick_personality(3, 0.30), EnemyBehavior.FLANKER)
	assert_eq(EnemyBehavior.pick_personality(3, 0.60), EnemyBehavior.WEAVER)
	assert_eq(EnemyBehavior.pick_personality(3, 0.90), EnemyBehavior.LUNGER)


func test_rusher_steers_directly_toward_player() -> void:
	var state := EnemyBehavior.State.new()
	state.reset(EnemyBehavior.RUSHER)
	var res := EnemyBehavior.step(
		state,
		0.016,
		Vector3(0.0, 0.9, 0.0),
		Vector3(0.0, 0.9, 10.0),
		6.0,
		true
	)
	assert_near(res.velocity_xz.x, 0.0)
	assert_near(res.velocity_xz.y, 6.0)
	assert_false(res.is_winding_up)


func test_flanker_arcs_laterally_at_mid_range_and_cuts_in_close() -> void:
	var state := EnemyBehavior.State.new()
	state.reset(EnemyBehavior.FLANKER, 0.8) # flank_side = +1.0

	# At 10m along +Z, perp = (-1, 0), so flanker arcs strongly toward -X while still advancing +Z
	var mid_res := EnemyBehavior.step(
		state,
		0.016,
		Vector3(0.0, 0.9, 0.0),
		Vector3(0.0, 0.9, 10.0),
		6.0,
		true
	)
	assert_lt(mid_res.velocity_xz.x, -2.5)
	assert_gt(mid_res.velocity_xz.y, 3.0)

	# Inside close range (2.5m), flanker straightens directly into the player
	var close_res := EnemyBehavior.step(
		state,
		0.016,
		Vector3(0.0, 0.9, 0.0),
		Vector3(0.0, 0.9, 2.5),
		6.0,
		true
	)
	assert_near(close_res.velocity_xz.x, 0.0)
	assert_gt(close_res.velocity_xz.y, 6.0)


func test_flanker_flips_side_near_arena_boundary() -> void:
	var state := EnemyBehavior.State.new()
	state.reset(EnemyBehavior.FLANKER, 0.1) # flank_side = -1.0 -> perp(-1,0)*-1 = (+1, 0) toward +X wall
	assert_near(state.flank_side, -1.0)

	EnemyBehavior.step(
		state,
		0.016,
		Vector3(46.5, 0.9, 0.0),
		Vector3(46.5, 0.9, 10.0),
		6.0,
		true
	)
	assert_near(state.flank_side, 1.0)


func test_weaver_oscillates_laterally_over_time_and_straightens_close() -> void:
	var state := EnemyBehavior.State.new()
	state.reset(EnemyBehavior.WEAVER, 0.5, 0.0, 0.5)

	# Step quarter-cycle forward -> sin > 0 -> negative X lateral motion
	var res_a := EnemyBehavior.step(
		state,
		0.45,
		Vector3(0.0, 0.9, 0.0),
		Vector3(0.0, 0.9, 10.0),
		6.0,
		true
	)
	assert_lt(res_a.velocity_xz.x, -1.5)
	assert_gt(res_a.velocity_xz.y, 2.5)

	# Step half-cycle later -> sin < 0 -> positive X lateral motion
	var res_b := EnemyBehavior.step(
		state,
		0.9,
		Vector3(0.0, 0.9, 0.0),
		Vector3(0.0, 0.9, 10.0),
		6.0,
		true
	)
	assert_gt(res_b.velocity_xz.x, 1.5)

	# Close range -> straightens out
	var res_close := EnemyBehavior.step(
		state,
		0.016,
		Vector3(0.0, 0.9, 0.0),
		Vector3(0.0, 0.9, 2.0),
		6.0,
		true
	)
	assert_near(res_close.velocity_xz.x, 0.0)


func test_lunger_winds_up_launches_and_interrupts_on_stagger() -> void:
	var state := EnemyBehavior.State.new()
	state.reset(EnemyBehavior.LUNGER)
	state.lunge_cooldown = 0.0

	# Enters WINDUP at 7m when grounded
	var windup_start := EnemyBehavior.step(
		state,
		0.016,
		Vector3(0.0, 0.9, 0.0),
		Vector3(0.0, 0.9, 7.0),
		6.0,
		true
	)
	assert_true(windup_start.started_windup)
	assert_true(windup_start.is_winding_up)
	assert_true(windup_start.suppress_stuck_timer)
	assert_near(windup_start.velocity_xz.length(), 0.0)
	assert_eq(state.lunge_state, EnemyBehavior.LUNGE_WINDUP)

	# Stagger cancels windup and sets interrupt cooldown
	state.on_stagger()
	assert_eq(state.lunge_state, EnemyBehavior.LUNGE_CHASE)
	assert_gte(state.lunge_cooldown, EnemyBehavior.LUNGE_INTERRUPT_COOLDOWN)

	# Re-arm and complete full windup -> launches forward + upward
	state.lunge_cooldown = 0.0
	EnemyBehavior.step(state, 0.016, Vector3(0.0, 0.9, 0.0), Vector3(0.0, 0.9, 7.0), 6.0, true)
	var launch := EnemyBehavior.step(
		state,
		EnemyBehavior.LUNGE_WINDUP_DURATION + 0.02,
		Vector3(0.0, 0.9, 0.0),
		Vector3(0.0, 0.9, 7.0),
		6.0,
		true
	)
	assert_gt(launch.lunge_launch_velocity.z, 10.0)
	assert_gt(launch.lunge_launch_velocity.y, 4.0)
	assert_true(launch.preserve_airborne_velocity)
	assert_eq(state.lunge_state, EnemyBehavior.LUNGE_AIRBORNE)
	assert_gte(state.lunge_cooldown, EnemyBehavior.LUNGE_COOLDOWN_DURATION - 0.01)


func test_compute_separation_pushes_crowded_enemies_apart() -> void:
	var positions: Array[Vector2] = [
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(20.0, 20.0),
	]
	var sep0 := EnemyBehavior.compute_separation(positions[0], positions, 0)
	var sep1 := EnemyBehavior.compute_separation(positions[1], positions, 1)
	var sep2 := EnemyBehavior.compute_separation(positions[2], positions, 2)

	assert_lt(sep0.x, -0.4)
	assert_near(sep0.y, 0.0)
	assert_gt(sep1.x, 0.4)
	assert_near(sep2.length(), 0.0)
