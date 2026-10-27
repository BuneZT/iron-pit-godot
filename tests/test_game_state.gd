extends TestCase

var state: GameState


func before_each() -> void:
	state = GameState.new()


func test_starts_in_menu_status_with_0_kills_and_0_score() -> void:
	assert_eq(state.status, "MENU")
	assert_eq(state.kills, 0)
	assert_eq(state.score, 0)


func test_transitions_through_start_pause_resume_and_game_over() -> void:
	state.start_match()
	assert_eq(state.status, "PLAYING")

	state.pause_match()
	assert_eq(state.status, "PAUSED")

	state.resume_match()
	assert_eq(state.status, "PLAYING")

	state.trigger_game_over()
	assert_eq(state.status, "GAME_OVER")


func test_ignores_pause_match_when_not_playing() -> void:
	state.pause_match()
	assert_eq(state.status, "MENU")


func test_records_enemy_kills_and_increments_score() -> void:
	state.start_match()
	state.record_kill(100)
	state.record_kill(150)
	assert_eq(state.kills, 2)
	assert_eq(state.score, 250)


func test_resets_kills_and_score_when_starting_new_match_after_game_over() -> void:
	state.start_match()
	state.record_kill(100)
	state.trigger_game_over()
	state.start_match()

	assert_eq(state.status, "PLAYING")
	assert_eq(state.kills, 0)
	assert_eq(state.score, 0)


func test_tracks_whether_curse_has_been_broken_at_wave_10() -> void:
	state.start_match()
	assert_false(state.is_curse_broken)
	assert_false(state.has_escaped)

	state.check_wave_milestone(9)
	assert_false(state.is_curse_broken)

	state.check_wave_milestone(10)
	assert_true(state.is_curse_broken)

	state.check_wave_milestone(11)
	assert_true(state.is_curse_broken)


func test_allows_player_to_escape_pit_once_curse_is_broken() -> void:
	state.start_match()
	state.check_wave_milestone(10)
	assert_true(state.is_curse_broken)

	state.escape_pit()
	assert_true(state.has_escaped)
	assert_eq(state.status, "MENU")


func test_resets_curse_broken_and_escape_status_upon_start_match() -> void:
	state.start_match()
	state.check_wave_milestone(10)
	state.escape_pit()
	assert_true(state.has_escaped)

	state.start_match()
	assert_false(state.is_curse_broken)
	assert_false(state.has_escaped)
