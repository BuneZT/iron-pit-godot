class_name RadarProjector
extends RefCounted

const DEFAULT_SCAN_RADIUS: float = 38.0


## Projects world-space enemy XZ positions into player-relative rotated radar coordinates.
## Each output Vector3 encodes:
##   x = normalized screen-right coordinate in [-1.0, 1.0] (+X is right)
##   y = normalized screen-down coordinate in [-1.0, 1.0] (-Y is straight ahead / up)
##   z = raw distance / scan_radius (> 1.0 indicates out-of-range; x,y are unit-clamped to rim)
static func project(
	player_pos: Vector3,
	player_yaw: float,
	enemy_positions: PackedVector3Array,
	scan_radius: float = DEFAULT_SCAN_RADIUS
) -> PackedVector3Array:
	var safe_radius: float = maxf(0.1, scan_radius)
	var count: int = enemy_positions.size()
	var out_blips := PackedVector3Array()
	if count == 0:
		return out_blips
	out_blips.resize(count)

	var sin_yaw: float = sin(player_yaw)
	var cos_yaw: float = cos(player_yaw)
	var px: float = player_pos.x
	var pz: float = player_pos.z

	for i in range(count):
		var e_pos: Vector3 = enemy_positions[i]
		var dx: float = e_pos.x - px
		var dz: float = e_pos.z - pz

		# Iron Pit camera basis: forward = (sin(yaw), 0, cos(yaw)), right = (-cos(yaw), 0, sin(yaw))
		var ahead: float = dx * sin_yaw + dz * cos_yaw
		var right: float = -dx * cos_yaw + dz * sin_yaw

		var dist: float = sqrt(right * right + ahead * ahead)
		var dist_ratio: float = dist / safe_radius

		var rx: float = 0.0
		var ry: float = 0.0
		if dist_ratio > 1.0 and dist > 0.0001:
			rx = right / dist
			ry = -ahead / dist
		else:
			rx = right / safe_radius
			ry = -ahead / safe_radius

		out_blips[i] = Vector3(rx, ry, dist_ratio)

	return out_blips
