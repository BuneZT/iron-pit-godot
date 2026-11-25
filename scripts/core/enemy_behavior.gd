class_name EnemyBehavior
extends RefCounted

const RUSHER: String = "RUSHER"
const FLANKER: String = "FLANKER"
const WEAVER: String = "WEAVER"
const LUNGER: String = "LUNGER"

const ALL_PERSONALITIES: Array[String] = [RUSHER, FLANKER, WEAVER, LUNGER]

const LUNGE_CHASE: String = "CHASE"
const LUNGE_WINDUP: String = "WINDUP"
const LUNGE_AIRBORNE: String = "AIRBORNE"

const FLANK_CLOSE_DIST: float = 3.2
const FLANK_FULL_DIST: float = 10.0
const FLANK_MAX_WEIGHT: float = 0.78
const FLANK_FAR_DIST: float = 26.0
const FLANK_FAR_WEIGHT: float = 0.55

const WEAVE_CLOSE_DIST: float = 2.4
const WEAVE_FULL_DIST: float = 6.0
const WEAVE_MAX_AMP: float = 0.85

const LUNGE_MIN_DIST: float = 3.8
const LUNGE_MAX_DIST: float = 10.5
const LUNGE_MAX_VERTICAL_DIFF: float = 1.6
const LUNGE_WINDUP_DURATION: float = 0.36
const LUNGE_AIRBORNE_DURATION: float = 0.55
const LUNGE_COOLDOWN_DURATION: float = 3.0
const LUNGE_INTERRUPT_COOLDOWN: float = 1.1
const LUNGE_FORWARD_SPEED: float = 12.8
const LUNGE_UPWARD_SPEED: float = 4.6

const SEPARATION_RADIUS: float = 2.6
const SEPARATION_WEIGHT: float = 0.45
const ARENA_FLANK_FLIP_BOUND: float = 45.0

const LUNGE_WINDUP_VISOR_COLOR: Color = Color(1.0, 0.96, 0.78)


class State:
	extends RefCounted
	var personality: String = RUSHER
	var flank_side: float = 1.0
	var weave_phase: float = 0.0
	var weave_freq: float = 3.4
	var lunge_state: String = LUNGE_CHASE
	var lunge_timer: float = 0.0
	var lunge_cooldown: float = 1.2

	func reset(
		new_personality: String,
		side_roll: float = 0.5,
		phase_roll: float = 0.0,
		freq_roll: float = 0.5
	) -> void:
		personality = EnemyBehavior.normalize_personality(new_personality)
		flank_side = -1.0 if side_roll < 0.5 else 1.0
		weave_phase = phase_roll * TAU
		weave_freq = 3.0 + clampf(freq_roll, 0.0, 1.0) * 1.1
		lunge_state = LUNGE_CHASE
		lunge_timer = 0.0
		lunge_cooldown = 0.9

	func on_stagger() -> void:
		if lunge_state == LUNGE_WINDUP:
			lunge_state = LUNGE_CHASE
			lunge_timer = 0.0
			lunge_cooldown = maxf(lunge_cooldown, LUNGE_INTERRUPT_COOLDOWN)
		elif lunge_state == LUNGE_AIRBORNE:
			lunge_state = LUNGE_CHASE
			lunge_timer = 0.0


class StepResult:
	extends RefCounted
	var velocity_xz: Vector2 = Vector2.ZERO
	var facing_dir_xz: Vector2 = Vector2(0.0, 1.0)
	var lunge_launch_velocity: Vector3 = Vector3.ZERO
	var started_windup: bool = false
	var is_winding_up: bool = false
	var preserve_airborne_velocity: bool = false
	var suppress_stuck_timer: bool = false

	func clear() -> void:
		velocity_xz = Vector2.ZERO
		facing_dir_xz = Vector2(0.0, 1.0)
		lunge_launch_velocity = Vector3.ZERO
		started_windup = false
		is_winding_up = false
		preserve_airborne_velocity = false
		suppress_stuck_timer = false


static func normalize_personality(value: String) -> String:
	var upper := value.strip_edges().to_upper()
	if upper == FLANKER or upper == WEAVER or upper == LUNGER:
		return upper
	return RUSHER


static func pick_personality(wave_number: int, roll: float) -> String:
	var r := clampf(roll, 0.0, 0.999999)
	if wave_number <= 1:
		return RUSHER if r < 0.65 else FLANKER
	if wave_number == 2:
		if r < 0.35:
			return RUSHER
		if r < 0.70:
			return FLANKER
		return WEAVER
	if r < 0.25:
		return RUSHER
	if r < 0.50:
		return FLANKER
	if r < 0.75:
		return WEAVER
	return LUNGER


static func compute_separation(
	self_pos: Vector2,
	neighbor_positions: Array[Vector2],
	self_index: int,
	radius: float = SEPARATION_RADIUS
) -> Vector2:
	if radius <= 0.0001:
		return Vector2.ZERO
	var push := Vector2.ZERO
	var r_sq := radius * radius
	for i in range(neighbor_positions.size()):
		if i == self_index:
			continue
		var diff := self_pos - neighbor_positions[i]
		var dist_sq := diff.length_squared()
		if dist_sq < r_sq:
			if dist_sq > 0.0001:
				var dist := sqrt(dist_sq)
				var strength := (radius - dist) / radius
				push += (diff / dist) * strength
			else:
				var angle := float((self_index * 73) % 360) * PI / 180.0
				push += Vector2(cos(angle), sin(angle))
	if push.length_squared() > 1.0:
		push = push.normalized()
	return push


