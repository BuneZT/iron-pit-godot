# AGENTS.md — Context, Visual Identity & Godot 4.7 Best Practices Guide for AI Coding Agents

This document defines the architecture, visual art direction, technical standards, and **Godot 4.7 + Jolt Physics 3D + GDScript 2.0 best practices** that all AI agents and contributors must follow when maintaining and expanding `iron-pit-godot`.

---

## 1. Project Overview

* **Title:** Iron Pit (`iron-pit-godot`)
* **Genre:** 90s Gothic Retro Arena Survival First-Person Shooter (FPS) with heavy kinetic physics knockdowns.
* **Aesthetic Identity & Setting:** Dark, grimy, tactile gothic aesthetic inspired by **Quake 1** and **Dark Forces**. Open-air crumbling stone ruins under an oppressive, overcast ash-grey sky, surrounded by dense exponential distance fog with no visible skybox seams or ceiling enclosures.
* **Tech Stack:** Godot 4.7.2-stable (`Forward+` renderer), built-in **Jolt Physics 3D**, strictly typed **GDScript 2.0**, `CanvasLayer` + `StyleBoxFlat` 90s HUD, Headless `SceneTree` unit & integration test runner.
* **Arena Scale:** `100m × 100m` flagstone ruins pit (`1 unit = 1 meter`), low crumbling stone parapets with crooked iron spikes, `1.8m` player/enemy height, global physics gravity `(0, -18, 0)`.

---

## 2. Directory Structure & Key Modules

```text
iron-pit-godot/
├── project.godot                 # Engine configuration (Forward+, Jolt Physics 3D, gravity -18.0, layers)
├── default_bus_layout.tres       # Audio Bus Layout (Master, Music, SFX)
├── AGENT.md                      # Godot 4.7 Best Practices Guide for AI Agents
├── AGENTS.md                     # Synced copy of AGENT.md for multi-agent compatibility
├── assets/
│   ├── audio/                    # Preloaded real CC0 .ogg/.wav sound effects (NO AudioStreamGenerator synthesis)
│   └── textures/                 # Pre-generated 128x128 Bayer-dithered retro PNG textures
├── scenes/
│   ├── Main.tscn                 # Root 3D arena scene, WorldEnvironment, DirectionalLight3D, Player, HUD
│   ├── Player.tscn               # CharacterBody3D + Cylinder/Capsule collider + Camera3D + WeaponRig
│   └── HUD.tscn                  # CanvasLayer 90s beveled iron HUD & modal screens
├── scripts/
│   ├── main.gd                   # Top-level orchestrator: match lifecycle, wave loop, input & HUD sync
│   ├── core/                     # Pure RefCounted GDScript game logic (Zero Node/SceneTree imports)
│   │   ├── arena_layout_generator.gd # Mulberry32 seeded layout (megaliths, barricades, braziers, fog spawns)
│   │   ├── audio_settings.gd     # Volume clamping, mute toggle, linear distance attenuation, JSON persistence
│   │   ├── game_state.gd         # Match lifecycle (MENU, PLAYING, PAUSED, GAME_OVER), kills, score, curse
│   │   ├── health_state.gd       # HP math, contact damage, post-hit invulnerability timer
│   │   ├── lore_catalog.gd       # Mor'gath narrative strings, Chronicle chapters, wave whispers
│   │   ├── wave_manager.gd       # Wave formula (3 + 2N), spawn queue interval, breather timer
│   │   └── weapon_state.gd       # Magazine ammo, fire rate cooldown, reload timer, damage stats
│   ├── scene/                    # Godot 4 3D & Jolt Physics controllers
│   │   ├── arena_builder.gd      # Constructs foggy ruins, parapets, monoliths, braziers, lighting
│   │   ├── audio_manager.gd      # Pooled AudioStreamPlayer rings, music ducking, distance attenuation
│   │   ├── enemy_controller.gd   # 21-part Gothic Fiend RigidBody3D meshes, stagger & ragdoll knockdown
│   │   ├── player_controller.gd  # CharacterBody3D movement (WASD/Sprint/Jump/Look), recoil, footsteps
│   │   └── weapon_controller.gd  # 9-part blackened-iron viewmodel gun, recoil kick, muzzle light, raycast
│   └── ui/
│       └── hud_controller.gd     # 90s chiseled iron & stone CanvasLayer HUD overlay & modal screens
├── tests/                        # Headless GDScript test suite (run via `godot --headless -s tests/run_tests.gd`)
└── docs/
    └── superpowers/
        ├── specs/                # Design specifications
        └── plans/                # Implementation plans
```

