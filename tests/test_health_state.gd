extends TestCase

var health: HealthState


func before_each() -> void:
	health = HealthState.new(100.0, 0.8)


func test_initializes_with_full_health_and_not_invulnerable() -> void:
	assert_eq(health.current, 100.0)
	assert_eq(health.max_hp, 100.0)
	assert_true(health.is_alive)
	assert_false(health.is_invulnerable)


func test_applies_damage_and_enters_invulnerability_window() -> void:
	var damaged := health.take_damage(15.0)
	assert_true(damaged)
	assert_eq(health.current, 85.0)
	assert_true(health.is_invulnerable)


func test_blocks_subsequent_damage_while_invulnerable_until_timer_expires() -> void:
	health.take_damage(15.0)
	assert_false(health.take_damage(15.0))
	assert_eq(health.current, 85.0)

	health.update(0.5)
	assert_true(health.is_invulnerable)
	assert_false(health.take_damage(15.0))

	health.update(0.35)
	assert_false(health.is_invulnerable)
	assert_true(health.take_damage(15.0))
	assert_eq(health.current, 70.0)


func test_clamps_health_at_0_and_marks_is_alive_false_on_lethal_damage() -> void:
	var fatal_health := HealthState.new(20.0, 0.8)
	fatal_health.take_damage(35.0)
	assert_eq(fatal_health.current, 0.0)
	assert_false(fatal_health.is_alive)
	assert_false(fatal_health.take_damage(10.0))


func test_resets_health_and_clears_invulnerability_timer() -> void:
	health.take_damage(40.0)
	health.reset()
	assert_eq(health.current, 100.0)
	assert_false(health.is_invulnerable)
	assert_true(health.is_alive)
