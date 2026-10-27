# Iron Pit Godot 4.7.2 Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate `iron-pit` 1:1 from Babylon.js + Havok V2 + TypeScript to Godot 4.7.2-stable (`Forward+` renderer, Jolt Physics 3D, GDScript 2.0) in a separate repository (`BuneZT/iron-pit-godot`) with full automated headless test coverage and an authoritative `AGENT.md` / `AGENTS.md` best-practices guide.

**Architecture:** Pure `RefCounted` core game logic (`scripts/core/`) completely decoupled from `Node`/`SceneTree` for fast headless unit testing, paired with Godot 4.7 scene controllers (`scripts/scene/`, `scripts/ui/`) and `.tscn` scenes (`Main.tscn`, `Player.tscn`, `HUD.tscn`). All 3D environment geometry, 21-part enemy anatomy, 9-part carbine viewmodel, physics impulses, audio pools, and 90s chiseled iron UI match the original game 1:1.

**Tech Stack:** Godot 4.7.2.stable (`Forward+`, Jolt Physics 3D), GDScript 2.0 (static typing), Headless `SceneTree` unit & integration test runner, GitHub Actions CI.

## Global Constraints

- Engine version: `Godot 4.7.2.stable` (`C:\Users\marci\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`)
- Zero procedural audio or procedural textures at runtime; use static assets in `res://assets/audio/` and `res://assets/textures/` with `BaseMaterial3D.TEXTURE_FILTER_NEAREST`.
- Core logic (`res://scripts/core/`) must extend `RefCounted` with zero `Node` or `SceneTree` state dependencies.
- Maintain exact gothic narrative copy (`ENTER THE PIT`, `RESUME FIGHT`, `RETURN TO PIT`, `PURGED`, `OVERRUN`, `SEAL SHATTERED`, and `LoreCatalog` strings).

---

### Task 1: Project Configuration, Git Setup, Headless Test Runner & `AGENT.md` / `AGENTS.md`

**Files:**
- Create: `project.godot`
- Create: `default_bus_layout.tres`
- Create: `.gitignore`
- Create: `AGENT.md`
- Create: `AGENTS.md`
- Create: `README.md`
- Create: `tests/run_tests.gd`
- Create: `tests/test_case.gd`

- [ ] **Step 1: Create `project.godot`, `default_bus_layout.tres`, and `.gitignore`**
- [ ] **Step 2: Create `tests/test_case.gd` and `tests/run_tests.gd` headless test harness**
- [ ] **Step 3: Create `AGENT.md`, `AGENTS.md`, and `README.md` with Godot 4.7 best practices**
- [ ] **Step 4: Run headless test runner to verify Godot 4.7.2 project boots cleanly**
- [ ] **Step 5: Commit Task 1**

---

### Task 2: Pure Core Logic (`scripts/core/`) & Unit Tests

**Files:**
- Create: `scripts/core/game_state.gd`
- Create: `scripts/core/health_state.gd`
- Create: `scripts/core/weapon_state.gd`
- Create: `scripts/core/wave_manager.gd`
- Create: `scripts/core/audio_settings.gd`
- Create: `scripts/core/lore_catalog.gd`
- Create: `scripts/core/arena_layout_generator.gd`
- Create: `tests/test_game_state.gd`
- Create: `tests/test_health_state.gd`
- Create: `tests/test_weapon_state.gd`
- Create: `tests/test_wave_manager.gd`
- Create: `tests/test_audio_settings.gd`
- Create: `tests/test_lore_catalog.gd`
- Create: `tests/test_arena_layout_generator.gd`

- [ ] **Step 1: Write core unit test suites (`test_game_state.gd`, `test_health_state.gd`, `test_weapon_state.gd`, `test_wave_manager.gd`, `test_audio_settings.gd`, `test_lore_catalog.gd`, `test_arena_layout_generator.gd`)**
- [ ] **Step 2: Implement pure `RefCounted` core modules matching 100% of original TypeScript behavior**
- [ ] **Step 3: Run headless test suite and verify all core unit tests pass**
- [ ] **Step 4: Commit Task 2**

---

### Task 3: Arena Builder, Gothic Atmosphere, Materials & Brazier Collisions (`scripts/scene/arena_builder.gd`)

**Files:**
- Create: `scripts/scene/arena_builder.gd`
- Create: `tests/test_arena_builder.gd`

