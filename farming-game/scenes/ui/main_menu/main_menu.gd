extends Control

# Kenney UI tiles live under res://assets/vendor/kenney_ui-pack-pixel-adventure/ for future button/panel themes.
const RUN_SETUP_SCENE := "res://scenes/ui/run_setup/run_setup.tscn"
const UI_FONT := preload("res://assets/game/ui/fonts/PixelOperator8.ttf")
const MENU_BG_PATHS: PackedStringArray = [
	"res://assets/game/ui/main_menu_background.jpg",
	"res://assets/game/ui/main_menu_background.jpeg",
]

@onready var _menu_background: TextureRect = $MenuBackground
@onready var _content_margin: MarginContainer = $ContentMargin
@onready var _main_column: VBoxContainer = $ContentMargin/MenuVBox/MenuCenterContainer/MainColumn
@onready var _fx_layer: Control = $FxLayer
@onready var _auth_backdrop: ColorRect = $AuthLayer/AuthBackdrop
@onready var _auth_panel: PanelContainer = $AuthLayer/AuthCenter/AuthPanel
@onready var _email: LineEdit = $AuthLayer/AuthCenter/AuthPanel/Margin/VBox/EmailEdit
@onready var _password: LineEdit = $AuthLayer/AuthCenter/AuthPanel/Margin/VBox/PasswordEdit
@onready var _auth_status: Label = $AuthLayer/AuthCenter/AuthPanel/Margin/VBox/AuthStatusLabel
@onready var _auth_title: Label = $AuthLayer/AuthCenter/AuthPanel/Margin/VBox/AuthTitle
@onready var _account_button: Button = $ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/AccountButton
@onready var _user_line: Label = $ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/UserLine
@onready var _title_label: Label = $ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/Title
@onready var _subtitle_label: Label = $ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/Subtitle

@onready var _settings_window: Window = $SettingsUILayer/SettingsWindow
@onready var _leaderboard_window: Window = $LeaderboardWindow
@onready var _leaderboard_list: ItemList = $LeaderboardWindow/Margin/VBox/LeaderboardList
@onready var _leaderboard_status: Label = $LeaderboardWindow/Margin/VBox/LeaderboardStatus


func _ready() -> void:
	get_tree().paused = false
	_load_menu_background_texture()
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
	_style_main_buttons()
	_soften_title_labels()
	call_deferred("_finalize_menu_column_layout")

	var tw := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_title_label, "modulate", Color(1.0, 0.95, 0.65), 1.25)
	tw.tween_property(_title_label, "modulate", Color(1.0, 1.0, 1.0), 1.25)

	Music.play_menu()


func _load_menu_background_texture() -> void:
	for path: String in MENU_BG_PATHS:
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var buf: PackedByteArray = f.get_buffer(f.get_length())
		if buf.is_empty():
			continue
		var img := Image.new()
		var err: Error
		if path.ends_with(".png"):
			err = img.load_png_from_buffer(buf)
		else:
			err = img.load_jpg_from_buffer(buf)
		if err != OK:
			continue
		_menu_background.texture = ImageTexture.create_from_image(img)
		return


func _finalize_menu_column_layout() -> void:
	await get_tree().process_frame
	_main_column.pivot_offset = Vector2(_main_column.size.x * 0.5, 0.0)


func _fix_key_font_sizes() -> void:
	_title_label.add_theme_font_size_override("font_size", 24)
	_subtitle_label.add_theme_font_size_override("font_size", 9)
	_user_line.add_theme_font_size_override("font_size", 9)
	_auth_title.add_theme_font_size_override("font_size", 16)
	_auth_status.add_theme_font_size_override("font_size", 9)
	_email.add_theme_font_size_override("font_size", 14)
	_password.add_theme_font_size_override("font_size", 14)
	for p in [
		$ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/PlayButton,
		$ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/HowToPlayButton,
		$ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/AccountButton,
		$ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/LeaderboardButton,
		$ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/SettingsButton,
		$ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/QuitButton,
	]:
		(p as Button).add_theme_font_size_override("font_size", 11)
	for p in [
		$AuthLayer/AuthCenter/AuthPanel/Margin/VBox/LoginButton,
		$AuthLayer/AuthCenter/AuthPanel/Margin/VBox/SignupButton,
		$AuthLayer/AuthCenter/AuthPanel/Margin/VBox/CloseAuthButton,
	]:
		(p as Button).add_theme_font_size_override("font_size", 10)


func _soften_title_labels() -> void:
	_title_label.add_theme_constant_override("outline_size", 4)
	_title_label.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.2, 0.92))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.25, 0.12, 0.35, 0.55))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	_subtitle_label.add_theme_constant_override("outline_size", 3)
	_subtitle_label.add_theme_color_override("font_outline_color", Color(0.14, 0.08, 0.22, 0.85))
	_user_line.add_theme_constant_override("outline_size", 0)


func _make_menu_button_stylebox(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(18)
	s.set_border_width_all(0)
	s.shadow_size = 0
	s.anti_aliasing = true
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _style_main_buttons() -> void:
	for b: Button in [
		$ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/PlayButton,
		$ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/HowToPlayButton,
		$ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/AccountButton,
		$ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/LeaderboardButton,
		$ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/SettingsButton,
		$ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/QuitButton,
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
	if open:
		_fit_auth_panel_to_screen()
	_auth_backdrop.visible = open
	_auth_panel.visible = open
	_content_margin.visible = not open
	if open:
		_auth_status.text = ""
		_email.grab_focus()


func _fit_auth_panel_to_screen() -> void:
	var vp: Vector2 = get_tree().root.get_viewport().get_visible_rect().size
	var max_w: int = maxi(260, int(vp.x) - 56)
	var panel_w: int = clampi(360, 280, max_w)
	_auth_panel.custom_minimum_size.x = panel_w


func _refresh_user_line() -> void:
	if Backend.is_logged_in():
		_user_line.text = "Signed in as %s" % Backend.current_email
		_account_button.text = "Sign out"
	else:
		_user_line.text = "Playing as guest (scores are local only)"
		_account_button.text = "Account"


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(RUN_SETUP_SCENE)


func _on_how_to_play_pressed() -> void:
	GameProgress.open_tutorial_replay_from_menu = true
	get_tree().change_scene_to_file(RUN_SETUP_SCENE)


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


func _on_settings_pressed() -> void:
	(_settings_window as Node).call("open_settings")


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
