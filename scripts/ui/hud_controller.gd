class_name HUDController
extends CanvasLayer

const HEALTH_SEGMENT_COUNT: int = 10
const AMMO_PIP_COUNT: int = 12

var on_action_button_click: Callable
var on_master_volume_change: Callable
var on_music_volume_change: Callable
var on_sfx_volume_change: Callable
var on_toggle_mute: Callable
var on_render_scale_change: Callable
var on_graphics_quality_change: Callable

var wave_value: Label
var enemies_label: Label
var enemies_value: Label
var kills_value: Label
var health_text: Label
var health_bar_fill: ColorRect
var ammo_value: Label
var reload_hint: Label
var crosshair: Control
var _ch_lines: Array[ColorRect] = []
var _ch_dot: ColorRect
var damage_vignette: Control
var radar_widget: RadarWidget

var health_segments: Array[ColorRect] = []
var health_segment_highlights: Array[ColorRect] = []
var ammo_pips: Array[ColorRect] = []
var ammo_pip_highlights: Array[ColorRect] = []

var modal_overlay: Control
var modal_title: Label
var modal_subtitle: Label
var action_button: Button
var settings_button: Button
var chronicle_button: Button
var chronicle_modal: Control
var chronicle_card: PanelContainer
var chronicle_close_button: Button
var settings_modal: Control
var settings_card: PanelContainer
var settings_close_button: Button
var settings_back_button: Button
var wave_whisper: Control
var wave_whisper_label: Label

var render_scale_slider: HSlider
var render_scale_value: Label
var graphics_quality_button: Button
var master_vol_slider: HSlider
var master_vol_value: Label
var music_vol_slider: HSlider
var music_vol_value: Label
var sfx_vol_slider: HSlider
var sfx_vol_value: Label
var mute_button: Button

var _pixel_font: FontFile
var _tex_iron_plate: Texture2D
var _tex_iron_recess: Texture2D
var _tex_btn_iron_normal: Texture2D
var _tex_btn_iron_hover: Texture2D
var _tex_btn_iron_pressed: Texture2D
var _tex_btn_ember_normal: Texture2D
var _tex_btn_ember_hover: Texture2D
var _tex_btn_ember_pressed: Texture2D
var _tex_slider_grabber: Texture2D
var _tex_slider_grabber_hi: Texture2D
var _tex_icon_cross: Texture2D
var _tex_icon_shells: Texture2D

var _sb_iron_plate: StyleBoxTexture
var _sb_iron_recess: StyleBoxTexture
var _sb_whisper_recess: StyleBoxTexture
var _sb_btn_iron_normal: StyleBoxTexture
var _sb_btn_iron_hover: StyleBoxTexture
var _sb_btn_iron_pressed: StyleBoxTexture
var _sb_btn_ember_normal: StyleBoxTexture
var _sb_btn_ember_hover: StyleBoxTexture
var _sb_btn_ember_pressed: StyleBoxTexture
var _sb_slider_track: StyleBoxTexture
var _sb_slider_fill: StyleBoxFlat
var _sb_slider_fill_hi: StyleBoxFlat

var _crosshair_expand_timer: float = 0.0
var _crosshair_hit_timer: float = 0.0
var _vignette_timer: float = 0.0
var _blink_time: float = 0.0
var _is_expanded: bool = false
var _is_hit: bool = false

var _last_wave: int = -1
var _last_is_in_breather: int = -1
var _last_remaining_enemies: int = -1
var _last_kills: int = -1
var _last_score: int = -1
var _last_hp_int: int = -1
var _last_max_hp_int: int = -1
var _last_lit_segments: int = -1
var _last_ammo: int = -1
var _last_is_reloading: int = -1
var _last_status: String = ""


func _init(action_cb: Callable = Callable(), audio_callbacks: Dictionary = {}) -> void:
	name = "HUDController"
	layer = 10
	on_action_button_click = action_cb
	if audio_callbacks.has("on_master_volume_change"):
		on_master_volume_change = audio_callbacks["on_master_volume_change"]
	if audio_callbacks.has("on_music_volume_change"):
		on_music_volume_change = audio_callbacks["on_music_volume_change"]
	if audio_callbacks.has("on_sfx_volume_change"):
		on_sfx_volume_change = audio_callbacks["on_sfx_volume_change"]
	if audio_callbacks.has("on_toggle_mute"):
		on_toggle_mute = audio_callbacks["on_toggle_mute"]
	if audio_callbacks.has("on_render_scale_change"):
		on_render_scale_change = audio_callbacks["on_render_scale_change"]
	if audio_callbacks.has("on_graphics_quality_change"):
		on_graphics_quality_change = audio_callbacks["on_graphics_quality_change"]

	_load_retro_assets()
	_build_shared_styleboxes()
	_build_ui()


func _load_retro_assets() -> void:
	_pixel_font = load("res://assets/fonts/iron_pixel.fnt") as FontFile
	_tex_iron_plate = load("res://assets/textures/ui/iron_plate_9slice.png") as Texture2D
	_tex_iron_recess = load("res://assets/textures/ui/iron_recess_9slice.png") as Texture2D
	_tex_btn_iron_normal = load("res://assets/textures/ui/btn_iron_normal.png") as Texture2D
	_tex_btn_iron_hover = load("res://assets/textures/ui/btn_iron_hover.png") as Texture2D
	_tex_btn_iron_pressed = load("res://assets/textures/ui/btn_iron_pressed.png") as Texture2D
	_tex_btn_ember_normal = load("res://assets/textures/ui/btn_ember_normal.png") as Texture2D
	_tex_btn_ember_hover = load("res://assets/textures/ui/btn_ember_hover.png") as Texture2D
	_tex_btn_ember_pressed = load("res://assets/textures/ui/btn_ember_pressed.png") as Texture2D
	_tex_slider_grabber = load("res://assets/textures/ui/slider_grabber.png") as Texture2D
	_tex_slider_grabber_hi = load("res://assets/textures/ui/slider_grabber_hi.png") as Texture2D
	_tex_icon_cross = load("res://assets/textures/ui/icon_med_cross.png") as Texture2D
	_tex_icon_shells = load("res://assets/textures/ui/icon_twin_shells.png") as Texture2D