- [ ] **Step 1: Write `tests/test_arena_builder.gd` verifying brazier collisions, dynamic layout rebuilds, and nearest-neighbor materials**
- [ ] **Step 2: Implement `scripts/scene/arena_builder.gd` (overcast ash-grey exponential fog, directional shadow light, 100x100m floor, 4 parapets with crooked spikes, invisible boundary walls, megaliths with chipped caps/rubble/iron bands, barricades with iron caps/stepping fragments, and 6 tripod braziers with `OmniLight3D` and resanctification)**
- [ ] **Step 3: Run headless test suite to verify `test_arena_builder.gd` passes**
- [ ] **Step 4: Commit Task 3**

---

### Task 4: Player Controller & Weapon Controller (`scripts/scene/player_controller.gd`, `scripts/scene/weapon_controller.gd`, `scenes/Player.tscn`)

**Files:**
- Create: `scripts/scene/player_controller.gd`
- Create: `scripts/scene/weapon_controller.gd`
- Create: `scenes/Player.tscn`
- Create: `tests/test_player_controller.gd`

- [ ] **Step 1: Write `tests/test_player_controller.gd` testing jump velocity, apex (>2.0m), landing at y=0.9, no double-jump, ±49.2m arena clamp, camera far plane (49.2m), and brazier collision**
- [ ] **Step 2: Implement `player_controller.gd`, `weapon_controller.gd` (9-part blackened-iron carbine viewmodel, muzzle flash cone, `OmniLight3D` burst, 3D tracer line, center-screen raycast), and `scenes/Player.tscn`**
- [ ] **Step 3: Run headless test suite to verify player and brazier interaction tests pass**
- [ ] **Step 4: Commit Task 4**

---

### Task 5: Enemy Controller & 21-Part Gothic Fiend Physics (`scripts/scene/enemy_controller.gd`)

**Files:**
- Create: `scripts/scene/enemy_controller.gd`
- Create: `tests/test_enemy_controller.gd`

- [ ] **Step 1: Write `tests/test_enemy_controller.gd` testing 3D contact damage (perched vs grounded), vertical pursuit leap, obstacle vault leap, ±49.2m arena clamp, fog spawn point distance (>=22m), non-lethal stagger, and fatal ragdoll knockdown**
- [ ] **Step 2: Implement `scripts/scene/enemy_controller.gd` with invisible `RigidBody3D` capsule, 21 articulated low-poly child meshes with raycast hitboxes, upright angular lock while alive, and rotational topple impulse on death**
- [ ] **Step 3: Run headless test suite to verify `test_enemy_controller.gd` passes**
- [ ] **Step 4: Commit Task 5**

---

### Task 6: Audio Manager, HUD Scene & HUD Controller (`scripts/scene/audio_manager.gd`, `scenes/HUD.tscn`, `scripts/ui/hud_controller.gd`)

**Files:**
- Create: `scripts/scene/audio_manager.gd`
- Create: `scripts/ui/hud_controller.gd`
- Create: `scenes/HUD.tscn`
- Create: `tests/test_hud_controller_lore.gd`

- [ ] **Step 1: Write `tests/test_hud_controller_lore.gd` testing start menu subtitle, game over lore subtitle, wave whisper visibility during breather vs combat, Chronicle modal open/close/Escape, crosshair pulse, and audio sliders**
- [ ] **Step 2: Implement `audio_manager.gd`, `hud_controller.gd`, and `scenes/HUD.tscn`**
- [ ] **Step 3: Run headless test suite to verify `test_hud_controller_lore.gd` passes**
- [ ] **Step 4: Commit Task 6**

---

### Task 7: Main Game Orchestrator (`scenes/Main.tscn`, `scripts/main.gd`), Full Integration Test & GitHub Repo Push

**Files:**
- Create: `scripts/main.gd`
- Create: `scenes/Main.tscn`
- Create: `tests/test_main_integration.gd`
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Implement `scripts/main.gd` and `scenes/Main.tscn` wiring `ArenaBuilder`, `PlayerController`, `WeaponController`, `EnemyController`, `AudioManager`, `HUDController`, and all core states**
- [ ] **Step 2: Write `tests/test_main_integration.gd` verifying full match lifecycle (MENU -> start match -> fire weapon -> hit/kill enemy -> wave progression -> pause/resume -> game over)**
- [ ] **Step 3: Run full headless test suite and full scene boot check with Godot 4.7.2**
- [ ] **Step 4: Create GitHub repository `BuneZT/iron-pit-godot` and push `main` branch**
