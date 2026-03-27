extends Control

# Kenney UI tiles live under res://assets/vendor/kenney_ui-pack-pixel-adventure/ for future button/panel themes.
const RUN_SETUP_SCENE := "res://scenes/ui/run_setup/run_setup.tscn"
const GAME_SCENE := "res://scenes/test/test_scene_gameloop.tscn"
const TUTORIAL_SCENE := "res://scenes/tutorial/tutorial_lesson.tscn"
const UI_FONT := preload("res://assets/game/ui/fonts/PixelOperator8.ttf")
const BuildInfo = preload("res://scripts/build_info.gd")
const MENU_BG_PATHS: PackedStringArray = [
	"res://assets/game/ui/main_menu_background.jpg",
	"res://assets/game/ui/main_menu_background.jpeg",
]

@onready var _menu_background: TextureRect = $MenuBackground
@onready var _content_margin: MarginContainer = $ContentMargin
@onready var _main_column: VBoxContainer = $ContentMargin/MenuVBox/MenuCenterContainer/MainColumn
@onready var _fx_layer: Control = $FxLayer
@onready var _menu_dim: ColorRect = $Dim
@onready var _auth_backdrop: ColorRect = $AuthLayer/AuthBackdrop
@onready var _auth_panel: PanelContainer = $AuthLayer/AuthCenter/AuthPanel
@onready var _email: LineEdit = $AuthLayer/AuthCenter/AuthPanel/Margin/VBox/EmailEdit
@onready var _password: LineEdit = $AuthLayer/AuthCenter/AuthPanel/Margin/VBox/PasswordEdit
@onready var _auth_status: Label = $AuthLayer/AuthCenter/AuthPanel/Margin/VBox/AuthStatusLabel
@onready var _auth_title: Label = $AuthLayer/AuthCenter/AuthPanel/Margin/VBox/AuthTitle
@onready var _login_button: Button = $AuthLayer/AuthCenter/AuthPanel/Margin/VBox/LoginButton
@onready var _signup_button: Button = $AuthLayer/AuthCenter/AuthPanel/Margin/VBox/SignupButton
@onready var _forgot_password_button: Button = $AuthLayer/AuthCenter/AuthPanel/Margin/VBox/ForgotPasswordButton
@onready var _account_button: Button = $ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/AccountButton
@onready var _user_line: Label = $ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/UserLine
@onready var _title_label: Label = $ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/Title
@onready var _subtitle_label: Label = $ContentMargin/MenuVBox/MenuCenterContainer/MainColumn/Subtitle
@onready var _version_label: Label = $FooterLayer/VersionLabel
@onready var _credits_button: Button = $FooterLayer/CreditsButton
@onready var _credits_layer: CanvasLayer = $CreditsLayer
@onready var _credits_backdrop: ColorRect = $CreditsLayer/CreditsBackdrop
@onready var _credits_text: Label = $CreditsLayer/CreditsCenter/CreditsPanel/Margin/VBox/CreditsText
@onready var _close_credits_button: Button = $CreditsLayer/CreditsCenter/CreditsPanel/Margin/VBox/CloseCreditsButton

@onready var _settings_window: Window = $SettingsUILayer/SettingsWindow
@onready var _leaderboard_layer: CanvasLayer = $LeaderboardLayer
@onready var _leaderboard_backdrop: ColorRect = $LeaderboardLayer/LeaderboardBackdrop
@onready var _leaderboard_list_base: ItemList = $LeaderboardLayer/LeaderboardCenter/LeaderboardPanel/Margin/VBox/BaseGameSection/LeaderboardListBase
@onready var _leaderboard_list_endless: ItemList = $LeaderboardLayer/LeaderboardCenter/LeaderboardPanel/Margin/VBox/EndlessSection/LeaderboardListEndless
@onready var _leaderboard_status: Label = $LeaderboardLayer/LeaderboardCenter/LeaderboardPanel/Margin/VBox/LeaderboardStatus
@onready var _mode_pick_layer: CanvasLayer = $ModePickLayer
@onready var _mode_pick_backdrop: ColorRect = $ModePickLayer/ModePickBackdrop

var _leaderboard_pending: int = 0
var _profile_is_edit_mode := false
var _auth_reset_mode := false

