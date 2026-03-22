extends Control

# Kenney UI tiles live under res://assets/vendor/kenney_ui-pack-pixel-adventure/ for future button/panel themes.
const GAME_SCENE := preload("res://scenes/test/test_scene_gameloop.tscn")
const UI_FONT := preload("res://assets/game/ui/fonts/PixelOperator8.ttf")
const FARMER_ATLAS: Texture2D = preload("res://assets/game/character/mana_seed_farmer.png")
const CROP_SHEET: Texture2D = preload("res://assets/game/objects/crop_spritesheet.png")
const TILLED_TEX: Texture2D = preload("res://assets/game/tilesets/tilled_dirt_wide.png")
const GRASS_TILE: Texture2D = preload("res://assets/game/tilesets/grass.png")
const TOMATO_ITEM: Texture2D = preload("res://assets/game/sprites/CropSprites/Tomato/tomato_item.png")

@onready var _content_margin: MarginContainer = $ContentMargin
@onready var _left_mascot_slot: Control = $ContentMargin/MenuHBox/LeftMascotSlot
@onready var _right_farm_slot: Control = $ContentMargin/MenuHBox/RightFarmSlot
@onready var _field_band: ColorRect = $FieldBand
@onready var _bg_decor_host: Control = $BgDecorHost
@onready var _cloud_left: Panel = $CloudLeft
@onready var _cloud_right: Panel = $CloudRight
@onready var _cloud_high: Panel = $CloudHigh
@onready var _fx_layer: Control = $FxLayer
@onready var _auth_backdrop: ColorRect = $AuthLayer/AuthBackdrop
@onready var _auth_panel: PanelContainer = $AuthLayer/AuthCenter/AuthPanel
@onready var _email: LineEdit = $AuthLayer/AuthCenter/AuthPanel/Margin/VBox/EmailEdit
@onready var _password: LineEdit = $AuthLayer/AuthCenter/AuthPanel/Margin/VBox/PasswordEdit
@onready var _auth_status: Label = $AuthLayer/AuthCenter/AuthPanel/Margin/VBox/AuthStatusLabel
@onready var _auth_title: Label = $AuthLayer/AuthCenter/AuthPanel/Margin/VBox/AuthTitle
@onready var _account_button: Button = $ContentMargin/MenuHBox/Center/MainColumn/AccountButton
@onready var _user_line: Label = $ContentMargin/MenuHBox/Center/MainColumn/UserLine
@onready var _title_label: Label = $ContentMargin/MenuHBox/Center/MainColumn/Title
@onready var _subtitle_label: Label = $ContentMargin/MenuHBox/Center/MainColumn/Subtitle

@onready var _leaderboard_window: Window = $LeaderboardWindow
@onready var _leaderboard_list: ItemList = $LeaderboardWindow/Margin/VBox/LeaderboardList
@onready var _leaderboard_status: Label = $LeaderboardWindow/Margin/VBox/LeaderboardStatus


func _ready() -> void:
	get_tree().paused = false
	_apply_font_recursive(self)
	_fix_key_font_sizes()
	_set_auth_open(false)
	_leaderboard_window.hide()
	_refresh_user_line()

	Backend.login_succeeded.connect(_on_login_succeeded)
	Backend.login_failed.connect(_on_login_failed)
	Backend.signup_succeeded.connect(_on_signup_succeeded)
	Backend.signup_failed.connect(_on_signup_failed)
	Backend.leaderboard_received.connect(_on_leaderboard_received)
	Backend.leaderboard_failed.connect(_on_leaderboard_failed)

	_add_menu_sparkles()
	call_deferred("_build_field_background")
	_add_sun_disk()
	_start_cloud_drift()
	_style_cloud_panels()
	_style_main_buttons()
	_soften_title_labels()
	_build_mascot_farmer()
	_build_farm_showcase()

	var tw := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_title_label, "modulate", Color(1.0, 0.95, 0.65), 1.25)
	tw.tween_property(_title_label, "modulate", Color(1.0, 1.0, 1.0), 1.25)


