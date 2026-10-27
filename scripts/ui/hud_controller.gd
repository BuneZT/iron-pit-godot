class_name HUDController
extends CanvasLayer

var on_action_button_click: Callable
var on_master_volume_change: Callable
var on_music_volume_change: Callable
var on_sfx_volume_change: Callable
var on_toggle_mute: Callable
var on_render_scale_change: Callable

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

var modal_overlay: Control
var modal_title: Label
var modal_subtitle: Label
var action_button: Button
var settings_button: Button
var chronicle_button: Button
var chronicle_modal: Control
var chronicle_close_button: Button
var settings_modal: Control
var settings_close_button: Button
var settings_back_button: Button
var wave_whisper: Control
var wave_whisper_label: Label

var render_scale_slider: HSlider
var render_scale_value: Label
var master_vol_slider: HSlider
var master_vol_value: Label
var music_vol_slider: HSlider
var music_vol_value: Label
var sfx_vol_slider: HSlider
var sfx_vol_value: Label
var mute_button: Button

var _crosshair_expand_timer: float = 0.0
var _crosshair_hit_timer: float = 0.0
var _vignette_timer: float = 0.0
var _is_expanded: bool = false
var _is_hit: bool = false


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

	_build_ui()


static func _make_iron_stylebox(
	bg_color: Color,
	border_color: Color,
	border_widths: Vector4i,
	accent_side: String = "",
	accent_color: Color = Color.TRANSPARENT,
	accent_width: int = 4,
	padding: Vector4i = Vector4i(16, 10, 16, 10)
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.border_width_left = border_widths.x
	sb.border_width_top = border_widths.y
	sb.border_width_right = border_widths.z
	sb.border_width_bottom = border_widths.w
	if accent_side == "bottom":
		sb.border_width_bottom = accent_width
		sb.border_color = accent_color
	elif accent_side == "top":
		sb.border_width_top = accent_width
		sb.border_color = accent_color
	elif accent_side == "left":
		sb.border_width_left = accent_width
		sb.border_color = accent_color
	elif accent_side == "right":
		sb.border_width_right = accent_width
		sb.border_color = accent_color
	sb.content_margin_left = float(padding.x)
	sb.content_margin_top = float(padding.y)
	sb.content_margin_right = float(padding.z)
	sb.content_margin_bottom = float(padding.w)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	sb.shadow_size = 12
	return sb


func _build_ui() -> void:
	var hud_root := Control.new()
	hud_root.name = "hud"
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_root)

	# 1. Heavy Blood Damage Vignette
	var vig_panel := Panel.new()
	vig_panel.name = "damageVignette"
	vig_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vig_sb := StyleBoxFlat.new()
	vig_sb.bg_color = Color(0.72, 0.11, 0.11, 0.18)
	vig_sb.border_color = Color(0.72, 0.11, 0.11, 0.88)
	vig_sb.border_width_left = 36
	vig_sb.border_width_top = 36
	vig_sb.border_width_right = 36
	vig_sb.border_width_bottom = 36
	vig_panel.add_theme_stylebox_override("panel", vig_sb)
	vig_panel.modulate.a = 0.0
	hud_root.add_child(vig_panel)
	damage_vignette = vig_panel

	# 2. Top Container (Top Bar + Wave Whisper)
	var top_container := VBoxContainer.new()
	top_container.name = "topContainer"
	top_container.anchor_left = 0.5
	top_container.anchor_right = 0.5
	top_container.offset_left = -200.0
	top_container.offset_right = 200.0
	top_container.offset_top = 18.0
	top_container.alignment = BoxContainer.ALIGNMENT_CENTER
	top_container.add_theme_constant_override("separation", 12)
	top_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(top_container)

	var top_bar := PanelContainer.new()
	top_bar.name = "topBar"
	top_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_stylebox_override(
		"panel",
		_make_iron_stylebox(
			Color("#1c1a18"),
			Color("#4a4440"),
			Vector4i(2, 2, 2, 4),
			"bottom",
			Color("#b45309"),
			4,
			Vector4i(26, 8, 26, 8)
		)
	)
	top_container.add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 28)
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_child(top_hbox)

	var wave_block := _make_stat_block("WAVE", "1", Color("#f59e0b"))
	wave_value = wave_block["value_label"]
	top_hbox.add_child(wave_block["container"])

	var hostiles_block := _make_stat_block("HOSTILES", "5", Color("#f3f4f6"))
	enemies_label = hostiles_block["title_label"]
	enemies_value = hostiles_block["value_label"]
	top_hbox.add_child(hostiles_block["container"])

	var kills_block := _make_stat_block("KILLS", "0", Color("#f3f4f6"))
	kills_value = kills_block["value_label"]
	top_hbox.add_child(kills_block["container"])

	var whisper_panel := PanelContainer.new()
	whisper_panel.name = "waveWhisper"
	whisper_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	whisper_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	whisper_panel.visible = false
	whisper_panel.add_theme_stylebox_override(
		"panel",
		_make_iron_stylebox(
			Color(0.07, 0.067, 0.063, 0.92),
			Color("#d97706"),
			Vector4i(3, 1, 3, 1),
			"",
			Color.TRANSPARENT,
			1,
			Vector4i(20, 6, 20, 6)
		)
	)
	wave_whisper_label = Label.new()
	wave_whisper_label.name = "waveWhisperLabel"
	wave_whisper_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_whisper_label.add_theme_color_override("font_color", Color("#fbbf24"))
	wave_whisper_label.add_theme_font_size_override("font_size", 13)
	whisper_panel.add_child(wave_whisper_label)
	top_container.add_child(whisper_panel)
	wave_whisper = whisper_panel

	# 3. Classic Quake Chunky Crosshair
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
		var cr := ColorRect.new()
		cr.position = r.position
		cr.size = r.size
		cr.color = Color("#f3f4f6")
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(cr)
		_ch_lines.append(cr)

	_ch_dot = ColorRect.new()
	_ch_dot.position = Vector2(12.0, 12.0)
	_ch_dot.size = Vector2(4.0, 4.0)
	_ch_dot.color = Color("#f59e0b")
	_ch_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_child(_ch_dot)

	# 4. Bottom-Left Health Panel
	var health_panel := PanelContainer.new()
	health_panel.name = "healthPanel"
	health_panel.anchor_left = 0.0
	health_panel.anchor_top = 1.0
	health_panel.anchor_right = 0.0
	health_panel.anchor_bottom = 1.0
	health_panel.offset_left = 24.0
	health_panel.offset_bottom = -24.0
	health_panel.offset_right = 294.0
	health_panel.offset_top = -96.0
	health_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_panel.add_theme_stylebox_override(
		"panel",
		_make_iron_stylebox(
			Color("#1c1a18"),
			Color("#dc2626"),
			Vector4i(5, 2, 2, 2),
			"left",
			Color("#dc2626"),
			5,
			Vector4i(16, 10, 16, 10)
		)
	)
	hud_root.add_child(health_panel)

	var health_vbox := VBoxContainer.new()
	health_vbox.add_theme_constant_override("separation", 6)
	health_panel.add_child(health_vbox)

	var health_header := HBoxContainer.new()
	health_vbox.add_child(health_header)

	var health_title := Label.new()
	health_title.text = "ARMOR INTEGRITY"
	health_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_title.add_theme_color_override("font_color", Color("#d1cbbe"))
	health_title.add_theme_font_size_override("font_size", 11)
	health_header.add_child(health_title)

	health_text = Label.new()
	health_text.name = "healthText"
	health_text.text = "100 / 100"
	health_text.add_theme_color_override("font_color", Color("#ef4444"))
	health_text.add_theme_font_size_override("font_size", 20)
	health_header.add_child(health_text)

	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(236.0, 12.0)
	bar_bg.color = Color("#0f0e0d")
	health_vbox.add_child(bar_bg)

	health_bar_fill = ColorRect.new()
	health_bar_fill.name = "healthBarFill"
	health_bar_fill.anchor_left = 0.0
	health_bar_fill.anchor_top = 0.0
	health_bar_fill.anchor_right = 1.0
	health_bar_fill.anchor_bottom = 1.0
	health_bar_fill.color = Color("#dc2626")
	bar_bg.add_child(health_bar_fill)

	# 5. Bottom-Right Ammo Panel
	var ammo_panel := PanelContainer.new()
	ammo_panel.name = "ammoPanel"
	ammo_panel.anchor_left = 1.0
	ammo_panel.anchor_top = 1.0
	ammo_panel.anchor_right = 1.0
	ammo_panel.anchor_bottom = 1.0
	ammo_panel.offset_left = -264.0
	ammo_panel.offset_right = -24.0
	ammo_panel.offset_top = -108.0
	ammo_panel.offset_bottom = -24.0
	ammo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_panel.add_theme_stylebox_override(
		"panel",
		_make_iron_stylebox(
			Color("#1c1a18"),
			Color("#d97706"),
			Vector4i(2, 2, 5, 2),
			"right",
			Color("#d97706"),
			5,
			Vector4i(18, 10, 18, 10)
		)
	)
	hud_root.add_child(ammo_panel)

	var ammo_vbox := VBoxContainer.new()
	ammo_vbox.alignment = BoxContainer.ALIGNMENT_END
	ammo_vbox.add_theme_constant_override("separation", 2)
	ammo_panel.add_child(ammo_vbox)

	var weapon_name_lbl := Label.new()
	weapon_name_lbl.text = "HEAVY IRON CARBINE"
	weapon_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_name_lbl.add_theme_color_override("font_color", Color("#a8a29e"))
	weapon_name_lbl.add_theme_font_size_override("font_size", 11)
	ammo_vbox.add_child(weapon_name_lbl)

	var ammo_hbox := HBoxContainer.new()
	ammo_hbox.alignment = BoxContainer.ALIGNMENT_END
	ammo_vbox.add_child(ammo_hbox)

	ammo_value = Label.new()
	ammo_value.name = "ammoValue"
	ammo_value.text = "12"
	ammo_value.add_theme_color_override("font_color", Color("#fbbf24"))
	ammo_value.add_theme_font_size_override("font_size", 28)
	ammo_hbox.add_child(ammo_value)

	var ammo_reserve := Label.new()
	ammo_reserve.text = " / ∞"
	ammo_reserve.add_theme_color_override("font_color", Color("#78716c"))
	ammo_reserve.add_theme_font_size_override("font_size", 18)
	ammo_hbox.add_child(ammo_reserve)

	reload_hint = Label.new()
	reload_hint.name = "reloadHint"
	reload_hint.text = "READY"
	reload_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reload_hint.add_theme_color_override("font_color", Color("#f59e0b"))
	reload_hint.add_theme_font_size_override("font_size", 11)
	ammo_vbox.add_child(reload_hint)

	# 6. Modal Overlay (Start / Pause / Game Over)
	var overlay_bg := ColorRect.new()
	overlay_bg.name = "modalOverlay"
	overlay_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_bg.color = Color(0.04, 0.043, 0.055, 0.88)
	add_child(overlay_bg)
	modal_overlay = overlay_bg

	var center_box := CenterContainer.new()
	center_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_bg.add_child(center_box)

	var modal_card := PanelContainer.new()
	modal_card.custom_minimum_size = Vector2(480.0, 0.0)
	modal_card.add_theme_stylebox_override(
		"panel",
		_make_iron_stylebox(
			Color("#191716"),
			Color("#d97706"),
			Vector4i(3, 5, 3, 3),
			"top",
			Color("#d97706"),
			5,
			Vector4i(36, 28, 36, 28)
		)
	)
	center_box.add_child(modal_card)

	var card_vbox := VBoxContainer.new()
	card_vbox.name = "cardVBox"
	card_vbox.add_theme_constant_override("separation", 14)
	modal_card.add_child(card_vbox)

	modal_title = Label.new()
	modal_title.name = "modalTitle"
	modal_title.text = "IRON PIT"
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_title.add_theme_color_override("font_color", Color("#f3f4f6"))
	modal_title.add_theme_font_size_override("font_size", 36)
	card_vbox.add_child(modal_title)

	modal_subtitle = Label.new()
	modal_subtitle.name = "modalSubtitle"
	modal_subtitle.text = LoreCatalog.INTRO_SUBTITLE
	modal_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_subtitle.custom_minimum_size = Vector2(400.0, 0.0)
	modal_subtitle.add_theme_color_override("font_color", Color("#a8a29e"))
	modal_subtitle.add_theme_font_size_override("font_size", 13)
	card_vbox.add_child(modal_subtitle)

	# Controls grid
	var controls_panel := PanelContainer.new()
	controls_panel.add_theme_stylebox_override(
		"panel",
		_make_iron_stylebox(Color("#0f0e0d"), Color("#383431"), Vector4i(1, 1, 1, 1), "", Color.TRANSPARENT, 1, Vector4i(16, 12, 16, 12))
	)
	card_vbox.add_child(controls_panel)

	var controls_grid := GridContainer.new()
	controls_grid.columns = 2
	controls_grid.add_theme_constant_override("h_separation", 24)
	controls_grid.add_theme_constant_override("v_separation", 8)
	controls_panel.add_child(controls_grid)

	var bindings: Array[Array] = [
		["WASD", "Move"],
		["MOUSE", "Aim"],
		["LMB", "Fire Weapon"],
		["R", "Reload"],
		["SHIFT", "Sprint"],
		["SPACE", "Jump"],
	]
	for b in bindings:
		var lbl := Label.new()
		lbl.text = "[%s] %s" % [b[0], b[1]]
		lbl.add_theme_color_override("font_color", Color("#fbbf24"))
		lbl.add_theme_font_size_override("font_size", 12)
		controls_grid.add_child(lbl)

	# Action Buttons
	action_button = Button.new()
	action_button.name = "actionButton"
	action_button.text = "ENTER THE PIT"
	action_button.custom_minimum_size = Vector2(0.0, 44.0)
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.add_theme_stylebox_override(
		"normal",
		_make_iron_stylebox(Color("#b45309"), Color("#f59e0b"), Vector4i(2, 2, 2, 2), "", Color.TRANSPARENT, 2, Vector4i(24, 12, 24, 12))
	)
	action_button.pressed.connect(func() -> void:
		if on_action_button_click.is_valid():
			on_action_button_click.call()
	)
	card_vbox.add_child(action_button)

	settings_button = Button.new()
	settings_button.name = "settingsButton"
	settings_button.text = "SETTINGS"
	settings_button.custom_minimum_size = Vector2(0.0, 36.0)
	settings_button.focus_mode = Control.FOCUS_NONE
	settings_button.pressed.connect(func() -> void:
		settings_modal.visible = true
	)
	card_vbox.add_child(settings_button)

	chronicle_button = Button.new()
	chronicle_button.name = "chronicleButton"
	chronicle_button.text = "THE CHRONICLE"
	chronicle_button.custom_minimum_size = Vector2(0.0, 36.0)
	chronicle_button.focus_mode = Control.FOCUS_NONE
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
	sett_bg.add_child(sett_center)

	var sett_card := PanelContainer.new()
	sett_card.custom_minimum_size = Vector2(540.0, 0.0)
	sett_card.add_theme_stylebox_override(
		"panel",
		_make_iron_stylebox(
			Color("#161413"),
			Color("#d97706"),
			Vector4i(6, 2, 2, 2),
			"left",
			Color("#d97706"),
			6,
			Vector4i(28, 24, 28, 24)
		)
	)
	sett_center.add_child(sett_card)

	var sett_vbox := VBoxContainer.new()
	sett_vbox.add_theme_constant_override("separation", 14)
	sett_card.add_child(sett_vbox)

	var sett_header := HBoxContainer.new()
	sett_vbox.add_child(sett_header)

	var sett_title := Label.new()
	sett_title.text = "SETTINGS"
	sett_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sett_title.add_theme_color_override("font_color", Color("#fbbf24"))
	sett_title.add_theme_font_size_override("font_size", 18)
	sett_header.add_child(sett_title)

	settings_close_button = Button.new()
	settings_close_button.name = "settingsCloseButton"
	settings_close_button.text = "×"
	settings_close_button.focus_mode = Control.FOCUS_NONE
	settings_close_button.pressed.connect(func() -> void:
		settings_modal.visible = false
	)
	sett_header.add_child(settings_close_button)

	# Video Settings Section
	var video_panel := PanelContainer.new()
	video_panel.add_theme_stylebox_override(
		"panel",
		_make_iron_stylebox(Color("#12100f"), Color("#383430"), Vector4i(1, 1, 1, 1), "", Color.TRANSPARENT, 1, Vector4i(14, 12, 14, 12))
	)
	var video_vbox := VBoxContainer.new()
	video_vbox.add_theme_constant_override("separation", 8)
	video_panel.add_child(video_vbox)

	var video_title := Label.new()
	video_title.text = "VIDEO"
	video_title.add_theme_color_override("font_color", Color("#d97706"))
	video_title.add_theme_font_size_override("font_size", 13)
	video_vbox.add_child(video_title)

	var scale_row := _make_render_scale_slider_row(100.0, func(val: float) -> void:
		_update_render_scale_label(val)
		if self.on_render_scale_change.is_valid():
			self.on_render_scale_change.call(val / 100.0)
	)
	render_scale_slider = scale_row["slider"]
	render_scale_value = scale_row["value_label"]
	video_vbox.add_child(scale_row["row"])
	sett_vbox.add_child(video_panel)

	# Audio Settings Section
	var audio_panel := PanelContainer.new()
	audio_panel.add_theme_stylebox_override(
		"panel",
		_make_iron_stylebox(Color("#12100f"), Color("#383430"), Vector4i(1, 1, 1, 1), "", Color.TRANSPARENT, 1, Vector4i(14, 12, 14, 12))
	)
	var audio_vbox := VBoxContainer.new()
	audio_vbox.add_theme_constant_override("separation", 8)
	audio_panel.add_child(audio_vbox)

	var audio_title := Label.new()
	audio_title.text = "AUDIO"
	audio_title.add_theme_color_override("font_color", Color("#d97706"))
	audio_title.add_theme_font_size_override("font_size", 13)
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
	mute_button.focus_mode = Control.FOCUS_NONE
	mute_button.pressed.connect(func() -> void:
		var is_muted := false
		if self.on_toggle_mute.is_valid():
			is_muted = bool(self.on_toggle_mute.call())
		_update_mute_button_label(is_muted)
	)
	mute_hbox.add_child(mute_button)
	sett_vbox.add_child(audio_panel)

	# Back Button & Footer
	settings_back_button = Button.new()
	settings_back_button.name = "settingsBackButton"
	settings_back_button.text = "BACK"
	settings_back_button.custom_minimum_size = Vector2(0.0, 36.0)
	settings_back_button.focus_mode = Control.FOCUS_NONE
	settings_back_button.pressed.connect(func() -> void:
		settings_modal.visible = false
	)
	sett_vbox.add_child(settings_back_button)

	var sett_footer := Label.new()
	sett_footer.text = "PRESS [ESC] OR CLICK TO RETURN"
	sett_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sett_footer.add_theme_color_override("font_color", Color("#78716c"))
	sett_footer.add_theme_font_size_override("font_size", 11)
	sett_vbox.add_child(sett_footer)

	# 7. Chronicle Modal Overlay
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
	chron_bg.add_child(chron_center)

	var chron_card := PanelContainer.new()
	chron_card.custom_minimum_size = Vector2(580.0, 0.0)
	chron_card.add_theme_stylebox_override(
		"panel",
		_make_iron_stylebox(
			Color("#161413"),
			Color("#d97706"),
			Vector4i(6, 2, 2, 2),
			"left",
			Color("#d97706"),
			6,
			Vector4i(28, 24, 28, 24)
		)
	)
	chron_center.add_child(chron_card)

	var chron_vbox := VBoxContainer.new()
	chron_vbox.add_theme_constant_override("separation", 14)
	chron_card.add_child(chron_vbox)

	var chron_header := HBoxContainer.new()
	chron_vbox.add_child(chron_header)

	var chron_title := Label.new()
	chron_title.text = "CHRONICLE OF THE PIT"
	chron_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chron_title.add_theme_color_override("font_color", Color("#fbbf24"))
	chron_title.add_theme_font_size_override("font_size", 18)
	chron_header.add_child(chron_title)

	chronicle_close_button = Button.new()
	chronicle_close_button.name = "chronicleCloseButton"
	chronicle_close_button.text = "×"
	chronicle_close_button.focus_mode = Control.FOCUS_NONE
	chronicle_close_button.pressed.connect(func() -> void:
		chronicle_modal.visible = false
	)
	chron_header.add_child(chronicle_close_button)

	for ch in LoreCatalog.CHRONICLE_CHAPTERS:
		var ch_panel := PanelContainer.new()
		ch_panel.add_theme_stylebox_override(
			"panel",
			_make_iron_stylebox(Color("#12100f"), Color("#383430"), Vector4i(1, 1, 1, 1), "", Color.TRANSPARENT, 1, Vector4i(14, 12, 14, 12))
		)
		var ch_vbox := VBoxContainer.new()
		ch_vbox.add_theme_constant_override("separation", 6)
		ch_panel.add_child(ch_vbox)

		var ch_title := Label.new()
		ch_title.text = String(ch["title"])
		ch_title.add_theme_color_override("font_color", Color("#d97706"))
		ch_title.add_theme_font_size_override("font_size", 13)
		ch_vbox.add_child(ch_title)

		var ch_body := Label.new()
		ch_body.text = String(ch["body"])
		ch_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ch_body.custom_minimum_size = Vector2(500.0, 0.0)
		ch_body.add_theme_color_override("font_color", Color("#d6d3d1"))
		ch_body.add_theme_font_size_override("font_size", 13)
		ch_vbox.add_child(ch_body)

		chron_vbox.add_child(ch_panel)

	var chron_footer := Label.new()
	chron_footer.text = "PRESS [ESC] OR CLICK TO RETURN"
	chron_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chron_footer.add_theme_color_override("font_color", Color("#78716c"))
	chron_footer.add_theme_font_size_override("font_size", 11)
	chron_vbox.add_child(chron_footer)


