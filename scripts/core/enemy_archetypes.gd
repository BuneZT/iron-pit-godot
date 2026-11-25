class_name EnemyArchetypes
extends RefCounted


class Spec:
	extends RefCounted
	var id: String
	var display_name: String
	var body_color: Color
	var accent_color: Color
	var horn_color: Color
	var visor_color: Color
	var visor_windup_color: Color
	var stride_cadence: float
	var stride_leg_amp: float
	var stride_arm_amp: float
	var stride_bob_amp: float
	var base_torso_pitch: float
	var base_arm_pitch: float
	var base_elbow_pitch: float
	var base_knee_pitch: float
	var sway_roll_amp: float
	var slash_speed: float
	var visual_scale: Vector3
	var pelvis_y: float
	var torso_offset: Vector3
	var head_offset: Vector3
	var shoulder_l_offset: Vector3
	var shoulder_r_offset: Vector3
	var elbow_l_offset: Vector3
	var elbow_r_offset: Vector3
	var hip_l_offset: Vector3
	var hip_r_offset: Vector3
	var knee_l_offset: Vector3
	var knee_r_offset: Vector3


static var _specs_cache: Dictionary = {}


static func get_spec(personality: String) -> Spec:
	var key := EnemyBehavior.normalize_personality(personality)
	if _specs_cache.is_empty():
		_init_specs()
	return _specs_cache[key]


static func get_all_ids() -> Array[String]:
	return EnemyBehavior.ALL_PERSONALITIES.duplicate()