@onready var _profile_backdrop: ColorRect = $ProfileWindow/ProfileBackdrop
@onready var _profile_panel: PanelContainer = $ProfileWindow/ProfileCenter/ProfilePanel
@onready var _profile_name: LineEdit = $ProfileWindow/ProfileCenter/ProfilePanel/Margin/VBox/ProfileNameEdit
@onready var _profile_status: Label = $ProfileWindow/ProfileCenter/ProfilePanel/Margin/VBox/ProfileStatusLabel
@onready var _profile_title: Label = $ProfileWindow/ProfileCenter/ProfilePanel/Margin/VBox/ProfileTitle
@onready var _account_backdrop: ColorRect = $AccountLayer/AccountBackdrop
@onready var _account_panel: PanelContainer = $AccountLayer/AccountCenter/AccountPanel
@onready var _account_status: Label = $AccountLayer/AccountCenter/AccountPanel/Margin/VBox/AccountStatusLabel

var _forgot_password_retry_until_unix: int = 0
var _forgot_password_timer: Timer
var _mobile_audio_unlock_done := false
var _mobile_fullscreen_requested := false
var _mobile_prompt_active := false

func _ready() -> void:
	get_tree().paused = false
	_load_menu_background_texture()
	_apply_font_recursive(self)
	_fix_key_font_sizes()
	_set_auth_open(false)
	_set_auth_mode_reset(false)
	_set_profile_open(false)
	_set_account_open(false)
	_leaderboard_layer.visible = false
	_credits_layer.visible = false
	_set_mode_pick_open(false)
	_style_leaderboard_panel()
	_style_mode_pick_panel()
	_leaderboard_backdrop.gui_input.connect(_on_leaderboard_backdrop_gui_input)
	_mode_pick_backdrop.gui_input.connect(_on_mode_pick_backdrop_gui_input)
	_account_backdrop.gui_input.connect(_on_account_backdrop_gui_input)
	_credits_button.pressed.connect(_on_credits_button_pressed)
	_credits_backdrop.gui_input.connect(_on_credits_backdrop_gui_input)
	_close_credits_button.pressed.connect(_on_close_credits_pressed)
	_refresh_user_line()

	Backend.login_succeeded.connect(_on_login_succeeded)
	Backend.login_failed.connect(_on_login_failed)
	Backend.signup_succeeded.connect(_on_signup_succeeded)
	Backend.signup_failed.connect(_on_signup_failed)
	Backend.profile_lookup_succeeded.connect(_on_profile_lookup_succeeded)
	Backend.profile_lookup_failed.connect(_on_profile_lookup_failed)
	Backend.profile_created.connect(_on_profile_created)
	Backend.profile_updated.connect(_on_profile_updated)
	Backend.profile_update_failed.connect(_on_profile_update_failed)
	Backend.password_reset_requested.connect(_on_password_reset_requested)
	Backend.password_reset_failed.connect(_on_password_reset_failed)
	Backend.password_reset_rate_limited.connect(_on_password_reset_rate_limited)
	Backend.password_changed.connect(_on_password_changed)
	Backend.password_change_failed.connect(_on_password_change_failed)
	Backend.password_recovery_ready.connect(_on_password_recovery_ready)
	Backend.password_recovery_failed.connect(_on_password_recovery_failed)
	Backend.leaderboard_received.connect(_on_leaderboard_received)
	Backend.leaderboard_failed.connect(_on_leaderboard_failed)
	Backend.leaderboard_endless_received.connect(_on_leaderboard_endless_received)
	Backend.leaderboard_endless_failed.connect(_on_leaderboard_endless_failed)
	Backend.run_submitted.connect(_on_menu_run_submitted_feedback)
	Backend.run_submit_failed.connect(_on_menu_run_submit_failed)
	Backend.try_start_password_recovery_from_web_url()
	_forgot_password_timer = Timer.new()
	_forgot_password_timer.wait_time = 1.0
	_forgot_password_timer.one_shot = false
	_forgot_password_timer.autostart = false
	add_child(_forgot_password_timer)
	_forgot_password_timer.timeout.connect(_on_forgot_password_countdown_tick)

	_add_menu_sparkles()
	_style_main_buttons()
	_soften_title_labels()
	call_deferred("_finalize_menu_column_layout")

	var tw := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_title_label, "modulate", Color(1.0, 0.95, 0.65), 1.25)
	tw.tween_property(_title_label, "modulate", Color(1.0, 1.0, 1.0), 1.25)
	_version_label.text = str(BuildInfo.VERSION)
	_credits_text.text = "Credits\nNathan - Software Engineer\nMujtaba - Game Designer\nMykola - Database Engineer\nChristian - Requirements Analyst\nRodney - Test Engineer\nYassin - Project Manager\n\nMusic credits: Undertale - Toby Fox"

	Music.play_menu()
	_setup_mobile_text_input()
	_apply_mobile_web_canvas_css()