func _make_stat_block(title_str: String, val_str: String, val_color: Color) -> Dictionary:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(96.0, 0.0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var t_lbl := Label.new()
	t_lbl.text = title_str
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.add_theme_color_override("font_color", Color("#a39e99"))
	t_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(t_lbl)

	var v_lbl := Label.new()
	v_lbl.text = val_str
	v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_lbl.add_theme_color_override("font_color", val_color)
	v_lbl.add_theme_font_size_override("font_size", 22)
	vbox.add_child(v_lbl)

	return {
		"container": vbox,
		"title_label": t_lbl,
		"value_label": v_lbl,
	}


func _make_slider_row(label_text: String, initial_val: float, on_change: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(64.0, 0.0)
	lbl.add_theme_color_override("font_color", Color("#a8a29e"))
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = initial_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(on_change)
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(round(initial_val))
	val_lbl.custom_minimum_size = Vector2(40.0, 0.0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
	val_lbl.add_theme_font_size_override("font_size", 11)
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
	lbl.custom_minimum_size = Vector2(130.0, 0.0)
	lbl.add_theme_color_override("font_color", Color("#a8a29e"))
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 50.0
	slider.max_value = 100.0
	slider.step = 5.0
	slider.value = initial_pct
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(on_change)
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(110.0, 0.0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
	val_lbl.add_theme_font_size_override("font_size", 11)
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
	var w := int(round(1280.0 * factor))
	var h := int(round(720.0 * factor))
	lbl.text = "%d%% [%d×%d]" % [int(round(pct)), w, h]


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

	_update_mute_button_label(is_muted)


func sync_audio_settings(data: Dictionary) -> void:
	sync_settings(data)


func _update_mute_button_label(is_muted: bool) -> void:
	if mute_button != null:
		mute_button.text = "UNMUTE AUDIO" if is_muted else "MUTE AUDIO"
		mute_button.add_theme_color_override(
			"font_color",
			Color("#ef4444") if is_muted else Color("#d6d3d1")
		)


func update_hud(snapshot: Dictionary) -> void:
	var wave: int = maxi(1, int(snapshot.get("wave", 1)))
	var is_in_breather: bool = bool(snapshot.get("is_in_breather", false))
	var remaining_enemies: int = int(snapshot.get("remaining_enemies", 0))
	var kills: int = int(snapshot.get("kills", 0))
	var score: int = int(snapshot.get("score", 0))
	var hp: float = float(snapshot.get("hp", 100.0))
	var max_hp: float = maxf(1.0, float(snapshot.get("max_hp", 100.0)))
	var ammo: int = int(snapshot.get("ammo", 12))
	var is_reloading: bool = bool(snapshot.get("is_reloading", false))
	var status: String = String(snapshot.get("status", "MENU"))

	var wave_str := str(wave)
	if wave_value.text != wave_str:
		wave_value.text = wave_str

	var target_enemies_label := "Status" if is_in_breather else "Hostiles"
	var target_enemies_value := "PURGED" if is_in_breather else str(remaining_enemies)
	if enemies_label.text != target_enemies_label:
		enemies_label.text = target_enemies_label
	if enemies_value.text != target_enemies_value:
		enemies_value.text = target_enemies_value

	var kills_str := str(kills)
	if kills_value.text != kills_str:
		kills_value.text = kills_str

	var hp_pct := clampf((hp / max_hp) * 100.0, 0.0, 100.0)
	var hp_str := "%d / %d" % [int(round(hp)), int(round(max_hp))]
	if health_text.text != hp_str:
		health_text.text = hp_str
	var target_anchor := hp_pct / 100.0
	if absf(health_bar_fill.anchor_right - target_anchor) > 0.001:
		health_bar_fill.anchor_right = target_anchor

	var ammo_str := str(ammo)
	if ammo_value.text != ammo_str:
		ammo_value.text = ammo_str

	var target_hint := "READY"
	if is_reloading:
		target_hint = "RELOADING..."
	elif ammo == 0:
		target_hint = "PRESS [R] TO RELOAD"
	elif ammo <= 3:
		target_hint = "LOW AMMO [R]"
	if reload_hint.text != target_hint:
		reload_hint.text = target_hint

	if wave_whisper != null:
		if is_in_breather:
			var whisper_text := LoreCatalog.get_wave_whisper(wave)
			if wave_whisper_label.text != whisper_text:
				wave_whisper_label.text = whisper_text
			wave_whisper.visible = true
		else:
			wave_whisper.visible = false

	if status == "PLAYING":
		modal_overlay.visible = false
		chronicle_modal.visible = false
		if settings_modal != null:
			settings_modal.visible = false
	else:
		modal_overlay.visible = true
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


func pulse_crosshair(hit_enemy: bool) -> void:
	_is_expanded = true
	crosshair.scale = Vector2(1.4, 1.4)
	_crosshair_expand_timer = 0.09

	if hit_enemy:
		_is_hit = true
		_set_crosshair_hit_color(true)
		_crosshair_hit_timer = 0.14


func _set_crosshair_hit_color(hit: bool) -> void:
	var line_col := Color("#dc2626") if hit else Color("#f3f4f6")
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
	if _crosshair_expand_timer > 0.0:
		_crosshair_expand_timer -= delta
		if _crosshair_expand_timer <= 0.0:
			_is_expanded = false
			crosshair.scale = Vector2.ONE

	if _crosshair_hit_timer > 0.0:
		_crosshair_hit_timer -= delta
		if _crosshair_hit_timer <= 0.0:
			_is_hit = false
			_set_crosshair_hit_color(false)

	if _vignette_timer > 0.0:
		_vignette_timer -= delta
		if _vignette_timer <= 0.0:
			damage_vignette.modulate.a = 0.0
