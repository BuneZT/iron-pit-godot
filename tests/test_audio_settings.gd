extends TestCase


func test_initializes_with_default_volume_values_and_unmuted_state() -> void:
	var settings := AudioSettings.new()
	assert_near(settings.master_volume, 0.8)
	assert_near(settings.music_volume, 0.6)
	assert_near(settings.sfx_volume, 0.8)
	assert_false(settings.is_muted)


func test_clamps_volume_inputs_between_0_and_1() -> void:
	var settings := AudioSettings.new()
	settings.set_master_volume(1.5)
	assert_near(settings.master_volume, 1.0)

	settings.set_master_volume(-0.2)
	assert_near(settings.master_volume, 0.0)

	settings.set_music_volume(2.0)
	assert_near(settings.music_volume, 1.0)

	settings.set_sfx_volume(-1.0)
	assert_near(settings.sfx_volume, 0.0)


func test_computes_effective_volumes_correctly_when_unmuted_and_muted() -> void:
	var settings := AudioSettings.new({
		"master_volume": 0.5,
		"music_volume": 0.8,
		"sfx_volume": 0.6,
	})

	assert_near(settings.get_effective_music_volume(), 0.4)
	assert_near(settings.get_effective_sfx_volume(), 0.3)
	assert_near(settings.get_effective_sfx_volume(2.0), 0.6)

	settings.toggle_mute()
	assert_true(settings.is_muted)
	assert_near(settings.get_effective_music_volume(), 0.0)
	assert_near(settings.get_effective_sfx_volume(), 0.0)

	settings.toggle_mute()
	assert_false(settings.is_muted)
	assert_near(settings.get_effective_music_volume(), 0.4)


func test_calculates_linear_distance_attenuation_with_radius_clamping() -> void:
	var settings := AudioSettings.new({
		"master_volume": 1.0,
		"sfx_volume": 1.0,
	})

	var base_vol := 0.8
	var max_radius := 20.0

	assert_near(settings.calculate_distance_volume(0.0, max_radius, base_vol), 0.8)
	assert_near(settings.calculate_distance_volume(10.0, max_radius, base_vol), 0.4)
	assert_near(settings.calculate_distance_volume(20.0, max_radius, base_vol), 0.0)
	assert_near(settings.calculate_distance_volume(25.0, max_radius, base_vol), 0.0)
	assert_near(settings.calculate_distance_volume(-5.0, max_radius, base_vol), 0.8)


func test_serializes_and_deserializes_audio_settings_cleanly() -> void:
	var original := AudioSettings.new({
		"master_volume": 0.75,
		"music_volume": 0.35,
		"sfx_volume": 0.9,
		"is_muted": true,
	})

	var json := original.serialize()
	var restored := AudioSettings.deserialize(json)

	assert_near(restored.master_volume, 0.75)
	assert_near(restored.music_volume, 0.35)
	assert_near(restored.sfx_volume, 0.9)
	assert_true(restored.is_muted)