func _is_touch_device() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("('ontouchstart' in window) || (navigator.maxTouchPoints > 0)", true)
	return false


func _setup_mobile_text_input() -> void:
	if not _is_touch_device():
		return
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_password.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	_profile_name.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	for e in [_email, _password, _profile_name]:
		if e == null:
			continue
		(e as LineEdit).virtual_keyboard_enabled = true
		(e as LineEdit).selecting_enabled = true
		(e as LineEdit).focus_mode = Control.FOCUS_ALL
		(e as LineEdit).gui_input.connect(_on_mobile_lineedit_gui_input.bind(e))
		(e as LineEdit).focus_entered.connect(_on_mobile_lineedit_focus_entered.bind(e))


func _apply_mobile_web_canvas_css() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"(function(){try{document.documentElement.style.margin='0';document.documentElement.style.padding='0';"
		+ "document.documentElement.style.background='#000';document.body.style.margin='0';document.body.style.padding='0';"
		+ "document.body.style.background='#000';document.body.style.overflow='hidden';"
		+ "const c=document.querySelector('canvas');if(c){c.style.width='100vw';c.style.height='100vh';c.style.display='block';}}catch(e){}})();",
		true
	)


func _on_mobile_lineedit_gui_input(event: InputEvent, field: LineEdit) -> void:
	if not _is_touch_device():
		return
	if event is InputEventScreenTouch and event.pressed:
		field.grab_focus()
		_mobile_prompt_fill_lineedit(field)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		field.grab_focus()
		_mobile_prompt_fill_lineedit(field)


func _on_mobile_lineedit_focus_entered(field: LineEdit) -> void:
	if not _is_touch_device() or not OS.has_feature("web"):
		return
	# Some mobile browsers focus the field but never show keyboard for canvas apps.
	# Prompt on focus as a fallback so auth always remains usable.
	call_deferred("_mobile_prompt_fill_lineedit", field)


func _mobile_prompt_fill_lineedit(field: LineEdit) -> void:
	if not OS.has_feature("web"):
		return
	if not _is_touch_device():
		return
	if _mobile_prompt_active:
		return
	_mobile_prompt_active = true
	var prompt_label := field.placeholder_text if not field.placeholder_text.is_empty() else "Enter text"
	var current := field.text
	var escaped_label := JSON.stringify(prompt_label)
	var escaped_current := JSON.stringify(current)
	var js := (
		"(function(){try{var v=window.prompt(%s,%s);if(v===null){return '__cancel__';}return String(v);}catch(e){return '__cancel__';}})();"
		% [escaped_label, escaped_current]
	)
	var result := str(JavaScriptBridge.eval(js, true))
	if result == "__cancel__":
		_mobile_prompt_active = false
		return
	# Email should never be capitalized by mobile keyboard autocorrect.
	if field == _email:
		result = result.to_lower()
	field.text = result
	field.caret_column = field.text.length()
	_mobile_prompt_active = false


func _mobile_prompt_text(prompt_label: String, current: String, password_mode: bool) -> String:
	if not OS.has_feature("web") or not _is_touch_device():
		return current
	var escaped_label := JSON.stringify(prompt_label)
	var escaped_current := JSON.stringify(current)
	var js := ""
	if password_mode:
		# Use an offscreen password input to reduce auto-cap/autocorrect behavior on phones.
		js = (
			"(function(){try{var i=document.createElement('input');i.type='password';i.autocapitalize='none';"
			+ "i.autocorrect='off';i.spellcheck=false;i.value=%s;i.style.position='fixed';i.style.left='-9999px';"
			+ "document.body.appendChild(i);i.focus();var v=window.prompt(%s, i.value);document.body.removeChild(i);"
			+ "if(v===null){return '__cancel__';}return String(v);}catch(e){return '__cancel__';}})();"
		) % [escaped_current, escaped_label]
	else:
		js = (
			"(function(){try{var v=window.prompt(%s,%s);if(v===null){return '__cancel__';}return String(v);}catch(e){return '__cancel__';}})();"
		) % [escaped_label, escaped_current]
	var result := str(JavaScriptBridge.eval(js, true))
	if result == "__cancel__":
		return current
	return result


