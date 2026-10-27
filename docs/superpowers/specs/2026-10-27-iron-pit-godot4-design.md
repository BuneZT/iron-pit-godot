# IRON PIT — Godot 4.7.2 1:1 Migration Design Specification

## 1. Overview & Goals

Migrate **Iron Pit** (`iron-pit`), a 90s Gothic Arena Survival First-Person Shooter originally built with Babylon.js + Havok Physics V2 + TypeScript, to **Godot 4.7.2-stable** as a 1:1 port in a dedicated repository (`C:\Users\marci\Documents\game_dev\iron-pit-godot` -> `https://github.com/BuneZT/iron-pit-godot`).

### Core Objectives
1. **100% Feature, Visual, Physics, Audio, Lore, and Gameplay Parity**:
   - Every formula, timer, dimension, material property, lighting value, procedural obstacle layout, articulated 21-part enemy mesh, 9-part blackened-iron carbine viewmodel, kinetic stagger/ragdoll knockdown impulse, and 90s chiseled iron HUD/modal flow must match the original game 1:1.
2. **Godot 4.7.2 Best Practices**:
   - Target `Godot 4.7.2.stable` with the `Forward+` renderer and built-in **Jolt Physics 3D**.
   - Strict separation between pure `RefCounted` core game logic (`scripts/core/`) and Godot `Node`/`Node3D`/`Control` scene controllers (`scripts/scene/`, `scripts/ui/`).
   - Declarative `.tscn` scenes combined with deterministic procedural 3D builders where geometry depends on seeded runtime parameters.
   - Authoritative `AGENTS.md` and `AGENT.md` documenting Godot 4.7 development best practices.
3. **Headless Automated Verification**:
   - Complete GDScript unit & integration test suite (`tests/`) executed headlessly via `godot --headless -s tests/run_tests.gd` with zero errors or leaks.

---

## 2. Architecture & Directory Structure

```text
iron-pit-godot/
├── project.godot                 # Godot 4.7 config: Forward+, Jolt Physics 3D, gravity -18.0, InputMap
├── default_bus_layout.tres       # Audio buses: Master, Music, SFX
├── AGENT.md                      # Godot 4.7 best practices guide for AI coding agents
├── AGENTS.md                     # Identical / synced agent guide for multi-tool compatibility
├── README.md                     # Project overview, controls, CLI commands, architecture
├── assets/
│   ├── audio/                    # Preloaded CC0 .ogg and .wav static audio assets
│   └── textures/                 # Pre-generated 128x128 Bayer-dithered retro PNG textures
├── scenes/
│   ├── Main.tscn                 # Root game scene (WorldEnvironment, DirectionalLight3D, Arena, Player, HUD)
│   ├── Player.tscn               # CharacterBody3D + CollisionShape3D + Camera3D + WeaponRig
│   └── HUD.tscn                  # CanvasLayer with 90s chiseled iron TopBar, Crosshair, Health, Ammo, Modals
├── scripts/
│   ├── main.gd                   # Top-level orchestrator (equivalent to GameApp.ts)
│   ├── core/                     # Pure RefCounted GDScript classes (Zero Node/SceneTree dependencies)
│   │   ├── arena_layout_generator.gd
│   │   ├── audio_settings.gd
│   │   ├── game_state.gd
│   │   ├── health_state.gd
│   │   ├── lore_catalog.gd
│   │   ├── wave_manager.gd
│   │   └── weapon_state.gd
│   ├── scene/                    # 3D Scene & Jolt Physics controllers
│   │   ├── arena_builder.gd      # Builds static 100x100m perimeter + dynamic megaliths/barricades/braziers
│   │   ├── audio_manager.gd      # Pooled AudioStreamPlayer nodes, music ducking, distance attenuation
│   │   ├── enemy_controller.gd   # Articulated 21-part Gothic Fiend RigidBody3D, chase, leap/vault, knockdown
│   │   ├── player_controller.gd  # CharacterBody3D movement, sprint, jump, mouse look, recoil, footsteps
│   │   └── weapon_controller.gd  # 9-part carbine viewmodel, muzzle flash/OmniLight3D, tracer, raycast
│   └── ui/
│       └── hud_controller.gd     # Updates CanvasLayer UI, crosshair pulse, damage vignette, modals, sliders
├── tests/
│   ├── run_tests.gd              # HeadlessSceneTree test runner exiting with code 0 (pass) or 1 (fail)
│   ├── test_arena_builder.gd
│   ├── test_arena_layout_generator.gd
│   ├── test_audio_settings.gd
│   ├── test_enemy_controller.gd
│   ├── test_game_state.gd
│   ├── test_health_state.gd
│   ├── test_hud_controller_lore.gd
│   ├── test_lore_catalog.gd
│   ├── test_player_controller.gd
│   ├── test_wave_manager.gd
│   └── test_weapon_state.gd
└── docs/
    └── superpowers/
        ├── specs/
        │   └── 2026-10-27-iron-pit-godot4-design.md
        └── plans/
            └── 2026-10-27-iron-pit-godot4-migration.md
```

