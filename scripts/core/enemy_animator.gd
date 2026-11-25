class_name EnemyAnimator
extends RefCounted

const CLIP_IDLE: String = "IDLE"
const CLIP_CHASE: String = "CHASE"
const CLIP_WINDUP: String = "WINDUP"
const CLIP_AIRBORNE: String = "AIRBORNE"
const CLIP_SLASH: String = "SLASH"
const CLIP_STAGGER: String = "STAGGER"
const CLIP_KNOCKED_DOWN: String = "KNOCKED_DOWN"


class State:
	extends RefCounted
	var personality: String = EnemyBehavior.RUSHER
	var stride_phase: float = 0.0
	var idle_phase: float = 0.0
	var slash_timer: float = 0.0
	var slash_duration: float = 0.36
	var slash_hand: float = 1.0
	var slash_cooldown: float = 0.0
	var windup_blend: float = 0.0
	var airborne_blend: float = 0.0
	var stagger_blend: float = 0.0
	var death_blend: float = 0.0
	var death_splay_sign: float = 1.0
	var smooth_bank: float = 0.0
	var active_clip: String = CLIP_IDLE

	func reset(new_personality: String, phase_roll: float = 0.0) -> void:
		personality = EnemyBehavior.normalize_personality(new_personality)
		stride_phase = phase_roll * TAU
		idle_phase = phase_roll * TAU
		slash_timer = 0.0
		slash_cooldown = 0.0
		slash_hand = -1.0 if phase_roll < 0.5 else 1.0
		windup_blend = 0.0
		airborne_blend = 0.0
		stagger_blend = 0.0
		death_blend = 0.0
		death_splay_sign = -1.0 if phase_roll < 0.5 else 1.0
		smooth_bank = 0.0
		active_clip = CLIP_IDLE


class Pose:
	extends RefCounted
	var body_offset_y: float = 0.0
	var torso_rot: Vector3 = Vector3.ZERO
	var head_rot: Vector3 = Vector3.ZERO
	var shoulder_l_rot: Vector3 = Vector3.ZERO
	var shoulder_r_rot: Vector3 = Vector3.ZERO
	var elbow_l_rot: Vector3 = Vector3.ZERO
	var elbow_r_rot: Vector3 = Vector3.ZERO
	var hip_l_rot: Vector3 = Vector3.ZERO
	var hip_r_rot: Vector3 = Vector3.ZERO
	var knee_l_rot: Vector3 = Vector3.ZERO
	var knee_r_rot: Vector3 = Vector3.ZERO

	func clear() -> void:
		body_offset_y = 0.0
		torso_rot = Vector3.ZERO
		head_rot = Vector3.ZERO
		shoulder_l_rot = Vector3.ZERO
		shoulder_r_rot = Vector3.ZERO
		elbow_l_rot = Vector3.ZERO
		elbow_r_rot = Vector3.ZERO
		hip_l_rot = Vector3.ZERO
		hip_r_rot = Vector3.ZERO
		knee_l_rot = Vector3.ZERO
		knee_r_rot = Vector3.ZERO


