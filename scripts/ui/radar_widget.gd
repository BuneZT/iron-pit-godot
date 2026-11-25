class_name RadarWidget
extends Control

const WIDGET_SIZE: float = 148.0
const PIXEL_STEP: float = 2.0
const INNER_RADIUS: float = 54.0

const COL_FOV_FILL := Color(0.72, 0.42, 0.08, 0.14)
const COL_RING_DIM := Color("#573c18")
const COL_RING_OUTER := Color("#946220")
const COL_AXIS := Color(0.34, 0.23, 0.09, 0.82)
const COL_BLIP_OUTLINE := Color("#450a0a")
const COL_BLIP_CORE := Color("#ef4444")
const COL_BLIP_CLOSE := Color("#ff3b2f")
const COL_BLIP_HOT := Color("#fecaca")
const COL_RIM_OUTLINE := Color("#070606")
const COL_RIM_CORE := Color("#f59e0b")
const COL_RIM_HOT := Color("#fef3c7")
const COL_PLAYER_OUTLINE := Color("#050506")
const COL_PLAYER_CORE := Color("#f5f5f0")

var bezel_texture: Texture2D
var blips: PackedVector3Array = PackedVector3Array()

var _center: Vector2 = Vector2(74.0, 74.0)
var _pulse_time: float = 0.0
var _fov_poly: PackedVector2Array = PackedVector2Array()
var _inner_ring_pts: PackedVector2Array = PackedVector2Array()
var _mid_ring_pts: PackedVector2Array = PackedVector2Array()
var _outer_ring_pts: PackedVector2Array = PackedVector2Array()
var _axis_pts: PackedVector2Array = PackedVector2Array()


func _init() -> void:
	name = "radarWidget"
	custom_minimum_size = Vector2(WIDGET_SIZE, WIDGET_SIZE)
	size = Vector2(WIDGET_SIZE, WIDGET_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bezel_texture = load("res://assets/textures/ui/radar_bezel.png") as Texture2D
	_precompute_geometry()


func _precompute_geometry() -> void:
	_center = Vector2(WIDGET_SIZE * 0.5, WIDGET_SIZE * 0.5)

	# Precompute forward FOV wedge polygon (±32 deg around straight up = -PI/2)
	_fov_poly = PackedVector2Array()
	_fov_poly.append(_center)
	var half_fov := deg_to_rad(32.0)
	var steps := 10
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var ang := -PI * 0.5 - half_fov + t * (half_fov * 2.0)
		_fov_poly.append(_center + Vector2(cos(ang), sin(ang)) * (INNER_RADIUS - 2.0))

	_inner_ring_pts = _build_pixel_circle(INNER_RADIUS * 0.36, 12.0)
	_mid_ring_pts = _build_pixel_circle(INNER_RADIUS * 0.70, 7.0)
	_outer_ring_pts = _build_pixel_circle(INNER_RADIUS - 2.0, 3.0)

	_axis_pts = PackedVector2Array()
	var span := int(INNER_RADIUS) - 4
	var step := 4
	var offset := -span
	while offset <= span:
		if abs(offset) >= 6:
			_axis_pts.append(_snap_px(Vector2(_center.x + float(offset), _center.y)))
			_axis_pts.append(_snap_px(Vector2(_center.x, _center.y + float(offset))))
		offset += step


func _build_pixel_circle(radius: float, deg_step: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var deg := 0.0
	while deg < 360.0:
		var rad := deg_to_rad(deg)
		var p := Vector2(_center.x + cos(rad) * radius, _center.y + sin(rad) * radius)
		pts.append(_snap_px(p))
		deg += deg_step
	return pts


static func _snap_px(v: Vector2) -> Vector2:
	return Vector2(floor(v.x / PIXEL_STEP) * PIXEL_STEP, floor(v.y / PIXEL_STEP) * PIXEL_STEP)


func set_blips(new_blips: PackedVector3Array) -> void:
	blips = new_blips
	if visible:
		queue_redraw()


func _process(delta: float) -> void:
	if not visible or blips.is_empty():
		return
	var dt := minf(delta, 0.1)
	_pulse_time += dt
	queue_redraw()


func _draw() -> void:
	var px_size := Vector2(PIXEL_STEP, PIXEL_STEP)

	if bezel_texture != null:
		draw_texture_rect(bezel_texture, Rect2(Vector2.ZERO, size), false)

	# 1. Subtle forward FOV cone
	if _fov_poly.size() >= 3:
		draw_colored_polygon(_fov_poly, COL_FOV_FILL)

	# 2. Stepped-pixel range rings & dotted crosshair axes
	for pt in _axis_pts:
		draw_rect(Rect2(pt, px_size), COL_AXIS)
	for pt in _inner_ring_pts:
		draw_rect(Rect2(pt, px_size), COL_RING_DIM)
	for pt in _mid_ring_pts:
		draw_rect(Rect2(pt, px_size), COL_RING_DIM)
	for pt in _outer_ring_pts:
		draw_rect(Rect2(pt, px_size), COL_RING_OUTER)

	# 3. Enemy blips (in-range crimson squares + out-of-range amber rim ticks)
	var pulse_on := sin(_pulse_time * 9.0) > 0.0
	var max_blip_r := INNER_RADIUS - 6.0
	var rim_r := INNER_RADIUS - 4.0

	for i in range(blips.size()):
		var b: Vector3 = blips[i]
		if b.z > 1.0:
			var rp := _snap_px(Vector2(_center.x + b.x * rim_r, _center.y + b.y * rim_r))
			draw_rect(Rect2(rp - Vector2(4.0, 4.0), Vector2(10.0, 10.0)), COL_RIM_OUTLINE)
			draw_rect(Rect2(rp - Vector2(2.0, 2.0), Vector2(6.0, 6.0)), COL_RIM_CORE)
			draw_rect(Rect2(rp, px_size), COL_RIM_HOT)
		else:
			var bp := _snap_px(Vector2(_center.x + b.x * max_blip_r, _center.y + b.y * max_blip_r))
			var is_close := b.z <= 0.28
			var core_col := COL_BLIP_CLOSE if (is_close and pulse_on) else COL_BLIP_CORE
			draw_rect(Rect2(bp - Vector2(4.0, 4.0), Vector2(10.0, 10.0)), COL_BLIP_OUTLINE)
			draw_rect(Rect2(bp - Vector2(2.0, 2.0), Vector2(6.0, 6.0)), core_col)
			draw_rect(Rect2(bp, px_size), COL_BLIP_HOT)

	# 5. Center player pixel chevron pointing UP (straight ahead)
	var c := _snap_px(_center)
	draw_rect(Rect2(c + Vector2(-4.0, -6.0), Vector2(10.0, 12.0)), COL_PLAYER_OUTLINE)
	draw_rect(Rect2(c + Vector2(0.0, -4.0), Vector2(2.0, 8.0)), COL_PLAYER_CORE)
	draw_rect(Rect2(c + Vector2(-2.0, 0.0), Vector2(6.0, 4.0)), COL_PLAYER_CORE)
