class_name GameApp
extends Node3D

const AUDIO_SETTINGS_PATH: String = "user://iron_pit_audio_settings.json"

var game_state: GameState = GameState.new()
var health_state: HealthState = HealthState.new(100.0, 0.8)
var weapon_state: WeaponState = WeaponState.new({
	"magazine_size": 12,
	"fire_cooldown": 0.25,
	"reload_duration": 1.2,
	"damage": 35.0,
})
var wave_manager: WaveManager = WaveManager.new({
	"spawn_interval": 0.8,
	"wave_breather_duration": 3.0,
})

var audio: AudioManager
var hud: HUDController
var player: PlayerController
var weapon_controller: WeaponController
var enemy_controller: EnemyController
var arena_builder: ArenaBuilder
var brazier_lights: Array[OmniLight3D] = []
var total_time: float = 0.0


func _ready() -> void:
	name = "GameApp"
	var settings := _load_audio_settings()
	audio = AudioManager.new(settings)
	add_child(audio)
	audio.preload_sounds()

	var initial_layout := ArenaLayoutGenerator.generate()
	var arena := ArenaBuilder.build(self, initial_layout)
	arena_builder = arena["builder"]
	brazier_lights = arena["brazier_lights"]

	player = PlayerController.new()
	add_child(player)

	weapon_controller = WeaponController.new(player.camera)
	add_child(weapon_controller)

	enemy_controller = EnemyController.new(self, initial_layout)

	player.on_footstep = func() -> void:
		audio.play("footstep")

	enemy_controller.on_enemy_groan = func(pos: Vector3) -> void:
		audio.play_distance_attenuated("enemy_groan", pos, player.position)

	hud = HUDController.new(
		Callable(self, "handle_modal_action"),
		{
			"on_master_volume_change": func(val: float) -> void:
				audio.settings.set_master_volume(val)
				audio.apply_settings()
				_save_audio_settings(),
			"on_music_volume_change": func(val: float) -> void:
				audio.settings.set_music_volume(val)
				audio.apply_settings()
				_save_audio_settings(),
			"on_sfx_volume_change": func(val: float) -> void:
				audio.settings.set_sfx_volume(val)
				audio.apply_settings()
				_save_audio_settings(),
			"on_toggle_mute": func() -> bool:
				var is_muted := audio.settings.toggle_mute()
				audio.apply_settings()
				_save_audio_settings()
				return is_muted,
		}
	)
	add_child(hud)
	hud.sync_audio_settings(audio.settings.data)
	sync_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and game_state.status == "PLAYING":
			_capture_mouse_safe()
			handle_primary_fire()
	elif event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE:
			if hud != null and hud.handle_escape_key():
				return
			if game_state.status == "PLAYING":
				pause_game()


func _physics_process(raw_dt: float) -> void:
	var dt := minf(raw_dt, 0.1)
	total_time += dt
	update_braziers(total_time, wave_manager.current_wave)
	update_game(dt)


func handle_modal_action() -> void:
	var status := game_state.status
	if status == "MENU" or status == "GAME_OVER":
		start_new_match()
	elif status == "PAUSED":
		game_state.resume_match()
		audio.resume_music()
		audio.duck_music(false)
		sync_hud()
	_capture_mouse_safe()


func pause_game() -> void:
	if game_state.status == "PLAYING":
		game_state.pause_match()
		audio.duck_music(true)
		_release_mouse_safe()
		sync_hud()


func start_new_match() -> void:
	enemy_controller.clear_all()
	var new_layout := ArenaLayoutGenerator.generate()
	brazier_lights = arena_builder.rebuild_dynamic_layout(new_layout)
	enemy_controller.set_layout(new_layout)
	player.reset()
	health_state.reset()
	weapon_state.reset()
	wave_manager.reset()
	wave_manager.start_first_wave()
	arena_builder.update_brazier_resanctification(1)
	game_state.start_match()
	audio.start_music()
	audio.duck_music(false)
	audio.play("wave_bell")
	sync_hud()


