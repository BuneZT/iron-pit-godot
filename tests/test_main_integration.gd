extends TestCase

var _app: GameApp


func before_each() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	_app = packed.instantiate() as GameApp
	scene_tree.root.add_child(_app)
	await scene_tree.physics_frame
	await scene_tree.physics_frame


func after_each() -> void:
	if is_instance_valid(_app):
		if _app.audio != null:
			_app.audio.stop_all()
		_app.get_parent().remove_child(_app)
		_app.free()


func test_main_scene_boots_in_menu_and_transitions_through_full_match_lifecycle() -> void:
	assert_eq(_app.game_state.status, "MENU")
	assert_true(_app.hud.modal_overlay.visible)
	assert_eq(_app.hud.modal_title.text, "IRON PIT")
	assert_eq(_app.hud.action_button.text, "ENTER THE PIT")
	assert_not_null(_app.hud.settings_button)

	# Verify viewport 3D render scaling is applied from settings
	assert_not_null(_app.settings)
	assert_near(_app.get_viewport().scaling_3d_scale, _app.settings.render_scale)

	# Test settings modal opening and changing render scale slider & graphics quality
	_app.hud.settings_button.pressed.emit()
	assert_true(_app.hud.settings_modal.visible)
	_app.hud.render_scale_slider.value = 75.0
	assert_near(_app.settings.render_scale, 0.75)
	assert_near(_app.get_viewport().scaling_3d_scale, 0.75)
	_app.hud.render_scale_slider.value = 60.0
	assert_near(_app.settings.render_scale, 0.60)
	assert_near(_app.get_viewport().scaling_3d_scale, 0.60)

	_app.hud.sync_settings({
		"master_volume": 0.8,
		"music_volume": 0.6,
		"sfx_volume": 0.8,
		"is_muted": false,
		"render_scale": 0.60,
		"graphics_quality": "HIGH",
	})
	_app.hud.graphics_quality_button.pressed.emit()
	assert_eq(_app.settings.graphics_quality, "LOW")
	assert_false(_app.arena_builder.directional_light.shadow_enabled)

	_app.hud.graphics_quality_button.pressed.emit()
	assert_eq(_app.settings.graphics_quality, "MEDIUM")
	assert_true(_app.arena_builder.directional_light.shadow_enabled)

	_app.hud.settings_close_button.pressed.emit()
	assert_false(_app.hud.settings_modal.visible)

	# Verify muzzle OmniLight3D is culled (visible = false) when not firing
	assert_false(_app.weapon_controller.muzzle_light.visible)

	# Start match via HUD action button
	_app.hud.action_button.pressed.emit()
	assert_eq(_app.game_state.status, "PLAYING")
	assert_false(_app.hud.modal_overlay.visible)
	assert_eq(_app.wave_manager.current_wave, 1)
	assert_eq(_app.wave_manager.remaining_enemies, 5)

	# Spawn and position an enemy directly in front of the player camera (along +Z, since yaw=0 looks along +Z)
	_app.enemy_controller.clear_all()
	var target_enemy := _app.enemy_controller.spawn_enemy(1, _app.player.position)
	target_enemy.root.global_position = Vector3(0.0, 0.9, 6.0)
	for part in target_enemy.parts:
		part.force_update_transform()
	await scene_tree.physics_frame
	await scene_tree.physics_frame

	# Fire weapon 3 times (3 * 35 = 105 >= 100 HP -> kills enemy!)
	_app.handle_primary_fire()
	assert_true(_app.weapon_controller.muzzle_light.visible)
	assert_eq(_app.weapon_state.ammo, 11)
	assert_near(target_enemy.hp, 65.0)
	assert_eq(target_enemy.state, "ALIVE")

	_app.weapon_state.update(0.3)
	_app.weapon_controller.update(0.3, false)
	assert_false(_app.weapon_controller.muzzle_light.visible)
	_app.handle_primary_fire()
	assert_eq(_app.weapon_state.ammo, 10)
	assert_near(target_enemy.hp, 30.0)

	_app.weapon_state.update(0.3)
	_app.handle_primary_fire()
	assert_eq(_app.weapon_state.ammo, 9)
	assert_eq(target_enemy.state, "KNOCKED_DOWN")
	assert_eq(_app.game_state.kills, 1)
	assert_eq(_app.game_state.score, 100)
	assert_eq(_app.wave_manager.remaining_enemies, 4)

	# Pause and resume
	_app.pause_game()
	assert_eq(_app.game_state.status, "PAUSED")
	assert_true(_app.hud.modal_overlay.visible)
	assert_eq(_app.hud.action_button.text, "RESUME FIGHT")

	_app.hud.action_button.pressed.emit()
	assert_eq(_app.game_state.status, "PLAYING")
	assert_false(_app.hud.modal_overlay.visible)

	# Trigger Game Over via lethal damage
	_app.health_state.take_damage(100.0)
	_app.game_state.trigger_game_over()
	_app.sync_hud()
	assert_eq(_app.game_state.status, "GAME_OVER")
	assert_true(_app.hud.modal_overlay.visible)
	assert_eq(_app.hud.modal_title.text, "OVERRUN")
	assert_eq(_app.hud.action_button.text, "RETURN TO PIT")


func test_jumping_enemies_do_not_float_or_freeze_mid_air_under_real_loop() -> void:
	_app.start_new_match()
	_app.enemy_controller.clear_all()

	var jumpers: Array = []
	for i in range(4):
		var e := _app.enemy_controller.spawn_enemy(1, Vector3.ZERO)
		var angle := float(i) * PI * 0.5
		e.root.position = Vector3(cos(angle) * 4.5, 0.9, sin(angle) * 4.5)
		e.prev_position = e.root.position
		e.jump_cooldown = 0.0
		jumpers.append(e)

	var max_y := 0.0
	var saw_jump := false
	for tick in range(90):
		_app.health_state.current = 9999.0
		# Circle player at elevated height for first 30 ticks to force leaps + yaw updates, then drop player
		var angle := float(tick) * 0.1
		var py := 2.4 if tick < 30 else 0.9
		_app.player.position = Vector3(sin(angle) * 3.0, py, cos(angle) * 3.0)
		_app.player.vertical_velocity = 0.0
		await scene_tree.physics_frame
		for e in jumpers:
			var y: float = e.root.position.y
			max_y = maxf(max_y, y)
			if y > 1.5:
				saw_jump = true

	assert_true(saw_jump)
	assert_lt(max_y, 2.8)
	for e in jumpers:
		assert_lt(e.root.position.y, 1.2)