func _mobile_collect_auth_fields(require_password: bool) -> bool:
	if not OS.has_feature("web") or not _is_touch_device():
		return true
	if _email.text.strip_edges().is_empty():
		_email.text = _mobile_prompt_text("Enter your email", _email.text, false).strip_edges().to_lower()
	if _email.text.strip_edges().is_empty():
		_auth_status.text = "Email is required."
		return false
	if require_password and _password.text.strip_edges().is_empty():
		_password.text = _mobile_prompt_text("Enter your password", _password.text, true)
	if require_password and _password.text.strip_edges().is_empty():
		_auth_status.text = "Password is required."
		return false
	return true


func _request_mobile_web_fullscreen() -> void:
	if _mobile_fullscreen_requested:
		return
	if not OS.has_feature("web"):
		return
	if not _is_touch_device():
		return
	_mobile_fullscreen_requested = true
	# iOS Safari may ignore full-screen for arbitrary pages; Android browsers usually allow this on gesture.
	JavaScriptBridge.eval(
		"(function(){try{var d=document.documentElement;if(!document.fullscreenElement){"
		+ "if(d.requestFullscreen){d.requestFullscreen();}else if(d.webkitRequestFullscreen){d.webkitRequestFullscreen();}}"
		+ "if(screen.orientation&&screen.orientation.lock){screen.orientation.lock('landscape').catch(function(){});}"
		+ "}catch(e){}})();",
		true
	)