static func _make_9slice(
	tex: Texture2D,
	tex_margins: Vector4,
	content_margins: Vector4
) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = tex_margins.x
	sb.texture_margin_top = tex_margins.y
	sb.texture_margin_right = tex_margins.z
	sb.texture_margin_bottom = tex_margins.w
	sb.content_margin_left = content_margins.x
	sb.content_margin_top = content_margins.y
	sb.content_margin_right = content_margins.z
	sb.content_margin_bottom = content_margins.w
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return sb


func _build_shared_styleboxes() -> void:
	_sb_iron_plate = _make_9slice(_tex_iron_plate, Vector4(16, 16, 16, 16), Vector4(28, 24, 28, 24))
	_sb_iron_recess = _make_9slice(_tex_iron_recess, Vector4(8, 8, 8, 8), Vector4(14, 12, 14, 12))
	_sb_whisper_recess = _make_9slice(_tex_iron_recess, Vector4(8, 8, 8, 8), Vector4(18, 7, 18, 7))

	_sb_btn_iron_normal = _make_9slice(_tex_btn_iron_normal, Vector4(16, 8, 16, 8), Vector4(16, 8, 16, 8))
	_sb_btn_iron_hover = _make_9slice(_tex_btn_iron_hover, Vector4(16, 8, 16, 8), Vector4(16, 8, 16, 8))
	_sb_btn_iron_pressed = _make_9slice(_tex_btn_iron_pressed, Vector4(16, 8, 16, 8), Vector4(16, 8, 16, 8))

	_sb_btn_ember_normal = _make_9slice(_tex_btn_ember_normal, Vector4(16, 8, 16, 8), Vector4(20, 10, 20, 10))
	_sb_btn_ember_hover = _make_9slice(_tex_btn_ember_hover, Vector4(16, 8, 16, 8), Vector4(20, 10, 20, 10))
	_sb_btn_ember_pressed = _make_9slice(_tex_btn_ember_pressed, Vector4(16, 8, 16, 8), Vector4(20, 10, 20, 10))

	_sb_slider_track = _make_9slice(_tex_iron_recess, Vector4(6, 6, 6, 6), Vector4(4, 6, 4, 6))

	_sb_slider_fill = StyleBoxFlat.new()
	_sb_slider_fill.bg_color = Color("#b45309")
	_sb_slider_fill.border_color = Color("#f59e0b")
	_sb_slider_fill.border_width_top = 2
	_sb_slider_fill.border_width_bottom = 2
	_sb_slider_fill.border_color = Color("#d97706")

	_sb_slider_fill_hi = StyleBoxFlat.new()
	_sb_slider_fill_hi.bg_color = Color("#d97706")
	_sb_slider_fill_hi.border_color = Color("#fbbf24")
	_sb_slider_fill_hi.border_width_top = 2


func _style_label(lbl: Label, font_size: int, color: Color, shadow_px: int = 2) -> void:
	lbl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _pixel_font != null:
		lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.03, 0.96))
	lbl.add_theme_constant_override("shadow_offset_x", shadow_px)
	lbl.add_theme_constant_override("shadow_offset_y", shadow_px)
	lbl.add_theme_constant_override("shadow_outline_size", 0)


func _style_button(btn: Button, is_primary: bool = false, font_size: int = 16) -> void:
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.focus_mode = Control.FOCUS_NONE
	if _pixel_font != null:
		btn.add_theme_font_override("font", _pixel_font)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.03, 0.95))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 2)
	if is_primary:
		btn.add_theme_stylebox_override("normal", _sb_btn_ember_normal)
		btn.add_theme_stylebox_override("hover", _sb_btn_ember_hover)
		btn.add_theme_stylebox_override("pressed", _sb_btn_ember_pressed)
		btn.add_theme_color_override("font_color", Color("#fef3c7"))
		btn.add_theme_color_override("font_hover_color", Color("#ffffff"))
		btn.add_theme_color_override("font_pressed_color", Color("#fde68a"))
	else:
		btn.add_theme_stylebox_override("normal", _sb_btn_iron_normal)
		btn.add_theme_stylebox_override("hover", _sb_btn_iron_hover)
		btn.add_theme_stylebox_override("pressed", _sb_btn_iron_pressed)
		btn.add_theme_color_override("font_color", Color("#d6d6dc"))
		btn.add_theme_color_override("font_hover_color", Color("#fbbf24"))
		btn.add_theme_color_override("font_pressed_color", Color("#f59e0b"))


