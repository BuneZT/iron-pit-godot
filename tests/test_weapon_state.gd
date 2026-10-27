extends TestCase

var weapon: WeaponState


func before_each() -> void:
	weapon = WeaponState.new({
		"magazine_size": 12,
		"fire_cooldown": 0.25,
		"reload_duration": 1.2,
		"damage": 35.0,
	})


func test_starts_with_full_magazine_and_ready_to_fire() -> void:
	assert_eq(weapon.ammo, 12)
	assert_eq(weapon.magazine_size, 12)
	assert_eq(weapon.damage, 35.0)
	assert_false(weapon.is_reloading)
	assert_true(weapon.can_fire())


func test_decrements_ammo_and_enforces_fire_cooldown_on_try_fire() -> void:
	assert_eq(weapon.try_fire(), "FIRED")
	assert_eq(weapon.ammo, 11)
	assert_false(weapon.can_fire())
	assert_eq(weapon.try_fire(), "COOLDOWN")

	weapon.update(0.25)
	assert_true(weapon.can_fire())
	assert_eq(weapon.try_fire(), "FIRED")
	assert_eq(weapon.ammo, 10)


func test_returns_empty_when_magazine_reaches_0_and_does_not_fire() -> void:
	for i in range(12):
		assert_eq(weapon.try_fire(), "FIRED")
		weapon.update(0.25)
	assert_eq(weapon.ammo, 0)
	assert_eq(weapon.try_fire(), "EMPTY")


func test_reloads_magazine_after_reload_duration_and_blocks_firing() -> void:
	weapon.try_fire()
	weapon.update(0.25)
	assert_eq(weapon.ammo, 11)

	assert_true(weapon.start_reload())
	assert_true(weapon.is_reloading)
	assert_eq(weapon.try_fire(), "RELOADING")

	weapon.update(0.6)
	assert_true(weapon.is_reloading)
	assert_eq(weapon.ammo, 11)

	var finished := weapon.update(0.6)
	assert_true(finished)
	assert_false(weapon.is_reloading)
	assert_eq(weapon.ammo, 12)


func test_does_not_start_reload_if_magazine_is_full_or_already_reloading() -> void:
	assert_false(weapon.start_reload())
	weapon.try_fire()
	assert_true(weapon.start_reload())
	assert_false(weapon.start_reload())


func test_automatically_starts_reload_on_dryfire_when_auto_reload_true() -> void:
	for i in range(12):
		assert_eq(weapon.try_fire(), "FIRED")
		weapon.update(0.25)
	assert_eq(weapon.ammo, 0)
	assert_false(weapon.is_reloading)

	assert_eq(weapon.try_fire(), "EMPTY")
	assert_true(weapon.is_reloading)
	assert_eq(weapon.try_fire(), "RELOADING")

	weapon.update(1.2)
	assert_false(weapon.is_reloading)
	assert_eq(weapon.ammo, 12)


func test_does_not_auto_reload_on_dryfire_when_auto_reload_false() -> void:
	var manual_weapon := WeaponState.new({
		"magazine_size": 6,
		"fire_cooldown": 0.2,
		"reload_duration": 1.0,
		"damage": 30.0,
		"auto_reload_on_empty": false,
	})

	for i in range(6):
		manual_weapon.try_fire()
		manual_weapon.update(0.2)
	assert_eq(manual_weapon.ammo, 0)

	assert_eq(manual_weapon.try_fire(), "EMPTY")
	assert_false(manual_weapon.is_reloading)
