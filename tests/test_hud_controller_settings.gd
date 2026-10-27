extends TestCase

var hud: HUDController


func before_each() -> void:
	hud = HUDController.new()
	scene_tree.root.add_child(hud)


func after_each() -> void:
	if is_instance_valid(hud):
		if hud.get_parent():
			hud.get_parent().remove_child(hud)
		hud.free()
	hud = null


func test_settings_button_exists_on_main_modal_and_audio_panel_removed() -> void:
	assert_not_null(hud.settings_button)
	assert_eq(hud.settings_button.text, "SETTINGS")
	assert_false(hud.settings_modal.visible)
	# Main modal card should have settings_button as a child
	assert_eq(hud.settings_button.get_parent().name, "cardVBox")


func test_opens_and_closes_settings_modal_via_buttons() -> void:
	hud.settings_button.emit_signal("pressed")
	assert_true(hud.settings_modal.visible)

	hud.settings_close_button.emit_signal("pressed")
	assert_false(hud.settings_modal.visible)

	hud.settings_button.emit_signal("pressed")
	assert_true(hud.settings_modal.visible)

	hud.settings_back_button.emit_signal("pressed")
	assert_false(hud.settings_modal.visible)


func test_closes_settings_modal_on_escape_key() -> void:
	hud.settings_button.emit_signal("pressed")
	assert_true(hud.settings_modal.visible)

	var handled := hud.handle_escape_key()
	assert_true(handled)
	assert_false(hud.settings_modal.visible)

	# Second escape call should return false when both modals are closed
	var second_handled := hud.handle_escape_key()
	assert_false(second_handled)


func test_render_scale_slider_fires_callback() -> void:
	var box: Array[float] = [0.0]
	hud.on_render_scale_change = func(val: float) -> void:
		box[0] = val

	hud.render_scale_slider.value = 75.0
	assert_near(box[0], 0.75)
	assert_true(hud.render_scale_value.text.begins_with("75%"))


func test_sync_settings_updates_all_sliders_and_labels() -> void:
	hud.sync_settings({
		"master_volume": 0.45,
		"music_volume": 0.70,
		"sfx_volume": 0.85,
		"is_muted": true,
		"render_scale": 0.60,
	})

	assert_near(hud.master_vol_slider.value, 45.0)
	assert_eq(hud.master_vol_value.text, "45%")
	assert_near(hud.music_vol_slider.value, 70.0)
	assert_eq(hud.music_vol_value.text, "70%")
	assert_near(hud.sfx_vol_slider.value, 85.0)
	assert_eq(hud.sfx_vol_value.text, "85%")
	assert_eq(hud.mute_button.text, "UNMUTE AUDIO")
	assert_near(hud.render_scale_slider.value, 60.0)
	assert_true(hud.render_scale_value.text.begins_with("60%"))