---

## 3. Core Architectural Rules & Godot 4.7 Best Practices

### 3.1 Strict Separation of Pure Core Logic vs. Scene Tree (`scripts/core/` vs. `scripts/scene/`)
* **Rule:** All gameplay rules, state machines, timers, ammo/damage math, wave scaling, lore strings, and procedural layout generation **must** live in `res://scripts/core/` as pure `RefCounted` classes (`extends RefCounted`) with **zero dependencies on `Node`, `SceneTree`, or `PhysicsServer3D`**.
* **Why:** Pure `RefCounted` objects instantiate in microseconds without scene tree overhead, cannot leak orphan nodes, and allow deterministic unit tests (`tests/test_*.gd`) to run headlessly in milliseconds.
* **Static Typing Mandatory:** Every variable, parameter, and function return type in GDScript 2.0 must use explicit static typing (`var hp: float = 100.0`, `func update(dt: float) -> int:`). Never use untyped dynamic variants where a concrete type or `Dictionary`/`Array[T]` applies.

### 3.2 Zero Runtime Allocation Churn in `_process` / `_physics_process`
In a 60–144 FPS 3D shooter, creating `Node` instances, `StandardMaterial3D` resources, or `Mesh` resources inside per-frame loops causes frame-time spikes:
* **Value Types in GDScript:** Unlike JavaScript/TypeScript, `Vector2`, `Vector3`, `Color`, `Quaternion`, `Basis`, and `Transform3D` in Godot 4 are stack-allocated value structs, not heap objects. However, `Object` subclasses (`RefCounted`, `Resource`, `Node`) and `Array`/`Dictionary` **are** heap-allocated.
* **Share Materials & Meshes:**
  * Cache shared `StandardMaterial3D` instances on the controller (`floor_mat`, `wall_mat`, `crypt_mat`, `iron_mat`, `ember_mat`) and reuse them across static geometry rather than duplicating materials for every obstacle.
  * Only create per-entity materials when an entity requires independent per-instance state (such as `body_mat` and `visor_mat` on `EnemyInstance` for individual white hit-flashes and death darkening), and explicitly clear them when the entity is freed.
* **Pool Audio Players & Reuse Transient Visuals:**
  * Pre-allocate `AudioStreamPlayer` pools at startup (`AudioManager.preload_sounds()`) instead of instantiating and freeing players on every gunshot or footstep.

### 3.3 Explicit Node & Resource Lifecycle (Preventing Orphan Nodes & RID Leaks)
* **Immediate Cleanup on Match Reset / Rebuild:**
  * When rebuilding the arena layout (`ArenaBuilder.rebuild_dynamic_layout()`) or clearing enemies (`EnemyController.clear_all()`), remove nodes from their parent immediately (`parent.remove_child(node)`) before calling `node.free()` (or `queue_free()`) so old collision shapes and named nodes do not linger in the `SceneTree` or `PhysicsServer3D` during the same frame.
* **No Orphan Nodes in Tests:**
  * Every test that instantiates `Node` or `Node3D` hierarchies must attach them to `scene_tree.root` and explicitly `free()` them in teardown so `godot --headless` exits with zero leaked instances or RIDs.

