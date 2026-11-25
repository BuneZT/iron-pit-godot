extends TestCase

var _root: Node3D
var _controller: EnemyController
var _enemy: EnemyController.EnemyInstance


func before_each() -> void:
	_root = Node3D.new()
	scene_tree.root.add_child(_root)
	var spawn_point := Vector3(0.0, 0.9, 0.0)
	_controller = EnemyController.new(_root, [spawn_point])
	_enemy = _controller.spawn_enemy(1, null, EnemyBehavior.RUSHER)
	await scene_tree.physics_frame


func after_each() -> void:
	if is_instance_valid(_root):
		_root.get_parent().remove_child(_root)
		_root.free()


func test_validates_3d_contact_damage_grounded_vs_perched_player() -> void:
	_enemy.root.position = Vector3(0.0, 0.9, 0.0)

	# Player is directly above on a 2m high barricade (y = 2.9, horizontal dist = 0)
	var perched_player_pos := Vector3(0.0, 2.9, 0.0)
	var damage_perched := _controller.update(0.016, perched_player_pos, 1)
	assert_near(damage_perched, 0.0)

	# Player at same elevation within contact distance (y = 0.9, x = 0.5)
	var grounded_player_pos := Vector3(0.5, 0.9, 0.0)
	var damage_grounded := _controller.update(0.016, grounded_player_pos, 1)
	assert_near(damage_grounded, 15.0)


func test_triggers_vertical_pursuit_leap_when_player_is_perched() -> void:
	_enemy.root.position = Vector3(0.0, 0.9, 0.0)
	_enemy.jump_cooldown = 0.0
	_enemy.root.linear_velocity = Vector3.ZERO
	_enemy.last_applied_impulse = Vector3.ZERO

	var elevated_player_pos := Vector3(0.0, 2.2, 3.0)
	_controller.update(0.016, elevated_player_pos, 1)

	assert_gt(_enemy.last_applied_impulse.y, 10.0)
	assert_gt(_enemy.last_applied_impulse.z, 5.0)
	assert_gt(_enemy.jump_cooldown, 1.0)


func test_triggers_obstacle_vault_leap_when_movement_is_stalled() -> void:
	_enemy.root.position = Vector3(0.0, 0.9, 0.0)
	_enemy.prev_position = _enemy.root.position
	_enemy.jump_cooldown = 0.0
	_enemy.stuck_timer = 0.28
	_enemy.root.linear_velocity = Vector3.ZERO
	_enemy.last_applied_impulse = Vector3.ZERO

	var player_pos := Vector3(0.0, 0.9, 3.0)
	_controller.update(0.016, player_pos, 1)

	assert_gt(_enemy.last_applied_impulse.y, 8.0)
	assert_gt(_enemy.last_applied_impulse.z, 5.0)
	assert_near(_enemy.stuck_timer, 0.0)
	assert_gt(_enemy.jump_cooldown, 1.0)


func test_blocks_mid_air_jump_when_not_grounded_on_world_geometry() -> void:
	# Enemy is suspended in open air at jump apex (vel.y == 0) with no world geometry beneath
	_enemy.root.position = Vector3(0.0, 2.5, 0.0)
	_enemy.prev_position = _enemy.root.position
	_enemy.jump_cooldown = 0.0
	_enemy.stuck_timer = 0.5
	_enemy.root.linear_velocity = Vector3.ZERO
	_enemy.last_applied_impulse = Vector3.ZERO

	var elevated_player_pos := Vector3(0.0, 4.0, 3.0)
	_controller.update(0.016, elevated_player_pos, 1)

	assert_near(_enemy.last_applied_impulse.y, 0.0)
	assert_near(_enemy.jump_cooldown, 0.0)


func test_clamps_enemy_within_100m_arena_boundary() -> void:
	_enemy.root.position = Vector3(-60.0, 0.9, 60.0)
	_controller.update(0.016, Vector3(0.0, 0.9, 0.0), 1)
	assert_near(_enemy.root.position.x, -49.2)
	assert_near(_enemy.root.position.z, 49.2)


func test_spawns_enemies_in_distance_fog_away_from_player_with_layout() -> void:
	var layout := ArenaLayoutGenerator.generate(42)
	var fog_controller := EnemyController.new(_root, layout)
	var player_pos := Vector3(0.0, 0.9, 0.0)
	var fog_enemy := fog_controller.spawn_enemy(1, player_pos)

	var dist := Vector2(
		fog_enemy.root.position.x - player_pos.x,
		fog_enemy.root.position.z - player_pos.z
	).length()
	var bounds: float = float(layout["arena_bounds"])
	assert_gte(dist, 22.0)
	assert_lte(absf(fog_enemy.root.position.x), bounds)
	assert_lte(absf(fog_enemy.root.position.z), bounds)


