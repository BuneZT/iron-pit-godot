# Iron Pit — Enemy Radar & Early-3D 90s/2000s Pixelated UI Revamp Design

## 1. Intent & Aesthetic Goals

Revamp Iron Pit's interface to replace its flat modern web-card look and unstyled default Godot widgets with a gritty, pixelated early-3D 90s/2000s FPS aesthetic inspired by *Quake* (1996), *Dark Forces II: Jedi Knight* (1997), and *Unreal* (1998), while adding a tactical proximity radar to give spatial awareness inside the arena's dense exponential fog.

### Visual Pillars
- **Pixelated & Dirty Gunmetal Iron:** Bayer-dithered dark charcoal gunmetal plates with soot grime, fine metallic scratches, chipped 1–2px pixel bevels, and dark oil-ringed rivets—minimal orange rust (matching `assets/textures/rusted_iron.png`).
- **Minimalist Floating Combat HUD:** Keep the 3D arena unobstructed. Bottom-left Vitals & Ammo and top-center Wave readout float cleanly with **no panel backgrounds**, relying on crisp blocky pixel glyphs, chunky icons, slim segmented pixel bars, and hard black pixel shadows for readability over fog or brazier light.
- **Tactile Hardware Radar:** Circular weathered gunmetal iron proximity scanner in the **bottom-right** corner with an **Ember/Amber** CRT scope dish, dirty scanlines, glass scratch, stepped-pixel rings/sweep, crimson fiend blips, and amber rim ticks for out-of-range foes. No `"SCAN 38M"` text label.
- **Cohesive Grimy Modals:** Start, Pause, Game Over, Settings, and Chronicle modals share the exact same dithered gunmetal 9-slice plates, riveted corners, recessed dark wells, custom beveled iron buttons (normal/hover/pressed), pixelated sliders, and crisp retro bitmap font.

### Non-Goals & Anti-Goals
- No full-arena minimap showing walls/megaliths/barricades (preserves fog tension).
- No runtime procedural `ImageTexture` generation (`AGENTS.md` §3.6).
- No heavy orange rust splotches covering the UI plates.
- No regressions to existing `HUDController` public node references, signals, or automated tests.

---

## 2. Chosen Approach

**Approach 1 — Pure-Core Radar Math + Static Pixel-Art UI Assets + Pixel-Snapped Radar Control**

### Alternatives Considered
- *Approach 1 (Chosen):* Pure `RefCounted` `RadarProjector` in `scripts/core/` + static pre-authored nearest-neighbor PNG UI assets & bitmap `.fnt` font in `assets/` + lightweight `RadarWidget` Control using integer-snapped `_draw()` + `StyleBoxTexture` 9-slice modals. Delivers authentic pixel grit, crisp modal readability/input, zero extra viewport passes, and zero per-frame allocations.
- *Approach 2 (Rejected):* Low-res `426×240` `SubViewport` HUD buffer scaled nearest-neighbor. Complicates Settings/Chronicle mouse input, cramps longer Chronicle text, and adds an extra fullscreen render pass.
- *Approach 3 (Rejected):* Pure `StyleBoxFlat` with no new textures or font. Cannot achieve Bayer-dithered grime, scratches, rivets, or authentic pixel lettering.

---

## 3. Functional & Visual Specification

### 3.1 Enemy Proximity Radar (`RadarProjector` + `RadarWidget`)
- **Placement:** Bottom-right corner (`152×152 px` widget anchored bottom-right with `18px` margin).
- **Orientation:** Player-centered, rotates with player camera `yaw` so straight up on the radar is always the player's current forward look direction (`(sin(yaw), cos(yaw))` in Iron Pit's right-handed Y-up coordinate space where `right = (-cos(yaw), sin(yaw))`).
  - Forward component (`ahead`): `dx * sin(yaw) + dz * cos(yaw)` → maps to `-Y` on screen (up).
  - Right component (`right`): `dx * (-cos(yaw)) + dz * sin(yaw)` → maps to `+X` on screen (right).
