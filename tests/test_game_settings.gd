extends TestCase


func test_initializes_with_default_values() -> void:
	var settings := GameSettings.new()
	assert_near(settings.master_volume, 0.8)
	assert_near(settings.music_volume, 0.6)
	assert_near(settings.sfx_volume, 0.8)
	assert_false(settings.is_muted)
	assert_near(settings.render_scale, 1.0)


func test_clamps_render_scale_between_half_and_one() -> void:
	var settings := GameSettings.new()
	settings.set_render_scale(1.2)
	assert_near(settings.render_scale, 1.0)

	settings.set_render_scale(0.3)
	assert_near(settings.render_scale, 0.5)

	settings.set_render_scale(0.75)
	assert_near(settings.render_scale, 0.75)


func test_clamps_volume_inputs_between_0_and_1() -> void:
	var settings := GameSettings.new()
	settings.set_master_volume(1.5)
	assert_near(settings.master_volume, 1.0)
	settings.set_master_volume(-0.2)
	assert_near(settings.master_volume, 0.0)

	settings.set_music_volume(2.0)
	assert_near(settings.music_volume, 1.0)

	settings.set_sfx_volume(-1.0)
	assert_near(settings.sfx_volume, 0.0)


func test_computes_effective_volumes_correctly() -> void:
	var settings := GameSettings.new({
		"master_volume": 0.5,
		"music_volume": 0.8,
		"sfx_volume": 0.6,
		"render_scale": 0.75,
	})
	assert_near(settings.get_effective_music_volume(), 0.4)
	assert_near(settings.get_effective_sfx_volume(), 0.3)
	assert_near(settings.get_effective_sfx_volume(2.0), 0.6)
	assert_near(settings.render_scale, 0.75)

	settings.toggle_mute()
	assert_true(settings.is_muted)
	assert_near(settings.get_effective_music_volume(), 0.0)
	assert_near(settings.get_effective_sfx_volume(), 0.0)


func test_serializes_and_deserializes_unified_settings() -> void:
	var original := GameSettings.new({
		"master_volume": 0.75,
		"music_volume": 0.35,
		"sfx_volume": 0.9,
		"is_muted": true,
		"render_scale": 0.65,
	})

	var json := original.serialize()
	var restored := GameSettings.deserialize(json)

	assert_near(restored.master_volume, 0.75)
	assert_near(restored.music_volume, 0.35)
	assert_near(restored.sfx_volume, 0.9)
	assert_true(restored.is_muted)
	assert_near(restored.render_scale, 0.65)


func test_deserializes_legacy_audio_only_settings_with_default_render_scale() -> void:
	var legacy_json := '{"master_volume": 0.5, "music_volume": 0.4, "sfx_volume": 0.3, "is_muted": false}'
	var restored := GameSettings.deserialize(legacy_json)

	assert_near(restored.master_volume, 0.5)
	assert_near(restored.music_volume, 0.4)
	assert_near(restored.sfx_volume, 0.3)
	assert_false(restored.is_muted)
	assert_near(restored.render_scale, 1.0)