func _fix_key_font_sizes() -> void:
	_title_label.add_theme_font_size_override("font_size", 32)
	_subtitle_label.add_theme_font_size_override("font_size", 10)
	_user_line.add_theme_font_size_override("font_size", 10)
	_auth_title.add_theme_font_size_override("font_size", 20)
	_auth_status.add_theme_font_size_override("font_size", 10)
	_email.add_theme_font_size_override("font_size", 16)
	_password.add_theme_font_size_override("font_size", 16)
	for p in [
		$ContentMargin/MenuHBox/Center/MainColumn/PlayButton,
		$ContentMargin/MenuHBox/Center/MainColumn/AccountButton,
		$ContentMargin/MenuHBox/Center/MainColumn/LeaderboardButton,
		$ContentMargin/MenuHBox/Center/MainColumn/QuitButton,
		$AuthLayer/AuthCenter/AuthPanel/Margin/VBox/LoginButton,
		$AuthLayer/AuthCenter/AuthPanel/Margin/VBox/SignupButton,
		$AuthLayer/AuthCenter/AuthPanel/Margin/VBox/CloseAuthButton
	]:
		(p as Button).add_theme_font_size_override("font_size", 12)


func _soften_title_labels() -> void:
	_title_label.add_theme_constant_override("outline_size", 5)
	_title_label.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.2, 0.92))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.25, 0.12, 0.35, 0.55))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	_subtitle_label.add_theme_constant_override("outline_size", 3)
	_subtitle_label.add_theme_color_override("font_outline_color", Color(0.14, 0.08, 0.22, 0.85))
	_user_line.add_theme_constant_override("outline_size", 0)


func _style_cloud_panels() -> void:
	for cloud: Panel in [_cloud_left, _cloud_right, _cloud_high]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(999)
		sb.shadow_size = 3
		sb.shadow_offset = Vector2(0, 2)
		sb.shadow_color = Color(0.75, 0.4, 0.35, 0.06)
		match cloud.name:
			"CloudLeft":
				sb.bg_color = Color(1, 1, 1, 0.2)
			"CloudRight":
				sb.bg_color = Color(1, 1, 1, 0.18)
			_:
				sb.bg_color = Color(1, 0.95, 0.88, 0.14)
		cloud.add_theme_stylebox_override("panel", sb)


func _make_menu_button_stylebox(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(22)
	s.set_border_width_all(0)
	s.shadow_size = 0
	s.anti_aliasing = true
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _style_main_buttons() -> void:
	for b: Button in [
		$ContentMargin/MenuHBox/Center/MainColumn/PlayButton,
		$ContentMargin/MenuHBox/Center/MainColumn/AccountButton,
		$ContentMargin/MenuHBox/Center/MainColumn/LeaderboardButton,
		$ContentMargin/MenuHBox/Center/MainColumn/QuitButton,
	]:
		var n := _make_menu_button_stylebox(Color(0.19, 0.15, 0.26, 1.0))
		var h := _make_menu_button_stylebox(Color(0.28, 0.22, 0.38, 1.0))
		var p := _make_menu_button_stylebox(Color(0.14, 0.11, 0.2, 1.0))
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", p)
		b.add_theme_stylebox_override("focus", n.duplicate())
		b.add_theme_stylebox_override("disabled", n.duplicate())
		b.add_theme_color_override("font_color", Color(0.98, 0.96, 0.94, 1.0))


func _add_menu_sparkles() -> void:
	for i in 10:
		var s := ColorRect.new()
		var sz := randf_range(2.0, 4.5)
		s.size = Vector2(sz, sz)
		s.position = Vector2(randf_range(8.0, 620.0), randf_range(10.0, 130.0))
		s.color = Color(1, 1, 1, randf_range(0.35, 0.75))
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx_layer.add_child(s)
		var st := randf_range(0.4, 1.1)
		var tw := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "modulate:a", 0.12, st)
		tw.tween_property(s, "modulate:a", 0.95, st)
	for i in 8:
		var f := ColorRect.new()
		var fsz := randf_range(2.0, 3.5)
		f.size = Vector2(fsz, fsz)
		var fx := randf_range(16.0, 600.0)
		var tries := 0
		while tries < 14 and fx > 228.0 and fx < 412.0:
			fx = randf_range(16.0, 600.0)
			tries += 1
		f.position = Vector2(fx, randf_range(200.0, 340.0))
		f.color = Color(1.0, 0.92, 0.45, randf_range(0.25, 0.55))
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx_layer.add_child(f)
		var ft := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		var slow := randf_range(0.8, 1.8)
		ft.tween_property(f, "modulate:a", 0.08, slow)
		ft.tween_property(f, "modulate:a", 0.65, slow)


