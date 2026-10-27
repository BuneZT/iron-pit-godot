class_name AudioSettings
extends RefCounted

var master_volume: float = 0.8
var music_volume: float = 0.6
var sfx_volume: float = 0.8
var is_muted: bool = false

var data: Dictionary:
	get:
		return {
			"master_volume": master_volume,
			"music_volume": music_volume,
			"sfx_volume": sfx_volume,
			"is_muted": is_muted,
		}


static func _clamp01(val: float) -> float:
	return clampf(val, 0.0, 1.0)


func _init(initial: Dictionary = {}) -> void:
	if initial.has("master_volume"):
		master_volume = _clamp01(float(initial["master_volume"]))
	elif initial.has("masterVolume"):
		master_volume = _clamp01(float(initial["masterVolume"]))
	else:
		master_volume = 0.8

	if initial.has("music_volume"):
		music_volume = _clamp01(float(initial["music_volume"]))
	elif initial.has("musicVolume"):
		music_volume = _clamp01(float(initial["musicVolume"]))
	else:
		music_volume = 0.6

	if initial.has("sfx_volume"):
		sfx_volume = _clamp01(float(initial["sfx_volume"]))
	elif initial.has("sfxVolume"):
		sfx_volume = _clamp01(float(initial["sfxVolume"]))
	else:
		sfx_volume = 0.8

	if initial.has("is_muted"):
		is_muted = bool(initial["is_muted"])
	elif initial.has("isMuted"):
		is_muted = bool(initial["isMuted"])
	else:
		is_muted = false


func set_master_volume(val: float) -> void:
	master_volume = _clamp01(val)


func set_music_volume(val: float) -> void:
	music_volume = _clamp01(val)


func set_sfx_volume(val: float) -> void:
	sfx_volume = _clamp01(val)


func toggle_mute() -> bool:
	is_muted = not is_muted
	return is_muted


func get_effective_music_volume() -> float:
	if is_muted:
		return 0.0
	return master_volume * music_volume


func get_effective_sfx_volume(multiplier: float = 1.0) -> float:
	if is_muted:
		return 0.0
	return _clamp01(master_volume * sfx_volume * multiplier)


func calculate_distance_volume(dist: float, max_radius: float, base_volume: float = 1.0) -> float:
	if is_muted or max_radius <= 0.0:
		return 0.0
	var clamped_dist := maxf(0.0, dist)
	if clamped_dist >= max_radius:
		return 0.0
	var factor := 1.0 - (clamped_dist / max_radius)
	return _clamp01(get_effective_sfx_volume(base_volume) * factor)


func serialize() -> String:
	return JSON.stringify(data)


static func deserialize(json_str: String) -> AudioSettings:
	var parsed: Variant = JSON.parse_string(json_str)
	if typeof(parsed) == TYPE_DICTIONARY:
		return AudioSettings.new(parsed as Dictionary)
	return AudioSettings.new()