### 3.4 Jolt Physics 3D & Collision Layer Best Practices
* **Explicit 3D Collision Layers & Masks (`project.godot`):**
  * **Layer 1 (`1` - `WorldGeometry`):** Static arena floor, parapets, invisible ceiling walls, megaliths, rubble, barricades, and brazier pedestals/bowls.
  * **Layer 2 (`2` - `Player`):** Player `CharacterBody3D` (`collision_layer = 2`, `collision_mask = 1`).
  * **Layer 3 (`4` - `EnemyBody`):** Enemy `RigidBody3D` capsule (`collision_layer = 4`, `collision_mask = 1 | 4`).
  * **Layer 4 (`8` - `EnemyHitbox`):** Pickable `Area3D` / collision shapes attached to each of the 21 visible anatomical parts of the Gothic Fiend (`collision_layer = 8`, `collision_mask = 0`), storing `set_meta("enemy_id", id)`.
* **Player Controller (`CharacterBody3D`):**
  * Use `CharacterBody3D` with `move_and_slide()` for responsive, deterministic Quake-style first-person movement, instant air/ground velocity control, and step/obstacle landing without physics-body bounce.
* **Enemy Controller (`RigidBody3D` Upright Chasers vs. Physical Ragdoll Knockdown):**
  * Keep living humanoid enemies upright while chasing by locking their angular axes:
    ```gdscript
    body.axis_lock_angular_x = true
    body.axis_lock_angular_y = true
    body.axis_lock_angular_z = true
    body.linear_damp = 0.8
    ```
  * Drive active enemy pursuit via `body.linear_velocity` and leap/stagger via `body.apply_impulse(impulse, offset)`.
  * On a fatal hit (`KNOCKED_DOWN`), unlock all angular axes, lower damping, apply an off-center impulse at the hit point, and impart spin angular velocity so the fiend violently flips and tumbles across the flagstones:
    ```gdscript
    body.axis_lock_angular_x = false
    body.axis_lock_angular_y = false
    body.axis_lock_angular_z = false
    body.mass = 1.2
    body.linear_damp = 0.25
    body.angular_damp = 0.25
    body.apply_impulse(knockdown_impulse, hit_offset)
    body.angular_velocity = spin_axis * 7.5
    ```
* **Delta Time (`dt`) Clamping:**
  * Always clamp frame delta time to `minf(delta, 0.1)` in `main.gd` before advancing gameplay timers or movement so window stalls never cause physics tunneling.

### 3.5 Raycasting & Picking Performance (`PhysicsRayQueryParameters3D`)
* **Never Make Decorative Geometry Pickable:**
  * Parapet iron spikes, megalith reinforcement bands, barricade top caps, brazier embers, viewmodel gun parts, muzzle flashes, and shot tracers must **never** have collision shapes on Layer 1 or Layer 4.
* **Explicit Raycast Mask (`1 | 8`):**
  * Weapon hitscan raycasts (`WeaponController.fire_raycast()`) must query `get_world_3d().direct_space_state.intersect_ray(query)` with `query.collision_mask = 1 | 8` (`collide_with_bodies = true`, `collide_with_areas = true`).
  * This guarantees tracers stop on world walls/megaliths/barricades/braziers (Layer 1) and register hits on any of the 21 anatomical enemy parts (Layer 4) while ignoring decorative meshes and the player's own collider.

### 3.6 Static Assets Mandatory for Audio & Textures (No Procedural Synthesis)
* **Always use preloaded static files** in `res://assets/audio/` (`.ogg` / `.wav`, CC0 licensed) and `res://assets/textures/` (`.png`).
* **Never use `AudioStreamGenerator` or runtime procedural `ImageTexture` generation.** Static pre-authored files sound and look markedly better and avoid runtime stalls.

### 3.7 Retro Textures & Nearest-Neighbor Point-Sampling Rules (PS1 / Quake 1 Crunch)
* **Mandatory Nearest-Neighbor Point Sampling:**
  * Every `StandardMaterial3D` used on world geometry, weapons, or enemies must enforce nearest-neighbor texture filtering:
    ```gdscript
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    ```
  * This preserves the sharp, crunchy `128×128` 90s Bayer-dithered pixel grit and prevents blurry modern bilinear/trilinear filtering.
* **Matte Weathered Surfaces:**
  * Stone, masonry, and rusted iron materials must keep specular reflections very low (`roughness = 0.95`, `metallic_specular = 0.02`) so surfaces read as porous, weathered stone and oxidized iron rather than shiny plastic.

