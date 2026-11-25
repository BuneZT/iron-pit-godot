extends TestCase


func test_all_four_archetypes_have_distinct_colors_and_motion_profiles() -> void:
	var ids := EnemyArchetypes.get_all_ids()
	assert_eq(ids.size(), 4)

	var body_colors: Array[Color] = []
	var visor_colors: Array[Color] = []
	var names: Array[String] = []
	for id in ids:
		var spec := EnemyArchetypes.get_spec(id)
		assert_eq(spec.id, id)
		assert_false(names.has(spec.display_name))
		assert_false(body_colors.has(spec.body_color))
		assert_false(visor_colors.has(spec.visor_color))
		names.append(spec.display_name)
		body_colors.append(spec.body_color)
		visor_colors.append(spec.visor_color)

	# Iron Prowler (LUNGER) sits lower and hunches deeper forward than Cinder Stalker (FLANKER)
	var lunger := EnemyArchetypes.get_spec(EnemyBehavior.LUNGER)
	var flanker := EnemyArchetypes.get_spec(EnemyBehavior.FLANKER)
	assert_lt(lunger.pelvis_y, flanker.pelvis_y)
	assert_gt(lunger.base_torso_pitch, flanker.base_torso_pitch)


func test_chase_stride_oscillates_opposite_legs_and_arms() -> void:
	var state := EnemyAnimator.State.new()
	state.reset(EnemyBehavior.RUSHER, 0.0)
	var pose := EnemyAnimator.Pose.new()

	EnemyAnimator.step(state, 0.15, 6.0, 0.0, true, false, false, false, false, pose)
	assert_eq(state.active_clip, EnemyAnimator.CLIP_CHASE)
	assert_gt(absf(pose.hip_l_rot.x), 0.1)
	# Opposite leg swings in opposite direction
	assert_lt(pose.hip_l_rot.x * pose.hip_r_rot.x, 0.0)
	# Knees only bend backward (+X)
	assert_gte(pose.knee_l_rot.x, 0.0)
	assert_gte(pose.knee_r_rot.x, 0.0)


func test_lunge_windup_crouches_body_and_cocks_arms_back() -> void:
	var state := EnemyAnimator.State.new()
	state.reset(EnemyBehavior.LUNGER, 0.0)
	var pose := EnemyAnimator.Pose.new()

	for _i in range(10):
		EnemyAnimator.step(state, 0.03, 0.0, 0.0, true, true, false, false, false, pose)

	assert_eq(state.active_clip, EnemyAnimator.CLIP_WINDUP)
	assert_lt(pose.body_offset_y, -0.15)
	assert_gt(pose.torso_rot.x, 0.6)
	assert_gt(pose.knee_l_rot.x, 0.8)
	assert_gt(pose.shoulder_l_rot.x, 0.4)


func test_airborne_leap_stretches_arms_forward_and_legs_back() -> void:
	var state := EnemyAnimator.State.new()
	state.reset(EnemyBehavior.LUNGER, 0.0)
	var pose := EnemyAnimator.Pose.new()

	for _i in range(12):
		EnemyAnimator.step(state, 0.03, 10.0, 0.0, false, false, false, false, false, pose)

	assert_eq(state.active_clip, EnemyAnimator.CLIP_AIRBORNE)
	assert_lt(pose.shoulder_l_rot.x, -1.0)
	assert_lt(pose.shoulder_r_rot.x, -1.0)
	assert_gt(pose.hip_l_rot.x, 0.3)


func test_close_range_triggers_alternating_slash_animation() -> void:
	var state := EnemyAnimator.State.new()
	state.reset(EnemyBehavior.FLANKER, 0.0)
	var pose := EnemyAnimator.Pose.new()

	EnemyAnimator.step(state, 0.016, 4.0, 0.0, true, false, false, false, true, pose)
	assert_eq(state.active_clip, EnemyAnimator.CLIP_SLASH)
	assert_gt(state.slash_timer, 0.0)
	var first_hand := state.slash_hand

	# Advance past slash + cooldown, then trigger next slash on opposite hand
	for _i in range(40):
		EnemyAnimator.step(state, 0.02, 4.0, 0.0, true, false, false, false, true, pose)
	assert_ne(state.slash_hand, first_hand)


func test_stagger_whips_torso_backward_and_flares_arms_outward() -> void:
	var state := EnemyAnimator.State.new()
	state.reset(EnemyBehavior.RUSHER, 0.0)
	var pose := EnemyAnimator.Pose.new()

	for _i in range(10):
		EnemyAnimator.step(state, 0.025, 0.0, 0.0, true, false, true, false, false, pose)

	assert_eq(state.active_clip, EnemyAnimator.CLIP_STAGGER)
	assert_lt(pose.torso_rot.x, -0.3)
	assert_lt(pose.shoulder_l_rot.z, -0.6)
	assert_gt(pose.shoulder_r_rot.z, 0.6)


func test_knocked_down_enters_death_splay_pose() -> void:
	var state := EnemyAnimator.State.new()
	state.reset(EnemyBehavior.WEAVER, 0.25)
	var pose := EnemyAnimator.Pose.new()

	for _i in range(10):
		EnemyAnimator.step(state, 0.03, 0.0, 0.0, false, false, false, true, false, pose)

	assert_eq(state.active_clip, EnemyAnimator.CLIP_KNOCKED_DOWN)
	assert_lt(pose.shoulder_l_rot.z, -0.8)
	assert_gt(pose.shoulder_r_rot.z, 0.7)
