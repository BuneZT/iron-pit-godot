# Settings Submenu & 3D Resolution Scale Slider Design

## 1. Overview
Iron Pit currently embeds audio sliders directly on the main pause/start modal overlay, cluttering the primary match card. This feature extracts all configuration into a dedicated gothic iron & stone **Settings Submenu** modal accessible via a `"SETTINGS"` button, and introduces a **3D Render Scale Slider** (50% to 100%) that dynamically adjusts internal 3D viewport rendering resolution while keeping the 2D retro HUD crisp and sharp.

---

## 2. Architecture & Data Flow

```
                      +---------------------------------------+
                      |       scripts/core/game_settings.gd   |
                      |  - master_volume, music_volume, etc.  |
                      |  - render_scale (0.50 to 1.00)        |
                      |  - serialize() / deserialize()        |
                      +-------------------+-------------------+
                                          |
                                          | (data snapshot)
                                          v
+-----------------------------+       +-----------------------------+
|        scripts/main.gd      | <---> | scripts/ui/hud_controller.gd|
|  - loads/saves settings     |       |  - Main Modal Card          |
|  - sets scaling_3d_scale    |       |    - Action Button          |
|  - sets audio bus volumes   |       |    - [SETTINGS] Button      |
+-----------------------------+       |    - [THE CHRONICLE] Button |
                                      |                             |
                                      |  - Settings Submenu Modal   |
                                      |    - VIDEO: 3D Render Scale |
                                      |    - AUDIO: Master/Music/SFX|
                                      |    - Mute Toggle            |
                                      |    - [BACK] / Close / ESC   |
                                      +-----------------------------+
```

---

## 3. Component Specifications

### 3.1 Core State: `scripts/core/game_settings.gd`
* **Type:** Pure `RefCounted` class with zero Node dependencies (`AGENTS.md` section 3.1).
* **Fields:**
  * `master_volume: float = 0.8` (clamped 0.0 – 1.0)
  * `music_volume: float = 0.6` (clamped 0.0 – 1.0)
  * `sfx_volume: float = 0.8` (clamped 0.0 – 1.0)
  * `is_muted: bool = false`
  * `render_scale: float = 1.0` (clamped 0.50 – 1.00, step 0.05)
* **Methods:**
  * `set_render_scale(val: float) -> void`
  * `set_master_volume(val: float) -> void`
  * `set_music_volume(val: float) -> void`
  * `set_sfx_volume(val: float) -> void`
  * `toggle_mute() -> bool`
  * `get_effective_music_volume() -> float`
  * `get_effective_sfx_volume(multiplier: float = 1.0) -> float`
  * `calculate_distance_volume(dist: float, max_radius: float, base_volume: float = 1.0) -> float`
  * `serialize() -> String`: JSON string containing audio and video values.
  * `static func deserialize(json_str: String) -> GameSettings`: Backward-compatible deserialization supporting both legacy audio-only files (`iron_pit_audio_settings.json`) and unified settings (`iron_pit_settings.json`).
* **Backward Compatibility:** `scripts/core/audio_settings.gd` will inherit from or wrap `GameSettings` to guarantee 100% backward compatibility with all existing tests.

### 3.2 UI Controller: `scripts/ui/hud_controller.gd`
* **Removal from Main Modal:** Remove the audio settings container from `modal_card` to streamline the intro/pause/game-over screen.
* **New Navigation Button:** Add a `"SETTINGS"` button on `modal_card` placed between the primary action button (`ENTER THE PIT` / `RESUME FIGHT` / `RETURN TO PIT`) and `THE CHRONICLE`.
* **New Settings Modal Overlay (`settings_modal: Control`):**
  * Full-screen semi-transparent backdrop (`Color(0.0, 0.0, 0.0, 0.88)`). Clicking on the backdrop dismisses the settings menu.
  * Centered card container (width 540px) styled with `_make_iron_stylebox` (dark stone background `#161413`, amber border `#d97706`).
  * **Header:** Title `"SETTINGS"` and a close button `"×"`.
  * **Video Settings Panel:**
    * Label: `"VIDEO CONFIGURATION"`
    * Slider: `"3D RENDER SCALE"` (range 50.0 to 100.0, step 5.0, initial 100.0).
    * Value indicator: e.g. `"100% [1280×720]"` or `"50% [640×360]"`.
  * **Audio Settings Panel:**
    * Label: `"AUDIO CONFIGURATION"`
    * Master volume slider (0% – 100%).
    * Music volume slider (0% – 100%).
    * SFX volume slider (0% – 100%).
    * `"MUTE AUDIO"` / `"UNMUTE AUDIO"` button.
  * **Footer:**
    * `"BACK TO MENU"` / `"BACK"` button.
    * Caption: `"PRESS [ESC] OR CLICK TO RETURN"`.
* **Keyboard & Dismissal Handling:**
  * When `settings_modal.visible == true`:
    * `handle_escape_key() -> bool` closes the settings modal and returns `true`, preventing unintended game unpausing.
    * Key event `KEY_ESCAPE` in `_input()` closes the settings modal.

### 3.3 Engine Integration: `scripts/main.gd`
* **Config Persistence:**
  * File path: `user://iron_pit_settings.json` (with automatic fallback to `user://iron_pit_audio_settings.json` if the new file does not exist).
* **Viewport 3D Scaling Application:**
  * `_apply_video_settings()` sets `get_viewport().scaling_3d_scale = settings.render_scale`.
* **Callbacks passed to `HUDController`:**
  * `on_render_scale_change: Callable` -> updates `settings.set_render_scale(val)`, calls `_apply_video_settings()`, saves settings.
  * `on_master_volume_change`, `on_music_volume_change`, `on_sfx_volume_change`, `on_toggle_mute` -> updates audio levels and saves settings.
* **Syncing Settings:**
  * `hud.sync_settings(settings.data)` updates all sliders and labels without emitting redundant feedback signals.

---

## 4. Testing & Verification

1. **Unit Tests (`tests/test_game_settings.gd`):**
   * Default values: volume at 0.8/0.6/0.8, muted false, render scale at 1.0 (100%).
   * Range clamping: render scale clamped between 0.50 and 1.00; volume clamped between 0.0 and 1.0.
   * Backward compatibility: Deserializing legacy audio JSON correctly loads audio while keeping render scale at default 1.0.
   * Full serialization and deserialization roundtrip.
2. **HUD Tests (`tests/test_hud_controller_settings.gd`):**
   * Settings button opens `settings_modal`.
   * Close button and Back button close `settings_modal`.
   * Pressing `[ESC]` or calling `handle_escape_key()` closes `settings_modal`.
   * Moving render scale slider triggers `on_render_scale_change`.
   * Moving audio sliders and clicking mute triggers corresponding callbacks.
3. **Integration Test (`tests/test_main_integration.gd`):**
   * Verifies `scaling_3d_scale` on viewport matches configured setting.
4. **Full Regression Test:**
   * Run all tests headlessly via Godot 4.7.2 console:
     `& "C:\Users\marci\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "C:\Users\marci\Documents\game_dev\iron-pit-godot" -s res://tests/run_tests.gd`
   * Confirm 0 errors, 0 leaked resources, 100% PASS.
