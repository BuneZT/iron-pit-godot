extends TestCase

var _hud: HUDController


func before_each() -> void:
	_hud = HUDController.new()
	scene_tree.root.add_child(_hud)


func after_each() -> void:
	if is_instance_valid(_hud):
		if _hud.get_parent():
			_hud.get_parent().remove_child(_hud)
		_hud.free()
	_hud = null


func test_loads_static_pixel_font_and_ui_textures() -> void:
	assert_not_null(_hud.radar_widget)
	assert_not_null(_hud.radar_widget.bezel_texture)
	assert_not_null(load("res://assets/fonts/iron_pixel.fnt"))
	assert_not_null(load("res://assets/textures/ui/iron_plate_9slice.png"))
	assert_not_null(load("res://assets/textures/ui/iron_recess_9slice.png"))
	assert_not_null(load("res://assets/textures/ui/icon_med_cross.png"))
	assert_not_null(load("res://assets/textures/ui/icon_twin_shells.png"))


func test_radar_is_anchored_bottom_right_and_only_visible_when_playing() -> void:
	assert_near(_hud.radar_widget.anchor_left, 1.0)
	assert_near(_hud.radar_widget.anchor_top, 1.0)
	assert_near(_hud.radar_widget.anchor_right, 1.0)
	assert_near(_hud.radar_widget.anchor_bottom, 1.0)
	assert_false(_hud.radar_widget.visible)

	var blips := PackedVector3Array([
		Vector3(0.25, -0.5, 0.56),
		Vector3(-1.0, 0.0, 1.4),
	])
	_hud.update_hud({
		"status": "PLAYING",
		"wave": 1,
		"remaining_enemies": 2,
		"is_in_breather": false,
		"kills": 0,
		"score": 0,
		"hp": 80.0,
		"max_hp": 100.0,
		"ammo": 9,
		"magazine_size": 12,
		"is_reloading": false,
		"radar_blips": blips,
	})
	assert_true(_hud.radar_widget.visible)
	assert_eq(_hud.radar_widget.blips.size(), 2)
	assert_near(_hud.radar_widget.blips[0].y, -0.5, 0.001)
	assert_gt(_hud.radar_widget.blips[1].z, 1.0)

	# Leaving PLAYING hides and clears radar
	_hud.update_hud({
		"status": "PAUSED",
		"wave": 1,
		"remaining_enemies": 2,
		"is_in_breather": false,
		"kills": 0,
		"score": 0,
		"hp": 80.0,
		"max_hp": 100.0,
		"ammo": 9,
		"magazine_size": 12,
		"is_reloading": false,
	})
	assert_false(_hud.radar_widget.visible)
	assert_eq(_hud.radar_widget.blips.size(), 0)


func test_minimalist_vitals_and_ammo_segments_update_and_hide_ready_hint() -> void:
	_hud.update_hud({
		"status": "PLAYING",
		"wave": 2,
		"remaining_enemies": 7,
		"is_in_breather": false,
		"kills": 12,
		"score": 1200,
		"hp": 80.0,
		"max_hp": 100.0,
		"ammo": 9,
		"magazine_size": 12,
		"is_reloading": false,
	})

	assert_eq(_hud.health_text.text, "80")
	assert_eq(_hud.ammo_value.text, "09")
	assert_false(_hud.reload_hint.visible)
	assert_eq(_hud.health_segments.size(), 10)
	assert_eq(_hud.ammo_pips.size(), 12)
	assert_eq(_hud.health_segments[7].color, Color("#dc2626"))
	assert_eq(_hud.health_segments[8].color, Color("#1c1b1f"))
	assert_eq(_hud.ammo_pips[8].color, Color("#d97706"))
	assert_eq(_hud.ammo_pips[9].color, Color("#1c1b1f"))

	# Low ammo reveals reload hint
	_hud.update_hud({
		"status": "PLAYING",
		"wave": 2,
		"remaining_enemies": 7,
		"is_in_breather": false,
		"kills": 12,
		"score": 1200,
		"hp": 80.0,
		"max_hp": 100.0,
		"ammo": 2,
		"magazine_size": 12,
		"is_reloading": false,
	})
	assert_true(_hud.reload_hint.visible)
	assert_eq(_hud.reload_hint.text, "LOW [R]")