func test_builds_distinct_articulated_rigs_for_all_four_archetypes() -> void:
	var rusher := _enemy
	var flanker := _controller.spawn_enemy(1, null, EnemyBehavior.FLANKER)
	var weaver := _controller.spawn_enemy(2, null, EnemyBehavior.WEAVER)
	var lunger := _controller.spawn_enemy(3, null, EnemyBehavior.LUNGER)

	# All archetypes have full articulated low-poly rigs (>=21 parts) and compound hitboxes
	for inst in [rusher, flanker, weaver, lunger]:
		assert_gte(inst.parts.size(), 21)
		assert_true(is_instance_valid(inst.rig.torso_pivot))
		assert_true(is_instance_valid(inst.rig.head_pivot))
		assert_true(is_instance_valid(inst.rig.hip_l_pivot))
		assert_true(is_instance_valid(inst.rig.shoulder_l_pivot))
		assert_eq(inst.hitbox_area.get_child_count(), inst.parts.size())
		assert_eq(inst.body_mat.texture_filter, BaseMaterial3D.TEXTURE_FILTER_NEAREST)

	# Distinct visual identities: different body & visor materials, plus archetype-specific anatomy
	assert_ne(rusher.body_mat, flanker.body_mat)
	assert_ne(flanker.body_mat, weaver.body_mat)
	assert_ne(weaver.body_mat, lunger.body_mat)
	assert_ne(rusher.visor_mat, flanker.visor_mat)
	assert_ne(flanker.visor_mat, weaver.visor_mat)
	assert_ne(weaver.visor_mat, lunger.visor_mat)
	# Flanker & Weaver have dual glowing eyes/slits; Rusher & Lunger have single visor bar
	assert_eq(flanker.rig.visor_parts.size(), 2)
	assert_eq(weaver.rig.visor_parts.size(), 2)
	assert_eq(rusher.rig.visor_parts.size(), 1)
	assert_eq(lunger.rig.visor_parts.size(), 1)


func test_handles_stagger_and_fatal_knockdown_with_rig_animations() -> void:
	assert_gte(_enemy.parts.size(), 21)

	# Non-lethal hit (35 damage -> 65 HP remaining)
	var outcome1 := _controller.apply_hit(_enemy.id, 35.0, Vector3(0.0, 1.2, 0.0), Vector3(0.0, 0.0, 1.0))
	assert_eq(outcome1, "HIT")
	assert_eq(_enemy.state, "ALIVE")
	assert_near(_enemy.hp, 65.0)
	assert_gt(_enemy.stagger_timer, 0.2)
	assert_true(_enemy.root.axis_lock_angular_x)

	# Updating during stagger drives backward torso recoil on the rig
	for _i in range(6):
		_controller.update(0.03, Vector3(0.0, 0.9, 10.0), 1)
	assert_eq(_enemy.anim_state.active_clip, EnemyAnimator.CLIP_STAGGER)
	assert_lt(_enemy.rig.torso_pivot.rotation.x, -0.2)

	# Fatal hit (70 damage -> <= 0 HP)
	var outcome2 := _controller.apply_hit(_enemy.id, 70.0, Vector3(0.0, 1.5, 0.0), Vector3(0.0, 0.0, 1.0))
	assert_eq(outcome2, "KILLED")
	assert_eq(_enemy.state, "KNOCKED_DOWN")
	assert_false(_enemy.root.axis_lock_angular_x)
	assert_false(_enemy.root.axis_lock_angular_y)
	assert_false(_enemy.root.axis_lock_angular_z)
	assert_gt(_enemy.last_applied_impulse.z, 20.0)
	assert_gt(_enemy.last_applied_impulse.y, 6.0)
	assert_eq(_enemy.hitbox_area.collision_layer, 0)

	# Updating while knocked down drives splayed death pose
	for _i in range(6):
		_controller.update(0.03, Vector3(0.0, 0.9, 10.0), 1)
	assert_eq(_enemy.anim_state.active_clip, EnemyAnimator.CLIP_KNOCKED_DOWN)
	assert_lt(_enemy.rig.shoulder_l_pivot.rotation.z, -0.7)