### 3.8 Low-Poly Architectural Imperfections & Atmosphere
* **No "Computer-Perfect" Primitives:**
  * Environment props must include purposeful structural imperfections:
    - Rusted 5-sided iron spikes with deterministic multi-axis tilts (`tilt_x`, `tilt_z`) and height variations (`spike_h`).
    - Megalith pillars topped with slanted 5-sided chipped stone caps, skewed iron reinforcement bands, and fallen rubble blocks.
    - Weathered stone barricades with slightly askew iron trim and fallen stepping stone fragments.
    - Crooked 3-legged brazier pedestals with faceted 6-sided columns and 7-sided hammered iron bowls.
* **Seamless Infinity Fog:**
  * Maintain exponential fog in `WorldEnvironment` (`fog_enabled = true`, `fog_density = 0.054`) with `fog_light_color` and `background_color` both set to gloomy ash-grey `Color(0.24, 0.25, 0.27)` and `Camera3D.far = 49.2` so no horizon seam or arena boundary is visible from the center.

### 3.9 Enemy Anatomy & Silhouette Standards (No Visible Cylinders)
* **Invisible Physics Proxy:**
  * Never render a visible capsule mesh on the root `RigidBody3D`. The root capsule `CollisionShape3D` (`height = 1.8`, `radius = 0.42`) must strictly act as an invisible Jolt physics collider.
* **Fully Articulated 21-Part Low-Poly Anatomy:**
  * Living enemies must be constructed out of distinct, faceted, low-poly anatomical `MeshInstance3D` nodes:
    - Forward-pitched hunched ribcage cuirass, narrower armored midsection vertebrae, and angular pelvis/hip girdle.
    - Segmented brawny legs: angled thighs, heavy greaves (shins), and pointed iron sabatons (boots) planted at ground level.
    - Hunched upper back mantle and sunken skull helm with asymmetrical horns (long curved left horn, shattered broken stump on right) and glowing crimson horizontal eye visor.
    - Asymmetrical shoulders: spiked left pauldron + dented right guard.
    - Segmented reaching arms: upper bicep, bent forearm, and sharp 4-sided iron talons/claws reaching toward the player.
* **Hitbox Propagation:**
  * Every visible anatomical child mesh must have an associated Layer 4 (`8`) hitbox shape with `set_meta("enemy_id", id)` so raycast hit detection works accurately across the entire humanoid body.

### 3.10 Gothic Narrative Tone & UI Copy Standards
* **Atmospheric Arena Terminology over Generic Arcade/Casual Jargon:**
  * All player-facing UI text, modal screens, prompts, button labels, and status callouts must uphold a grim, dark gothic arena atmosphere inspired by *Quake 1* and *Dark Forces*:
    - **Replay / Game Over:** Use `"RETURN TO PIT"` instead of `"PLAY AGAIN"` or `"RETRY"`.
    - **Resume / Unpause:** Use `"RESUME FIGHT"` instead of `"RESUME GAME"` or `"CONTINUE"`.
    - **Game Start:** Use `"ENTER THE PIT"` instead of `"START GAME"` or `"PLAY"`.
    - **Wave Cleared:** Use `"PURGED"` instead of generic `"CLEAR"` or `"ELIMINATED"`.
    - **Defeat / Loss:** Frame defeat somberly (`"OVERRUN"` with `LoreCatalog.get_game_over_message(wave, kills, score)`).
    - **Adversaries:** Refer to foes as `"fiends"`, `"hostiles"`, or `"demonic chasers"`.

---

## 4. Development & Verification Workflow

Before claiming any task or feature is complete, always run and verify the headless test suite using Godot 4.7.2:

```powershell
# Run all unit and scene integration tests headlessly
& "C:\Users\marci\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "C:\Users\marci\Documents\game_dev\iron-pit-godot" -s res://tests/run_tests.gd
```

All tests must output `[PASS]` and exit with code `0` and zero leaked resources or script errors.
