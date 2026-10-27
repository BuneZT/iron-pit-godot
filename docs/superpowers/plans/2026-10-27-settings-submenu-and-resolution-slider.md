# Settings Submenu & 3D Resolution Scale Slider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a dedicated 90s gothic Settings Submenu modal in HUDController, relocate audio settings into it, and add a 3D Render Scale slider (50% to 100%) backed by a pure RefCounted `GameSettings` core model.

**Architecture:** A pure `RefCounted` `GameSettings` model in `scripts/core/game_settings.gd` handles persistence, clamping, and state for both video and audio. `HUDController` in `scripts/ui/` exposes a `"SETTINGS"` button on the main modal and manages a separate `settings_modal` overlay with sliders and keyboard/mouse dismissal. `GameApp` in `scripts/main.gd` connects the callbacks, applies `get_viewport().scaling_3d_scale`, and persists settings.

**Tech Stack:** Godot 4.7.2 Forward+, GDScript 2.0 (strictly typed), Jolt Physics 3D, headless SceneTree test runner.

## Global Constraints

- GDScript 2.0 strict static typing on all variables, parameters, and return types.
- Pure RefCounted classes in `scripts/core/` with zero Node or SceneTree dependencies (`AGENTS.md` 3.1).
- 90s gothic retro aesthetic using `_make_iron_stylebox` (dark stone `#161413`, amber `#d97706`).
- All headless tests run via `& "C:\Users\marci\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "C:\Users\marci\Documents\game_dev\iron-pit-godot" -s res://tests/run_tests.gd` and must pass with 0 errors and 0 leaks.

---

### Task 1: Core `GameSettings` Model & Backward Compatibility

**Files:**
- Create: `scripts/core/game_settings.gd`
- Modify: `scripts/core/audio_settings.gd`
- Create: `tests/test_game_settings.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Produces: `GameSettings` with:
  - `var master_volume: float`
  - `var music_volume: float`
  - `var sfx_volume: float`
  - `var is_muted: bool`
  - `var render_scale: float` (0.50 to 1.00)
  - `func set_render_scale(val: float) -> void`
  - `func set_master_volume(val: float) -> void`
  - `func set_music_volume(val: float) -> void`
  - `func set_sfx_volume(val: float) -> void`
  - `func toggle_mute() -> bool`
  - `func get_effective_music_volume() -> float`
  - `func get_effective_sfx_volume(multiplier: float = 1.0) -> float`
  - `func calculate_distance_volume(dist: float, max_radius: float, base_volume: float = 1.0) -> float`
  - `func serialize() -> String`
  - `static func deserialize(json_str: String) -> GameSettings`

- [ ] **Step 1: Write the failing unit tests for `GameSettings`**
Create `tests/test_game_settings.gd` verifying defaults, volume clamping (0..1), render scale clamping (0.5..1.0), serialization, and deserialization from both legacy audio JSON and unified JSON.

- [ ] **Step 2: Run test runner to verify failure**
Run headless test suite. Expected: FAIL because `GameSettings` class does not exist yet.

- [ ] **Step 3: Implement `GameSettings` in `scripts/core/game_settings.gd`**
Implement pure `RefCounted` `GameSettings` with static typing and all required methods.

- [ ] **Step 4: Update `scripts/core/audio_settings.gd` to inherit from `GameSettings`**
Ensure `AudioSettings extends GameSettings` maintains 100% backward compatibility for all existing tests and code.

- [ ] **Step 5: Run tests to verify all pass**
Run headless test suite and confirm `test_game_settings.gd` and `test_audio_settings.gd` both pass.

- [ ] **Step 6: Commit**
`git add scripts/core/game_settings.gd scripts/core/audio_settings.gd tests/test_game_settings.gd tests/run_tests.gd`
`git commit -m "feat(core): implement pure RefCounted GameSettings and test suite"`

---

### Task 2: UI Settings Submenu in `HUDController`

**Files:**
- Modify: `scripts/ui/hud_controller.gd`
- Create: `tests/test_hud_controller_settings.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `GameSettings.data` Dictionary
- Produces in `HUDController`:
  - `var settings_button: Button`
  - `var settings_modal: Control`
  - `var settings_close_button: Button`
  - `var settings_back_button: Button`
  - `var render_scale_slider: HSlider`
  - `var render_scale_value: Label`
  - `var on_render_scale_change: Callable`
  - `func sync_settings(data: Dictionary) -> void`
  - `func handle_escape_key() -> bool` (updated to close settings modal first)

