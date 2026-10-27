class_name WaveManager
extends RefCounted

var _spawn_interval: float = 0.8
var _wave_breather_duration: float = 3.0

var _current_wave: int = 0
var _total_for_wave: int = 0
var _to_spawn_count: int = 0
var _remaining_enemies: int = 0
var _spawn_timer: float = 0.0
var _breather_timer: float = 0.0
var _is_in_breather: bool = false

var current_wave: int:
	get:
		return _current_wave

var total_for_wave: int:
	get:
		return _total_for_wave

var remaining_enemies: int:
	get:
		return _remaining_enemies

var is_in_breather: bool:
	get:
		return _is_in_breather


func _init(config: Dictionary = {}) -> void:
	_spawn_interval = float(config.get("spawn_interval", 0.8))
	_wave_breather_duration = float(config.get("wave_breather_duration", 3.0))


static func compute_wave_enemy_count(wave_number: int) -> int:
	return 3 + 2 * wave_number


func start_first_wave() -> void:
	_start_wave(1)


func _start_wave(wave_number: int) -> void:
	_current_wave = wave_number
	var count := compute_wave_enemy_count(wave_number)
	_total_for_wave = count
	_to_spawn_count = count
	_remaining_enemies = count
	_spawn_timer = 0.0
	_breather_timer = 0.0
	_is_in_breather = false


func on_enemy_killed() -> void:
	if _remaining_enemies > 0:
		_remaining_enemies -= 1
		if _remaining_enemies == 0:
			_is_in_breather = true
			_breather_timer = _wave_breather_duration


func update(dt: float) -> int:
	if _current_wave == 0:
		return 0

	if _is_in_breather:
		_breather_timer -= dt
		if _breather_timer <= 0.0:
			_start_wave(_current_wave + 1)
		return 0

	if _to_spawn_count <= 0:
		return 0

	_spawn_timer -= dt
	var spawned_now := 0
	while _to_spawn_count > 0 and _spawn_timer <= 0.0:
		_to_spawn_count -= 1
		spawned_now += 1
		_spawn_timer += _spawn_interval

	return spawned_now


func reset() -> void:
	_current_wave = 0
	_total_for_wave = 0
	_to_spawn_count = 0
	_remaining_enemies = 0
	_spawn_timer = 0.0
	_breather_timer = 0.0
	_is_in_breather = false
