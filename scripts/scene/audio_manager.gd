class_name AudioManager
extends Node

const SOUND_FILES: Dictionary = {
	"gunshot": {"path": "res://assets/audio/gunshot.ogg", "volume": 0.85, "pool_size": 4},
	"dryfire": {"path": "res://assets/audio/dryfire.ogg", "volume": 0.65, "pool_size": 2},
	"reload": {"path": "res://assets/audio/reload.ogg", "volume": 0.75, "pool_size": 2},
	"hit": {"path": "res://assets/audio/hit.ogg", "volume": 0.70, "pool_size": 4},
	"knockdown": {"path": "res://assets/audio/knockdown.ogg", "volume": 0.90, "pool_size": 3},
	"hurt": {"path": "res://assets/audio/hurt.ogg", "volume": 0.85, "pool_size": 2},
	"enemy_groan": {"path": "res://assets/audio/enemy_groan.ogg", "volume": 0.75, "pool_size": 3},
	"footstep": {"path": "res://assets/audio/footstep.ogg", "volume": 0.45, "pool_size": 3},
	"wave_bell": {"path": "res://assets/audio/wave_bell.wav", "volume": 0.85, "pool_size": 2},
}

const MUSIC_FILE: Dictionary = {
	"path": "res://assets/audio/music_ambient.ogg",
	"base_volume": 0.80,
}

var settings: AudioSettings
var _pools: Dictionary = {}
var _pool_indices: Dictionary = {}
var _music_player: AudioStreamPlayer
var _is_music_ducked: bool = false
var _music_wanted: bool = false


func _init(initial_settings: AudioSettings = null) -> void:
	name = "AudioManager"
	settings = initial_settings if initial_settings != null else AudioSettings.new()


static func _linear_to_db_safe(linear: float) -> float:
	if linear <= 0.0001:
		return -80.0
	return linear_to_db(linear)


func preload_sounds() -> void:
	# Preload looping ambient BGM
	var music_stream: AudioStream = load(String(MUSIC_FILE["path"]))
	if music_stream is AudioStreamOggVorbis:
		(music_stream as AudioStreamOggVorbis).loop = true
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.stream = music_stream
	_music_player.volume_db = _linear_to_db_safe(_get_calculated_music_volume())
	add_child(_music_player)

	# Preload pools for each SFX
	for key in SOUND_FILES.keys():
		var cfg: Dictionary = SOUND_FILES[key]
		var stream: AudioStream = load(String(cfg["path"]))
		var pool_size: int = int(cfg["pool_size"])
		var base_vol: float = float(cfg["volume"])
		var pool: Array[AudioStreamPlayer] = []
		for i in range(pool_size):
			var player := AudioStreamPlayer.new()
			player.name = "%s_%d" % [key, i]
			player.stream = stream
			player.volume_db = _linear_to_db_safe(settings.get_effective_sfx_volume(base_vol))
			add_child(player)
			pool.append(player)
		_pools[key] = pool
		_pool_indices[key] = 0


func start_music() -> void:
	_music_wanted = true
	if _music_player == null:
		return
	_music_player.volume_db = _linear_to_db_safe(_get_calculated_music_volume())
	if not _music_player.playing:
		_music_player.play()
	_music_player.stream_paused = false


func pause_music() -> void:
	if _music_player == null:
		return
	_music_player.stream_paused = true


func resume_music() -> void:
	if not _music_wanted or _music_player == null:
		return
	_music_player.volume_db = _linear_to_db_safe(_get_calculated_music_volume())
	_music_player.stream_paused = false
	if not _music_player.playing:
		_music_player.play()


func duck_music(ducked: bool) -> void:
	_is_music_ducked = ducked
	if _music_player != null:
		_music_player.volume_db = _linear_to_db_safe(_get_calculated_music_volume())


func _get_calculated_music_volume() -> float:
	var effective := settings.get_effective_music_volume() * float(MUSIC_FILE["base_volume"])
	return effective * 0.4 if _is_music_ducked else effective


func play(effect: String, volume_multiplier: float = 1.0) -> void:
	if settings.is_muted or not SOUND_FILES.has(effect):
		return
	if not _pools.has(effect):
		return
	var pool: Array = _pools[effect]
	if pool.is_empty():
		return

	var cfg: Dictionary = SOUND_FILES[effect]
	var idx: int = int(_pool_indices.get(effect, 0))
	var player: AudioStreamPlayer = pool[idx]
	_pool_indices[effect] = (idx + 1) % pool.size()

	var vol := settings.get_effective_sfx_volume(float(cfg["volume"]) * volume_multiplier)
	player.volume_db = _linear_to_db_safe(vol)
	player.play(0.0)


func play_distance_attenuated(
	effect: String,
	source_pos: Vector3,
	listener_pos: Vector3,
	max_radius: float = 24.0
) -> void:
	if settings.is_muted or not SOUND_FILES.has(effect):
		return
	var dist := source_pos.distance_to(listener_pos)
	if dist >= max_radius:
		return

	var cfg: Dictionary = SOUND_FILES[effect]
	var factor := 1.0 - (dist / max_radius)
	var effective_vol := settings.calculate_distance_volume(dist, max_radius, float(cfg["volume"]))
	if effective_vol <= 0.01:
		return

	play(effect, factor)


func stop_all() -> void:
	_music_wanted = false
	if _music_player != null:
		_music_player.stop()
	for key in _pools.keys():
		var pool: Array = _pools[key]
		for p in pool:
			var player := p as AudioStreamPlayer
			if player != null:
				player.stop()


func apply_settings() -> void:
	if _music_player != null:
		_music_player.volume_db = _linear_to_db_safe(_get_calculated_music_volume())
		if _music_wanted and not _music_player.playing and not settings.is_muted:
			_music_player.play()