func _try_unlock_mobile_audio() -> void:
	if _mobile_audio_unlock_done:
		return
	_mobile_audio_unlock_done = true
	Music.ensure_web_audio_unlocked()


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
	_profile_name.add_theme_font_size_override("font_size", 14)
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
		$AuthLayer/AuthCenter/AuthPanel/Margin/VBox/ForgotPasswordButton,
		$AuthLayer/AuthCenter/AuthPanel/Margin/VBox/CloseAuthButton,
	]:
		(p as Button).add_theme_font_size_override("font_size", 10)
		
	for p in [
		$ProfileWindow/ProfileCenter/ProfilePanel/Margin/VBox/CreateProfileButton,
		$AccountLayer/AccountCenter/AccountPanel/Margin/VBox/ChangeUsernameButton,
		$AccountLayer/AccountCenter/AccountPanel/Margin/VBox/ChangePasswordButton,
		$AccountLayer/AccountCenter/AccountPanel/Margin/VBox/SignOutButton,
		$AccountLayer/AccountCenter/AccountPanel/Margin/VBox/CloseAccountButton,
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
	var cn := _make_menu_button_stylebox(Color(0.19, 0.15, 0.26, 1.0))
	var ch := _make_menu_button_stylebox(Color(0.28, 0.22, 0.38, 1.0))
	var cp := _make_menu_button_stylebox(Color(0.14, 0.11, 0.2, 1.0))
	_credits_button.add_theme_stylebox_override("normal", cn)
	_credits_button.add_theme_stylebox_override("hover", ch)
	_credits_button.add_theme_stylebox_override("pressed", cp)
	_credits_button.add_theme_stylebox_override("focus", cn.duplicate())
	_credits_button.add_theme_stylebox_override("disabled", cn.duplicate())
	_credits_button.add_theme_color_override("font_color", Color(0.98, 0.96, 0.94, 1.0))
	_credits_button.add_theme_font_size_override("font_size", 9)


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


func _style_leaderboard_panel() -> void:
	var tl: Label = _leaderboard_layer.get_node_or_null("LeaderboardCenter/LeaderboardPanel/Margin/VBox/LeaderboardTitle") as Label
	if tl:
		tl.add_theme_font_size_override("font_size", 13)
	var back_btn: Button = _leaderboard_layer.get_node_or_null("LeaderboardCenter/LeaderboardPanel/Margin/VBox/BackLeaderboardButton") as Button
	if back_btn:
		var n := _make_menu_button_stylebox(Color(0.19, 0.15, 0.26, 1.0))
		var h := _make_menu_button_stylebox(Color(0.28, 0.22, 0.38, 1.0))
		var pr := _make_menu_button_stylebox(Color(0.14, 0.11, 0.2, 1.0))
		back_btn.add_theme_stylebox_override("normal", n)
		back_btn.add_theme_stylebox_override("hover", h)
		back_btn.add_theme_stylebox_override("pressed", pr)
		back_btn.add_theme_stylebox_override("focus", n.duplicate())
		back_btn.add_theme_color_override("font_color", Color(0.98, 0.96, 0.94, 1.0))
		back_btn.add_theme_font_size_override("font_size", 11)


func _style_mode_pick_panel() -> void:
	var tl: Label = _mode_pick_layer.get_node_or_null("ModePickCenter/ModePickPanel/Margin/VBox/ModePickTitle") as Label
	if tl:
		tl.add_theme_font_size_override("font_size", 13)
	for b in [
		_mode_pick_layer.get_node_or_null("ModePickCenter/ModePickPanel/Margin/VBox/NormalModeButton"),
		_mode_pick_layer.get_node_or_null("ModePickCenter/ModePickPanel/Margin/VBox/EndlessModeButton"),
		_mode_pick_layer.get_node_or_null("ModePickCenter/ModePickPanel/Margin/VBox/ModePickBackButton"),
	]:
		if b is Button:
			var bbtn := b as Button
			var n := _make_menu_button_stylebox(Color(0.19, 0.15, 0.26, 1.0))
			var h := _make_menu_button_stylebox(Color(0.28, 0.22, 0.38, 1.0))
			var pr := _make_menu_button_stylebox(Color(0.14, 0.11, 0.2, 1.0))
			bbtn.add_theme_stylebox_override("normal", n)
			bbtn.add_theme_stylebox_override("hover", h)
			bbtn.add_theme_stylebox_override("pressed", pr)
			bbtn.add_theme_stylebox_override("focus", n.duplicate())
			bbtn.add_theme_stylebox_override("disabled", n.duplicate())
			bbtn.add_theme_color_override("font_color", Color(0.98, 0.96, 0.94, 1.0))
			bbtn.add_theme_font_size_override("font_size", 11)


func _apply_font_recursive(node: Node) -> void:
	if node is Control:
		var c := node as Control
		if c is Button or c is Label or c is LineEdit:
			c.add_theme_font_override("font", UI_FONT)
			c.add_theme_font_size_override("font_size", 10)
		elif c is ItemList:
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


func _set_auth_mode_reset(reset_mode: bool) -> void:
	_auth_reset_mode = reset_mode
	if reset_mode:
		_auth_title.text = "Reset Password"
		_login_button.text = "Save Password"
		_signup_button.visible = false
		_forgot_password_button.visible = false
		_email.visible = false
	else:
		_auth_title.text = "Sign in"
		_login_button.text = "Log in"
		_signup_button.visible = true
		_forgot_password_button.visible = true
		_email.visible = true


func _fit_auth_panel_to_screen() -> void:
	var vp: Vector2 = get_tree().root.get_viewport().get_visible_rect().size
	var max_w: int = maxi(260, int(vp.x) - 56)
	var panel_w: int = clampi(360, 280, max_w)
	_auth_panel.custom_minimum_size.x = panel_w

func _set_profile_open(open: bool) -> void:
	if open:
		_fit_profile_panel_to_screen()
	_profile_backdrop.visible = open
	_profile_panel.visible = open
	_content_margin.visible = not open
	if open:
		_profile_status.text = ""
		_profile_name.grab_focus()


func _fit_profile_panel_to_screen() -> void:
	var vp: Vector2 = get_tree().root.get_viewport().get_visible_rect().size
	var max_w: int = maxi(260, int(vp.x) - 56)
	var panel_w: int = clampi(360, 280, max_w)
	_profile_panel.custom_minimum_size.x = panel_w


func _set_account_open(open: bool) -> void:
	if open:
		_fit_account_panel_to_screen()
	_account_backdrop.visible = open
	_account_panel.visible = open
	_content_margin.visible = not open
	if open:
		_account_status.text = ""


func _fit_account_panel_to_screen() -> void:
	var vp: Vector2 = get_tree().root.get_viewport().get_visible_rect().size
	var max_w: int = maxi(260, int(vp.x) - 56)
	var panel_w: int = clampi(360, 280, max_w)
	_account_panel.custom_minimum_size.x = panel_w


func _refresh_user_line() -> void:
	if Backend.is_logged_in():
		_user_line.text = "Signed in as %s" % Backend.current_display_name
	else:
		_user_line.text = "Playing as guest (scores are local only)"
	_account_button.text = "Account"


func _on_menu_run_submitted_feedback(_data: Variant) -> void:
	if get_tree().current_scene != self:
		return
	if not is_instance_valid(_user_line):
		return
	_user_line.text = "Your last run was saved to the leaderboard."
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(_user_line):
		_refresh_user_line()


func _on_menu_run_submit_failed(_reason: String) -> void:
	if get_tree().current_scene != self:
		return
	if not is_instance_valid(_user_line):
		return
	var short := _reason.strip_edges()
	if short.length() > 90:
		short = short.substr(0, 87) + "..."
	_user_line.text = "Could not upload saved run: %s" % short
	await get_tree().create_timer(6.0).timeout
	if is_instance_valid(_user_line):
		_refresh_user_line()


func _set_mode_pick_open(open: bool) -> void:
	_mode_pick_layer.visible = open
	_content_margin.visible = not open
	_fx_layer.visible = not open
	_menu_dim.visible = not open


func _on_play_pressed() -> void:
	_try_unlock_mobile_audio()
	_request_mobile_web_fullscreen()
	GameProgress.tutorial_mode = false
	GameProgress.exit_tutorial_to_main_menu = false
	_leaderboard_layer.visible = false
	_set_mode_pick_open(true)


func _on_mode_normal_pressed() -> void:
	GameProgress.endless_mode = false
	_set_mode_pick_open(false)
	get_tree().change_scene_to_file(RUN_SETUP_SCENE)


func _on_mode_endless_pressed() -> void:
	GameProgress.endless_mode = true
	_set_mode_pick_open(false)
	get_tree().change_scene_to_file(RUN_SETUP_SCENE)


func _on_mode_pick_back_pressed() -> void:
	_set_mode_pick_open(false)


func _on_mode_pick_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_mode_pick_open(false)


func _on_credits_button_pressed() -> void:
	_credits_layer.visible = true


func _on_credits_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close_credits_pressed()


func _on_close_credits_pressed() -> void:
	_credits_layer.visible = false


func _on_leaderboard_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close_leaderboard_pressed()


func _on_how_to_play_pressed() -> void:
	GameProgress.endless_mode = false
	GameProgress.tutorial_mode = true
	GameProgress.exit_tutorial_to_main_menu = true
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_account_button_pressed() -> void:
	_try_unlock_mobile_audio()
	if Backend.is_logged_in():
		if _account_panel.visible:
			_set_account_open(false)
		else:
			_set_auth_open(false)
			_set_account_open(true)
		return
	if _auth_panel.visible:
		_set_auth_mode_reset(false)
		_set_auth_open(false)
	else:
		_set_auth_mode_reset(false)
		_set_auth_open(true)


func _on_close_auth_pressed() -> void:
	_set_auth_mode_reset(false)
	_set_auth_open(false)


func _on_login_pressed() -> void:
	_try_unlock_mobile_audio()
	if not _mobile_collect_auth_fields(true):
		return
	if _auth_reset_mode:
		var new_password := _password.text.strip_edges()
		if new_password.length() < 6:
			_auth_status.text = "Password must be at least 6 characters."
			return
		_auth_status.text = "Saving new password..."
		Backend.change_password(new_password)
		return
	var em := _email.text.strip_edges().to_lower()
	if not _email_is_valid_format(em):
		_auth_status.text = "Enter a valid email (needs @ and a domain like .com or .ca)."
		return
	_auth_status.text = "Signing in..."
	Backend.login(em, _password.text)


func _on_signup_pressed() -> void:
	_try_unlock_mobile_audio()
	if not _mobile_collect_auth_fields(true):
		return
	var em := _email.text.strip_edges().to_lower()
	if not _email_is_valid_format(em):
		_auth_status.text = "Enter a valid email (needs @ and a domain like .com or .ca)."
		return
	_auth_status.text = "Creating account..."
	Backend.signup(em, _password.text)


func _on_forgot_password_pressed() -> void:
	_try_unlock_mobile_audio()
	if _forgot_password_seconds_left() > 0:
		_auth_status.text = "Too many reset requests. Wait %ds and try again." % _forgot_password_seconds_left()
		return
	if not _mobile_collect_auth_fields(false):
		return
	var em := _email.text.strip_edges().to_lower()
	if not _email_is_valid_format(em):
		_auth_status.text = "Enter your account email first."
		return
	_auth_status.text = "Sending reset email..."
	Backend.request_password_reset(em)
	
func _on_create_profile_pressed() -> void:
	var name := _profile_name.text.strip_edges()
	if name.is_empty():
		_profile_status.text = "Enter a profile name."
		return

	if _profile_is_edit_mode:
		_profile_status.text = "Updating username..."
		Backend.update_profile(name)
	else:
		_profile_status.text = "Creating profile..."
		Backend.create_profile(name)


func _on_login_succeeded(_user_id: String) -> void:
	_auth_status.text = "Checking profile..."
	Backend.get_my_profile()
	

func _on_login_failed(message: String) -> void:
	_auth_status.text = message


func _on_signup_succeeded(message: String) -> void:
	_auth_status.text = message
	_refresh_user_line()
	if Backend.is_logged_in():
		_set_auth_open(false)


func _on_signup_failed(message: String) -> void:
	_auth_status.text = message
	
func _on_profile_lookup_succeeded(data: Variant) -> void:
	if typeof(data) != TYPE_ARRAY:
		_auth_status.text = "Unexpected profile response."
		return

	var rows: Array = data
	if rows.is_empty():
		_show_profile_prompt()
	else:
		_auth_status.text = "Welcome back!"
		_refresh_user_line()
		_set_auth_open(false)

func _on_profile_created(_data: Variant) -> void:
	_profile_status.text = "Profile created!"
	_profile_is_edit_mode = false
	_refresh_user_line()
	_set_profile_open(false)
	_set_auth_open(false)


func _on_profile_updated(data: Variant) -> void:
	if typeof(data) == TYPE_ARRAY:
		var rows: Array = data
		if not rows.is_empty():
			var row_value: Variant = rows[0]
			if typeof(row_value) == TYPE_DICTIONARY:
				var row: Dictionary = row_value
				Backend.current_display_name = str(row.get("display_name", Backend.current_display_name))
	_profile_status.text = "Username updated!"
	_profile_is_edit_mode = false
	_refresh_user_line()
	_set_profile_open(false)
	_set_account_open(true)


func _on_profile_update_failed(reason: String) -> void:
	var lowered := reason.to_lower()
	if lowered.contains("duplicate") or lowered.contains("display_name_key") or lowered.contains("already"):
		_profile_status.text = "That username is already taken. Try another one."
	else:
		_profile_status.text = "Could not update username. Please try again."


func _on_profile_lookup_failed(reason: String) -> void:
	_auth_status.text = reason
	
func _show_profile_prompt() -> void:
	_set_auth_open(false)
	_set_profile_open(true)
	_profile_is_edit_mode = false
	_profile_title.text = "Create Profile"
	_profile_status.text = "Choose a profile name to finish setup."
	_profile_name.text = ""
	_profile_name.grab_focus()


func _on_change_username_pressed() -> void:
	_set_account_open(false)
	_set_profile_open(true)
	_profile_is_edit_mode = true
	_profile_title.text = "Change Username"
	_profile_status.text = "Enter a new display name."
	_profile_name.text = Backend.current_display_name
	_profile_name.grab_focus()


func _on_change_password_pressed() -> void:
	_account_status.text = "Sending reset email..."
	Backend.request_password_reset(Backend.current_email)


func _on_sign_out_pressed() -> void:
	Backend.logout()
	_set_account_open(false)
	_set_auth_open(false)
	_refresh_user_line()


func _on_close_account_pressed() -> void:
	_set_account_open(false)


func _on_account_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_account_open(false)


func _on_password_reset_requested(message: String) -> void:
	_stop_forgot_password_countdown()
	if _account_panel.visible:
		_account_status.text = message
	else:
		_auth_status.text = message


func _on_password_reset_failed(message: String) -> void:
	if _account_panel.visible:
		_account_status.text = message
	else:
		_auth_status.text = message


func _forgot_password_seconds_left() -> int:
	return maxi(0, _forgot_password_retry_until_unix - int(Time.get_unix_time_from_system()))


func _start_forgot_password_countdown(wait_seconds: int) -> void:
	if wait_seconds <= 0:
		return
	_forgot_password_retry_until_unix = int(Time.get_unix_time_from_system()) + wait_seconds
	_update_forgot_password_button_countdown()
	if _forgot_password_seconds_left() > 0 and _forgot_password_timer != null and _forgot_password_timer.is_stopped():
		_forgot_password_timer.start()


func _stop_forgot_password_countdown() -> void:
	_forgot_password_retry_until_unix = 0
	_forgot_password_button.text = "Forgot password"
	if _forgot_password_timer != null and not _forgot_password_timer.is_stopped():
		_forgot_password_timer.stop()


func _update_forgot_password_button_countdown() -> void:
	var secs := _forgot_password_seconds_left()
	if secs > 0:
		_forgot_password_button.text = "Forgot password (%ds)" % secs
	else:
		_forgot_password_button.text = "Forgot password"


func _on_forgot_password_countdown_tick() -> void:
	_update_forgot_password_button_countdown()
	if _forgot_password_seconds_left() <= 0 and _forgot_password_timer != null:
		_forgot_password_timer.stop()


func _on_password_reset_rate_limited(wait_seconds: int, _message: String) -> void:
	_start_forgot_password_countdown(wait_seconds)
	var line := "Too many reset requests. Wait %ds and try again." % _forgot_password_seconds_left()
	if _account_panel.visible:
		_account_status.text = line
	else:
		_auth_status.text = line


func _on_password_changed(message: String) -> void:
	_set_auth_mode_reset(false)
	_auth_status.text = message


func _on_password_change_failed(message: String) -> void:
	_auth_status.text = message


func _on_password_recovery_ready(email: String) -> void:
	_set_account_open(false)
	_set_auth_mode_reset(true)
	_set_auth_open(true)
	_email.text = email
	_password.text = ""
	_auth_status.text = "Enter your new password."
	_password.grab_focus()


func _on_password_recovery_failed(message: String) -> void:
	_set_auth_mode_reset(false)
	_set_auth_open(true)
	_auth_status.text = message

func _on_leaderboard_pressed() -> void:
	_set_mode_pick_open(false)
	_leaderboard_layer.visible = true
	_leaderboard_status.text = "Loading..."
	_leaderboard_list_base.clear()
	_leaderboard_list_endless.clear()
	_leaderboard_pending = 2
	Backend.get_top_10()
	Backend.get_top_10_endless()


func _on_settings_pressed() -> void:
	(_settings_window as Node).call("open_settings")


func _friendly_endless_leaderboard_error(raw: String) -> String:
	var r := raw.strip_edges()
	if r.length() > 160 or r.contains("function public.") or r.contains("PGRST"):
		return "Endless scores need the server script (leaderboard_endless_runs.sql)."
	return "Could not load endless list."


func _on_leaderboard_failed(reason: String) -> void:
	_leaderboard_list_base.clear()
	_leaderboard_pending = maxi(0, _leaderboard_pending - 1)
	var short := reason.strip_edges()
	if short.length() > 100:
		short = short.substr(0, 97) + "..."
	_leaderboard_list_base.add_item("— Base game: %s —" % short)
	_leaderboard_try_finish_status()


func _on_leaderboard_endless_failed(reason: String) -> void:
	_leaderboard_list_endless.clear()
	_leaderboard_pending = maxi(0, _leaderboard_pending - 1)
	_leaderboard_list_endless.add_item("— %s —" % _friendly_endless_leaderboard_error(reason))
	_leaderboard_try_finish_status()


func _fill_leaderboard_rows(list: ItemList, rows: Array) -> void:
	list.clear()
	var rank := 1
	for entry in rows:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry
		var name := str(d.get("display_name", d.get("user_id", "?")))
		var score := int(d.get("score_total", 0))
		var waves := int(d.get("waves_completed", 0))
		var fed := int(d.get("total_fed", 0))
		var missed := int(d.get("total_missed", 0))
		list.add_item("%d. %s — %d pts (Wave %d) | Fed: %d | Missed: %d" % [rank, name, score, waves, fed, missed])
		rank += 1


func _leaderboard_try_finish_status() -> void:
	if _leaderboard_pending > 0:
		return
	if _leaderboard_status.text == "Loading...":
		_leaderboard_status.text = "Top scores (best run per account, per mode)"


func _on_leaderboard_received(data: Variant) -> void:
	if typeof(data) != TYPE_ARRAY:
		_leaderboard_list_base.clear()
		_leaderboard_status.text = "Base game: unexpected response."
		_leaderboard_pending = maxi(0, _leaderboard_pending - 1)
		_leaderboard_try_finish_status()
		return
	var rows: Array = data
	if rows.is_empty():
		_leaderboard_list_base.clear()
		_leaderboard_list_base.add_item("(No scores yet)")
	else:
		_fill_leaderboard_rows(_leaderboard_list_base, rows)
	_leaderboard_pending -= 1
	_leaderboard_try_finish_status()


func _on_leaderboard_endless_received(data: Variant) -> void:
	if typeof(data) != TYPE_ARRAY:
		_leaderboard_list_endless.clear()
		_leaderboard_status.text = "Endless mode: unexpected response."
		_leaderboard_pending = maxi(0, _leaderboard_pending - 1)
		_leaderboard_try_finish_status()
		return
	var rows: Array = data
	if rows.is_empty():
		_leaderboard_list_endless.clear()
		_leaderboard_list_endless.add_item("(No scores yet)")
	else:
		_fill_leaderboard_rows(_leaderboard_list_endless, rows)
	_leaderboard_pending -= 1
	_leaderboard_try_finish_status()


func _on_close_leaderboard_pressed() -> void:
	_leaderboard_layer.visible = false