func test_animates_chase_stride_and_close_slash_on_joint_pivots() -> void:
	_enemy.root.position = Vector3(0.0, 0.9, 0.0)
	_enemy.prev_position = _enemy.root.position
	_enemy.anim_state.stride_phase = 0.0
	var initial_hip_x := _enemy.rig.hip_l_pivot.rotation.x

	# Chasing player at 12m advances stride phase and swings hip joints
	_controller.update(0.12, Vector3(0.0, 0.9, 12.0), 1)
	assert_eq(_enemy.anim_state.active_clip, EnemyAnimator.CLIP_CHASE)
	assert_gt(absf(_enemy.rig.hip_l_pivot.rotation.x - initial_hip_x), 0.1)

	# Close range triggers claw slash clip
	_enemy.root.position = Vector3(0.0, 0.9, 10.8)
	_enemy.prev_position = _enemy.root.position
	_controller.update(0.016, Vector3(0.0, 0.9, 12.0), 1)
	assert_eq(_enemy.anim_state.active_clip, EnemyAnimator.CLIP_SLASH)


func test_shares_materials_per_archetype_and_flashes_without_mutating_peers() -> void:
	var second_rusher := _controller.spawn_enemy(1, null, EnemyBehavior.RUSHER)
	assert_eq(_enemy.body_mat, second_rusher.body_mat)
	assert_eq(_enemy.accent_mat, second_rusher.accent_mat)
	assert_eq(_enemy.horn_mat, second_rusher.horn_mat)
	assert_eq(_enemy.visor_mat, second_rusher.visor_mat)
	assert_eq(_enemy.root.physics_material_override, second_rusher.root.physics_material_override)

	# Hit first rusher -> switches to shared flash material without mutating second rusher's material
	_controller.apply_hit(_enemy.id, 35.0, Vector3(0.0, 1.2, 0.0), Vector3(0.0, 0.0, 1.0))
	assert_ne(_enemy.body_mat, second_rusher.body_mat)
	assert_true(_enemy.body_mat.emission_enabled)
	assert_false(second_rusher.body_mat.emission_enabled)

	# After flash timer expires, first rusher returns to shared rusher alive material
	_controller.update(0.15, Vector3(0.0, 0.9, 10.0), 1)
	assert_eq(_enemy.body_mat, second_rusher.body_mat)


func test_pools_despawned_enemy_hierarchies_per_archetype_for_reuse() -> void:
	var lunger := _controller.spawn_enemy(3, Vector3(0.0, 0.9, 10.0), EnemyBehavior.LUNGER)
	var original_root := lunger.root
	# Kill and despawn lunger
	_controller.apply_hit(lunger.id, 150.0, Vector3(0.0, 1.5, 0.0), Vector3(0.0, 0.0, 1.0))
	assert_eq(lunger.state, "KNOCKED_DOWN")
	_controller.update(3.0, Vector3(0.0, 0.9, 10.0), 3)
	assert_eq(_controller.get_pooled_count_for(EnemyBehavior.LUNGER), 1)

	# Spawning a different archetype does not hijack the pooled Lunger rig
	var weaver := _controller.spawn_enemy(2, Vector3(0.0, 0.9, 10.0), EnemyBehavior.WEAVER)
	assert_ne(weaver.root, original_root)
	assert_eq(_controller.get_pooled_count_for(EnemyBehavior.LUNGER), 1)

	# Spawning a Lunger reuses the pooled Lunger RigidBody3D hierarchy with restored state & anim pose
	var reused := _controller.spawn_enemy(3, Vector3(0.0, 0.9, 10.0), EnemyBehavior.LUNGER)
	assert_eq(_controller.get_pooled_count_for(EnemyBehavior.LUNGER), 0)
	assert_eq(reused.root, original_root)
	assert_eq(reused.state, "ALIVE")
	assert_eq(reused.personality, EnemyBehavior.LUNGER)
	assert_eq(reused.behavior.personality, EnemyBehavior.LUNGER)
	assert_eq(reused.anim_state.active_clip, EnemyAnimator.CLIP_IDLE)
	assert_eq(reused.eye_visor.material_override, reused.visor_mat)
	assert_eq(reused.hitbox_area.collision_layer, 8)
	assert_true(reused.root.axis_lock_angular_x)
	assert_eq(int(reused.root.get_meta("enemy_id")), reused.id)
	assert_eq(int(reused.hitbox_area.get_meta("enemy_id")), reused.id)