func _style_slider(slider: HSlider) -> void:
	slider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slider.focus_mode = Control.FOCUS_NONE
	slider.add_theme_stylebox_override("slider", _sb_slider_track)
	slider.add_theme_stylebox_override("grabber_area", _sb_slider_fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", _sb_slider_fill_hi)
	if _tex_slider_grabber != null:
		slider.add_theme_icon_override("grabber", _tex_slider_grabber)
	if _tex_slider_grabber_hi != null:
		slider.add_theme_icon_override("grabber_highlight", _tex_slider_grabber_hi)


func _make_etched_divider() -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dark_line := ColorRect.new()
	dark_line.custom_minimum_size = Vector2(0.0, 2.0)
	dark_line.color = Color("#08080a")
	dark_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(dark_line)
	var hi_line := ColorRect.new()
	hi_line.custom_minimum_size = Vector2(0.0, 1.0)
	hi_line.color = Color("#54545c")
	hi_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(hi_line)
	return wrap


func _build_ui() -> void:
	var hud_root := Control.new()
	hud_root.name = "hud"
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(hud_root)

	# 1. Heavy Blood Damage Vignette
	var vig_panel := Panel.new()
	vig_panel.name = "damageVignette"
	vig_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vig_sb := StyleBoxFlat.new()
	vig_sb.bg_color = Color(0.68, 0.08, 0.08, 0.16)
	vig_sb.border_color = Color(0.75, 0.09, 0.09, 0.88)
	vig_sb.border_width_left = 34
	vig_sb.border_width_top = 34
	vig_sb.border_width_right = 34
	vig_sb.border_width_bottom = 34
	vig_panel.add_theme_stylebox_override("panel", vig_sb)
	vig_panel.modulate.a = 0.0
	hud_root.add_child(vig_panel)
	damage_vignette = vig_panel

	# 2. Minimalist Floating Top-Center Wave Strip (NO background box) + Wave Whisper
	var top_container := VBoxContainer.new()
	top_container.name = "topContainer"
	top_container.anchor_left = 0.5
	top_container.anchor_right = 0.5
	top_container.offset_left = -240.0
	top_container.offset_right = 240.0
	top_container.offset_top = 12.0
	top_container.alignment = BoxContainer.ALIGNMENT_CENTER
	top_container.add_theme_constant_override("separation", 6)
	top_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(top_container)

	var top_strip := HBoxContainer.new()
	top_strip.name = "topBar"
	top_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	top_strip.add_theme_constant_override("separation", 12)
	top_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_container.add_child(top_strip)

	var wave_lbl := Label.new()
	wave_lbl.text = "WAVE"
	_style_label(wave_lbl, 14, Color("#9898a2"))
	top_strip.add_child(wave_lbl)

	wave_value = Label.new()
	wave_value.name = "waveValue"
	wave_value.text = "01"
	_style_label(wave_value, 16, Color("#f59e0b"))
	top_strip.add_child(wave_value)

	var sep1 := Label.new()
	sep1.text = "|"
	_style_label(sep1, 14, Color("#565660"))
	top_strip.add_child(sep1)

	enemies_label = Label.new()
	enemies_label.name = "enemiesLabel"
	enemies_label.text = "FIENDS"
	_style_label(enemies_label, 14, Color("#9898a2"))
	top_strip.add_child(enemies_label)

	enemies_value = Label.new()
	enemies_value.name = "enemiesValue"
	enemies_value.text = "05"
	_style_label(enemies_value, 16, Color("#f0eee8"))
	top_strip.add_child(enemies_value)

	var sep2 := Label.new()
	sep2.text = "|"
	_style_label(sep2, 14, Color("#565660"))
	top_strip.add_child(sep2)

	var kills_lbl := Label.new()
	kills_lbl.text = "SLAIN"
	_style_label(kills_lbl, 14, Color("#9898a2"))
	top_strip.add_child(kills_lbl)

	kills_value = Label.new()
	kills_value.name = "killsValue"
	kills_value.text = "00"
	_style_label(kills_value, 16, Color("#f0eee8"))
	top_strip.add_child(kills_value)

	# Subtle etched hairline beneath the floating wave strip
	var hairline_wrap := CenterContainer.new()
	hairline_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hairline_vbox := VBoxContainer.new()
	hairline_vbox.add_theme_constant_override("separation", 0)
	hairline_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hl_top := ColorRect.new()
	hl_top.custom_minimum_size = Vector2(300.0, 1.0)
	hl_top.color = Color(0.55, 0.55, 0.60, 0.45)
	hl_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hairline_vbox.add_child(hl_top)
	var hl_bot := ColorRect.new()
	hl_bot.custom_minimum_size = Vector2(300.0, 2.0)
	hl_bot.color = Color(0.03, 0.03, 0.04, 0.72)
	hl_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hairline_vbox.add_child(hl_bot)
	hairline_wrap.add_child(hairline_vbox)
	top_container.add_child(hairline_wrap)

	var whisper_panel := PanelContainer.new()
	whisper_panel.name = "waveWhisper"
	whisper_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	whisper_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	whisper_panel.visible = false
	whisper_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	whisper_panel.add_theme_stylebox_override("panel", _sb_whisper_recess)
	wave_whisper_label = Label.new()
	wave_whisper_label.name = "waveWhisperLabel"
	wave_whisper_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(wave_whisper_label, 14, Color("#fbbf24"))
	whisper_panel.add_child(wave_whisper_label)
	top_container.add_child(whisper_panel)
	wave_whisper = whisper_panel

	# 3. Classic Quake Chunky Pixel Crosshair with hard black shadow outline
	crosshair = Control.new()
	crosshair.name = "crosshair"
	crosshair.anchor_left = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -14.0
	crosshair.offset_top = -14.0
	crosshair.offset_right = 14.0
	crosshair.offset_bottom = 14.0
	crosshair.pivot_offset = Vector2(14.0, 14.0)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(crosshair)

	var line_rects: Array[Rect2] = [
		Rect2(13.0, 0.0, 2.0, 8.0),
		Rect2(13.0, 20.0, 2.0, 8.0),
		Rect2(0.0, 13.0, 8.0, 2.0),
		Rect2(20.0, 13.0, 8.0, 2.0),
	]
	for r in line_rects:
		var outline := ColorRect.new()
		outline.position = r.position - Vector2(1.0, 1.0)
		outline.size = r.size + Vector2(2.0, 2.0)
		outline.color = Color(0.02, 0.02, 0.03, 0.85)
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(outline)

		var cr := ColorRect.new()
		cr.position = r.position
		cr.size = r.size
		cr.color = Color("#e8e4da")
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(cr)
		_ch_lines.append(cr)

	var dot_outline := ColorRect.new()
	dot_outline.position = Vector2(11.0, 11.0)
	dot_outline.size = Vector2(6.0, 6.0)
	dot_outline.color = Color(0.02, 0.02, 0.03, 0.9)
	dot_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_child(dot_outline)

	_ch_dot = ColorRect.new()
	_ch_dot.position = Vector2(12.0, 12.0)
	_ch_dot.size = Vector2(4.0, 4.0)
	_ch_dot.color = Color("#f59e0b")
	_ch_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_child(_ch_dot)

	# 4. Minimalist Floating Bottom-Left Combined Armor + Ammo (NO background box)
	var vitals_vbox := VBoxContainer.new()
	vitals_vbox.name = "vitalsCluster"
	vitals_vbox.anchor_left = 0.0
	vitals_vbox.anchor_top = 1.0
	vitals_vbox.anchor_right = 0.0
	vitals_vbox.anchor_bottom = 1.0
	vitals_vbox.offset_left = 22.0
	vitals_vbox.offset_top = -92.0
	vitals_vbox.offset_right = 420.0
	vitals_vbox.offset_bottom = -20.0
	vitals_vbox.alignment = BoxContainer.ALIGNMENT_END
	vitals_vbox.add_theme_constant_override("separation", 10)
	vitals_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(vitals_vbox)

	# Row 1: Chunky Cross (+) Icon + Blocky HP + 10 Segmented Pixel Cells
	var health_row := HBoxContainer.new()
	health_row.name = "healthRow"
	health_row.add_theme_constant_override("separation", 10)
	health_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	health_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_vbox.add_child(health_row)

	var cross_icon := TextureRect.new()
	cross_icon.name = "healthIcon"
	cross_icon.texture = _tex_icon_cross
	cross_icon.custom_minimum_size = Vector2(28.0, 28.0)
	cross_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cross_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cross_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_row.add_child(cross_icon)

	health_text = Label.new()
	health_text.name = "healthText"
	health_text.text = "100"
	health_text.custom_minimum_size = Vector2(56.0, 0.0)
	health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(health_text, 24, Color("#ef4444"))
	health_row.add_child(health_text)

	var health_segs_hbox := HBoxContainer.new()
	health_segs_hbox.name = "healthSegments"
	health_segs_hbox.add_theme_constant_override("separation", 4)
	health_segs_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	health_segs_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_row.add_child(health_segs_hbox)

	for i in range(HEALTH_SEGMENT_COUNT):
		var cell_shadow := ColorRect.new()
		cell_shadow.custom_minimum_size = Vector2(12.0, 16.0)
		cell_shadow.color = Color(0.03, 0.03, 0.04, 0.92)
		cell_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		health_segs_hbox.add_child(cell_shadow)

		var cell_fill := ColorRect.new()
		cell_fill.position = Vector2(1.0, 1.0)
		cell_fill.size = Vector2(10.0, 12.0)
		cell_fill.color = Color("#dc2626")
		cell_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell_shadow.add_child(cell_fill)
		health_segments.append(cell_fill)

		var cell_hi := ColorRect.new()
		cell_hi.position = Vector2(1.0, 1.0)
		cell_hi.size = Vector2(10.0, 2.0)
		cell_hi.color = Color("#fca5a5")
		cell_hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell_shadow.add_child(cell_hi)
		health_segment_highlights.append(cell_hi)

	# Keep hidden normalized health_bar_fill tracker for API compatibility
	var bar_tracker := Control.new()
	bar_tracker.name = "healthBarTracker"
	bar_tracker.visible = false
	bar_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_vbox.add_child(bar_tracker)
	health_bar_fill = ColorRect.new()
	health_bar_fill.name = "healthBarFill"
	health_bar_fill.anchor_left = 0.0
	health_bar_fill.anchor_top = 0.0
	health_bar_fill.anchor_right = 1.0
	health_bar_fill.anchor_bottom = 1.0
	health_bar_fill.color = Color("#dc2626")
	bar_tracker.add_child(health_bar_fill)

	# Row 2: Twin Brass Shells Icon + Blocky Ammo + 12 Brass Shell Ticks + Conditional Reload Flash
	var ammo_row := HBoxContainer.new()
	ammo_row.name = "ammoRow"
	ammo_row.add_theme_constant_override("separation", 10)
	ammo_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	ammo_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_vbox.add_child(ammo_row)

	var shells_icon := TextureRect.new()
	shells_icon.name = "ammoIcon"
	shells_icon.texture = _tex_icon_shells
	shells_icon.custom_minimum_size = Vector2(28.0, 28.0)
	shells_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shells_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shells_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_row.add_child(shells_icon)

	ammo_value = Label.new()
	ammo_value.name = "ammoValue"
	ammo_value.text = "12"
	ammo_value.custom_minimum_size = Vector2(56.0, 0.0)
	ammo_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(ammo_value, 24, Color("#fbbf24"))
	ammo_row.add_child(ammo_value)

	var ammo_pips_hbox := HBoxContainer.new()
	ammo_pips_hbox.name = "ammoPips"
	ammo_pips_hbox.add_theme_constant_override("separation", 3)
	ammo_pips_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ammo_pips_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_row.add_child(ammo_pips_hbox)

	for i in range(AMMO_PIP_COUNT):
		var pip_shadow := ColorRect.new()
		pip_shadow.custom_minimum_size = Vector2(10.0, 16.0)
		pip_shadow.color = Color(0.03, 0.03, 0.04, 0.92)
		pip_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ammo_pips_hbox.add_child(pip_shadow)

		var pip_fill := ColorRect.new()
		pip_fill.position = Vector2(1.0, 1.0)
		pip_fill.size = Vector2(8.0, 12.0)
		pip_fill.color = Color("#d97706")
		pip_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip_shadow.add_child(pip_fill)
		ammo_pips.append(pip_fill)

		var pip_hi := ColorRect.new()
		pip_hi.position = Vector2(1.0, 1.0)
		pip_hi.size = Vector2(8.0, 2.0)
		pip_hi.color = Color("#fef08a")
		pip_hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip_shadow.add_child(pip_hi)
		ammo_pip_highlights.append(pip_hi)

	reload_hint = Label.new()
	reload_hint.name = "reloadHint"
	reload_hint.text = ""
	reload_hint.visible = false
	reload_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_label(reload_hint, 14, Color("#f59e0b"))
	ammo_row.add_child(reload_hint)

	# 5. Bottom-Right Circular Grimy Gunmetal Rotating Proximity Radar (no "SCAN 38M" text)
	radar_widget = RadarWidget.new()
	radar_widget.anchor_left = 1.0
	radar_widget.anchor_top = 1.0
	radar_widget.anchor_right = 1.0
	radar_widget.anchor_bottom = 1.0
	radar_widget.offset_left = -166.0
	radar_widget.offset_top = -166.0
	radar_widget.offset_right = -18.0
	radar_widget.offset_bottom = -18.0
	radar_widget.visible = false
	hud_root.add_child(radar_widget)

	# 6. Modal Overlay (Start / Pause / Game Over) — Grimy Gunmetal Iron Plate
	var overlay_bg := ColorRect.new()
	overlay_bg.name = "modalOverlay"
	overlay_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_bg.color = Color(0.03, 0.032, 0.04, 0.86)
	add_child(overlay_bg)
	modal_overlay = overlay_bg

	var center_box := CenterContainer.new()
	center_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_bg.add_child(center_box)

	var modal_card := PanelContainer.new()
	modal_card.name = "modalCard"
	modal_card.custom_minimum_size = Vector2(540.0, 0.0)
	modal_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modal_card.add_theme_stylebox_override("panel", _sb_iron_plate)
	center_box.add_child(modal_card)

	var card_vbox := VBoxContainer.new()
	card_vbox.name = "cardVBox"
	card_vbox.add_theme_constant_override("separation", 14)
	modal_card.add_child(card_vbox)

	modal_title = Label.new()
	modal_title.name = "modalTitle"
	modal_title.text = "IRON PIT"
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(modal_title, 32, Color("#f59e0b"), 3)
	card_vbox.add_child(modal_title)

	card_vbox.add_child(_make_etched_divider())

	modal_subtitle = Label.new()
	modal_subtitle.name = "modalSubtitle"
	modal_subtitle.text = LoreCatalog.INTRO_SUBTITLE
	modal_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_subtitle.custom_minimum_size = Vector2(460.0, 0.0)
	_style_label(modal_subtitle, 14, Color("#c2c0ba"))
	card_vbox.add_child(modal_subtitle)

	# Recessed Controls Grid
	var controls_panel := PanelContainer.new()
	controls_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	controls_panel.add_theme_stylebox_override("panel", _sb_iron_recess)
	card_vbox.add_child(controls_panel)

	var controls_grid := GridContainer.new()
	controls_grid.columns = 2
	controls_grid.add_theme_constant_override("h_separation", 28)
	controls_grid.add_theme_constant_override("v_separation", 8)
	controls_panel.add_child(controls_grid)

	var bindings: Array[Array] = [
		["WASD", "MOVE"],
		["MOUSE", "AIM"],
		["LMB", "FIRE"],
		["R", "RELOAD"],
		["SHIFT", "SPRINT"],
		["SPACE", "JUMP"],
	]
	for b in bindings:
		var lbl := Label.new()
		lbl.text = "[%s] %s" % [b[0], b[1]]
		_style_label(lbl, 14, Color("#d97706"))
		controls_grid.add_child(lbl)

	# Action Buttons (All custom beveled iron plates — zero default Godot widgets)
	action_button = Button.new()
	action_button.name = "actionButton"
	action_button.text = "ENTER THE PIT"
	action_button.custom_minimum_size = Vector2(0.0, 46.0)
	_style_button(action_button, true, 18)
	action_button.pressed.connect(func() -> void:
		if on_action_button_click.is_valid():
			on_action_button_click.call()
	)
	card_vbox.add_child(action_button)

	settings_button = Button.new()
	settings_button.name = "settingsButton"
	settings_button.text = "SETTINGS"
	settings_button.custom_minimum_size = Vector2(0.0, 38.0)
	_style_button(settings_button, false, 16)
	settings_button.pressed.connect(func() -> void:
		settings_modal.visible = true
	)
	card_vbox.add_child(settings_button)

	chronicle_button = Button.new()
	chronicle_button.name = "chronicleButton"
	chronicle_button.text = "THE CHRONICLE"
	chronicle_button.custom_minimum_size = Vector2(0.0, 38.0)
	_style_button(chronicle_button, false, 16)
	chronicle_button.pressed.connect(func() -> void:
		chronicle_modal.visible = true
	)
	card_vbox.add_child(chronicle_button)

	# 7. Settings Modal Overlay
	var sett_bg := ColorRect.new()
	sett_bg.name = "settingsModal"
	sett_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	sett_bg.color = Color(0.0, 0.0, 0.0, 0.88)
	sett_bg.visible = false
	sett_bg.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			sett_bg.visible = false
	)
	add_child(sett_bg)
	settings_modal = sett_bg

	var sett_center := CenterContainer.new()
	sett_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	sett_center.mouse_filter = Control.MOUSE_FILTER_PASS
	sett_bg.add_child(sett_center)

	var sett_card := PanelContainer.new()
	sett_card.name = "settingsCard"
	sett_card.custom_minimum_size = Vector2(620.0, 0.0)
	sett_card.mouse_filter = Control.MOUSE_FILTER_STOP
	sett_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sett_card.add_theme_stylebox_override("panel", _sb_iron_plate)
	sett_center.add_child(sett_card)
	settings_card = sett_card

	var sett_vbox := VBoxContainer.new()
	sett_vbox.add_theme_constant_override("separation", 12)
	sett_card.add_child(sett_vbox)

	var sett_header := HBoxContainer.new()
	sett_vbox.add_child(sett_header)

	var sett_title := Label.new()
	sett_title.text = "SETTINGS"
	sett_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(sett_title, 20, Color("#f59e0b"))
	sett_header.add_child(sett_title)

	settings_close_button = Button.new()
	settings_close_button.name = "settingsCloseButton"
	settings_close_button.text = "×"
	settings_close_button.custom_minimum_size = Vector2(36.0, 32.0)
	_style_button(settings_close_button, false, 16)
	settings_close_button.pressed.connect(func() -> void:
		settings_modal.visible = false
	)
	sett_header.add_child(settings_close_button)

	sett_vbox.add_child(_make_etched_divider())

	# Video Settings Recessed Section
	var video_panel := PanelContainer.new()
	video_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	video_panel.add_theme_stylebox_override("panel", _sb_iron_recess)
	var video_vbox := VBoxContainer.new()
	video_vbox.add_theme_constant_override("separation", 10)
	video_panel.add_child(video_vbox)

	var video_title := Label.new()
	video_title.text = "VIDEO"
	_style_label(video_title, 14, Color("#d97706"))
	video_vbox.add_child(video_title)

	var scale_row := _make_render_scale_slider_row(100.0, func(val: float) -> void:
		_update_render_scale_label(val)
		if self.on_render_scale_change.is_valid():
			self.on_render_scale_change.call(val / 100.0)
	)
	render_scale_slider = scale_row["slider"]
	render_scale_value = scale_row["value_label"]
	video_vbox.add_child(scale_row["row"])

	var quality_row := HBoxContainer.new()
	quality_row.add_theme_constant_override("separation", 12)
	var quality_lbl := Label.new()
	quality_lbl.text = "GRAPHICS QUALITY"
	quality_lbl.custom_minimum_size = Vector2(180.0, 0.0)
	quality_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(quality_lbl, 14, Color("#a8a8b2"))
	quality_row.add_child(quality_lbl)

	graphics_quality_button = Button.new()
	graphics_quality_button.name = "graphicsQualityButton"
	graphics_quality_button.text = "MEDIUM"
	graphics_quality_button.custom_minimum_size = Vector2(126.0, 32.0)
	_style_button(graphics_quality_button, false, 14)
	graphics_quality_button.pressed.connect(func() -> void:
		var next_q := _cycle_graphics_quality(graphics_quality_button.text)
		_update_graphics_quality_button(next_q)
		if self.on_graphics_quality_change.is_valid():
			self.on_graphics_quality_change.call(next_q)
	)
	quality_row.add_child(graphics_quality_button)
	_update_graphics_quality_button("MEDIUM")
	video_vbox.add_child(quality_row)

	sett_vbox.add_child(video_panel)

	# Audio Settings Recessed Section
	var audio_panel := PanelContainer.new()
	audio_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	audio_panel.add_theme_stylebox_override("panel", _sb_iron_recess)
	var audio_vbox := VBoxContainer.new()
	audio_vbox.add_theme_constant_override("separation", 10)
	audio_panel.add_child(audio_vbox)

	var audio_title := Label.new()
	audio_title.text = "AUDIO"
	_style_label(audio_title, 14, Color("#d97706"))
	audio_vbox.add_child(audio_title)

	var master_row := _make_slider_row("MASTER", 80.0, func(val: float) -> void:
		if master_vol_value != null:
			master_vol_value.text = "%d%%" % int(round(val))
		if self.on_master_volume_change.is_valid():
			self.on_master_volume_change.call(val / 100.0)
	)
	master_vol_slider = master_row["slider"]
	master_vol_value = master_row["value_label"]
	audio_vbox.add_child(master_row["row"])

	var music_row := _make_slider_row("MUSIC", 60.0, func(val: float) -> void:
		if music_vol_value != null:
			music_vol_value.text = "%d%%" % int(round(val))
		if self.on_music_volume_change.is_valid():
			self.on_music_volume_change.call(val / 100.0)
	)
	music_vol_slider = music_row["slider"]
	music_vol_value = music_row["value_label"]
	audio_vbox.add_child(music_row["row"])

	var sfx_row := _make_slider_row("SFX", 80.0, func(val: float) -> void:
		if sfx_vol_value != null:
			sfx_vol_value.text = "%d%%" % int(round(val))
		if self.on_sfx_volume_change.is_valid():
			self.on_sfx_volume_change.call(val / 100.0)
	)
	sfx_vol_slider = sfx_row["slider"]
	sfx_vol_value = sfx_row["value_label"]
	audio_vbox.add_child(sfx_row["row"])

	var mute_hbox := HBoxContainer.new()
	mute_hbox.alignment = BoxContainer.ALIGNMENT_END
	audio_vbox.add_child(mute_hbox)

	mute_button = Button.new()
	mute_button.name = "muteButton"
	mute_button.text = "MUTE AUDIO"
	mute_button.custom_minimum_size = Vector2(150.0, 32.0)
	_style_button(mute_button, false, 14)
	mute_button.pressed.connect(func() -> void:
		var is_muted := false
		if self.on_toggle_mute.is_valid():
			is_muted = bool(self.on_toggle_mute.call())
		_update_mute_button_label(is_muted)
	)
	mute_hbox.add_child(mute_button)
	sett_vbox.add_child(audio_panel)

	settings_back_button = Button.new()
	settings_back_button.name = "settingsBackButton"
	settings_back_button.text = "BACK"
	settings_back_button.custom_minimum_size = Vector2(0.0, 38.0)
	_style_button(settings_back_button, false, 16)
	settings_back_button.pressed.connect(func() -> void:
		settings_modal.visible = false
	)
	sett_vbox.add_child(settings_back_button)

	var sett_footer := Label.new()
	sett_footer.text = "PRESS [ESC] OR CLICK OUTSIDE TO RETURN"
	sett_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(sett_footer, 12, Color("#787882"))
	sett_vbox.add_child(sett_footer)

	# 8. Chronicle Modal Overlay
	var chron_bg := ColorRect.new()
	chron_bg.name = "chronicleModal"
	chron_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	chron_bg.color = Color(0.0, 0.0, 0.0, 0.88)
	chron_bg.visible = false
	chron_bg.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			chron_bg.visible = false
	)
	add_child(chron_bg)
	chronicle_modal = chron_bg

	var chron_center := CenterContainer.new()
	chron_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	chron_center.mouse_filter = Control.MOUSE_FILTER_PASS
	chron_bg.add_child(chron_center)

	var chron_card := PanelContainer.new()
	chron_card.name = "chronicleCard"
	chron_card.custom_minimum_size = Vector2(740.0, 0.0)
	chron_card.mouse_filter = Control.MOUSE_FILTER_STOP
	chron_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chron_card.add_theme_stylebox_override("panel", _sb_iron_plate)
	chron_center.add_child(chron_card)
	chronicle_card = chron_card

	var chron_vbox := VBoxContainer.new()
	chron_vbox.add_theme_constant_override("separation", 12)
	chron_card.add_child(chron_vbox)

	var chron_header := HBoxContainer.new()
	chron_vbox.add_child(chron_header)

	var chron_title := Label.new()
	chron_title.text = "CHRONICLE OF THE PIT"
	chron_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(chron_title, 20, Color("#f59e0b"))
	chron_header.add_child(chron_title)

	chronicle_close_button = Button.new()
	chronicle_close_button.name = "chronicleCloseButton"
	chronicle_close_button.text = "×"
	chronicle_close_button.custom_minimum_size = Vector2(36.0, 32.0)
	_style_button(chronicle_close_button, false, 16)
	chronicle_close_button.pressed.connect(func() -> void:
		chronicle_modal.visible = false
	)
	chron_header.add_child(chronicle_close_button)

	chron_vbox.add_child(_make_etched_divider())

	for ch in LoreCatalog.CHRONICLE_CHAPTERS:
		var ch_panel := PanelContainer.new()
		ch_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ch_panel.add_theme_stylebox_override("panel", _sb_iron_recess)
		var ch_vbox := VBoxContainer.new()
		ch_vbox.add_theme_constant_override("separation", 6)
		ch_panel.add_child(ch_vbox)

		var ch_title := Label.new()
		ch_title.text = String(ch["title"])
		_style_label(ch_title, 14, Color("#d97706"))
		ch_vbox.add_child(ch_title)

		var ch_body := Label.new()
		ch_body.text = String(ch["body"])
		ch_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ch_body.custom_minimum_size = Vector2(650.0, 0.0)
		_style_label(ch_body, 14, Color("#cfcdc8"), 1)
		ch_vbox.add_child(ch_body)

		chron_vbox.add_child(ch_panel)

	var chron_footer := Label.new()
	chron_footer.text = "PRESS [ESC] OR CLICK OUTSIDE TO RETURN"
	chron_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(chron_footer, 12, Color("#787882"))
	chron_vbox.add_child(chron_footer)


