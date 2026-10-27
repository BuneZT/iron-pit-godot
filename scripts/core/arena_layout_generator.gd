class_name ArenaLayoutGenerator
extends RefCounted

const SAFE_RADIUS: float = 10.0
const ARENA_BOUNDS: float = 42.0
const MIN_OBSTACLE_SPACING: float = 6.5


class Mulberry32:
	extends RefCounted
	var _s: int

	func _init(seed_val: int) -> void:
		_s = ((seed_val & 0xFFFFFFFF) + 0x6D2B79F5) & 0xFFFFFFFF

	func next() -> float:
		_s = ((_s ^ (_s >> 15)) * (_s | 1)) & 0xFFFFFFFF
		var prod: int = ((_s ^ (_s >> 7)) * (_s | 61)) & 0xFFFFFFFF
		_s = (_s ^ ((_s + prod) & 0xFFFFFFFF)) & 0xFFFFFFFF
		var out: int = (_s ^ (_s >> 14)) & 0xFFFFFFFF
		return float(out) / 4294967296.0


static func create_rng(seed_val: Variant = null) -> Callable:
	if seed_val == null:
		return func() -> float: return randf()
	var prng := Mulberry32.new(int(seed_val))
	return func() -> float: return prng.next()


static func generate(seed_val: Variant = null) -> Dictionary:
	var rng: Callable = create_rng(seed_val)
	var megaliths: Array[Dictionary] = []
	var barricades: Array[Dictionary] = []
	var braziers: Array[Dictionary] = []

	var quadrants: Array[Dictionary] = [
		{"sign_x": 1.0, "sign_z": 1.0, "base_angle": PI / 4.0},
		{"sign_x": -1.0, "sign_z": 1.0, "base_angle": (3.0 * PI) / 4.0},
		{"sign_x": -1.0, "sign_z": -1.0, "base_angle": (5.0 * PI) / 4.0},
		{"sign_x": 1.0, "sign_z": -1.0, "base_angle": (7.0 * PI) / 4.0},
	]

	# 1. Generate Gothic Megaliths (4-5 total)
	for idx in range(quadrants.size()):
		var q: Dictionary = quadrants[idx]
		var is_outer: bool = (idx % 2 == 1)
		var mx: float = 0.0
		var mz: float = 0.0
		if is_outer:
			mx = float(q["sign_x"]) * (27.0 + float(rng.call()) * 8.0)
			mz = float(q["sign_z"]) * (27.0 + float(rng.call()) * 8.0)
		else:
			mx = float(q["sign_x"]) * (17.0 + float(rng.call()) * 7.0)
			mz = float(q["sign_z"]) * (17.0 + float(rng.call()) * 7.0)

		var w: float = 3.5 + float(rng.call()) * 0.5
		var d: float = 3.5 + float(rng.call()) * 0.5
		var h: float = 4.4 + float(rng.call()) * 0.8

		megaliths.append({
			"id": "megalith_%d" % idx,
			"type": "MEGALITH",
			"x": mx,
			"z": mz,
			"width": w,
			"height": h,
			"depth": d,
			"rotation_y": (float(rng.call()) - 0.5) * 0.3,
			"cap_angle": float(rng.call()) * PI * 2.0,
			"rubble_offset": {
				"x": (1.0 if float(rng.call()) > 0.5 else -1.0) * 2.2,
				"z": (1.0 if float(rng.call()) > 0.5 else -1.0) * 2.1,
			}
		})

	# Optional 5th outer megalith
	var extra_q: Dictionary = quadrants[int(floor(float(rng.call()) * 4.0))]
	var extra_mx: float = float(extra_q["sign_x"]) * (28.0 + float(rng.call()) * 7.0)
	var extra_mz: float = float(extra_q["sign_z"]) * (14.0 + float(rng.call()) * 10.0)
	var extra_collides: bool = false
	for m in megaliths:
		if Vector2(float(m["x"]) - extra_mx, float(m["z"]) - extra_mz).length() < MIN_OBSTACLE_SPACING:
			extra_collides = true
			break

	if not extra_collides:
		megaliths.append({
			"id": "megalith_4",
			"type": "MEGALITH",
			"x": extra_mx,
			"z": extra_mz,
			"width": 3.6,
			"height": 4.8,
			"depth": 3.6,
			"rotation_y": (float(rng.call()) - 0.5) * 0.25,
			"cap_angle": float(rng.call()) * PI * 2.0,
			"rubble_offset": {"x": 2.2, "z": -2.1}
		})

	# 2. Generate Crypt Barricades: 4 Mid-field + 4 Outer Wall-Flank (8 total)
	for idx in range(quadrants.size()):
		var q: Dictionary = quadrants[idx]
		var attempts: int = 0
		var mid_valid: bool = false
		var bx: float = 0.0
		var bz: float = 0.0
		var b_len: float = 5.8 + float(rng.call()) * 1.0
		var b_thick: float = 1.4
		var is_horiz: bool = float(rng.call()) > 0.5

		while attempts < 25 and not mid_valid:
			attempts += 1
			if attempts % 2 == 0:
				if is_horiz:
					bx = float(q["sign_x"]) * (10.0 + float(rng.call()) * 12.0)
					bz = float(q["sign_z"]) * (18.0 + float(rng.call()) * 8.0)
				else:
					bx = float(q["sign_x"]) * (18.0 + float(rng.call()) * 8.0)
					bz = float(q["sign_z"]) * (10.0 + float(rng.call()) * 12.0)
			else:
				bx = float(q["sign_x"]) * (13.0 + float(rng.call()) * 10.0)
				bz = float(q["sign_z"]) * (13.0 + float(rng.call()) * 10.0)

			var dist_center := Vector2(bx, bz).length()
			if dist_center < SAFE_RADIUS + 0.5:
				continue
			if absf(bx) > ARENA_BOUNDS or absf(bz) > ARENA_BOUNDS:
				continue

			var too_close := false
			for obs in megaliths:
				if Vector2(float(obs["x"]) - bx, float(obs["z"]) - bz).length() < MIN_OBSTACLE_SPACING:
					too_close = true
					break
			if not too_close:
				for obs in barricades:
					if Vector2(float(obs["x"]) - bx, float(obs["z"]) - bz).length() < MIN_OBSTACLE_SPACING:
						too_close = true
						break
			if not too_close:
				mid_valid = true

		if mid_valid:
			barricades.append({
				"id": "barricade_%d_mid" % idx,
				"type": "BARRICADE",
				"x": bx,
				"z": bz,
				"width": b_len if is_horiz else b_thick,
				"height": 1.9,
				"depth": b_thick if is_horiz else b_len,
				"rotation_y": (float(rng.call()) - 0.5) * 0.15,
			})

		# Outer Wall-Flank Barricade (30m - 40m)
		var outer_attempts: int = 0
		var outer_valid: bool = false
		var obx: float = 0.0
		var obz: float = 0.0
		var is_wall_along_x: bool = float(rng.call()) > 0.5

		while outer_attempts < 30 and not outer_valid:
			outer_attempts += 1
			if is_wall_along_x:
				obx = float(q["sign_x"]) * (16.0 + float(rng.call()) * 20.0)
				obz = float(q["sign_z"]) * (32.0 + float(rng.call()) * 8.0)
			else:
				obx = float(q["sign_x"]) * (32.0 + float(rng.call()) * 8.0)
				obz = float(q["sign_z"]) * (16.0 + float(rng.call()) * 20.0)

			if absf(obx) > ARENA_BOUNDS or absf(obz) > ARENA_BOUNDS:
				continue

			var too_close := false
			for obs in megaliths:
				if Vector2(float(obs["x"]) - obx, float(obs["z"]) - obz).length() < MIN_OBSTACLE_SPACING:
					too_close = true
					break
			if not too_close:
				for obs in barricades:
					if Vector2(float(obs["x"]) - obx, float(obs["z"]) - obz).length() < MIN_OBSTACLE_SPACING:
						too_close = true
						break
			if not too_close:
				outer_valid = true

		if outer_valid:
			barricades.append({
				"id": "barricade_%d_outer" % idx,
				"type": "BARRICADE",
				"x": obx,
				"z": obz,
				"width": 6.2 if is_wall_along_x else b_thick,
				"height": 1.9,
				"depth": b_thick if is_wall_along_x else 6.2,
				"rotation_y": (float(rng.call()) - 0.5) * 0.12,
			})

	# 3. Generate Braziers / Lamps (6 total: 2 Inner, 2 Mid, 2 Outer)
	var brazier_configs: Array[Dictionary] = [
		{"q": quadrants[0], "min_d": 12.0, "max_d": 17.0},
		{"q": quadrants[2], "min_d": 12.0, "max_d": 17.0},
		{"q": quadrants[1], "min_d": 21.0, "max_d": 28.0},
		{"q": quadrants[3], "min_d": 21.0, "max_d": 28.0},
		{"q": quadrants[0], "min_d": 32.0, "max_d": 39.0},
		{"q": quadrants[2], "min_d": 32.0, "max_d": 39.0},
	]

	for idx in range(brazier_configs.size()):
		var cfg: Dictionary = brazier_configs[idx]
		var q: Dictionary = cfg["q"]
		var min_d: float = float(cfg["min_d"])
		var max_d: float = float(cfg["max_d"])
		var b_x: float = 0.0
		var b_z: float = 0.0
		var valid: bool = false
		var attempts: int = 0

		while attempts < 35 and not valid:
			attempts += 1
			var angle: float = float(q["base_angle"]) + (float(rng.call()) - 0.5) * 0.7
			var dist: float = min_d + float(rng.call()) * (max_d - min_d)
			b_x = cos(angle) * dist
			b_z = sin(angle) * dist

			if absf(b_x) > ARENA_BOUNDS or absf(b_z) > ARENA_BOUNDS:
				continue

			var too_close := false
			for obs in megaliths:
				if Vector2(float(obs["x"]) - b_x, float(obs["z"]) - b_z).length() < 4.5:
					too_close = true
					break
			if not too_close:
				for obs in barricades:
					if Vector2(float(obs["x"]) - b_x, float(obs["z"]) - b_z).length() < 4.5:
						too_close = true
						break
			if not too_close:
				for obs in braziers:
					if Vector2(float(obs["x"]) - b_x, float(obs["z"]) - b_z).length() < 4.5:
						too_close = true
						break
			if not too_close:
				valid = true

		if not valid:
			b_x = float(q["sign_x"]) * ((min_d + max_d) / 2.0)
			b_z = float(q["sign_z"]) * ((min_d + max_d) / 2.0)

		braziers.append({
			"id": "brazier_%d" % idx,
			"x": b_x,
			"z": b_z,
		})

	return {
		"megaliths": megaliths,
		"barricades": barricades,
		"braziers": braziers,
		"safe_radius": SAFE_RADIUS,
		"arena_bounds": ARENA_BOUNDS,
	}


