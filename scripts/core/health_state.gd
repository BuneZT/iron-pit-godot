class_name HealthState
extends RefCounted

var _current: float
var _max: float
var _invulnerability_duration: float
var _invulnerability_timer: float = 0.0

var current: float:
	get:
		return _current

var max_hp: float:
	get:
		return _max

var is_alive: bool:
	get:
		return _current > 0.0

var is_invulnerable: bool:
	get:
		return _invulnerability_timer > 0.0


func _init(max_health: float = 100.0, invulnerability_duration: float = 0.8) -> void:
	_max = max_health
	_current = max_health
	_invulnerability_duration = invulnerability_duration


func take_damage(amount: float) -> bool:
	if not is_alive or is_invulnerable or amount <= 0.0:
		return false

	_current = maxf(0.0, _current - amount)
	if _current > 0.0:
		_invulnerability_timer = _invulnerability_duration
	return true


func update(dt: float) -> void:
	if _invulnerability_timer > 0.0:
		_invulnerability_timer = maxf(0.0, _invulnerability_timer - dt)


func reset() -> void:
	_current = _max
	_invulnerability_timer = 0.0