func _make_slider_row(label_text: String, initial_val: float, on_change: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(88.0, 0.0)
	_style_label(lbl, 14, Color("#a8a8b2"))
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = initial_val
	slider.custom_minimum_size = Vector2(0.0, 26.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(slider)
	slider.value_changed.connect(on_change)
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(round(initial_val))
	val_lbl.custom_minimum_size = Vector2(56.0, 0.0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(val_lbl, 14, Color("#fbbf24"))
	row.add_child(val_lbl)

	return {
		"row": row,
		"slider": slider,
		"value_label": val_lbl,
	}


func _make_render_scale_slider_row(initial_pct: float, on_change: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = "3D RENDER SCALE"
	lbl.custom_minimum_size = Vector2(180.0, 0.0)
	_style_label(lbl, 14, Color("#a8a8b2"))
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 50.0
	slider.max_value = 100.0
	slider.step = 5.0
	slider.value = initial_pct
	slider.custom_minimum_size = Vector2(0.0, 26.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(slider)
	slider.value_changed.connect(on_change)
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(165.0, 0.0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(val_lbl, 14, Color("#fbbf24"))
	row.add_child(val_lbl)

	_update_render_scale_label_node(val_lbl, initial_pct)

	return {
		"row": row,
		"slider": slider,
		"value_label": val_lbl,
	}


func _update_render_scale_label(pct: float) -> void:
	if render_scale_value != null:
		_update_render_scale_label_node(render_scale_value, pct)


func _update_render_scale_label_node(lbl: Label, pct: float) -> void:
	var factor := pct / 100.0
	var base_w := 1280.0
	var base_h := 720.0
	if is_inside_tree() and get_viewport() != null:
		var vp_size := get_viewport().get_visible_rect().size
		if vp_size.x > 0.0 and vp_size.y > 0.0:
			base_w = vp_size.x
			base_h = vp_size.y
	var w := int(round(base_w * factor))
	var h := int(round(base_h * factor))
	lbl.text = "%d%% [%d×%d]" % [int(round(pct)), w, h]


static func _cycle_graphics_quality(current: String) -> String:
	match current.strip_edges().to_upper():
		"LOW":
			return "MEDIUM"
		"MEDIUM":
			return "HIGH"
		"HIGH":
			return "LOW"
		_:
			return "MEDIUM"


func _update_graphics_quality_button(quality: String) -> void:
	if graphics_quality_button == null:
		return
	var norm := GameSettings._normalize_quality(quality)
	graphics_quality_button.text = norm
	var col := Color("#fbbf24")
	if norm == "LOW":
		col = Color("#34d399")
	elif norm == "HIGH":
		col = Color("#f87171")
	graphics_quality_button.add_theme_color_override("font_color", col)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE:
			if settings_modal != null and settings_modal.visible:
				settings_modal.visible = false
				get_viewport().set_input_as_handled()
			elif chronicle_modal != null and chronicle_modal.visible:
				chronicle_modal.visible = false
				get_viewport().set_input_as_handled()


func handle_escape_key() -> bool:
	if settings_modal != null and settings_modal.visible:
		settings_modal.visible = false
		return true
	if chronicle_modal != null and chronicle_modal.visible:
		chronicle_modal.visible = false
		return true
	return false


func sync_settings(data: Dictionary) -> void:
	var master_pct := int(round(float(data.get("master_volume", 0.8)) * 100.0))
	var music_pct := int(round(float(data.get("music_volume", 0.6)) * 100.0))
	var sfx_pct := int(round(float(data.get("sfx_volume", 0.8)) * 100.0))
	var is_muted := bool(data.get("is_muted", false))
	var render_scale_pct := int(round(float(data.get("render_scale", 1.0)) * 100.0))
	var graphics_quality := String(data.get("graphics_quality", "MEDIUM"))

	if master_vol_slider != null:
		master_vol_slider.set_value_no_signal(float(master_pct))
	if master_vol_value != null:
		master_vol_value.text = "%d%%" % master_pct

	if music_vol_slider != null:
		music_vol_slider.set_value_no_signal(float(music_pct))
	if music_vol_value != null:
		music_vol_value.text = "%d%%" % music_pct

	if sfx_vol_slider != null:
		sfx_vol_slider.set_value_no_signal(float(sfx_pct))
	if sfx_vol_value != null:
		sfx_vol_value.text = "%d%%" % sfx_pct

	if render_scale_slider != null:
		render_scale_slider.set_value_no_signal(float(render_scale_pct))
	if render_scale_value != null:
		_update_render_scale_label(float(render_scale_pct))

	_update_graphics_quality_button(graphics_quality)
	_update_mute_button_label(is_muted)


func sync_audio_settings(data: Dictionary) -> void:
	sync_settings(data)


func _update_mute_button_label(is_muted: bool) -> void:
	if mute_button != null:
		mute_button.text = "UNMUTE AUDIO" if is_muted else "MUTE AUDIO"
		mute_button.add_theme_color_override(
			"font_color",
			Color("#ef4444") if is_muted else Color("#d6d6dc")
		)


func _update_health_segments(lit_count: int) -> void:
	for i in range(health_segments.size()):
		var is_lit := i < lit_count
		health_segments[i].color = Color("#dc2626") if is_lit else Color("#1c1b1f")
		health_segment_highlights[i].color = Color("#fca5a5") if is_lit else Color("#28272c")


func _update_ammo_pips(ammo: int) -> void:
	for i in range(ammo_pips.size()):
		var is_loaded := i < ammo
		ammo_pips[i].color = Color("#d97706") if is_loaded else Color("#1c1b1f")
		ammo_pip_highlights[i].color = Color("#fef08a") if is_loaded else Color("#28272c")


func update_hud(snapshot: Dictionary) -> void:
	var wave: int = maxi(1, int(snapshot.get("wave", 1)))
	var is_in_breather: bool = bool(snapshot.get("is_in_breather", false))
	var breather_int: int = 1 if is_in_breather else 0
	var remaining_enemies: int = int(snapshot.get("remaining_enemies", 0))
	var kills: int = int(snapshot.get("kills", 0))
	var score: int = int(snapshot.get("score", 0))
	var hp: float = float(snapshot.get("hp", 100.0))
	var max_hp: float = maxf(1.0, float(snapshot.get("max_hp", 100.0)))
	var hp_int: int = int(round(hp))
	var max_hp_int: int = int(round(max_hp))
	var ammo: int = int(snapshot.get("ammo", 12))
	var is_reloading: bool = bool(snapshot.get("is_reloading", false))
	var reloading_int: int = 1 if is_reloading else 0
	var status: String = String(snapshot.get("status", "MENU"))

	var wave_changed := (wave != _last_wave)
	var breather_changed := (breather_int != _last_is_in_breather)
	var remaining_changed := (remaining_enemies != _last_remaining_enemies)
	var kills_changed := (kills != _last_kills)
	var score_changed := (score != _last_score)
	var status_changed := (status != _last_status)

	if wave_changed:
		wave_value.text = "%02d" % wave

	if breather_changed or remaining_changed:
		enemies_label.text = "STATUS" if is_in_breather else "FIENDS"
		enemies_value.text = "PURGED" if is_in_breather else ("%02d" % remaining_enemies)
		enemies_value.add_theme_color_override(
			"font_color",
			Color("#f59e0b") if is_in_breather else Color("#f0eee8")
		)

	if kills_changed:
		kills_value.text = "%02d" % kills

	if hp_int != _last_hp_int or max_hp_int != _last_max_hp_int:
		_last_hp_int = hp_int
		_last_max_hp_int = max_hp_int
		health_text.text = "%d" % hp_int

	var hp_ratio := clampf(hp / max_hp, 0.0, 1.0)
	if absf(health_bar_fill.anchor_right - hp_ratio) > 0.001:
		health_bar_fill.anchor_right = hp_ratio

	var lit_segments := int(ceil(hp_ratio * float(HEALTH_SEGMENT_COUNT)))
	if hp <= 0.0:
		lit_segments = 0
	if lit_segments != _last_lit_segments:
		_last_lit_segments = lit_segments
		_update_health_segments(lit_segments)

	if ammo != _last_ammo or reloading_int != _last_is_reloading:
		if ammo != _last_ammo:
			ammo_value.text = "%02d" % ammo
			_update_ammo_pips(ammo)
		var target_hint := ""
		var hint_col := Color("#f59e0b")
		if is_reloading:
			target_hint = "RELOADING..."
			hint_col = Color("#fbbf24")
		elif ammo == 0:
			target_hint = "[R] RELOAD"
			hint_col = Color("#ef4444")
		elif ammo <= 3:
			target_hint = "LOW [R]"
			hint_col = Color("#f59e0b")
		reload_hint.text = target_hint
		reload_hint.visible = (target_hint != "")
		reload_hint.add_theme_color_override("font_color", hint_col)
		_last_ammo = ammo
		_last_is_reloading = reloading_int

	if radar_widget != null:
		var show_radar := (status == "PLAYING")
		if radar_widget.visible != show_radar:
			radar_widget.visible = show_radar
		if snapshot.has("radar_blips") and snapshot["radar_blips"] is PackedVector3Array:
			radar_widget.set_blips(snapshot["radar_blips"])
		elif not show_radar and radar_widget.blips.size() > 0:
			radar_widget.set_blips(PackedVector3Array())

	if wave_whisper != null and (breather_changed or wave_changed):
		if is_in_breather:
			var whisper_text := LoreCatalog.get_wave_whisper(wave)
			if wave_whisper_label.text != whisper_text:
				wave_whisper_label.text = whisper_text
			wave_whisper.visible = true
		else:
			wave_whisper.visible = false

	if status == "PLAYING":
		if status_changed or modal_overlay.visible:
			modal_overlay.visible = false
			chronicle_modal.visible = false
			if settings_modal != null:
				settings_modal.visible = false
	else:
		modal_overlay.visible = true
		if status_changed or wave_changed or kills_changed or score_changed:
			if status == "MENU":
				modal_title.text = "IRON PIT"
				modal_subtitle.text = LoreCatalog.INTRO_SUBTITLE
				action_button.text = "ENTER THE PIT"
			elif status == "PAUSED":
				modal_title.text = "PAUSED"
				modal_subtitle.text = "Wave %d suspended — %d hostiles slain." % [wave, kills]
				action_button.text = "RESUME FIGHT"
			elif status == "GAME_OVER":
				modal_title.text = "OVERRUN"
				modal_subtitle.text = LoreCatalog.get_game_over_message(wave, kills, score)
				action_button.text = "RETURN TO PIT"

	_last_wave = wave
	_last_is_in_breather = breather_int
	_last_remaining_enemies = remaining_enemies
	_last_kills = kills
	_last_score = score
	_last_status = status


func pulse_crosshair(hit_enemy: bool) -> void:
	_is_expanded = true
	crosshair.scale = Vector2(1.4, 1.4)
	_crosshair_expand_timer = 0.09

	if hit_enemy:
		_is_hit = true
		_set_crosshair_hit_color(true)
		_crosshair_hit_timer = 0.14


func _set_crosshair_hit_color(hit: bool) -> void:
	var line_col := Color("#dc2626") if hit else Color("#e8e4da")
	var dot_col := Color("#dc2626") if hit else Color("#f59e0b")
	for cr in _ch_lines:
		cr.color = line_col
	if _ch_dot != null:
		_ch_dot.color = dot_col


func flash_damage_vignette() -> void:
	damage_vignette.modulate.a = 1.0
	_vignette_timer = 0.22


func trigger_damage_vignette() -> void:
	flash_damage_vignette()


func _process(delta: float) -> void:
	var dt := minf(delta, 0.1)
	if _crosshair_expand_timer > 0.0:
		_crosshair_expand_timer -= dt
		if _crosshair_expand_timer <= 0.0:
			_is_expanded = false
			crosshair.scale = Vector2.ONE

	if _crosshair_hit_timer > 0.0:
		_crosshair_hit_timer -= dt
		if _crosshair_hit_timer <= 0.0:
			_is_hit = false
			_set_crosshair_hit_color(false)

	if _vignette_timer > 0.0:
		_vignette_timer -= dt
		if _vignette_timer <= 0.0:
			damage_vignette.modulate.a = 0.0

	if reload_hint != null and reload_hint.visible:
		_blink_time += dt
		reload_hint.modulate.a = 1.0 if sin(_blink_time * 8.0) >= -0.2 else 0.4