static func _init_specs() -> void:
	# 1. RUSHER — Iron Brute: broad hunched juggernaut, heavy stomping cadence
	var rusher := Spec.new()
	rusher.id = EnemyBehavior.RUSHER
	rusher.display_name = "Iron Brute"
	rusher.body_color = Color(0.58, 0.50, 0.45)
	rusher.accent_color = Color(0.42, 0.36, 0.33)
	rusher.horn_color = Color(0.46, 0.41, 0.32)
	rusher.visor_color = Color(1.0, 0.16, 0.02)
	rusher.visor_windup_color = EnemyBehavior.LUNGE_WINDUP_VISOR_COLOR
	rusher.stride_cadence = 1.45
	rusher.stride_leg_amp = 0.52
	rusher.stride_arm_amp = 0.44
	rusher.stride_bob_amp = 0.055
	rusher.base_torso_pitch = 0.20
	rusher.base_arm_pitch = -0.35
	rusher.base_elbow_pitch = -0.55
	rusher.base_knee_pitch = 0.14
	rusher.sway_roll_amp = 0.08
	rusher.slash_speed = 6.2
	rusher.visual_scale = Vector3.ONE
	rusher.pelvis_y = -0.13
	rusher.torso_offset = Vector3(0.0, 0.14, 0.02)
	rusher.head_offset = Vector3(0.0, 0.62, 0.20)
	rusher.shoulder_l_offset = Vector3(-0.46, 0.48, 0.06)
	rusher.shoulder_r_offset = Vector3(0.46, 0.46, 0.05)
	rusher.elbow_l_offset = Vector3(-0.02, -0.32, 0.02)
	rusher.elbow_r_offset = Vector3(0.02, -0.32, 0.02)
	rusher.hip_l_offset = Vector3(-0.20, -0.06, 0.0)
	rusher.hip_r_offset = Vector3(0.20, -0.06, 0.0)
	rusher.knee_l_offset = Vector3(0.0, -0.34, 0.0)
	rusher.knee_r_offset = Vector3(0.0, -0.34, 0.0)
	_specs_cache[EnemyBehavior.RUSHER] = rusher

	# 2. FLANKER — Cinder Stalker: tall lean hunter with twin swept horns & scythe claws
	var flanker := Spec.new()
	flanker.id = EnemyBehavior.FLANKER
	flanker.display_name = "Cinder Stalker"
	flanker.body_color = Color(0.36, 0.40, 0.45)
	flanker.accent_color = Color(0.26, 0.30, 0.35)
	flanker.horn_color = Color(0.60, 0.55, 0.44)
	flanker.visor_color = Color(1.0, 0.60, 0.08)
	flanker.visor_windup_color = EnemyBehavior.LUNGE_WINDUP_VISOR_COLOR
	flanker.stride_cadence = 1.85
	flanker.stride_leg_amp = 0.68
	flanker.stride_arm_amp = 0.56
	flanker.stride_bob_amp = 0.065
	flanker.base_torso_pitch = 0.28
	flanker.base_arm_pitch = -0.25
	flanker.base_elbow_pitch = -0.68
	flanker.base_knee_pitch = 0.16
	flanker.sway_roll_amp = 0.14
	flanker.slash_speed = 8.4
	flanker.visual_scale = Vector3.ONE
	flanker.pelvis_y = -0.08
	flanker.torso_offset = Vector3(0.0, 0.14, 0.02)
	flanker.head_offset = Vector3(0.0, 0.66, 0.14)
	flanker.shoulder_l_offset = Vector3(-0.37, 0.52, 0.03)
	flanker.shoulder_r_offset = Vector3(0.37, 0.52, 0.03)
	flanker.elbow_l_offset = Vector3(-0.02, -0.34, 0.02)
	flanker.elbow_r_offset = Vector3(0.02, -0.34, 0.02)
	flanker.hip_l_offset = Vector3(-0.15, -0.06, 0.0)
	flanker.hip_r_offset = Vector3(0.15, -0.06, 0.0)
	flanker.knee_l_offset = Vector3(0.0, -0.37, 0.0)
	flanker.knee_r_offset = Vector3(0.0, -0.37, 0.0)
	_specs_cache[EnemyBehavior.FLANKER] = flanker

	# 3. WEAVER — Ash Wraith: crooked iron-caged frame with splayed twitching limbs
	var weaver := Spec.new()
	weaver.id = EnemyBehavior.WEAVER
	weaver.display_name = "Ash Wraith"
	weaver.body_color = Color(0.40, 0.48, 0.40)
	weaver.accent_color = Color(0.28, 0.35, 0.29)
	weaver.horn_color = Color(0.54, 0.52, 0.39)
	weaver.visor_color = Color(0.76, 0.95, 0.24)
	weaver.visor_windup_color = EnemyBehavior.LUNGE_WINDUP_VISOR_COLOR
	weaver.stride_cadence = 1.95
	weaver.stride_leg_amp = 0.60
	weaver.stride_arm_amp = 0.52
	weaver.stride_bob_amp = 0.05
	weaver.base_torso_pitch = 0.16
	weaver.base_arm_pitch = -0.48
	weaver.base_elbow_pitch = -0.42
	weaver.base_knee_pitch = 0.22
	weaver.sway_roll_amp = 0.22
	weaver.slash_speed = 7.6
	weaver.visual_scale = Vector3.ONE
	weaver.pelvis_y = -0.10
	weaver.torso_offset = Vector3(0.0, 0.14, 0.02)
	weaver.head_offset = Vector3(0.02, 0.64, 0.12)
	weaver.shoulder_l_offset = Vector3(-0.38, 0.49, 0.02)
	weaver.shoulder_r_offset = Vector3(0.38, 0.45, 0.02)
	weaver.elbow_l_offset = Vector3(-0.08, -0.30, 0.03)
	weaver.elbow_r_offset = Vector3(0.08, -0.30, 0.03)
	weaver.hip_l_offset = Vector3(-0.17, -0.06, 0.0)
	weaver.hip_r_offset = Vector3(0.17, -0.06, 0.0)
	weaver.knee_l_offset = Vector3(-0.02, -0.36, 0.02)
	weaver.knee_r_offset = Vector3(0.02, -0.36, 0.02)
	_specs_cache[EnemyBehavior.WEAVER] = weaver

	# 4. LUNGER — Iron Prowler: low coiled beast with dorsal spikes & massive pounce claws
	var lunger := Spec.new()
	lunger.id = EnemyBehavior.LUNGER
	lunger.display_name = "Iron Prowler"
	lunger.body_color = Color(0.50, 0.34, 0.30)
	lunger.accent_color = Color(0.34, 0.23, 0.20)
	lunger.horn_color = Color(0.58, 0.50, 0.39)
	lunger.visor_color = Color(1.0, 0.30, 0.04)
	lunger.visor_windup_color = EnemyBehavior.LUNGE_WINDUP_VISOR_COLOR
	lunger.stride_cadence = 1.75
	lunger.stride_leg_amp = 0.58
	lunger.stride_arm_amp = 0.62
	lunger.stride_bob_amp = 0.07
	lunger.base_torso_pitch = 0.46
	lunger.base_arm_pitch = -0.38
	lunger.base_elbow_pitch = -0.45
	lunger.base_knee_pitch = 0.38
	lunger.sway_roll_amp = 0.11
	lunger.slash_speed = 7.8
	lunger.visual_scale = Vector3.ONE
	lunger.pelvis_y = -0.22
	lunger.torso_offset = Vector3(0.0, 0.12, 0.08)
	lunger.head_offset = Vector3(0.0, 0.36, 0.36)
	lunger.shoulder_l_offset = Vector3(-0.47, 0.34, 0.14)
	lunger.shoulder_r_offset = Vector3(0.47, 0.34, 0.14)
	lunger.elbow_l_offset = Vector3(-0.04, -0.36, 0.04)
	lunger.elbow_r_offset = Vector3(0.04, -0.36, 0.04)
	lunger.hip_l_offset = Vector3(-0.22, -0.04, -0.04)
	lunger.hip_r_offset = Vector3(0.22, -0.04, -0.04)
	lunger.knee_l_offset = Vector3(0.0, -0.30, 0.06)
	lunger.knee_r_offset = Vector3(0.0, -0.30, 0.06)
	_specs_cache[EnemyBehavior.LUNGER] = lunger
