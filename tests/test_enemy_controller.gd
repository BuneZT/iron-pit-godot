extends TestCase

var _root: Node3D
var _controller: EnemyController
var _enemy: EnemyController.EnemyInstance


func before_each() -> void:
	_root = Node3D.new()
	scene_tree.root.add_child(_root)
	var spawn_point := Vector3(0.0, 0.9, 0.0)
	_controller = EnemyController.new(_root, [spawn_point])
	_enemy = _controller.spawn_enemy(1)
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


func test_builds_23_part_anatomy_and_handles_stagger_and_fatal_knockdown() -> void:
	assert_eq(_enemy.parts.size(), 23)

	# Non-lethal hit (35 damage -> 65 HP remaining)
	var outcome1 := _controller.apply_hit(_enemy.id, 35.0, Vector3(0.0, 1.2, 0.0), Vector3(0.0, 0.0, 1.0))
	assert_eq(outcome1, "HIT")
	assert_eq(_enemy.state, "ALIVE")
	assert_near(_enemy.hp, 65.0)
	assert_gt(_enemy.stagger_timer, 0.2)
	assert_true(_enemy.root.axis_lock_angular_x)

	# Fatal hit (70 damage -> <= 0 HP)
	var outcome2 := _controller.apply_hit(_enemy.id, 70.0, Vector3(0.0, 1.5, 0.0), Vector3(0.0, 0.0, 1.0))
	assert_eq(outcome2, "KILLED")
	assert_eq(_enemy.state, "KNOCKED_DOWN")
	assert_false(_enemy.root.axis_lock_angular_x)
	assert_false(_enemy.root.axis_lock_angular_y)
	assert_false(_enemy.root.axis_lock_angular_z)
	assert_gt(_enemy.last_applied_impulse.z, 20.0)
	assert_gt(_enemy.last_applied_impulse.y, 6.0)