func _capture_mouse_safe() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _release_mouse_safe() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func handle_primary_fire() -> void:
	var fire_outcome := weapon_state.try_fire()
	if fire_outcome == "EMPTY":
		audio.play("dryfire")
		audio.play("reload")
		sync_hud()
		return
	if fire_outcome != "FIRED":
		return

	audio.play("gunshot")
	player.add_camera_recoil(0.032)

	var hit_info := weapon_controller.fire_raycast()
	var hit_enemy := false

	if hit_info["enemy_id"] != null:
		var outcome := enemy_controller.apply_hit(
			int(hit_info["enemy_id"]),
			weapon_state.damage,
			hit_info["hit_point"],
			hit_info["ray_direction"]
		)

		if outcome == "HIT":
			hit_enemy = true
			audio.play("hit")
		elif outcome == "KILLED":
			hit_enemy = true
			audio.play("knockdown")
			game_state.record_kill(100)
			wave_manager.on_enemy_killed()

	hud.pulse_crosshair(hit_enemy)
	sync_hud()


func update_braziers(time: float, wave: int) -> void:
	var wave_bonus := minf(0.5, maxf(0.0, float(wave - 1) * 0.05))
	var base_intensity := 0.76 + wave_bonus
	for i in range(brazier_lights.size()):
		var light := brazier_lights[i]
		if not is_instance_valid(light):
			continue
		var offset := float(i) * 1.7
		light.light_energy = (
			base_intensity
			+ 0.14 * sin((time + offset) * 7.5)
			+ 0.06 * cos((time + offset) * 17.3)
		)


func update_game(dt: float) -> void:
	if game_state.status != "PLAYING":
		return

	if player.is_pressing_reload():
		if weapon_state.start_reload():
			audio.play("reload")

	player.update(dt)
	health_state.update(dt)
	weapon_state.update(dt)
	weapon_controller.update(dt, weapon_state.is_reloading)

	var prev_wave := wave_manager.current_wave
	var to_spawn := wave_manager.update(dt)
	if wave_manager.current_wave > prev_wave:
		audio.play("wave_bell")
		game_state.check_wave_milestone(wave_manager.current_wave)
		arena_builder.update_brazier_resanctification(wave_manager.current_wave)

	for i in range(to_spawn):
		enemy_controller.spawn_enemy(wave_manager.current_wave, player.position)

	var contact_damage := enemy_controller.update(dt, player.position, wave_manager.current_wave)

	if contact_damage > 0.0 and health_state.take_damage(contact_damage):
		audio.play("hurt")
		hud.flash_damage_vignette()

		if not health_state.is_alive:
			game_state.trigger_game_over()
			audio.duck_music(true)
			_release_mouse_safe()

	sync_hud()


func _load_audio_settings() -> AudioSettings:
	if FileAccess.file_exists(AUDIO_SETTINGS_PATH):
		var file := FileAccess.open(AUDIO_SETTINGS_PATH, FileAccess.READ)
		if file != null:
			var content := file.get_as_text()
			file.close()
			return AudioSettings.deserialize(content)
	return AudioSettings.new()


func _save_audio_settings() -> void:
	var file := FileAccess.open(AUDIO_SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(audio.settings.serialize())
		file.close()


func sync_hud() -> void:
	hud.update_hud({
		"status": game_state.status,
		"wave": wave_manager.current_wave,
		"remaining_enemies": wave_manager.remaining_enemies,
		"is_in_breather": wave_manager.is_in_breather,
		"kills": game_state.kills,
		"score": game_state.score,
		"hp": health_state.current,
		"max_hp": health_state.max_hp,
		"ammo": weapon_state.ammo,
		"magazine_size": weapon_state.magazine_size,
		"is_reloading": weapon_state.is_reloading,
		"is_curse_broken": game_state.is_curse_broken,
	})