- [ ] **Step 1: Write the failing tests for HUD Settings Submenu**
Create `tests/test_hud_controller_settings.gd` testing:
  - Settings button exists on modal card.
  - Clicking Settings button opens `settings_modal`.
  - Settings modal contains video render scale slider and audio sliders.
  - Moving render scale slider fires `on_render_scale_change`.
  - Clicking Close button or Back button closes `settings_modal`.
  - Pressing `[ESC]` or calling `handle_escape_key()` closes `settings_modal` and returns `true`.

- [ ] **Step 2: Run test runner to verify failure**
Run headless test suite. Expected: FAIL because `settings_modal` does not exist yet.

- [ ] **Step 3: Implement Settings Submenu in `scripts/ui/hud_controller.gd`**
- Remove audio panel from the primary `modal_card`.
- Add `settings_button` to `modal_card` between `action_button` and `chronicle_button`.
- Construct `settings_modal` with:
  - Video section: "3D RENDER SCALE" slider (50.0 to 100.0, step 5.0) with resolution label display (e.g. "100% [1280×720]").
  - Audio section: Master, Music, SFX sliders + Mute button.
  - Back button and Close "×" button.
- Update `handle_escape_key()` and `_input()` to handle closing `settings_modal`.
- Add `sync_settings(data: Dictionary)` to update all sliders without firing signals.

- [ ] **Step 4: Run tests to verify they pass**
Run headless test runner to verify `test_hud_controller_settings.gd` and `test_hud_controller_lore.gd` pass.

- [ ] **Step 5: Commit**
`git add scripts/ui/hud_controller.gd tests/test_hud_controller_settings.gd tests/run_tests.gd`
`git commit -m "feat(ui): add dedicated settings submenu with resolution slider to HUD"`

---

### Task 3: GameApp Integration & Persistence

**Files:**
- Modify: `scripts/main.gd`
- Modify: `tests/test_main_integration.gd`

**Interfaces:**
- Consumes: `GameSettings`, `HUDController`, `get_viewport().scaling_3d_scale`
- Persists to: `user://iron_pit_settings.json` (fallback load from `user://iron_pit_audio_settings.json`)

- [ ] **Step 1: Write integration test assertions for settings and viewport scale**
Update `tests/test_main_integration.gd` to verify viewport scaling matches `render_scale` when settings are applied or changed.

- [ ] **Step 2: Run test runner to verify failure/baseline**
Run headless test suite.

- [ ] **Step 3: Update `scripts/main.gd`**
- Replace audio-only settings file path with unified `SETTINGS_PATH = "user://iron_pit_settings.json"`.
- Implement `_load_settings() -> GameSettings` checking both paths.
- Implement `_apply_video_settings()` setting `get_viewport().scaling_3d_scale = settings.render_scale`.
- Pass `on_render_scale_change` callback to `HUDController`.
- Call `hud.sync_settings(settings.data)` on ready and settings change.

- [ ] **Step 4: Run tests to verify all pass**
Run headless test suite to verify `test_main_integration.gd` passes.

- [ ] **Step 5: Commit**
`git add scripts/main.gd tests/test_main_integration.gd`
`git commit -m "feat(main): wire settings submenu, viewport 3D scaling, and unified persistence"`

---

### Task 4: Complete Verification & Polish

**Files:**
- All touched files

- [ ] **Step 1: Run complete test suite headlessly**
Run full test suite via Godot 4.7.2 console.
Expected: 100% pass, 0 failures, 0 leaked nodes or RIDs.

- [ ] **Step 2: Verify git status and clean working tree**
Verify no leftover temporary files or uncommitted changes.