static func step(
	state: State,
	dt: float,
	horizontal_speed: float,
	lateral_speed: float,
	is_grounded: bool,
	is_winding_up: bool,
	is_staggered: bool,
	is_knocked_down: bool,
	in_slash_range: bool,
	out_pose: Pose = null
) -> Pose:
	var pose := out_pose if out_pose != null else Pose.new()
	pose.clear()

	var spec := EnemyArchetypes.get_spec(state.personality)
	var blend_rate := minf(1.0, dt * 14.0)

	# Blend secondary state weights smoothly
	state.windup_blend = lerpf(state.windup_blend, 1.0 if (is_winding_up and not is_knocked_down) else 0.0, minf(1.0, dt * 16.0))
	state.airborne_blend = lerpf(state.airborne_blend, 1.0 if (not is_grounded and not is_knocked_down) else 0.0, minf(1.0, dt * 12.0))
	state.stagger_blend = lerpf(state.stagger_blend, 1.0 if (is_staggered and not is_knocked_down) else 0.0, minf(1.0, dt * 20.0))
	state.death_blend = lerpf(state.death_blend, 1.0 if is_knocked_down else 0.0, minf(1.0, dt * 18.0))

	# Advance locomotion and breathing phases
	state.idle_phase = fmod(state.idle_phase + dt * 2.8, TAU)
	var speed_factor := clampf(horizontal_speed / 6.0, 0.0, 1.8)
	if not is_knocked_down and not is_staggered and not is_winding_up and is_grounded and horizontal_speed > 0.25:
		state.stride_phase = fmod(state.stride_phase + dt * horizontal_speed * spec.stride_cadence, TAU)

	# Close-range melee slash timer
	if state.slash_cooldown > 0.0:
		state.slash_cooldown = maxf(0.0, state.slash_cooldown - dt)
	if state.slash_timer > 0.0:
		state.slash_timer = maxf(0.0, state.slash_timer - dt)
	elif (
		in_slash_range
		and not is_knocked_down
		and not is_staggered
		and not is_winding_up
		and state.slash_cooldown <= 0.0
	):
		state.slash_duration = clampf(2.4 / spec.slash_speed, 0.24, 0.44)
		state.slash_timer = state.slash_duration
		state.slash_cooldown = state.slash_duration + 0.22
		state.slash_hand = -state.slash_hand

	# Smooth lateral banking into turns/strafe
	var target_bank := clampf(lateral_speed / 7.0, -1.0, 1.0) * spec.sway_roll_amp
	state.smooth_bank = lerpf(state.smooth_bank, target_bank, blend_rate)

	# Determine active clip label for inspection/testing
	if is_knocked_down:
		state.active_clip = CLIP_KNOCKED_DOWN
	elif is_staggered:
		state.active_clip = CLIP_STAGGER
	elif is_winding_up:
		state.active_clip = CLIP_WINDUP
	elif not is_grounded:
		state.active_clip = CLIP_AIRBORNE
	elif state.slash_timer > 0.0:
		state.active_clip = CLIP_SLASH
	elif horizontal_speed > 0.25:
		state.active_clip = CLIP_CHASE
	else:
		state.active_clip = CLIP_IDLE

	# 1. Base idle + chase stride pose
	var move_weight := clampf(speed_factor, 0.0, 1.0)
	var s := sin(state.stride_phase)
	var c := cos(state.stride_phase)
	var breath := sin(state.idle_phase)

	var stride_bob := absf(s) * spec.stride_bob_amp * move_weight + breath * 0.012
	var torso_pitch := spec.base_torso_pitch + move_weight * 0.12
	var torso_yaw := -s * 0.14 * move_weight
	var torso_roll := -state.smooth_bank + c * spec.sway_roll_amp * 0.45 * move_weight

	var head_pitch := -spec.base_torso_pitch * 0.45 + breath * 0.04
	var head_yaw := s * 0.08 * move_weight
	var head_roll := 0.0
	if state.personality == EnemyBehavior.WEAVER:
		# Crooked eerie twitching head tilt for Ash Wraith
		head_roll = 0.22 + sin(state.idle_phase * 2.3) * 0.16
		torso_roll += sin(state.stride_phase * 0.5) * 0.10 * move_weight

	# Legs: -X swings forward (+Z), +X bends knee backward (-Z)
	var leg_l_pitch := -s * spec.stride_leg_amp * move_weight
	var leg_r_pitch := s * spec.stride_leg_amp * move_weight
	var knee_l_pitch := spec.base_knee_pitch + maxf(0.0, c) * 0.65 * move_weight
	var knee_r_pitch := spec.base_knee_pitch + maxf(0.0, -c) * 0.65 * move_weight

	# Arms: counter-swing opposite the legs; -X raises arm forward toward player
	var arm_l_pitch := spec.base_arm_pitch + s * spec.stride_arm_amp * move_weight
	var arm_r_pitch := spec.base_arm_pitch - s * spec.stride_arm_amp * move_weight
	var arm_l_roll := -0.10 - (0.24 if state.personality == EnemyBehavior.WEAVER else 0.0)
	var arm_r_roll := 0.10 + (0.24 if state.personality == EnemyBehavior.WEAVER else 0.0)
	var elbow_l_pitch := spec.base_elbow_pitch - maxf(0.0, -s) * 0.28 * move_weight
	var elbow_r_pitch := spec.base_elbow_pitch - maxf(0.0, s) * 0.28 * move_weight

	# 2. Overlay close-range claw slash
	if state.slash_timer > 0.0 and state.slash_duration > 0.001:
		var t := 1.0 - (state.slash_timer / state.slash_duration)
		# Quick wind-back (0..0.3), snap forward strike (0.3..0.7), recover (0.7..1.0)
		var slash_wave := sin(t * PI)
		var strike_arc := sin((t - 0.18) * PI * 1.25)
		var is_left := state.slash_hand < 0.0
		if is_left:
			arm_l_pitch = lerpf(arm_l_pitch, -1.55 + strike_arc * 1.25, slash_wave)
			arm_l_roll = lerpf(arm_l_roll, -0.35 + strike_arc * 0.45, slash_wave)
			elbow_l_pitch = lerpf(elbow_l_pitch, -0.95 + maxf(0.0, strike_arc) * 0.55, slash_wave)
			torso_yaw += slash_wave * 0.32
		else:
			arm_r_pitch = lerpf(arm_r_pitch, -1.55 + strike_arc * 1.25, slash_wave)
			arm_r_roll = lerpf(arm_r_roll, 0.35 - strike_arc * 0.45, slash_wave)
			elbow_r_pitch = lerpf(elbow_r_pitch, -0.95 + maxf(0.0, strike_arc) * 0.55, slash_wave)
			torso_yaw -= slash_wave * 0.32

	# 3. Blend LUNGE WINDUP crouch & coil telegraph
	if state.windup_blend > 0.001:
		var w := state.windup_blend
		stride_bob = lerpf(stride_bob, -0.22, w)
		torso_pitch = lerpf(torso_pitch, 0.72, w)
		torso_yaw = lerpf(torso_yaw, 0.0, w)
		head_pitch = lerpf(head_pitch, -0.45, w)
		leg_l_pitch = lerpf(leg_l_pitch, -0.58, w)
		leg_r_pitch = lerpf(leg_r_pitch, -0.42, w)
		knee_l_pitch = lerpf(knee_l_pitch, 1.05, w)
		knee_r_pitch = lerpf(knee_r_pitch, 0.92, w)
		arm_l_pitch = lerpf(arm_l_pitch, 0.58, w)
		arm_r_pitch = lerpf(arm_r_pitch, 0.58, w)
		arm_l_roll = lerpf(arm_l_roll, -0.48, w)
		arm_r_roll = lerpf(arm_r_roll, 0.48, w)
		elbow_l_pitch = lerpf(elbow_l_pitch, -1.15, w)
		elbow_r_pitch = lerpf(elbow_r_pitch, -1.15, w)

	# 4. Blend AIRBORNE pounce / vault stretch
	if state.airborne_blend > 0.001:
		var a := state.airborne_blend
		stride_bob = lerpf(stride_bob, 0.04, a)
		torso_pitch = lerpf(torso_pitch, 0.50, a)
		head_pitch = lerpf(head_pitch, -0.25, a)
		leg_l_pitch = lerpf(leg_l_pitch, 0.52, a)
		leg_r_pitch = lerpf(leg_r_pitch, 0.30, a)
		knee_l_pitch = lerpf(knee_l_pitch, 0.48, a)
		knee_r_pitch = lerpf(knee_r_pitch, 0.72, a)
		arm_l_pitch = lerpf(arm_l_pitch, -1.45, a)
		arm_r_pitch = lerpf(arm_r_pitch, -1.35, a)
		arm_l_roll = lerpf(arm_l_roll, -0.24, a)
		arm_r_roll = lerpf(arm_r_roll, 0.24, a)
		elbow_l_pitch = lerpf(elbow_l_pitch, -0.25, a)
		elbow_r_pitch = lerpf(elbow_r_pitch, -0.25, a)

	# 5. Blend HIT STAGGER recoil (snaps chest backward, flares arms wide)
	if state.stagger_blend > 0.001:
		var st := state.stagger_blend
		stride_bob = lerpf(stride_bob, -0.05, st)
		torso_pitch = lerpf(torso_pitch, -0.44, st)
		torso_yaw = lerpf(torso_yaw, 0.26 * state.death_splay_sign, st)
		head_pitch = lerpf(head_pitch, -0.38, st)
		arm_l_pitch = lerpf(arm_l_pitch, -0.78, st)
		arm_r_pitch = lerpf(arm_r_pitch, -0.62, st)
		arm_l_roll = lerpf(arm_l_roll, -0.82, st)
		arm_r_roll = lerpf(arm_r_roll, 0.82, st)
		elbow_l_pitch = lerpf(elbow_l_pitch, -0.32, st)
		elbow_r_pitch = lerpf(elbow_r_pitch, -0.32, st)

	# 6. Blend KNOCKED_DOWN death splay pose (holds splayed silhouette while Jolt body tumbles)
	if state.death_blend > 0.001:
		var d := state.death_blend
		var sgn := state.death_splay_sign
		stride_bob = lerpf(stride_bob, 0.0, d)
		torso_pitch = lerpf(torso_pitch, -0.28, d)
		torso_yaw = lerpf(torso_yaw, 0.18 * sgn, d)
		torso_roll = lerpf(torso_roll, 0.15 * sgn, d)
		head_pitch = lerpf(head_pitch, -0.42, d)
		head_roll = lerpf(head_roll, 0.30 * sgn, d)
		arm_l_pitch = lerpf(arm_l_pitch, -0.95, d)
		arm_r_pitch = lerpf(arm_r_pitch, -0.55, d)
		arm_l_roll = lerpf(arm_l_roll, -1.05, d)
		arm_r_roll = lerpf(arm_r_roll, 0.92, d)
		elbow_l_pitch = lerpf(elbow_l_pitch, -0.28, d)
		elbow_r_pitch = lerpf(elbow_r_pitch, -0.52, d)
		leg_l_pitch = lerpf(leg_l_pitch, -0.26, d)
		leg_r_pitch = lerpf(leg_r_pitch, 0.34, d)
		knee_l_pitch = lerpf(knee_l_pitch, 0.45, d)
		knee_r_pitch = lerpf(knee_r_pitch, 0.25, d)

	pose.body_offset_y = stride_bob
	pose.torso_rot = Vector3(torso_pitch, torso_yaw, torso_roll)
	pose.head_rot = Vector3(head_pitch, head_yaw, head_roll)
	pose.shoulder_l_rot = Vector3(arm_l_pitch, 0.0, arm_l_roll)
	pose.shoulder_r_rot = Vector3(arm_r_pitch, 0.0, arm_r_roll)
	pose.elbow_l_rot = Vector3(elbow_l_pitch, 0.0, 0.0)
	pose.elbow_r_rot = Vector3(elbow_r_pitch, 0.0, 0.0)
	pose.hip_l_rot = Vector3(leg_l_pitch, 0.0, -0.06 if state.death_blend < 0.5 else -0.24)
	pose.hip_r_rot = Vector3(leg_r_pitch, 0.0, 0.06 if state.death_blend < 0.5 else 0.24)
	pose.knee_l_rot = Vector3(knee_l_pitch, 0.0, 0.0)
	pose.knee_r_rot = Vector3(knee_r_pitch, 0.0, 0.0)
	return pose