func test_flanker_and_weaver_steer_laterally_in_controller() -> void:
	_controller.clear_all()
	var flanker := _controller.spawn_enemy(1, null, EnemyBehavior.FLANKER)
	flanker.root.position = Vector3(0.0, 0.9, 0.0)
	flanker.prev_position = flanker.root.position
	flanker.behavior.flank_side = 1.0

	_controller.update(0.016, Vector3(0.0, 0.9, 10.0), 1)
	assert_lt(flanker.root.linear_velocity.x, -2.0)
	assert_gt(flanker.root.linear_velocity.z, 2.5)

	_controller.clear_all()
	var weaver := _controller.spawn_enemy(2, null, EnemyBehavior.WEAVER)
	weaver.root.position = Vector3(0.0, 0.9, 0.0)
	weaver.prev_position = weaver.root.position
	weaver.behavior.weave_phase = 0.0
	weaver.behavior.weave_freq = 3.5
	weaver.jump_cooldown = 5.0

	_controller.update(0.45, Vector3(0.0, 0.9, 10.0), 2)
	var vx_first := weaver.root.linear_velocity.x
	_controller.update(0.9, Vector3(0.0, 0.9, 10.0), 2)
	var vx_second := weaver.root.linear_velocity.x
	assert_lt(vx_first, -1.0)
	assert_gt(vx_second, 1.0)


func test_lunger_telegraphs_with_visor_flash_crouch_and_launches_impulse() -> void:
	_controller.clear_all()
	var groans := {"count": 0}
	_controller.on_enemy_groan = func(_pos: Vector3) -> void:
		groans["count"] = int(groans["count"]) + 1

	var lunger := _controller.spawn_enemy(3, null, EnemyBehavior.LUNGER)
	var lunger_visor := _controller.get_archetype_visor_mat(EnemyBehavior.LUNGER)
	lunger.root.position = Vector3(0.0, 0.9, 0.0)
	lunger.prev_position = lunger.root.position
	lunger.root.linear_velocity = Vector3.ZERO
	lunger.behavior.lunge_cooldown = 0.0
	lunger.groan_timer = 10.0

	# Enters windup at 7m: stops moving, flares visor white-gold, crouches rig, emits groan cue
	_controller.update(0.016, Vector3(0.0, 0.9, 7.0), 3)
	assert_eq(lunger.behavior.lunge_state, EnemyBehavior.LUNGE_WINDUP)
	assert_eq(lunger.visor_mat.albedo_color, EnemyBehavior.LUNGE_WINDUP_VISOR_COLOR)
	assert_eq(lunger.anim_state.active_clip, EnemyAnimator.CLIP_WINDUP)
	assert_near(lunger.root.linear_velocity.x, 0.0)
	assert_near(lunger.root.linear_velocity.z, 0.0)
	assert_eq(int(groans["count"]), 1)

	# Advance slightly during windup -> rig visibly crouches downward
	_controller.update(0.12, Vector3(0.0, 0.9, 7.0), 3)
	assert_lt(lunger.rig.visual_rig.position.y, -0.1)

	# Shooting during windup interrupts lunge and restores archetype visor
	_controller.apply_hit(lunger.id, 35.0, Vector3(0.0, 1.2, 0.0), Vector3(0.0, 0.0, -1.0))
	assert_eq(lunger.behavior.lunge_state, EnemyBehavior.LUNGE_CHASE)
	assert_eq(lunger.visor_mat, lunger_visor)

	# Re-arm and complete full windup -> fires forward+upward Jolt impulse
	lunger.stagger_timer = 0.0
	lunger.behavior.lunge_cooldown = 0.0
	lunger.root.position = Vector3(0.0, 0.9, 0.0)
	lunger.root.linear_velocity = Vector3.ZERO
	lunger.last_applied_impulse = Vector3.ZERO
	_controller.update(0.016, Vector3(0.0, 0.9, 7.0), 3)
	_controller.update(EnemyBehavior.LUNGE_WINDUP_DURATION + 0.02, Vector3(0.0, 0.9, 7.0), 3)
	assert_gt(lunger.last_applied_impulse.z, 15.0)
	assert_gt(lunger.last_applied_impulse.y, 6.0)
	assert_eq(lunger.behavior.lunge_state, EnemyBehavior.LUNGE_AIRBORNE)
	assert_eq(lunger.visor_mat, lunger_visor)


func test_pack_separation_pushes_crowded_rushers_apart() -> void:
	_controller.clear_all()
	var left_rusher := _controller.spawn_enemy(1, null, EnemyBehavior.RUSHER)
	var right_rusher := _controller.spawn_enemy(1, null, EnemyBehavior.RUSHER)
	left_rusher.root.position = Vector3(-0.5, 0.9, 0.0)
	right_rusher.root.position = Vector3(0.5, 0.9, 0.0)
	left_rusher.prev_position = left_rusher.root.position
	right_rusher.prev_position = right_rusher.root.position

	_controller.update(0.016, Vector3(0.0, 0.9, 12.0), 1)
	assert_lt(left_rusher.root.linear_velocity.x, -0.5)
	assert_gt(right_rusher.root.linear_velocity.x, 0.5)
	assert_gt(left_rusher.root.linear_velocity.z, 4.0)
	assert_gt(right_rusher.root.linear_velocity.z, 4.0)
