# IRON PIT — 90s Gothic Arena Survival FPS (Godot 4.7 Edition)

A dark, atmospheric wave-based 3D arena survival First-Person Shooter inspired by **Quake 1** and **Dark Forces**, ported 1:1 to **Godot 4.7.2-stable** (`Forward+` renderer, **Jolt Physics 3D**, and strictly typed **GDScript 2.0**).

---

## Aesthetic & Visual Features

- **Bleak Overcast Daylight & Heavy Fog**:
  - Open-air desolate ruins shrouded under an oppressive ash-grey overcast sky (`Color(0.24, 0.25, 0.27)`).
  - Deep exponential distance fog calibrated to seamlessly match the clear color, creating an infinite void where gothic ruins and approaching enemies loom out of the murky mist.
- **Gritty 90s Retro Textures & Point Sampling**:
  - Static 128×128 pixel textures crafted with a **4×4 Bayer matrix dither** and discrete palette quantization (pitch-black mortar trenches, chipped stone bevels, water runoff streaks, and oxidized pitted rust).
  - Enforces `BaseMaterial3D.TEXTURE_FILTER_NEAREST` point sampling across all geometry to eliminate modern bilinear blur and deliver authentic crunchy retro pixel grit.
- **Weathered Low-Poly Architecture with Imperfections**:
  - `100m × 100m` open flagstone arena enclosed by low crumbling stone parapets topped with crooked, multi-axis bent rusted iron spikes.
  - Fractured basalt megaliths with slanted chipped stone caps, crooked iron reinforcement bands, and fallen rubble blocks.
  - `6` smoking gothic iron fire-braziers distributed across inner, mid-field, and outer perimeter sectors with dynamic, organic flame-flickering `OmniLight3D` nodes that shift toward cleansed gold/white as waves progress.
- **Quake 1 Gothic Fiends (21-Part Grotesque Low-Poly Anatomy)**:
  - Invisible `RigidBody3D` physics capsule proxy paired with a 21-part articulated humanoid mesh hierarchy (angled greaves, pointed iron sabatons, armored vertebrae midsection, and forward-pitched hunched ribcage).
  - Sunken skull helm with asymmetrical horns (long curved left horn, shattered right stump) and glowing crimson eye visor.
  - Forward-reaching clawed arms with iron talons aggressively chasing and leaping toward the player.
- **Blackened-Iron Blunderbuss / Nailgun Carbine**:
  - 9-part hammered-iron viewmodel receiver with welded side plates, brass heat shroud, cocking lever, aged oak grip, and crooked front sight.
  - Dynamic muzzle flash cone, 3D shot tracer line, and a 50ms dynamic `OmniLight3D` that illuminates nearby stone pillars and ground in fiery amber light with every shot.
- **90s Beveled Iron & Stone HUD**:
  - Chiseled dark iron borders with 3D metallic bevels (`StyleBoxFlat`), retro monospaced typography, ambient wave whispers, interactive Chronicle grimoire modal, audio mixer sliders, and a classic Quake chunky dot-and-brackets crosshair.

---

## Gameplay & Kinetic Physics (Jolt Physics 3D)

- **Heavy Kinetic Gunplay**:
  - Center-screen hitscan raycasts (`PhysicsRayQueryParameters3D`) with visual recoil kickback, dynamic tracer lines, and shot impact lighting.
  - **Non-Lethal Hit Stagger**: Non-fatal shots apply a physical impulse (`J = 11.5 N·s` horizontal + `2.6 N·s` vertical) that knocks living enemies backward and flashes their armor white.
  - **Fatal Knockdown Ragdolls**: Lethal hits unlock all 3 rotational axes on the `RigidBody3D`, lower damping, and apply an off-center impulse (`J = 21.0 N·s` horizontal + `6.5 N·s` vertical) at the exact hit point with spin torque (`7.5 rad/s`), causing the fiend to physically flip and tumble across the flagstones.
- **Escalating Wave Survival & Mor'gath's Curse**:
  - Wave formula scales enemy counts ($3 + 2N$) with staggered fog spawns, speed/HP scaling, inter-wave breather whispers, and the Wave 10 Curse Broken milestone.
- **Real CC0 Audio Assets**:
  - Preloaded sound effects in `res://assets/audio/` (`gunshot.ogg`, `dryfire.ogg`, `reload.ogg`, `hit.ogg`, `knockdown.ogg`, `hurt.ogg`, `enemy_groan.ogg`, `footstep.ogg`, `wave_bell.wav`, `music_ambient.ogg`).

---

## Controls

| Input | Action |
| :--- | :--- |
| `W / A / S / D` or `Arrow Keys` | Move |
| `Shift` | Sprint |
| `Space` | Jump |
| `Mouse` (Captured) | Aim / Look |
| `Left Mouse Button` | Fire Weapon |
| `R` | Reload (`12` rounds) |
| `ESC` | Pause / Unlock Cursor / Close Chronicle |

---

## Running & Testing (Godot 4.7.2)

```powershell
# Import resources and run the full headless unit & integration test suite
& "C:\Users\marci\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s res://tests/run_tests.gd

# Launch the interactive game
& "C:\Users\marci\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path .
```
