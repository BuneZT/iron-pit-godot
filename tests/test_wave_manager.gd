extends TestCase

var waves: WaveManager


func before_each() -> void:
	waves = WaveManager.new({
		"spawn_interval": 0.8,
		"wave_breather_duration": 3.0,
	})


func test_starts_wave_1_with_5_enemies_queued() -> void:
	waves.start_first_wave()
	assert_eq(waves.current_wave, 1)
	assert_eq(waves.total_for_wave, 5)
	assert_eq(waves.remaining_enemies, 5)
	assert_false(waves.is_in_breather)


func test_spawns_enemies_at_configured_interval_until_queue_is_empty() -> void:
	waves.start_first_wave()

	assert_eq(waves.update(0.016), 1)
	assert_eq(waves.update(0.4), 0)
	assert_eq(waves.update(0.4), 1)
	assert_eq(waves.update(0.8), 1)
	assert_eq(waves.update(0.8), 1)
	assert_eq(waves.update(0.8), 1)
	assert_eq(waves.update(0.8), 0)


func test_transitions_to_breather_when_all_enemies_killed_then_starts_wave_2() -> void:
	waves.start_first_wave()
	for i in range(5):
		waves.on_enemy_killed()
	assert_eq(waves.remaining_enemies, 0)
	assert_true(waves.is_in_breather)

	waves.update(1.5)
	assert_eq(waves.current_wave, 1)
	assert_true(waves.is_in_breather)

	waves.update(1.6)
	assert_false(waves.is_in_breather)
	assert_eq(waves.current_wave, 2)
	assert_eq(waves.total_for_wave, 7)
	assert_eq(waves.remaining_enemies, 7)


func test_resets_back_to_initial_state_on_reset() -> void:
	waves.start_first_wave()
	waves.on_enemy_killed()
	waves.reset()
	assert_eq(waves.current_wave, 0)
	assert_eq(waves.remaining_enemies, 0)