---

## 3. Component-by-Component 1:1 Mapping

### 3.1 Core Logic (`scripts/core/`)
All classes extend `RefCounted` with `class_name` declarations and strict static typing:
* **`GameState` (`game_state.gd`)**:
  * Status values: `"MENU"`, `"PLAYING"`, `"PAUSED"`, `"GAME_OVER"`.
  * Properties: `status`, `kills`, `score`, `is_curse_broken`, `has_escaped`.
  * Methods: `start_match()`, `pause_match()`, `resume_match()`, `trigger_game_over()`, `record_kill(points := 100)`, `check_wave_milestone(wave: int)` (sets `is_curse_broken = true` at `wave >= 10`), `escape_pit()`.
* **`HealthState` (`health_state.gd`)**:
  * Configurable `max_health = 100.0`, `invulnerability_duration = 0.8`.
  * Properties: `current`, `max_hp`, `is_alive`, `is_invulnerable`.
  * Methods: `take_damage(amount: float) -> bool`, `update(dt: float) -> void`, `reset() -> void`.
* **`WeaponState` (`weapon_state.gd`)**:
  * Config defaults: `magazine_size = 12`, `fire_cooldown = 0.25`, `reload_duration = 1.2`, `damage = 35`, `auto_reload_on_empty = true`.
  * Fire outcomes: `"FIRED"`, `"COOLDOWN"`, `"EMPTY"`, `"RELOADING"`.
  * Methods: `can_fire() -> bool`, `try_fire() -> String`, `start_reload() -> bool`, `update(dt: float) -> bool`, `reset() -> void`.
* **`WaveManager` (`wave_manager.gd`)**:
  * Config defaults: `spawn_interval = 0.8`, `wave_breather_duration = 3.0`.
  * Formula: `compute_wave_enemy_count(wave_number: int) -> int` returns `3 + 2 * wave_number`.
  * Methods: `start_first_wave()`, `on_enemy_killed()`, `update(dt: float) -> int`, `reset()`.
* **`AudioSettings` (`audio_settings.gd`)**:
  * Defaults: `master_volume = 0.8`, `music_volume = 0.6`, `sfx_volume = 0.8`, `is_muted = false`.
  * Methods: `set_master_volume(val)`, `set_music_volume(val)`, `set_sfx_volume(val)`, `toggle_mute() -> bool`, `get_effective_music_volume() -> float`, `get_effective_sfx_volume(multiplier := 1.0) -> float`, `calculate_distance_volume(dist: float, max_radius: float, base_volume := 1.0) -> float`, `serialize() -> String`, `static deserialize(json_str: String) -> AudioSettings`.
  * Persisted to `user://iron_pit_audio_settings.json`.
* **`LoreCatalog` (`lore_catalog.gd`)**:
  * Exact constants and methods: `INTRO_SUBTITLE`, `CHRONICLE_CHAPTERS` (3 chapters), `WAVE_WHISPERS` (10 wave whispers + endless fallback), `get_wave_whisper(wave: int) -> String`, `get_game_over_message(wave: int, kills: int, score: int) -> String`, `get_victory_title() -> String`, `get_victory_subtitle() -> String`.
* **`ArenaLayoutGenerator` (`arena_layout_generator.gd`)**:
  * Constants: `SAFE_RADIUS = 10.0`, `ARENA_BOUNDS = 42.0`, `MIN_OBSTACLE_SPACING = 6.5`.
  * Deterministic Mulberry32 PRNG when seed is provided, random otherwise.
  * Generates 4-5 `megaliths`, 8 `barricades` (4 mid-field, 4 outer wall-flank), and 6 `braziers` (2 inner, 2 mid, 2 outer) across all 4 quadrants.
  * `find_fog_spawn_point(player_pos: Vector2, layout: Dictionary, rng: Callable) -> Vector2` samples 24m–35m in distance fog avoiding obstacles, with deterministic opposite-corner fallback.

### 3.2 3D Scene & Physics (`scripts/scene/`)
* **Physics & Collision Layers**:
  * Global gravity: `Vector3(0, -18.0, 0)`.
  * Layer 1 (`1`): Static World Geometry (Floor, Parapets, Invisible Boundary Walls, Megaliths, Rubble, Barricades, Brazier Pedestals & Bowls). Pickable by weapon raycasts so tracers stop on walls.
  * Layer 2 (`2`): Player `CharacterBody3D`. Collides with Layer 1.
  * Layer 3 (`4`): Enemy `RigidBody3D` physics capsule. Collides with Layer 1 and Layer 3 (`1 | 4`).
  * Layer 4 (`8`): Enemy Hitbox `Area3D` / `StaticBody3D` shapes attached to the 21 visible anatomical parts (or compound collision shapes with metadata) so `PhysicsRayQueryParameters3D` with collision mask `1 | 8` detects exact hits on every anatomical limb, horn, claw, and torso plate while ignoring decorative spikes/embers/viewmodels.