- **Scan Range:** `38.0m` (matches Iron Pit's dense fog visibility envelope).
- **Tracked Targets:** Living enemies only (`enemy.state == "ALIVE"`). Knocked-down/ragdoll corpses disappear from the radar immediately upon death.
- **In-Range Blips (`dist <= 38.0m`):** Drawn as crisp pixel-snapped square crimson markers (`#ef4444` core, `#fecaca` hot pixel center, `#450a0a` dark outline) scaled proportionally inside the inner dish radius. Close threats (`dist <= 10.0m`) subtly pulse brightness.
- **Out-of-Range Rim Ticks (`dist > 38.0m`):** Clamped onto the inner perimeter ring (`r = 0.94`) as compact amber/gold (`#f59e0b` / `#fef3c7`) pixel markers so players never lose the final straggler in a wave.
- **Dish Visuals:** Static pre-authored nearest-neighbor `radar_bezel.png` (weathered gunmetal circular frame, 4 bolts, dark Ember/Amber recessed dish with subtle scanlines & glass scratch) + pixel-snapped dynamic `_draw()` pass for subtle forward FOV wedge, stepped concentric range rings, dotted axes, slowly rotating ember sweep line, center player chevron, and enemy blips. Zero text badge below the radar.

### 3.2 Minimalist Floating In-Game HUD (`HUDController`)
- **Top-Center Wave Strip (No background box):**
  - Single compact horizontal line near top-center (`offset_top = 14px`): `WAVE 01 | HOSTILES 05 | KILLS 00` (switches to `STATUS PURGED` during wave breather), crisp pixel font with hard black shadow `(2, 2)` and a thin etched 2px dark/iron underline below.
  - `wave_whisper` breather lore banner sits cleanly directly beneath the top strip with a slim grimy iron accent frame when visible.
- **Bottom-Left Combined Vitals & Ammo (No background box):**
  - Anchored bottom-left (`offset_left = 20px`, `offset_bottom = -20px`), tightly stacked two-row layout:
    - **Row 1 (Health / Armor):** Static `icon_med_cross.png` (`9×9` pixel sprite displayed at `27×27` nearest) + chunky crimson HP readout (`health_text`, e.g. `100`) + slim 10-cell segmented crimson pixel health bar (`health_bar_fill` preserved for compatibility alongside crisp discrete pixel segments).
    - **Row 2 (Ammo / Carbine):** Static `icon_twin_shells.png` (`9×9` pixel sprite displayed at `27×27` nearest) + chunky amber ammo readout (`ammo_value`, e.g. `12`) + slim 12-pip brass shell bar.
    - **Reload / Low-Ammo Hint (`reload_hint`):** Hidden/empty when healthy (`ammo > 3` and not reloading) to keep the HUD minimalist; shows sharp blinking amber/crimson text (`LOW AMMO [R]`, `PRESS [R] TO RELOAD`, or `RELOADING...`) only when actionable.
- **Crosshair & Blood Vignette:** Keep Iron Pit's chunky pixel crosshair (adding a 1px dark outline behind the cross arms for contrast over bright fog) and blood-red edge damage vignette.

### 3.3 Grimy Gunmetal Modals & Controls
- **Static Pixel Assets (`assets/textures/ui/`):**
  - `iron_plate_9slice.png` — Bayer-dithered dark gunmetal iron plate with subtle scratches, chipped bevels, and 4 oil-ringed corner rivets.
  - `iron_recess_9slice.png` — Deep recessed charcoal control well with inset dark/light 1px pixel bevels.
  - `btn_iron_normal.png`, `btn_iron_hover.png`, `btn_iron_pressed.png` — Secondary iron buttons with bevel highlight/inset press states.
  - `btn_ember_normal.png`, `btn_ember_hover.png`, `btn_ember_pressed.png` — Primary ember-accented iron action button (`ENTER THE PIT` / `RESUME FIGHT` / `RETURN TO PIT`).
  - `slider_grabber.png`, `slider_grabber_hi.png` — Chunky beveled iron slider thumb.
  - `radar_bezel.png` — Circular gunmetal radar frame & dark Ember/Amber dirty glass dish.
  - `icon_med_cross.png`, `icon_twin_shells.png` — Crisp 9×9 pixel HUD icons.
- **Static Pixel Bitmap Font (`assets/fonts/iron_pixel.fnt` + `iron_pixel.png`):**
  - Pre-authored crisp pixel-art BMFont covering printable ASCII (`32–126`) plus `×`, `—`, `∞`, and `·`, loaded as a Godot `FontFile` with nearest-neighbor scaling and hard black pixel shadows.
- **Compatibility Contract:** Preserve all existing public variables, signals, callbacks, and node names tested by `test_hud_controller_lore.gd`, `test_hud_controller_settings.gd`, and `test_main_integration.gd` (`cardVBox`, `settings_button`, `chronicle_button`, `modal_overlay`, `modal_title`, `modal_subtitle`, `action_button`, `settings_modal`, `settings_card`, `chronicle_modal`, `wave_whisper`, `wave_whisper_label`, `render_scale_slider`, `graphics_quality_button`, `health_text`, `health_bar_fill`, `ammo_value`, `reload_hint`, etc.).

---

## 4. Architecture & Data Flow

1. `scripts/core/radar_projector.gd` (`class_name RadarProjector extends RefCounted`):
   - `static func project_blips(player_pos: Vector3, player_yaw: float, enemy_positions: Array[Vector3], scan_radius: float = 38.0, out_blips: Array[Dictionary] = []) -> Array[Dictionary]`
   - Reuses pre-allocated blip dictionaries/arrays when passed `out_blips` or writes packed arrays to avoid per-frame GC churn.
   - Actually even cleaner & zero-allocation: returns/fills `PackedVector3Array` (`x = norm_x`, `y = norm_y`, `z = dist_ratio`, where `z > 1.0` indicates clamped out-of-range rim tick!). Zero Dictionary allocations per frame!
2. `scripts/main.gd` (`GameApp`):
   - Pre-allocates `_radar_enemy_positions: PackedVector3Array` and `_radar_blips: PackedVector3Array` on `GameApp`.
   - In `sync_hud()`, collects `root.position` for every `ALIVE` enemy in `enemy_controller.enemies`, projects via `RadarProjector.project_into(...)`, and passes `_radar_blips` inside `_hud_snapshot["radar_blips"]` (and hides radar when `status != "PLAYING"`).
3. `scripts/ui/radar_widget.gd` (`class_name RadarWidget extends Control`):
   - Renders `radar_bezel.png` and pixel-snapped `_draw()` sweep/rings/blips/rim-ticks/player-chevron.
4. `scripts/ui/hud_controller.gd` (`class_name HUDController extends CanvasLayer`):
   - Applies shared pixel font + `StyleBoxTexture` retro theme across HUD & modals, wires `radar_widget` into bottom-right, implements floating bottom-left Armor+Ammo and top-center Wave strip.

---

## 5. Verification Plan

- Add `tests/test_radar_projector.gd` covering forward/behind/left/right projection under multiple `yaw` angles, exact `scan_radius` normalization, out-of-range rim clamping, and empty input.
- Add `tests/test_hud_controller_radar.gd` verifying `RadarWidget` exists on `HUDController`, updates blip state from `update_hud`, hides/clears cleanly when not playing, and verifies all static UI textures & pixel font load with zero errors.
- Verify all existing 87 tests plus all new tests pass via `godot --headless --path . -s res://tests/run_tests.gd` with exit code `0` and zero orphan nodes/leaks.