static func find_fog_spawn_point(player_pos: Vector2, layout: Dictionary, rng: Variant = null) -> Vector2:
	var rng_fn: Callable = rng if rng is Callable else func() -> float: return randf()
	var min_distance: float = 24.0
	var max_distance: float = 35.0
	var arena_bounds: float = float(layout.get("arena_bounds", ARENA_BOUNDS))
	var all_obstacles: Array = []
	all_obstacles.append_array(layout.get("megaliths", []))
	all_obstacles.append_array(layout.get("barricades", []))

	for i in range(35):
		var angle: float = float(rng_fn.call()) * PI * 2.0
		var player_dist_from_origin := player_pos.length()
		if player_dist_from_origin > 20.0:
			var center_angle := atan2(-player_pos.y, -player_pos.x)
			angle = center_angle + (float(rng_fn.call()) - 0.5) * PI * 1.3

		var dist: float = min_distance + float(rng_fn.call()) * (max_distance - min_distance)
		var cand_x: float = player_pos.x + cos(angle) * dist
		var cand_z: float = player_pos.y + sin(angle) * dist

		cand_x = clampf(cand_x, -arena_bounds, arena_bounds)
		cand_z = clampf(cand_z, -arena_bounds, arena_bounds)

		var actual_dist := Vector2(cand_x - player_pos.x, cand_z - player_pos.y).length()
		if actual_dist < 20.0:
			continue

		var collides_with_obstacle := false
		for obs in all_obstacles:
			var half_w: float = float(obs["width"]) / 2.0 + 1.2
			var half_d: float = float(obs["depth"]) / 2.0 + 1.2
			var inside_box: bool = absf(cand_x - float(obs["x"])) < half_w and absf(cand_z - float(obs["z"])) < half_d
			var too_close_center: bool = Vector2(cand_x - float(obs["x"]), cand_z - float(obs["z"])).length() < 2.6
			if inside_box or too_close_center:
				collides_with_obstacle = true
				break

		if not collides_with_obstacle:
			return Vector2(cand_x, cand_z)

	# Deterministic fallback: far corner opposite the player
	var sign_x: float = -1.0 if player_pos.x >= 0.0 else 1.0
	var sign_z: float = -1.0 if player_pos.y >= 0.0 else 1.0
	var corner_candidates: Array[Vector2] = [
		Vector2(sign_x * 36.0, sign_z * 36.0),
		Vector2(sign_x * 38.0, sign_z * 20.0),
		Vector2(sign_x * 20.0, sign_z * 38.0),
	]
	for c in corner_candidates:
		var collides := false
		for obs in all_obstacles:
			if Vector2(c.x - float(obs["x"]), c.y - float(obs["z"])).length() < 3.0:
				collides = true
				break
		if not collides:
			return c

	return corner_candidates[0]