* **Atmosphere & Materials (`ArenaBuilder` / `arena_builder.gd`)**:
  * `WorldEnvironment` with custom `Environment`:
    * Background mode: `BG_COLOR`, color `Color(0.24, 0.25, 0.27, 1.0)`.
    * Ambient light: Sky/Hemisphere contribution matching `Color(0.42, 0.44, 0.46)` diffuse and `Color(0.2, 0.19, 0.18)` ground reflection (`energy = 0.65`).
    * Exponential Fog enabled: `fog_light_color = Color(0.24, 0.25, 0.27)`, `fog_density = 0.054`.
  * `DirectionalLight3D`: positioned at `(35, 45, 30)` pointing along `Vector3(-0.4, -1.0, -0.3).normalized()`, color `Color(0.75, 0.76, 0.78)`, `light_energy = 0.45`, `shadow_enabled = true`.
  * Shared `StandardMaterial3D` resources with `TEXTURE_FILTER_NEAREST` (nearest-neighbor point sampling for authentic 90s pixel grit) and low specular (`metallic_specular = 0.02`, high `roughness = 0.96`):
    * `floor_mat`: `stone_floor.png`, UV1 scale `Vector3(40, 40, 1)`
    * `wall_mat`: `dungeon_wall.png`, UV1 scale `Vector3(8, 2.5, 1)`
    * `crypt_mat`: `crypt_stone.png`, UV1 scale `Vector3(3, 3, 1)`
    * `iron_mat`: `rusted_iron.png`, UV1 scale `Vector3(2, 2, 1)`
    * `ember_mat`: albedo `Color(1.0, 0.55, 0.1)`, emission enabled `Color(1.0, 0.45, 0.05)`
  * Static Perimeter (`100m × 100m`):
    * Floor box (`100 × 1 × 100` at `y = -0.5`).
    * 4 stone parapets (`height = 1.5`, `thickness = 0.8`) + invisible ceiling boundary walls (`height = 6.0` above parapets) + 37 crooked 5-sided iron spikes per wall with deterministic multi-axis tilt (`tilt_x`, `tilt_z`, `spike_h`).
  * Dynamic Obstacles & Braziers:
    * `rebuild_dynamic_layout(layout)` frees previous dynamic nodes and constructs megaliths (pillar + 5-sided chipped stone cap + fallen rubble block + 2 skewed iron bands), crypt barricades (slab + iron top cap + fallen stepping fragment), and 6 braziers (3 angled 5-sided tripod legs, 6-sided central pedestal with cylinder collider, 7-sided fire bowl with cylinder collider, glowing ember sphere, and flickering `OmniLight3D` with `omni_range = 22.0`).
    * `update_brazier_resanctification(wave)` shifts brazier light color from `(1.0, 0.62, 0.22)` toward cleansed gold/white and expands range `22.0 + wave_progress * 8.0`.
* **Player Controller (`player_controller.gd`)**:
  * `CharacterBody3D` with cylinder/capsule collision shape (`radius = 0.45`, `height = 1.8`), centered at `y = 0.9` on flat ground.
  * `Camera3D` at `(0, 1.58, 0)` world height (`+0.68` above collider center), `near = 0.1`, `far = 49.2`, `fov = rad_to_deg(1.1)` (`~63.0 deg`).
  * Constants: `walk_speed = 7.2`, `sprint_speed = 12.0`, `jump_speed = 7.8`, `gravity = -20.0`, `mouse_sensitivity = 0.0022`, `max_pitch = deg_to_rad(82.0)`.
  * Recoil pitch recovery (`0.45 rad/s`), footstep cadence (`0.32s` sprinting, `0.44s` walking), arena bounds clamp (`±49.2m`).
* **Weapon Controller (`weapon_controller.gd`)**:
  * Attached to `Camera3D` at rest offset `Vector3(0.32, -0.28, -0.62)` (in Godot camera `-Z` forward space).
  * 9-part procedural blackened-iron Blunderbuss/Carbine mesh hierarchy: receiver, 8-sided barrel, 8-sided muzzle ring, brass clamping band, brass heat shroud, crooked welded side plate, 5-sided cocking lever, crooked front sight, and aged oak grip.
  * Muzzle node with 6-sided muzzle flash cone (`0.05s` burst), `OmniLight3D` (`omni_range = 14.0`, burst `light_energy = 1.7`), and 3D `ImmediateMesh` shot tracer line (`0.055s`).
  * Center-screen raycast (`49.2m` range) returning `{ enemy_id, hit_point, ray_direction }`.
