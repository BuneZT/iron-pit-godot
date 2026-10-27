extends TestCase

var _hud: HUDController


func before_each() -> void:
	_hud = HUDController.new()
	scene_tree.root.add_child(_hud)


func after_each() -> void:
	if is_instance_valid(_hud):
		_hud.get_parent().remove_child(_hud)
		_hud.free()


func test_updates_start_menu_subtitle_with_lore_catalog_intro_subtitle() -> void:
	var snapshot := {
		"status": "MENU",
		"wave": 1,
		"remaining_enemies": 5,
		"is_in_breather": false,
		"kills": 0,
		"score": 0,
		"hp": 100.0,
		"max_hp": 100.0,
		"ammo": 12,
		"magazine_size": 12,
		"is_reloading": false,
	}
	_hud.update_hud(snapshot)
	assert_eq(_hud.modal_subtitle.text, LoreCatalog.INTRO_SUBTITLE)


func test_updates_game_over_subtitle_with_lore_catalog_defeat_message() -> void:
	var snapshot := {
		"status": "GAME_OVER",
		"wave": 3,
		"remaining_enemies": 0,
		"is_in_breather": false,
		"kills": 14,
		"score": 1400,
		"hp": 0.0,
		"max_hp": 100.0,
		"ammo": 0,
		"magazine_size": 12,
		"is_reloading": false,
	}
	_hud.update_hud(snapshot)
	assert_eq(_hud.modal_subtitle.text, LoreCatalog.get_game_over_message(3, 14, 1400))


func test_displays_wave_whisper_during_breather_and_hides_during_combat() -> void:
	var breather_snapshot := {
		"status": "PLAYING",
		"wave": 2,
		"remaining_enemies": 0,
		"is_in_breather": true,
		"kills": 5,
		"score": 500,
		"hp": 100.0,
		"max_hp": 100.0,
		"ammo": 12,
		"magazine_size": 12,
		"is_reloading": false,
	}
	_hud.update_hud(breather_snapshot)
	assert_eq(_hud.wave_whisper_label.text, LoreCatalog.get_wave_whisper(2))
	assert_true(_hud.wave_whisper.visible)

	var combat_snapshot := breather_snapshot.duplicate()
	combat_snapshot["is_in_breather"] = false
	combat_snapshot["remaining_enemies"] = 7
	_hud.update_hud(combat_snapshot)
	assert_false(_hud.wave_whisper.visible)


func test_opens_and_closes_chronicle_modal_via_buttons() -> void:
	assert_false(_hud.chronicle_modal.visible)

	_hud.chronicle_button.pressed.emit()
	assert_true(_hud.chronicle_modal.visible)

	_hud.chronicle_close_button.pressed.emit()
	assert_false(_hud.chronicle_modal.visible)


func test_closes_chronicle_modal_on_escape_key() -> void:
	_hud.chronicle_button.pressed.emit()
	assert_true(_hud.chronicle_modal.visible)

	var handled := _hud.handle_escape_key()
	assert_true(handled)
	assert_false(_hud.chronicle_modal.visible)