func _build_field_background() -> void:
	for ch in _field_band.get_children():
		ch.queue_free()
	var sz := _field_band.size
	var w := maxi(1, ceili(sz.x))
	var h := maxi(1, ceili(sz.y))
	var top_c := Color(0.42, 0.6, 0.4, 1.0)
	var bot_c := Color(0.12, 0.36, 0.25, 1.0)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var hm1 := maxi(h - 1, 1)
	for y in h:
		var t := float(y) / float(hm1)
		var c := top_c.lerp(bot_c, t)
		for x in w:
			img.set_pixel(x, y, c)
	var grad_tex := ImageTexture.create_from_image(img)
	var grad_tr := TextureRect.new()
	grad_tr.texture = grad_tex
	grad_tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grad_tr.stretch_mode = TextureRect.STRETCH_SCALE
	grad_tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_field_band.add_child(grad_tr)
	var grass := TextureRect.new()
	grass.texture = GRASS_TILE
	grass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grass.stretch_mode = TextureRect.STRETCH_TILE
	grass.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	grass.modulate = Color(1.0, 1.0, 1.0, 0.3)
	_field_band.add_child(grass)


func _add_sun_disk() -> void:
	var halo := Panel.new()
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	halo.offset_left = -168.0
	halo.offset_top = -14.0
	halo.offset_right = 24.0
	halo.offset_bottom = 178.0
	var hb := StyleBoxFlat.new()
	hb.bg_color = Color(1.0, 0.55, 0.35, 0.18)
	hb.set_corner_radius_all(999)
	halo.add_theme_stylebox_override("panel", hb)
	_bg_decor_host.add_child(halo)
	var sun := Panel.new()
	sun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sun.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sun.offset_left = -132.0
	sun.offset_top = 18.0
	sun.offset_right = -12.0
	sun.offset_bottom = 138.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.78, 0.28, 0.78)
	sb.set_corner_radius_all(999)
	sun.add_theme_stylebox_override("panel", sb)
	_bg_decor_host.add_child(sun)
	var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(sun, "modulate", Color(1.05, 1.02, 0.88, 1.0), 1.8)
	pulse.tween_property(sun, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.8)


func _organic_blotch(center: Vector2, rx: float, ry: float, steps: int = 26) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var t := TAU * float(i) / float(steps)
		var wobble := 1.0 + 0.09 * sin(t * 4.1 + 0.8)
		pts.append(center + Vector2(cos(t) * rx * wobble, sin(t) * ry * wobble))
	return pts


func _add_blob_shadow(world: Node2D, center: Vector2, rx: float, ry: float, z_idx: int = 2) -> void:
	var sh := Polygon2D.new()
	sh.z_index = z_idx
	sh.color = Color(0.04, 0.1, 0.05, 0.38)
	sh.polygon = _organic_blotch(center + Vector2(2, 1), rx * 1.08, ry * 0.55, 18)
	world.add_child(sh)


func _add_soft_soil_mound(world: Node2D, center: Vector2) -> void:
	var base := Polygon2D.new()
	base.z_index = 0
	base.color = Color(0.36, 0.24, 0.14, 0.96)
	base.polygon = _organic_blotch(center, 58.0, 20.0)
	world.add_child(base)
	var mid := Polygon2D.new()
	mid.z_index = 1
	mid.color = Color(0.44, 0.3, 0.19, 0.78)
	mid.polygon = _organic_blotch(center + Vector2(-5, -4), 38.0, 13.0, 20)
	world.add_child(mid)
	var tip := Polygon2D.new()
	tip.z_index = 1
	tip.color = Color(0.52, 0.38, 0.24, 0.45)
	tip.polygon = _organic_blotch(center + Vector2(10, -2), 22.0, 9.0, 16)
	world.add_child(tip)
	var grit := Sprite2D.new()
	var dirt_at := AtlasTexture.new()
	dirt_at.atlas = TILLED_TEX
	dirt_at.region = Rect2(0, 0, 48, 16)
	grit.texture = dirt_at
	grit.position = center + Vector2(0, -2)
	grit.scale = Vector2(2.2, 2.2)
	grit.z_index = 1
	grit.modulate = Color(1, 1, 1, 0.42)
	world.add_child(grit)


func _add_viewport_bottom_feather(world: Node2D, vp_size: Vector2i) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.2, 0.52, 0.34, 0.0))
	g.set_color(1, Color(0.18, 0.46, 0.3, 0.92))
	g.add_point(0.45, Color(0.2, 0.52, 0.34, 0.0))
	g.add_point(0.82, Color(0.2, 0.52, 0.34, 0.55))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 8
	gt.height = 48
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var spr := Sprite2D.new()
	spr.texture = gt
	spr.centered = false
	var band_h := 64.0
	spr.position = Vector2(0.0, float(vp_size.y) - band_h)
	spr.scale = Vector2(float(vp_size.x) / 8.0, band_h / 48.0)
	spr.z_index = 48
	world.add_child(spr)