* **Enemy Controller (`enemy_controller.gd`)**:
  * Each Gothic Fiend is a `RigidBody3D` (`mass = 1.5`, capsule collider `height = 1.8, radius = 0.42`, invisible root collider).
  * 21 articulated low-poly child meshes (chest plate, mid-spine, pelvis, left/right thigh/shin/sabaton, hunch mantle, skull helm, long curved left horn, shattered right horn stump, glowing crimson eye visor, spiked left pauldron + spike, dented right pauldron, left/right bicep/forearm/4-sided claws).
  * Each visible part registers a pickable hitbox collider on Layer 4 (`8`) with metadata `enemy_id`.
  * While `"ALIVE"`, angular axes are locked (`axis_lock_angular_x/y/z = true`, `linear_damp = 0.8`) so the fiend remains upright while chasing at `5.5 + min(2.2, (wave - 1) * 0.25) m/s`.
  * 3D contact damage (`15` damage when `horizontal_dist <= 1.45` and `abs(vertical_diff) <= 1.4`).
  * Vertical pursuit leap (`vertical_diff > 0.6` and `horizontal_dist <= 5.2`) and obstacle vault leap (`stuck_timer >= 0.28` when actual distance traveled `< expected * 0.45`).
  * Non-lethal hit (`"HIT"`): `0.26s` stagger, `0.11s` white armor flash, horizontal impulse `11.5` + upward `2.6`.
  * Fatal hit (`"KILLED"`): state `"KNOCKED_DOWN"`, `2.6s` despawn timer, darkens armor/visor materials, unlocks angular axes (`axis_lock_angular_x/y/z = false`, `mass = 1.2`, `linear_damp = 0.25`, `angular_damp = 0.25`), applies off-center impulse (`21.0` horizontal + `6.5` upward) at hit point plus topple `angular_velocity` (`7.5 rad/s` perpendicular to shot direction).

### 3.3 Audio System (`scripts/scene/audio_manager.gd`)
* Preloads all 9 SFX files (`gunshot.ogg`, `dryfire.ogg`, `reload.ogg`, `hit.ogg`, `knockdown.ogg`, `hurt.ogg`, `enemy_groan.ogg`, `footstep.ogg`, `wave_bell.wav`) into pooled `AudioStreamPlayer` rings and `music_ambient.ogg` into a looping `AudioStreamPlayer`.
* Supports `start_music()`, `pause_music()`, `resume_music()`, `duck_music(ducked: bool)` (`0.4x` multiplier when paused/game-over), `play(effect, volume_multiplier)`, `play_distance_attenuated(effect, source_pos, listener_pos, max_radius := 24.0)`, and `apply_settings()`.

### 3.4 HUD & Gothic UI (`scenes/HUD.tscn` & `scripts/ui/hud_controller.gd`)
* Recreates the exact 90s beveled iron & stone aesthetic using `CanvasLayer` and `StyleBoxFlat` panels:
  * **Damage Vignette**: Full-screen crimson inner border flash (`0.22s`).
  * **Top Container**: Chiseled iron top bar (`WAVE`, `HOSTILES`/`STATUS: PURGED`, `KILLS`) + non-intrusive golden italic `waveWhisper` banner during breathers.
  * **Chunky Crosshair**: 4 lines + amber center dot; expands (`1.4x` for `90ms`) on fire and turns blood-red (`#dc2626` for `140ms`) on enemy hit.
  * **Bottom-Left Health Panel**: `ARMOR INTEGRITY`, `100 / 100` text, and segmented crimson health bar fill.
  * **Bottom-Right Ammo Panel**: `HEAVY IRON CARBINE`, `12 / ∞` counter, and status hint (`READY`, `LOW AMMO [R]`, `PRESS [R] TO RELOAD`, `RELOADING...`).
  * **Modal Overlay**: Title (`IRON PIT` / `PAUSED` / `OVERRUN`), lore subtitle, 2-column controls badge grid (`WASD`, `MOUSE`, `LMB`, `R`, `SHIFT`, `SPACE`), Master/Music/SFX sliders + `MUTE AUDIO`/`UNMUTE AUDIO` button, primary action button (`ENTER THE PIT` / `RESUME FIGHT` / `RETURN TO PIT`), and `THE CHRONICLE` button.
  * **Chronicle Modal**: Weathered stone grimoire overlay displaying all 3 chapters from `LoreCatalog.CHRONICLE_CHAPTERS`, closable via `×` button, backdrop click, or `ESC`.
