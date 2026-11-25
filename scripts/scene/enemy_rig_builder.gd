class_name EnemyRigBuilder
extends RefCounted


class Rig:
	extends RefCounted
	var archetype_id: String = EnemyBehavior.RUSHER
	var visual_rig: Node3D
	var pelvis_pivot: Node3D
	var torso_pivot: Node3D
	var head_pivot: Node3D
	var shoulder_l_pivot: Node3D
	var shoulder_r_pivot: Node3D
	var elbow_l_pivot: Node3D
	var elbow_r_pivot: Node3D
	var hip_l_pivot: Node3D
	var hip_r_pivot: Node3D
	var knee_l_pivot: Node3D
	var knee_r_pivot: Node3D
	var parts: Array[MeshInstance3D] = []
	var body_parts: Array[MeshInstance3D] = []
	var accent_parts: Array[MeshInstance3D] = []
	var horn_parts: Array[MeshInstance3D] = []
	var visor_parts: Array[MeshInstance3D] = []
	var core_shadow_parts: Array[MeshInstance3D] = []
	var limb_shadow_parts: Array[MeshInstance3D] = []
	var eye_visor: MeshInstance3D

	func apply_pose(pose: EnemyAnimator.Pose) -> void:
		if is_instance_valid(visual_rig):
			visual_rig.position.y = pose.body_offset_y
		if is_instance_valid(torso_pivot):
			torso_pivot.rotation = pose.torso_rot
		if is_instance_valid(head_pivot):
			head_pivot.rotation = pose.head_rot
		if is_instance_valid(shoulder_l_pivot):
			shoulder_l_pivot.rotation = pose.shoulder_l_rot
		if is_instance_valid(shoulder_r_pivot):
			shoulder_r_pivot.rotation = pose.shoulder_r_rot
		if is_instance_valid(elbow_l_pivot):
			elbow_l_pivot.rotation = pose.elbow_l_rot
		if is_instance_valid(elbow_r_pivot):
			elbow_r_pivot.rotation = pose.elbow_r_rot
		if is_instance_valid(hip_l_pivot):
			hip_l_pivot.rotation = pose.hip_l_rot
		if is_instance_valid(hip_r_pivot):
			hip_r_pivot.rotation = pose.hip_r_rot
		if is_instance_valid(knee_l_pivot):
			knee_l_pivot.rotation = pose.knee_l_rot
		if is_instance_valid(knee_r_pivot):
			knee_r_pivot.rotation = pose.knee_r_rot

	func apply_body_materials(body_mat: Material, accent_mat: Material) -> void:
		for bp in body_parts:
			if is_instance_valid(bp):
				bp.material_override = body_mat
		for ap in accent_parts:
			if is_instance_valid(ap):
				ap.material_override = accent_mat

	func apply_visor_material(visor_mat: Material) -> void:
		for vp in visor_parts:
			if is_instance_valid(vp):
				vp.material_override = visor_mat

	func apply_shadow_quality(allow_shadows: bool, allow_limb_shadows: bool) -> void:
		var core_mode := (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if allow_shadows
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		var limb_mode := (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if allow_limb_shadows
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		for cp in core_shadow_parts:
			if is_instance_valid(cp):
				cp.cast_shadow = core_mode
		for lp in limb_shadow_parts:
			if is_instance_valid(lp):
				lp.cast_shadow = limb_mode

	func disable_all_shadows() -> void:
		for part in parts:
			if is_instance_valid(part):
				part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func set_enemy_id_meta(enemy_id: int) -> void:
		for part in parts:
			if is_instance_valid(part):
				part.set_meta("enemy_id", enemy_id)


var _box_mesh_cache: Dictionary = {}
var _box_shape_cache: Dictionary = {}
var _cyl_mesh_cache: Dictionary = {}
var _cyl_shape_cache: Dictionary = {}


func build_rig(
	archetype_id: String,
	root: RigidBody3D,
	hitbox_area: Area3D,
	enemy_id: int,
	mats: Dictionary,
	allow_shadows: bool,
	allow_limb_shadows: bool
) -> Rig:
	var key := EnemyBehavior.normalize_personality(archetype_id)
	var spec := EnemyArchetypes.get_spec(key)
	var rig := Rig.new()
	rig.archetype_id = key

	var visual_rig := Node3D.new()
	visual_rig.name = "VisualRig"
	visual_rig.scale = spec.visual_scale
	root.add_child(visual_rig)
	rig.visual_rig = visual_rig

	var pelvis_pivot := _make_pivot("PelvisPivot", Vector3(0.0, spec.pelvis_y, 0.0), visual_rig)
	var torso_pivot := _make_pivot("TorsoPivot", spec.torso_offset, pelvis_pivot)
	var head_pivot := _make_pivot("HeadPivot", spec.head_offset, torso_pivot)
	var shoulder_l_pivot := _make_pivot("ShoulderLPivot", spec.shoulder_l_offset, torso_pivot)
	var shoulder_r_pivot := _make_pivot("ShoulderRPivot", spec.shoulder_r_offset, torso_pivot)
	var elbow_l_pivot := _make_pivot("ElbowLPivot", spec.elbow_l_offset, shoulder_l_pivot)
	var elbow_r_pivot := _make_pivot("ElbowRPivot", spec.elbow_r_offset, shoulder_r_pivot)
	var hip_l_pivot := _make_pivot("HipLPivot", spec.hip_l_offset, pelvis_pivot)
	var hip_r_pivot := _make_pivot("HipRPivot", spec.hip_r_offset, pelvis_pivot)
	var knee_l_pivot := _make_pivot("KneeLPivot", spec.knee_l_offset, hip_l_pivot)
	var knee_r_pivot := _make_pivot("KneeRPivot", spec.knee_r_offset, hip_r_pivot)

	rig.pelvis_pivot = pelvis_pivot
	rig.torso_pivot = torso_pivot
	rig.head_pivot = head_pivot
	rig.shoulder_l_pivot = shoulder_l_pivot
	rig.shoulder_r_pivot = shoulder_r_pivot
	rig.elbow_l_pivot = elbow_l_pivot
	rig.elbow_r_pivot = elbow_r_pivot
	rig.hip_l_pivot = hip_l_pivot
	rig.hip_r_pivot = hip_r_pivot
	rig.knee_l_pivot = knee_l_pivot
	rig.knee_r_pivot = knee_r_pivot

	match key:
		EnemyBehavior.FLANKER:
			_build_flanker(rig, root, hitbox_area, enemy_id, mats, allow_shadows, allow_limb_shadows)
		EnemyBehavior.WEAVER:
			_build_weaver(rig, root, hitbox_area, enemy_id, mats, allow_shadows, allow_limb_shadows)
		EnemyBehavior.LUNGER:
			_build_lunger(rig, root, hitbox_area, enemy_id, mats, allow_shadows, allow_limb_shadows)
		_:
			_build_rusher(rig, root, hitbox_area, enemy_id, mats, allow_shadows, allow_limb_shadows)

	if not rig.visor_parts.is_empty():
		rig.eye_visor = rig.visor_parts[0]

	return rig


func _make_pivot(pivot_name: String, pos: Vector3, parent: Node3D) -> Node3D:
	var n := Node3D.new()
	n.name = pivot_name
	n.position = pos
	parent.add_child(n)
	return n


# ------------------------------------------------------------------------------
# 1. RUSHER — IRON BRUTE (Heavy hunched armored juggernaut)
# ------------------------------------------------------------------------------
func _build_rusher(
	rig: Rig,
	root: RigidBody3D,
	hitbox_area: Area3D,
	id: int,
	mats: Dictionary,
	allow_shadows: bool,
	allow_limb_shadows: bool
) -> void:
	var body_mat: Material = mats["body"]
	var accent_mat: Material = mats["accent"]
	var horn_mat: Material = mats["horn"]
	var visor_mat: Material = mats["visor"]

	# Pelvis & waist girdle
	_box(rig, root, hitbox_area, "brutePelvis_%d" % id, Vector3(0.64, 0.22, 0.44), Vector3(0.0, 0.0, 0.0), Vector3.ZERO, accent_mat, rig.pelvis_pivot, id, "accent", false)

	# Heavy angular torso + breast ridge + hunched back mantle + dorsal plates
	var chest := _box(rig, root, hitbox_area, "bruteChest_%d" % id, Vector3(0.78, 0.46, 0.54), Vector3(0.0, 0.34, 0.06), Vector3(0.10, 0.0, -0.02), body_mat, rig.torso_pivot, id, "body", allow_shadows)
	rig.core_shadow_parts.append(chest)
	_box(rig, root, hitbox_area, "bruteMidSpine_%d" % id, Vector3(0.54, 0.24, 0.38), Vector3(0.0, 0.11, 0.02), Vector3.ZERO, accent_mat, rig.torso_pivot, id, "accent", false)
	_box(rig, root, hitbox_area, "bruteBreastRidge_%d" % id, Vector3(0.42, 0.30, 0.12), Vector3(0.0, 0.34, 0.31), Vector3(0.14, 0.0, 0.0), accent_mat, rig.torso_pivot, id, "accent", false)
	var hunch := _box(rig, root, hitbox_area, "bruteHunch_%d" % id, Vector3(0.76, 0.42, 0.54), Vector3(0.0, 0.52, -0.08), Vector3(0.24, 0.0, 0.0), body_mat, rig.torso_pivot, id, "body", allow_shadows)
	rig.core_shadow_parts.append(hunch)
	_box(rig, root, hitbox_area, "bruteBackPlate_%d" % id, Vector3(0.32, 0.28, 0.14), Vector3(0.0, 0.54, -0.34), Vector3(0.28, 0.0, 0.0), accent_mat, rig.torso_pivot, id, "accent", false)

	# Sunken horned skull helm + jaw guard + asymmetrical horns + crimson visor
	_box(rig, root, hitbox_area, "bruteSkull_%d" % id, Vector3(0.38, 0.38, 0.44), Vector3(0.0, 0.14, 0.04), Vector3(0.12, 0.0, 0.0), body_mat, rig.head_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "bruteJaw_%d" % id, Vector3(0.30, 0.14, 0.16), Vector3(0.0, -0.02, 0.20), Vector3(0.08, 0.0, 0.0), accent_mat, rig.head_pivot, id, "accent", false)
	_cyl(rig, root, hitbox_area, "bruteHornL_%d" % id, 0.02, 0.12, 0.54, 5, Vector3(-0.18, 0.38, 0.04), Vector3(-0.38, 0.10, 0.34), horn_mat, rig.head_pivot, id, "horn", false)
	_cyl(rig, root, hitbox_area, "bruteHornR_%d" % id, 0.08, 0.11, 0.18, 5, Vector3(0.17, 0.28, 0.04), Vector3(-0.18, -0.10, -0.28), horn_mat, rig.head_pivot, id, "horn", false)
	_box(rig, root, hitbox_area, "bruteVisor_%d" % id, Vector3(0.32, 0.075, 0.14), Vector3(0.0, 0.16, 0.22), Vector3.ZERO, visor_mat, rig.head_pivot, id, "visor", false)

	# Asymmetrical shoulders: heavily spiked left pauldron + battered right guard
	var pl := _box(rig, root, hitbox_area, "brutePauldronL_%d" % id, Vector3(0.38, 0.32, 0.44), Vector3(-0.04, 0.04, 0.0), Vector3(0.12, 0.05, -0.28), body_mat, rig.shoulder_l_pivot, id, "body", allow_limb_shadows)
	rig.limb_shadow_parts.append(pl)
	_cyl(rig, root, hitbox_area, "bruteSpikeL1_%d" % id, 0.02, 0.085, 0.28, 5, Vector3(-0.18, 0.24, 0.05), Vector3(0.08, 0.0, 0.52), horn_mat, rig.shoulder_l_pivot, id, "horn", false)
	_cyl(rig, root, hitbox_area, "bruteSpikeL2_%d" % id, 0.02, 0.065, 0.22, 5, Vector3(-0.15, 0.20, -0.11), Vector3(-0.22, 0.0, 0.42), horn_mat, rig.shoulder_l_pivot, id, "horn", false)
	_box(rig, root, hitbox_area, "bruteBicepL_%d" % id, Vector3(0.20, 0.34, 0.22), Vector3(-0.02, -0.16, 0.0), Vector3.ZERO, body_mat, rig.shoulder_l_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "bruteForearmL_%d" % id, Vector3(0.22, 0.36, 0.22), Vector3(0.0, -0.16, 0.02), Vector3.ZERO, accent_mat, rig.elbow_l_pivot, id, "accent", false)
	_cyl(rig, root, hitbox_area, "bruteClawL_%d" % id, 0.015, 0.09, 0.24, 4, Vector3(0.0, -0.40, 0.04), Vector3(PI, 0.0, 0.0), horn_mat, rig.elbow_l_pivot, id, "horn", false)

	var pr := _box(rig, root, hitbox_area, "brutePauldronR_%d" % id, Vector3(0.32, 0.28, 0.38), Vector3(0.04, 0.02, 0.0), Vector3(0.08, -0.05, 0.22), body_mat, rig.shoulder_r_pivot, id, "body", allow_limb_shadows)
	rig.limb_shadow_parts.append(pr)
	_box(rig, root, hitbox_area, "bruteBicepR_%d" % id, Vector3(0.20, 0.34, 0.22), Vector3(0.02, -0.16, 0.0), Vector3.ZERO, body_mat, rig.shoulder_r_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "bruteForearmR_%d" % id, Vector3(0.22, 0.36, 0.22), Vector3(0.0, -0.16, 0.02), Vector3.ZERO, accent_mat, rig.elbow_r_pivot, id, "accent", false)
	_cyl(rig, root, hitbox_area, "bruteClawR_%d" % id, 0.015, 0.09, 0.24, 4, Vector3(0.0, -0.40, 0.04), Vector3(PI, 0.0, 0.0), horn_mat, rig.elbow_r_pivot, id, "horn", false)

	# Heavy iron-greaved legs
	var tl := _box(rig, root, hitbox_area, "bruteThighL_%d" % id, Vector3(0.24, 0.36, 0.28), Vector3(0.0, -0.17, 0.0), Vector3.ZERO, body_mat, rig.hip_l_pivot, id, "body", allow_limb_shadows)
	rig.limb_shadow_parts.append(tl)
	_box(rig, root, hitbox_area, "bruteShinL_%d" % id, Vector3(0.20, 0.34, 0.24), Vector3(0.0, -0.16, 0.0), Vector3.ZERO, body_mat, rig.knee_l_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "bruteSabatonL_%d" % id, Vector3(0.22, 0.13, 0.36), Vector3(0.0, -0.31, 0.08), Vector3.ZERO, accent_mat, rig.knee_l_pivot, id, "accent", false)

	var tr := _box(rig, root, hitbox_area, "bruteThighR_%d" % id, Vector3(0.24, 0.36, 0.28), Vector3(0.0, -0.17, 0.0), Vector3.ZERO, body_mat, rig.hip_r_pivot, id, "body", allow_limb_shadows)
	rig.limb_shadow_parts.append(tr)
	_box(rig, root, hitbox_area, "bruteShinR_%d" % id, Vector3(0.20, 0.34, 0.24), Vector3(0.0, -0.16, 0.0), Vector3.ZERO, body_mat, rig.knee_r_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "bruteSabatonR_%d" % id, Vector3(0.22, 0.13, 0.36), Vector3(0.0, -0.31, 0.08), Vector3.ZERO, accent_mat, rig.knee_r_pivot, id, "accent", false)


# ------------------------------------------------------------------------------
# 2. FLANKER — CINDER STALKER (Tall lean predatory frame, twin horns & scythe claws)
# ------------------------------------------------------------------------------
func _build_flanker(
	rig: Rig,
	root: RigidBody3D,
	hitbox_area: Area3D,
	id: int,
	mats: Dictionary,
	allow_shadows: bool,
	allow_limb_shadows: bool
) -> void:
	var body_mat: Material = mats["body"]
	var accent_mat: Material = mats["accent"]
	var horn_mat: Material = mats["horn"]
	var visor_mat: Material = mats["visor"]

	# Narrow predatory pelvis & tapered V-torso
	_box(rig, root, hitbox_area, "stalkerPelvis_%d" % id, Vector3(0.46, 0.18, 0.32), Vector3(0.0, 0.0, 0.0), Vector3.ZERO, accent_mat, rig.pelvis_pivot, id, "accent", false)
	_box(rig, root, hitbox_area, "stalkerWaist_%d" % id, Vector3(0.36, 0.26, 0.28), Vector3(0.0, 0.14, 0.0), Vector3.ZERO, accent_mat, rig.torso_pivot, id, "accent", false)
	var chest := _box(rig, root, hitbox_area, "stalkerChest_%d" % id, Vector3(0.62, 0.44, 0.38), Vector3(0.0, 0.42, 0.04), Vector3(0.10, 0.0, 0.0), body_mat, rig.torso_pivot, id, "body", allow_shadows)
	rig.core_shadow_parts.append(chest)
	# Swept twin back blade fins for unmistakable lean silhouette
	var fin_l := _box(rig, root, hitbox_area, "stalkerFinL_%d" % id, Vector3(0.10, 0.44, 0.24), Vector3(-0.24, 0.56, -0.18), Vector3(-0.38, -0.18, -0.28), accent_mat, rig.torso_pivot, id, "accent", allow_shadows)
	rig.core_shadow_parts.append(fin_l)
	_box(rig, root, hitbox_area, "stalkerFinR_%d" % id, Vector3(0.10, 0.44, 0.24), Vector3(0.24, 0.56, -0.18), Vector3(-0.38, 0.18, 0.28), accent_mat, rig.torso_pivot, id, "accent", false)

	# Tall narrow executioner helm + twin swept-back curved horns + V-angled amber eyes
	_box(rig, root, hitbox_area, "stalkerHelm_%d" % id, Vector3(0.28, 0.40, 0.34), Vector3(0.0, 0.16, 0.02), Vector3(0.08, 0.0, 0.0), body_mat, rig.head_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "stalkerCrest_%d" % id, Vector3(0.08, 0.24, 0.38), Vector3(0.0, 0.32, -0.02), Vector3(-0.18, 0.0, 0.0), accent_mat, rig.head_pivot, id, "accent", false)
	_cyl(rig, root, hitbox_area, "stalkerHornL_%d" % id, 0.015, 0.085, 0.54, 5, Vector3(-0.14, 0.40, -0.04), Vector3(-0.55, 0.14, 0.30), horn_mat, rig.head_pivot, id, "horn", false)
	_cyl(rig, root, hitbox_area, "stalkerHornR_%d" % id, 0.015, 0.085, 0.54, 5, Vector3(0.14, 0.40, -0.04), Vector3(-0.55, -0.14, -0.30), horn_mat, rig.head_pivot, id, "horn", false)
	_box(rig, root, hitbox_area, "stalkerEyeL_%d" % id, Vector3(0.11, 0.055, 0.10), Vector3(-0.075, 0.18, 0.16), Vector3(0.0, 0.0, -0.26), visor_mat, rig.head_pivot, id, "visor", false)
	_box(rig, root, hitbox_area, "stalkerEyeR_%d" % id, Vector3(0.11, 0.055, 0.10), Vector3(0.075, 0.18, 0.16), Vector3(0.0, 0.0, 0.26), visor_mat, rig.head_pivot, id, "visor", false)

	# Flared blade shoulders + lean arms + long sweeping bone-iron scythe blades
	var pl := _box(rig, root, hitbox_area, "stalkerPauldronL_%d" % id, Vector3(0.32, 0.14, 0.36), Vector3(-0.08, 0.08, 0.0), Vector3(0.0, 0.0, -0.45), body_mat, rig.shoulder_l_pivot, id, "body", allow_limb_shadows)
	rig.limb_shadow_parts.append(pl)
	_box(rig, root, hitbox_area, "stalkerBicepL_%d" % id, Vector3(0.14, 0.36, 0.15), Vector3(0.0, -0.17, 0.0), Vector3.ZERO, body_mat, rig.shoulder_l_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "stalkerForearmL_%d" % id, Vector3(0.13, 0.34, 0.15), Vector3(0.0, -0.16, 0.02), Vector3.ZERO, accent_mat, rig.elbow_l_pivot, id, "accent", false)
	_cyl(rig, root, hitbox_area, "stalkerScytheL_%d" % id, 0.01, 0.095, 0.56, 4, Vector3(-0.03, -0.52, 0.10), Vector3(2.85, 0.0, -0.14), horn_mat, rig.elbow_l_pivot, id, "horn", false)

	var pr := _box(rig, root, hitbox_area, "stalkerPauldronR_%d" % id, Vector3(0.32, 0.14, 0.36), Vector3(0.08, 0.08, 0.0), Vector3(0.0, 0.0, 0.45), body_mat, rig.shoulder_r_pivot, id, "body", allow_limb_shadows)
	rig.limb_shadow_parts.append(pr)
	_box(rig, root, hitbox_area, "stalkerBicepR_%d" % id, Vector3(0.14, 0.36, 0.15), Vector3(0.0, -0.17, 0.0), Vector3.ZERO, body_mat, rig.shoulder_r_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "stalkerForearmR_%d" % id, Vector3(0.13, 0.34, 0.15), Vector3(0.0, -0.16, 0.02), Vector3.ZERO, accent_mat, rig.elbow_r_pivot, id, "accent", false)
	_cyl(rig, root, hitbox_area, "stalkerScytheR_%d" % id, 0.01, 0.095, 0.56, 4, Vector3(0.03, -0.52, 0.10), Vector3(2.85, 0.0, 0.14), horn_mat, rig.elbow_r_pivot, id, "horn", false)

	# Long slender runner legs
	var tl := _box(rig, root, hitbox_area, "stalkerThighL_%d" % id, Vector3(0.16, 0.40, 0.18), Vector3(0.0, -0.19, 0.0), Vector3.ZERO, body_mat, rig.hip_l_pivot, id, "body", allow_limb_shadows)
	rig.limb_shadow_parts.append(tl)
	_box(rig, root, hitbox_area, "stalkerShinL_%d" % id, Vector3(0.13, 0.38, 0.16), Vector3(0.0, -0.18, 0.0), Vector3.ZERO, body_mat, rig.knee_l_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "stalkerFootL_%d" % id, Vector3(0.14, 0.10, 0.30), Vector3(0.0, -0.34, 0.07), Vector3.ZERO, accent_mat, rig.knee_l_pivot, id, "accent", false)

	var tr := _box(rig, root, hitbox_area, "stalkerThighR_%d" % id, Vector3(0.16, 0.40, 0.18), Vector3(0.0, -0.19, 0.0), Vector3.ZERO, body_mat, rig.hip_r_pivot, id, "body", allow_limb_shadows)
	rig.limb_shadow_parts.append(tr)
	_box(rig, root, hitbox_area, "stalkerShinR_%d" % id, Vector3(0.13, 0.38, 0.16), Vector3(0.0, -0.18, 0.0), Vector3.ZERO, body_mat, rig.knee_r_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "stalkerFootR_%d" % id, Vector3(0.14, 0.10, 0.30), Vector3(0.0, -0.34, 0.07), Vector3.ZERO, accent_mat, rig.knee_r_pivot, id, "accent", false)


# ------------------------------------------------------------------------------
# 3. WEAVER — ASH WRAITH (Crooked oxidized-iron fiend with cage-helm & jagged rods)
# ------------------------------------------------------------------------------
func _build_weaver(
	rig: Rig,
	root: RigidBody3D,
	hitbox_area: Area3D,
	id: int,
	mats: Dictionary,
	allow_shadows: bool,
	allow_limb_shadows: bool
) -> void:
	var body_mat: Material = mats["body"]
	var accent_mat: Material = mats["accent"]
	var horn_mat: Material = mats["horn"]
	var visor_mat: Material = mats["visor"]

	# Crooked skeletal pelvis & asymmetric jagged ribcage torso
	_box(rig, root, hitbox_area, "wraithPelvis_%d" % id, Vector3(0.50, 0.18, 0.34), Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.06), accent_mat, rig.pelvis_pivot, id, "accent", false)
	_box(rig, root, hitbox_area, "wraithSpine_%d" % id, Vector3(0.32, 0.28, 0.26), Vector3(0.0, 0.15, -0.02), Vector3(0.08, 0.0, -0.06), accent_mat, rig.torso_pivot, id, "accent", false)
	var chest := _box(rig, root, hitbox_area, "wraithRibcage_%d" % id, Vector3(0.58, 0.42, 0.40), Vector3(0.02, 0.40, 0.03), Vector3(0.14, 0.06, 0.08), body_mat, rig.torso_pivot, id, "body", allow_shadows)
	rig.core_shadow_parts.append(chest)
	# Three crooked protruding iron rods/spikes sticking from back
	var rod1 := _cyl(rig, root, hitbox_area, "wraithRod1_%d" % id, 0.02, 0.06, 0.56, 4, Vector3(-0.18, 0.66, -0.18), Vector3(-0.38, 0.0, -0.44), horn_mat, rig.torso_pivot, id, "horn", allow_shadows)
	rig.core_shadow_parts.append(rod1)
	_cyl(rig, root, hitbox_area, "wraithRod2_%d" % id, 0.02, 0.065, 0.66, 4, Vector3(0.04, 0.72, -0.22), Vector3(-0.48, 0.0, 0.14), horn_mat, rig.torso_pivot, id, "horn", false)
	_cyl(rig, root, hitbox_area, "wraithRod3_%d" % id, 0.02, 0.055, 0.46, 4, Vector3(0.24, 0.60, -0.14), Vector3(-0.28, 0.0, 0.52), horn_mat, rig.torso_pivot, id, "horn", false)

	# Tilted iron cage-helm with vertical bars + twin vertical sulfur-green slits
	_box(rig, root, hitbox_area, "wraithCageHelm_%d" % id, Vector3(0.34, 0.38, 0.36), Vector3(0.0, 0.16, 0.02), Vector3(0.06, 0.0, 0.10), body_mat, rig.head_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "wraithBarCenter_%d" % id, Vector3(0.045, 0.34, 0.06), Vector3(0.0, 0.16, 0.21), Vector3(0.06, 0.0, 0.10), accent_mat, rig.head_pivot, id, "accent", false)
	_cyl(rig, root, hitbox_area, "wraithCrownL_%d" % id, 0.015, 0.05, 0.28, 4, Vector3(-0.12, 0.42, 0.0), Vector3(0.10, 0.0, -0.22), horn_mat, rig.head_pivot, id, "horn", false)
	_cyl(rig, root, hitbox_area, "wraithCrownR_%d" % id, 0.015, 0.05, 0.22, 4, Vector3(0.12, 0.38, -0.02), Vector3(-0.12, 0.0, 0.34), horn_mat, rig.head_pivot, id, "horn", false)
	_box(rig, root, hitbox_area, "wraithSlitL_%d" % id, Vector3(0.06, 0.18, 0.08), Vector3(-0.075, 0.16, 0.18), Vector3(0.06, 0.0, 0.10), visor_mat, rig.head_pivot, id, "visor", false)
	_box(rig, root, hitbox_area, "wraithSlitR_%d" % id, Vector3(0.06, 0.18, 0.08), Vector3(0.075, 0.16, 0.18), Vector3(0.06, 0.0, 0.10), visor_mat, rig.head_pivot, id, "visor", false)

	# Wiry splayed arms + forked twin iron talons
	var pl := _box(rig, root, hitbox_area, "wraithShoulderL_%d" % id, Vector3(0.24, 0.20, 0.26), Vector3(-0.04, 0.04, 0.0), Vector3(0.0, 0.0, -0.35), accent_mat, rig.shoulder_l_pivot, id, "accent", allow_limb_shadows)
	rig.limb_shadow_parts.append(pl)
	_box(rig, root, hitbox_area, "wraithBicepL_%d" % id, Vector3(0.13, 0.34, 0.14), Vector3(-0.04, -0.15, 0.0), Vector3(0.0, 0.0, -0.22), body_mat, rig.shoulder_l_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "wraithForearmL_%d" % id, Vector3(0.12, 0.34, 0.13), Vector3(0.0, -0.16, 0.02), Vector3.ZERO, body_mat, rig.elbow_l_pivot, id, "body", false)
	_cyl(rig, root, hitbox_area, "wraithTalonL1_%d" % id, 0.01, 0.055, 0.30, 4, Vector3(-0.04, -0.40, 0.04), Vector3(PI, 0.0, -0.18), horn_mat, rig.elbow_l_pivot, id, "horn", false)
	_cyl(rig, root, hitbox_area, "wraithTalonL2_%d" % id, 0.01, 0.05, 0.26, 4, Vector3(0.04, -0.38, 0.05), Vector3(PI, 0.0, 0.18), horn_mat, rig.elbow_l_pivot, id, "horn", false)

	var pr := _box(rig, root, hitbox_area, "wraithShoulderR_%d" % id, Vector3(0.20, 0.22, 0.24), Vector3(0.04, 0.02, 0.0), Vector3(0.0, 0.0, 0.28), accent_mat, rig.shoulder_r_pivot, id, "accent", allow_limb_shadows)
	rig.limb_shadow_parts.append(pr)
	_box(rig, root, hitbox_area, "wraithBicepR_%d" % id, Vector3(0.13, 0.34, 0.14), Vector3(0.04, -0.15, 0.0), Vector3(0.0, 0.0, 0.22), body_mat, rig.shoulder_r_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "wraithForearmR_%d" % id, Vector3(0.12, 0.34, 0.13), Vector3(0.0, -0.16, 0.02), Vector3.ZERO, body_mat, rig.elbow_r_pivot, id, "body", false)
	_cyl(rig, root, hitbox_area, "wraithTalonR1_%d" % id, 0.01, 0.055, 0.30, 4, Vector3(0.04, -0.40, 0.04), Vector3(PI, 0.0, 0.18), horn_mat, rig.elbow_r_pivot, id, "horn", false)
	_cyl(rig, root, hitbox_area, "wraithTalonR2_%d" % id, 0.01, 0.05, 0.26, 4, Vector3(-0.04, -0.38, 0.05), Vector3(PI, 0.0, -0.18), horn_mat, rig.elbow_r_pivot, id, "horn", false)

	# Gaunt legs with iron knee spurs
	var tl := _box(rig, root, hitbox_area, "wraithThighL_%d" % id, Vector3(0.15, 0.38, 0.17), Vector3(-0.01, -0.18, 0.0), Vector3.ZERO, body_mat, rig.hip_l_pivot, id, "body", allow_limb_shadows)
	rig.limb_shadow_parts.append(tl)
	_cyl(rig, root, hitbox_area, "wraithKneeSpurL_%d" % id, 0.01, 0.05, 0.18, 4, Vector3(0.0, 0.02, 0.13), Vector3(1.25, 0.0, 0.0), horn_mat, rig.knee_l_pivot, id, "horn", false)
	_box(rig, root, hitbox_area, "wraithShinL_%d" % id, Vector3(0.13, 0.36, 0.15), Vector3(0.0, -0.17, 0.0), Vector3.ZERO, body_mat, rig.knee_l_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "wraithFootL_%d" % id, Vector3(0.15, 0.10, 0.30), Vector3(0.0, -0.33, 0.06), Vector3.ZERO, accent_mat, rig.knee_l_pivot, id, "accent", false)

	var tr := _box(rig, root, hitbox_area, "wraithThighR_%d" % id, Vector3(0.15, 0.38, 0.17), Vector3(0.01, -0.18, 0.0), Vector3.ZERO, body_mat, rig.hip_r_pivot, id, "body", allow_limb_shadows)
	rig.limb_shadow_parts.append(tr)
	_cyl(rig, root, hitbox_area, "wraithKneeSpurR_%d" % id, 0.01, 0.05, 0.18, 4, Vector3(0.0, 0.02, 0.13), Vector3(1.25, 0.0, 0.0), horn_mat, rig.knee_r_pivot, id, "horn", false)
	_box(rig, root, hitbox_area, "wraithShinR_%d" % id, Vector3(0.13, 0.36, 0.15), Vector3(0.0, -0.17, 0.0), Vector3.ZERO, body_mat, rig.knee_r_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "wraithFootR_%d" % id, Vector3(0.15, 0.10, 0.30), Vector3(0.0, -0.33, 0.06), Vector3.ZERO, accent_mat, rig.knee_r_pivot, id, "accent", false)


# ------------------------------------------------------------------------------
# 4. LUNGER — IRON PROWLER (Low-slung coiled beast with dorsal spikes & huge claws)
# ------------------------------------------------------------------------------
func _build_lunger(
	rig: Rig,
	root: RigidBody3D,
	hitbox_area: Area3D,
	id: int,
	mats: Dictionary,
	allow_shadows: bool,
	allow_limb_shadows: bool
) -> void:
	var body_mat: Material = mats["body"]
	var accent_mat: Material = mats["accent"]
	var horn_mat: Material = mats["horn"]
	var visor_mat: Material = mats["visor"]

	# Low coiled beast pelvis & wide muscular hunched torso
	_box(rig, root, hitbox_area, "prowlerPelvis_%d" % id, Vector3(0.64, 0.24, 0.48), Vector3(0.0, 0.0, -0.04), Vector3(0.16, 0.0, 0.0), accent_mat, rig.pelvis_pivot, id, "accent", false)
	var chest := _box(rig, root, hitbox_area, "prowlerBack_%d" % id, Vector3(0.84, 0.44, 0.64), Vector3(0.0, 0.24, 0.08), Vector3(0.16, 0.0, 0.0), body_mat, rig.torso_pivot, id, "body", allow_shadows)
	rig.core_shadow_parts.append(chest)
	var hump := _box(rig, root, hitbox_area, "prowlerRidge_%d" % id, Vector3(0.56, 0.22, 0.56), Vector3(0.0, 0.46, -0.04), Vector3(0.24, 0.0, 0.0), accent_mat, rig.torso_pivot, id, "accent", allow_shadows)
	rig.core_shadow_parts.append(hump)

	# Row of 3 jagged dorsal spine spikes along the beast's arched back
	_cyl(rig, root, hitbox_area, "prowlerDorsal1_%d" % id, 0.02, 0.11, 0.40, 5, Vector3(0.0, 0.62, 0.10), Vector3(-0.22, 0.0, 0.0), horn_mat, rig.torso_pivot, id, "horn", false)
	_cyl(rig, root, hitbox_area, "prowlerDorsal2_%d" % id, 0.02, 0.10, 0.46, 5, Vector3(0.0, 0.64, -0.10), Vector3(-0.40, 0.0, 0.0), horn_mat, rig.torso_pivot, id, "horn", false)
	_cyl(rig, root, hitbox_area, "prowlerDorsal3_%d" % id, 0.02, 0.09, 0.34, 5, Vector3(0.0, 0.52, -0.28), Vector3(-0.56, 0.0, 0.0), horn_mat, rig.torso_pivot, id, "horn", false)

	# Low-slung wide horned beast helm jutting forward + wide flare visor
	_box(rig, root, hitbox_area, "prowlerSkull_%d" % id, Vector3(0.46, 0.30, 0.42), Vector3(0.0, 0.06, 0.08), Vector3(-0.18, 0.0, 0.0), body_mat, rig.head_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "prowlerJaw_%d" % id, Vector3(0.38, 0.12, 0.30), Vector3(0.0, -0.10, 0.16), Vector3(-0.10, 0.0, 0.0), accent_mat, rig.head_pivot, id, "accent", false)
	_cyl(rig, root, hitbox_area, "prowlerHornL_%d" % id, 0.02, 0.10, 0.44, 5, Vector3(-0.26, 0.16, 0.06), Vector3(0.32, 0.0, 0.82), horn_mat, rig.head_pivot, id, "horn", false)
	_cyl(rig, root, hitbox_area, "prowlerHornR_%d" % id, 0.02, 0.10, 0.44, 5, Vector3(0.26, 0.16, 0.06), Vector3(0.32, 0.0, -0.82), horn_mat, rig.head_pivot, id, "horn", false)
	_box(rig, root, hitbox_area, "prowlerVisor_%d" % id, Vector3(0.40, 0.09, 0.14), Vector3(0.0, 0.08, 0.26), Vector3(-0.18, 0.0, 0.0), visor_mat, rig.head_pivot, id, "visor", false)

	# Oversized gorilla-like arms + heavy spiked bracers + massive pounce claws
	var pl := _box(rig, root, hitbox_area, "prowlerShoulderL_%d" % id, Vector3(0.34, 0.30, 0.38), Vector3(-0.04, 0.04, 0.0), Vector3(0.0, 0.0, -0.25), body_mat, rig.shoulder_l_pivot, id, "body", allow_limb_shadows)
	rig.limb_shadow_parts.append(pl)
	_box(rig, root, hitbox_area, "prowlerBicepL_%d" % id, Vector3(0.22, 0.38, 0.24), Vector3(-0.03, -0.18, 0.02), Vector3.ZERO, body_mat, rig.shoulder_l_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "prowlerForearmL_%d" % id, Vector3(0.24, 0.40, 0.26), Vector3(0.0, -0.19, 0.04), Vector3.ZERO, accent_mat, rig.elbow_l_pivot, id, "accent", false)
	_cyl(rig, root, hitbox_area, "prowlerClawL1_%d" % id, 0.015, 0.09, 0.34, 4, Vector3(-0.06, -0.48, 0.06), Vector3(2.92, 0.0, -0.10), horn_mat, rig.elbow_l_pivot, id, "horn", false)
	_cyl(rig, root, hitbox_area, "prowlerClawL2_%d" % id, 0.015, 0.09, 0.34, 4, Vector3(0.06, -0.48, 0.06), Vector3(2.92, 0.0, 0.10), horn_mat, rig.elbow_l_pivot, id, "horn", false)

	var pr := _box(rig, root, hitbox_area, "prowlerShoulderR_%d" % id, Vector3(0.34, 0.30, 0.38), Vector3(0.04, 0.04, 0.0), Vector3(0.0, 0.0, 0.25), body_mat, rig.shoulder_r_pivot, id, "body", allow_limb_shadows)
	rig.limb_shadow_parts.append(pr)
	_box(rig, root, hitbox_area, "prowlerBicepR_%d" % id, Vector3(0.22, 0.38, 0.24), Vector3(0.03, -0.18, 0.02), Vector3.ZERO, body_mat, rig.shoulder_r_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "prowlerForearmR_%d" % id, Vector3(0.24, 0.40, 0.26), Vector3(0.0, -0.19, 0.04), Vector3.ZERO, accent_mat, rig.elbow_r_pivot, id, "accent", false)
	_cyl(rig, root, hitbox_area, "prowlerClawR1_%d" % id, 0.015, 0.09, 0.34, 4, Vector3(-0.06, -0.48, 0.06), Vector3(2.92, 0.0, -0.10), horn_mat, rig.elbow_r_pivot, id, "horn", false)
	_cyl(rig, root, hitbox_area, "prowlerClawR2_%d" % id, 0.015, 0.09, 0.34, 4, Vector3(0.06, -0.48, 0.06), Vector3(2.92, 0.0, 0.10), horn_mat, rig.elbow_r_pivot, id, "horn", false)

	# Short coiled muscular hind legs
	var tl := _box(rig, root, hitbox_area, "prowlerThighL_%d" % id, Vector3(0.24, 0.34, 0.28), Vector3(0.0, -0.15, 0.03), Vector3(-0.24, 0.0, 0.0), body_mat, rig.hip_l_pivot, id, "body", allow_limb_shadows)
	rig.limb_shadow_parts.append(tl)
	_box(rig, root, hitbox_area, "prowlerShinL_%d" % id, Vector3(0.20, 0.32, 0.22), Vector3(0.0, -0.15, -0.02), Vector3(0.18, 0.0, 0.0), body_mat, rig.knee_l_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "prowlerPawL_%d" % id, Vector3(0.24, 0.12, 0.36), Vector3(0.0, -0.29, 0.08), Vector3.ZERO, accent_mat, rig.knee_l_pivot, id, "accent", false)

	var tr := _box(rig, root, hitbox_area, "prowlerThighR_%d" % id, Vector3(0.24, 0.34, 0.28), Vector3(0.0, -0.15, 0.03), Vector3(-0.24, 0.0, 0.0), body_mat, rig.hip_r_pivot, id, "body", allow_limb_shadows)
	rig.limb_shadow_parts.append(tr)
	_box(rig, root, hitbox_area, "prowlerShinR_%d" % id, Vector3(0.20, 0.32, 0.22), Vector3(0.0, -0.15, -0.02), Vector3(0.18, 0.0, 0.0), body_mat, rig.knee_r_pivot, id, "body", false)
	_box(rig, root, hitbox_area, "prowlerPawR_%d" % id, Vector3(0.24, 0.12, 0.36), Vector3(0.0, -0.29, 0.08), Vector3.ZERO, accent_mat, rig.knee_r_pivot, id, "accent", false)


# ------------------------------------------------------------------------------
# Cached mesh & compound hitbox helpers
# ------------------------------------------------------------------------------
func _box(
	rig: Rig,
	root: RigidBody3D,
	hitbox_area: Area3D,
	part_name: String,
	size: Vector3,
	pos: Vector3,
	rot: Vector3,
	mat: Material,
	parent: Node3D,
	enemy_id: int,
	group: String,
	cast_shadow: bool
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = _get_box_mesh(size)
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("enemy_id", enemy_id)
	parent.add_child(mi)

	_register_part(rig, mi, group)

	if hitbox_area != null:
		var col := CollisionShape3D.new()
		col.shape = _get_box_shape(size)
		col.transform = _compute_transform_relative_to_root(mi, root)
		hitbox_area.add_child(col)

	return mi


func _cyl(
	rig: Rig,
	root: RigidBody3D,
	hitbox_area: Area3D,
	part_name: String,
	d_top: float,
	d_bot: float,
	h: float,
	segs: int,
	pos: Vector3,
	rot: Vector3,
	mat: Material,
	parent: Node3D,
	enemy_id: int,
	group: String,
	cast_shadow: bool
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = _get_cyl_mesh(d_top, d_bot, h, segs)
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("enemy_id", enemy_id)
	parent.add_child(mi)

	_register_part(rig, mi, group)

	if hitbox_area != null:
		var col := CollisionShape3D.new()
		col.shape = _get_cyl_shape(d_top, d_bot, h)
		col.transform = _compute_transform_relative_to_root(mi, root)
		hitbox_area.add_child(col)

	return mi


func _register_part(rig: Rig, mi: MeshInstance3D, group: String) -> void:
	rig.parts.append(mi)
	match group:
		"body":
			rig.body_parts.append(mi)
		"accent":
			rig.accent_parts.append(mi)
		"horn":
			rig.horn_parts.append(mi)
		"visor":
			rig.visor_parts.append(mi)


func _get_box_mesh(size: Vector3) -> BoxMesh:
	var key := "%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
	if not _box_mesh_cache.has(key):
		var box := BoxMesh.new()
		box.size = size
		_box_mesh_cache[key] = box
	return _box_mesh_cache[key]


func _get_box_shape(size: Vector3) -> BoxShape3D:
	var key := "%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
	if not _box_shape_cache.has(key):
		var shape := BoxShape3D.new()
		shape.size = size
		_box_shape_cache[key] = shape
	return _box_shape_cache[key]


func _get_cyl_mesh(d_top: float, d_bot: float, h: float, segs: int) -> CylinderMesh:
	var key := "%.3f_%.3f_%.3f_%d" % [d_top, d_bot, h, segs]
	if not _cyl_mesh_cache.has(key):
		var cyl := CylinderMesh.new()
		cyl.top_radius = d_top / 2.0
		cyl.bottom_radius = d_bot / 2.0
		cyl.height = h
		cyl.radial_segments = maxi(4, segs)
		cyl.rings = 1
		_cyl_mesh_cache[key] = cyl
	return _cyl_mesh_cache[key]


func _get_cyl_shape(d_top: float, d_bot: float, h: float) -> CylinderShape3D:
	var key := "%.3f_%.3f_%.3f" % [d_top, d_bot, h]
	if not _cyl_shape_cache.has(key):
		var shape := CylinderShape3D.new()
		shape.height = h
		shape.radius = maxf(d_top, d_bot) / 2.0
		_cyl_shape_cache[key] = shape
	return _cyl_shape_cache[key]


func _compute_transform_relative_to_root(node: Node3D, root_node: Node3D) -> Transform3D:
	var xform := node.transform
	var p := node.get_parent()
	while p is Node3D and p != root_node:
		xform = (p as Node3D).transform * xform
		p = p.get_parent()
	return xform
