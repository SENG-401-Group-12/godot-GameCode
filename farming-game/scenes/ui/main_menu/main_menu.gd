extends Control

const GAME_SCENE := preload("res://scenes/test/test_scene_gameloop.tscn")
const UI_FONT := preload("res://assets/game/ui/fonts/PixelOperator8.ttf")

@onready var _auth_panel: PanelContainer = $AuthLayer/AuthCenter/AuthPanel
@onready var _email: LineEdit = $AuthLayer/AuthCenter/AuthPanel/Margin/VBox/EmailEdit
@onready var _password: LineEdit = $AuthLayer/AuthCenter/AuthPanel/Margin/VBox/PasswordEdit
@onready var _auth_status: Label = $AuthLayer/AuthCenter/AuthPanel/Margin/VBox/AuthStatusLabel
@onready var _account_button: Button = $ContentMargin/Center/MainColumn/AccountButton
@onready var _user_line: Label = $ContentMargin/Center/MainColumn/UserLine

@onready var _leaderboard_window: Window = $LeaderboardWindow
@onready var _leaderboard_list: ItemList = $LeaderboardWindow/Margin/VBox/LeaderboardList
@onready var _leaderboard_status: Label = $LeaderboardWindow/Margin/VBox/LeaderboardStatus


func _ready() -> void:
	_apply_font_recursive(self)
	_auth_panel.visible = false
	_leaderboard_window.hide()
	_refresh_user_line()

	Backend.login_succeeded.connect(_on_login_succeeded)
	Backend.login_failed.connect(_on_login_failed)
	Backend.signup_succeeded.connect(_on_signup_succeeded)
	Backend.signup_failed.connect(_on_signup_failed)
	Backend.leaderboard_received.connect(_on_leaderboard_received)


func _apply_font_recursive(node: Node) -> void:
	if node is Control:
		var c := node as Control
		if c is Button or c is Label or c is LineEdit:
			c.add_theme_font_override("font", UI_FONT)
			c.add_theme_font_size_override("font_size", 10)
	for child in node.get_children():
		_apply_font_recursive(child)


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
		_auth_panel.visible = false
		return
	_auth_panel.visible = !_auth_panel.visible
	_auth_status.text = ""


func _on_close_auth_pressed() -> void:
	_auth_panel.visible = false


func _on_login_pressed() -> void:
	_auth_status.text = "Signing in..."
	Backend.login(_email.text.strip_edges(), _password.text)


func _on_signup_pressed() -> void:
	_auth_status.text = "Creating account..."
	Backend.signup(_email.text.strip_edges(), _password.text)


func _on_guest_pressed() -> void:
	Backend.continue_as_guest()
	_refresh_user_line()
	_auth_panel.visible = false


func _on_login_succeeded(_user_id: String) -> void:
	_auth_status.text = "Welcome back!"
	_refresh_user_line()


func _on_login_failed(message: String) -> void:
	_auth_status.text = message


func _on_signup_succeeded(message: String) -> void:
	_auth_status.text = message
	_refresh_user_line()


func _on_signup_failed(message: String) -> void:
	_auth_status.text = message


func _on_leaderboard_pressed() -> void:
	_leaderboard_window.popup_centered_ratio(0.85)
	_leaderboard_status.text = "Loading..."
	_leaderboard_list.clear()
	Backend.get_top_10()


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
