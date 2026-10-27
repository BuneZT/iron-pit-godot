extends TestCase


func test_provides_compelling_intro_subtitle() -> void:
	assert_contains(LoreCatalog.INTRO_SUBTITLE, "Mor'gath")
	assert_contains(LoreCatalog.INTRO_SUBTITLE, "ten onslaughts")


func test_contains_three_chronicle_chapters_with_titles_and_bodies() -> void:
	assert_eq(LoreCatalog.CHRONICLE_CHAPTERS.size(), 3)
	assert_eq(LoreCatalog.CHRONICLE_CHAPTERS[0]["title"], "I. THE DESECRATED SLEEP")
	assert_eq(LoreCatalog.CHRONICLE_CHAPTERS[1]["title"], "II. THE SOVEREIGN'S TETHER")
	assert_eq(LoreCatalog.CHRONICLE_CHAPTERS[2]["title"], "III. THE TENTH BELL")
	for chapter in LoreCatalog.CHRONICLE_CHAPTERS:
		assert_gt(String(chapter["body"]).length(), 50)


func test_returns_appropriate_wave_whispers_for_waves_1_to_10_and_endless() -> void:
	assert_contains(LoreCatalog.get_wave_whisper(1), "Sovereign's essence")
	assert_contains(LoreCatalog.get_wave_whisper(5), "The entity bleeds")
	assert_contains(LoreCatalog.get_wave_whisper(10), "tether shatters")
	assert_contains(LoreCatalog.get_wave_whisper(11), "hunt never ends")
	assert_contains(LoreCatalog.get_wave_whisper(99), "hunt never ends")


func test_formats_game_over_defeat_message() -> void:
	var msg := LoreCatalog.get_game_over_message(4, 18, 1800)
	assert_contains(msg, "Wave 4")
	assert_contains(msg, "18 hostiles")
	assert_contains(msg, "Mor'gath's curse knits your broken bones")


func test_provides_victory_message_for_breaking_seal() -> void:
	assert_eq(LoreCatalog.get_victory_title(), "SEAL SHATTERED")
	assert_contains(LoreCatalog.get_victory_subtitle(), "Ten bells have tolled")