func _start_cloud_drift() -> void:
	var ctw := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ctw.tween_property(_cloud_left, "position:x", _cloud_left.position.x + 14.0, 5.5)
	ctw.tween_property(_cloud_left, "position:x", _cloud_left.position.x, 5.5)
	var ctw2 := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ctw2.tween_property(_cloud_right, "position:x", _cloud_right.position.x - 12.0, 6.2)
	ctw2.tween_property(_cloud_right, "position:x", _cloud_right.position.x, 6.2)
	var ctw3 := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ctw3.tween_property(_cloud_high, "position:x", _cloud_high.position.x + 10.0, 7.0)
	ctw3.tween_property(_cloud_high, "position:x", _cloud_high.position.x, 7.0)


func _build_mascot_farmer() -> void:
	var vp_size := Vector2i(150, maxi(280, int(_left_mascot_slot.size.y)))
	if vp_size.y < 200:
		vp_size.y = 300
	_attach_sprite_viewport(_left_mascot_slot, vp_size, func(world: Node2D) -> void:
		var sprite := AnimatedSprite2D.new()
		sprite.z_index = 4
		sprite.position = Vector2(float(vp_size.x) * 0.5, float(vp_size.y) * 0.72)
		sprite.scale = Vector2(3.35, 3.35)
		_add_blob_shadow(world, Vector2(sprite.position.x + 4.0, float(vp_size.y) - 10.0), 38.0, 12.0, 1)
		var sf := SpriteFrames.new()
		sf.add_animation("walk")
		var walk_regions: Array[Rect2] = [
			Rect2(0, 192, 64, 64),
			Rect2(64, 192, 64, 64),
			Rect2(128, 192, 64, 64),
			Rect2(64, 192, 64, 64),
		]
		for r: Rect2 in walk_regions:
			var at := AtlasTexture.new()
			at.atlas = FARMER_ATLAS
			at.region = r
			sf.add_frame("walk", at, 1.0)
		sf.set_animation_speed("walk", 7.0)
		sf.set_animation_loop("walk", true)
		sprite.sprite_frames = sf
		sprite.animation = "walk"
		sprite.play()
		world.add_child(sprite)
		var bob := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(sprite, "position:y", sprite.position.y - 6.0, 0.55)
		bob.tween_property(sprite, "position:y", sprite.position.y + 6.0, 0.55)
	)


func _build_farm_showcase() -> void:
	var vp_size := Vector2i(150, maxi(280, int(_right_farm_slot.size.y)))
	if vp_size.y < 200:
		vp_size.y = 300
	_attach_sprite_viewport(_right_farm_slot, vp_size, func(world: Node2D) -> void:
		var cx := float(vp_size.x) * 0.5
		var cy := float(vp_size.y)
		var mound_center := Vector2(cx, cy - 52.0)
		_add_soft_soil_mound(world, mound_center)
		var plant := Sprite2D.new()
		var pat := AtlasTexture.new()
		pat.atlas = CROP_SHEET
		pat.region = Rect2(64, 32, 16, 16)
		plant.texture = pat
		plant.position = Vector2(cx - 6.0, cy - 112.0)
		plant.scale = Vector2(4.0, 4.0)
		plant.z_index = 4
		_add_blob_shadow(world, plant.position + Vector2(2, 52.0), 14.0, 6.0, 2)
		world.add_child(plant)
		var plant2 := Sprite2D.new()
		var p2 := AtlasTexture.new()
		p2.atlas = CROP_SHEET
		p2.region = Rect2(48, 32, 16, 16)
		plant2.texture = p2
		plant2.position = Vector2(cx + 22.0, cy - 102.0)
		plant2.scale = Vector2(3.5, 3.5)
		plant2.z_index = 4
		_add_blob_shadow(world, plant2.position + Vector2(0, 46.0), 12.0, 5.0, 2)
		world.add_child(plant2)
		var basket := Sprite2D.new()
		basket.texture = TOMATO_ITEM
		basket.position = Vector2(cx + 18.0, cy - 142.0)
		basket.scale = Vector2(3.2, 3.2)
		basket.z_index = 4
		_add_blob_shadow(world, basket.position + Vector2(2, 28.0), 16.0, 7.0, 2)
		world.add_child(basket)
		var floaty := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		floaty.tween_property(basket, "position:y", basket.position.y - 5.0, 0.7)
		floaty.tween_property(basket, "position:y", basket.position.y + 5.0, 0.7)
		var sway := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sway.tween_property(plant, "rotation", 0.04, 1.1)
		sway.tween_property(plant, "rotation", -0.04, 1.1)
	)


