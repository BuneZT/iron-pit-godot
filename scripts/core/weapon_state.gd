class_name WeaponState
extends RefCounted

var _magazine_size: int = 12
var _fire_cooldown: float = 0.25
var _reload_duration: float = 1.2
var _damage: float = 35.0
var _auto_reload_on_empty: bool = true

var _ammo: int = 12
var _cooldown_timer: float = 0.0
var _reload_timer: float = 0.0
var _is_reloading: bool = false

var ammo: int:
	get:
		return _ammo

var magazine_size: int:
	get:
		return _magazine_size

var damage: float:
	get:
		return _damage

var is_reloading: bool:
	get:
		return _is_reloading


func _init(config: Dictionary = {}) -> void:
	_magazine_size = int(config.get("magazine_size", 12))
	_fire_cooldown = float(config.get("fire_cooldown", 0.25))
	_reload_duration = float(config.get("reload_duration", 1.2))
	_damage = float(config.get("damage", 35.0))
	_auto_reload_on_empty = bool(config.get("auto_reload_on_empty", true))
	_ammo = _magazine_size


func can_fire() -> bool:
	return not _is_reloading and _cooldown_timer <= 0.0 and _ammo > 0


func try_fire() -> String:
	if _is_reloading:
		return "RELOADING"
	if _ammo <= 0:
		if _auto_reload_on_empty:
			start_reload()
		return "EMPTY"
	if _cooldown_timer > 0.0:
		return "COOLDOWN"

	_ammo -= 1
	_cooldown_timer = _fire_cooldown
	return "FIRED"


func start_reload() -> bool:
	if _is_reloading or _ammo >= _magazine_size:
		return false

	_is_reloading = true
	_reload_timer = _reload_duration
	return true


func update(dt: float) -> bool:
	if _cooldown_timer > 0.0:
		_cooldown_timer = maxf(0.0, _cooldown_timer - dt)

	if _is_reloading:
		_reload_timer -= dt
		if _reload_timer <= 0.0:
			_reload_timer = 0.0
			_is_reloading = false
			_ammo = _magazine_size
			return true

	return false


func reset() -> void:
	_ammo = _magazine_size
	_cooldown_timer = 0.0
	_reload_timer = 0.0
	_is_reloading = false