static func step(
	state: State,
	dt: float,
	enemy_pos: Vector3,
	player_pos: Vector3,
	chase_speed: float,
	is_grounded: bool,
	separation_xz: Vector2 = Vector2.ZERO,
	out_result: StepResult = null
) -> StepResult:
	var res := out_result if out_result != null else StepResult.new()
	res.clear()

	var to_player_xz := Vector2(player_pos.x - enemy_pos.x, player_pos.z - enemy_pos.z)
	var dist := to_player_xz.length()
	var vertical_diff := player_pos.y - enemy_pos.y
	var direct_dir := to_player_xz / dist if dist > 0.0001 else Vector2(0.0, 1.0)
	res.facing_dir_xz = direct_dir

	if state.lunge_cooldown > 0.0:
		state.lunge_cooldown = maxf(0.0, state.lunge_cooldown - dt)

	if state.personality == LUNGER:
		if state.lunge_state == LUNGE_AIRBORNE:
			state.lunge_timer -= dt
			res.preserve_airborne_velocity = true
			res.suppress_stuck_timer = true
			if state.lunge_timer <= 0.0 or (state.lunge_timer <= LUNGE_AIRBORNE_DURATION - 0.15 and is_grounded):
				state.lunge_state = LUNGE_CHASE
				state.lunge_timer = 0.0
			return res

		if state.lunge_state == LUNGE_WINDUP:
			state.lunge_timer -= dt
			res.suppress_stuck_timer = true
			if state.lunge_timer <= 0.0:
				if is_grounded:
					res.lunge_launch_velocity = Vector3(
						direct_dir.x * LUNGE_FORWARD_SPEED,
						LUNGE_UPWARD_SPEED,
						direct_dir.y * LUNGE_FORWARD_SPEED
					)
					state.lunge_state = LUNGE_AIRBORNE
					state.lunge_timer = LUNGE_AIRBORNE_DURATION
					state.lunge_cooldown = LUNGE_COOLDOWN_DURATION
					res.preserve_airborne_velocity = true
				else:
					state.lunge_state = LUNGE_CHASE
					state.lunge_timer = 0.0
					state.lunge_cooldown = LUNGE_INTERRUPT_COOLDOWN
			else:
				res.is_winding_up = true
				res.velocity_xz = Vector2.ZERO
			return res

		if (
			state.lunge_cooldown <= 0.0
			and is_grounded
			and dist >= LUNGE_MIN_DIST
			and dist <= LUNGE_MAX_DIST
			and absf(vertical_diff) <= LUNGE_MAX_VERTICAL_DIFF
		):
			state.lunge_state = LUNGE_WINDUP
			state.lunge_timer = LUNGE_WINDUP_DURATION
			res.started_windup = true
			res.is_winding_up = true
			res.suppress_stuck_timer = true
			res.velocity_xz = Vector2.ZERO
			return res

	var steer_dir := direct_dir
	var speed_mult := 1.0
	var perp := Vector2(-direct_dir.y, direct_dir.x)

	match state.personality:
		FLANKER:
			var flank_vec := perp * state.flank_side
			if (
				(absf(enemy_pos.x) > ARENA_FLANK_FLIP_BOUND and enemy_pos.x * flank_vec.x > 0.0)
				or (absf(enemy_pos.z) > ARENA_FLANK_FLIP_BOUND and enemy_pos.z * flank_vec.y > 0.0)
			):
				state.flank_side = -state.flank_side
				flank_vec = perp * state.flank_side

			var flank_weight := 0.0
			if dist > FLANK_CLOSE_DIST:
				if dist <= FLANK_FULL_DIST:
					var t := (dist - FLANK_CLOSE_DIST) / (FLANK_FULL_DIST - FLANK_CLOSE_DIST)
					flank_weight = lerpf(0.0, FLANK_MAX_WEIGHT, t)
				elif dist <= FLANK_FAR_DIST:
					var t := (dist - FLANK_FULL_DIST) / (FLANK_FAR_DIST - FLANK_FULL_DIST)
					flank_weight = lerpf(FLANK_MAX_WEIGHT, FLANK_FAR_WEIGHT, t)
				else:
					flank_weight = FLANK_FAR_WEIGHT
			steer_dir = (direct_dir + flank_vec * flank_weight).normalized()
			speed_mult = 1.06
		WEAVER:
			state.weave_phase += dt * state.weave_freq
			var weave_amp := 0.0
			if dist > WEAVE_CLOSE_DIST:
				if dist <= WEAVE_FULL_DIST:
					var t := (dist - WEAVE_CLOSE_DIST) / (WEAVE_FULL_DIST - WEAVE_CLOSE_DIST)
					weave_amp = lerpf(0.0, WEAVE_MAX_AMP, t)
				else:
					weave_amp = WEAVE_MAX_AMP
			var lateral := sin(state.weave_phase) * weave_amp
			steer_dir = (direct_dir + perp * lateral).normalized()
			speed_mult = 1.04
		LUNGER:
			speed_mult = 0.96
		_:
			speed_mult = 1.0

	if separation_xz.length_squared() > 0.0001:
		var sep := separation_xz if separation_xz.length_squared() <= 1.0 else separation_xz.normalized()
		var combined := steer_dir + sep * SEPARATION_WEIGHT
		if combined.length_squared() > 0.0001:
			steer_dir = combined.normalized()

	res.velocity_xz = steer_dir * (chase_speed * speed_mult)
	res.facing_dir_xz = steer_dir
	return res