func _attach_sprite_viewport(host: Control, vp_size: Vector2i, build_world: Callable) -> void:
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	svc.stretch = true
	host.add_child(svc)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.handle_input_locally = false
	vp.disable_3d = true
	vp.size = vp_size
	svc.add_child(vp)
	var world := Node2D.new()
	vp.add_child(world)
	build_world.call(world)
	_add_viewport_bottom_feather(world, vp_size)


func _apply_font_recursive(node: Node) -> void:
	if node is Control:
		var c := node as Control
		if c is Button or c is Label or c is LineEdit:
			c.add_theme_font_override("font", UI_FONT)
			c.add_theme_font_size_override("font_size", 10)
	for child in node.get_children():
		_apply_font_recursive(child)


func _email_is_valid_format(raw: String) -> bool:
	var email := raw.strip_edges()
	if email.is_empty():
		return false
	if not email.contains("@"):
		return false
	var parts := email.split("@")
	if parts.size() != 2 or str(parts[0]).is_empty() or str(parts[1]).is_empty():
		return false
	var domain: String = str(parts[1])
	if not domain.contains("."):
		return false
	var host_bits := domain.split(".")
	if host_bits.is_empty():
		return false
	var tld := str(host_bits[host_bits.size() - 1])
	return tld.length() >= 2


func _set_auth_open(open: bool) -> void:
	_auth_backdrop.visible = open
	_auth_panel.visible = open
	_content_margin.visible = not open
	if open:
		_auth_status.text = ""
		_email.grab_focus()


func _refresh_user_line() -> void:
	if Backend.is_logged_in():
		_user_line.text = "Signed in as %s" % Backend.current_email
		_account_button.text = "Sign out"
	else:
		_user_line.text = "Playing as guest (scores are local only)"
		_account_button.text = "Account"


func _on_play_pressed() -> void:
	get_tree().change_scene_to_packed(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_account_button_pressed() -> void:
	if Backend.is_logged_in():
		Backend.logout()
		_refresh_user_line()
		_set_auth_open(false)
		return
	if _auth_panel.visible:
		_set_auth_open(false)
	else:
		_set_auth_open(true)


func _on_close_auth_pressed() -> void:
	_set_auth_open(false)


func _on_login_pressed() -> void:
	var em := _email.text.strip_edges()
	if not _email_is_valid_format(em):
		_auth_status.text = "Enter a valid email (needs @ and a domain like .com or .ca)."
		return
	_auth_status.text = "Signing in..."
	Backend.login(em, _password.text)


func _on_signup_pressed() -> void:
	var em := _email.text.strip_edges()
	if not _email_is_valid_format(em):
		_auth_status.text = "Enter a valid email (needs @ and a domain like .com or .ca)."
		return
	_auth_status.text = "Creating account..."
	Backend.signup(em, _password.text)


func _on_login_succeeded(_user_id: String) -> void:
	_auth_status.text = "Welcome back!"
	_refresh_user_line()
	_set_auth_open(false)


func _on_login_failed(message: String) -> void:
	_auth_status.text = message


func _on_signup_succeeded(message: String) -> void:
	_auth_status.text = message
	_refresh_user_line()
	if Backend.is_logged_in():
		_set_auth_open(false)


func _on_signup_failed(message: String) -> void:
	_auth_status.text = message


func _on_leaderboard_pressed() -> void:
	_leaderboard_window.popup_centered_ratio(0.85)
	_leaderboard_status.text = "Loading..."
	_leaderboard_list.clear()
	Backend.get_top_10()


func _on_leaderboard_failed(reason: String) -> void:
	_leaderboard_list.clear()
	_leaderboard_status.text = reason


func _on_leaderboard_received(data: Variant) -> void:
	_leaderboard_list.clear()
	if typeof(data) != TYPE_ARRAY:
		_leaderboard_status.text = "Unexpected response."
		return
	var rows: Array = data
	if rows.is_empty():
		_leaderboard_status.text = "No scores yet."
		return
	_leaderboard_status.text = "Top runs"
	var rank := 1
	for entry in rows:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry
		var name := str(d.get("display_name", d.get("user_id", "?")))
		var score := int(d.get("score_total", 0))
		var waves := int(d.get("waves_completed", 0))
		_leaderboard_list.add_item("%d. %s — %d pts, wave %d" % [rank, name, score, waves])
		rank += 1


func _on_close_leaderboard_pressed() -> void:
	_leaderboard_window.hide()
