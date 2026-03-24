class_name GamePauseLayer
extends CanvasLayer

const MAIN_MENU := "res://scenes/ui/main_menu/main_menu.tscn"
const UI_FONT := preload("res://assets/game/ui/fonts/PixelOperator8.ttf")

@onready var _root: Control = $PauseRoot
@onready var _settings_window: Window = $SettingsUILayer/SettingsWindow
@onready var _leaderboard_layer: CanvasLayer = $PauseLeaderboardLayer
@onready var _leaderboard_backdrop: ColorRect = $PauseLeaderboardLayer/LbBackdrop
@onready var _leaderboard_list_base: ItemList = $PauseLeaderboardLayer/LbCenter/LbPanel/Margin/VBox/BaseGameSection/LeaderboardListBase
@onready var _leaderboard_list_endless: ItemList = $PauseLeaderboardLayer/LbCenter/LbPanel/Margin/VBox/EndlessSection/LeaderboardListEndless
@onready var _leaderboard_status: Label = $PauseLeaderboardLayer/LbCenter/LbPanel/Margin/VBox/LeaderboardStatus

var _leaderboard_pending: int = 0


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_leaderboard_layer.visible = false
	_leaderboard_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_leaderboard_backdrop.gui_input.connect(_on_leaderboard_backdrop_gui_input)
	_apply_fonts(_root)
	_apply_fonts(_leaderboard_layer)
	var title: Label = _root.get_node("Center/Panel/Margin/VBox/Title") as Label
	if title:
		title.add_theme_font_size_override("font_size", 22)
	var hint: Label = _root.get_node("Center/Panel/Margin/VBox/Hint") as Label
	if hint:
		hint.add_theme_font_size_override("font_size", 8)
		hint.modulate = Color(0.85, 0.85, 0.85)
	Backend.leaderboard_received.connect(_on_leaderboard_received)
	Backend.leaderboard_failed.connect(_on_leaderboard_failed)
	Backend.leaderboard_endless_received.connect(_on_leaderboard_endless_received)
	Backend.leaderboard_endless_failed.connect(_on_leaderboard_endless_failed)
	_style_pause_leaderboard_panel()


func _style_pause_leaderboard_panel() -> void:
	var tl: Label = _leaderboard_layer.get_node_or_null("LbCenter/LbPanel/Margin/VBox/LeaderboardTitle") as Label
	if tl:
		tl.add_theme_font_size_override("font_size", 13)


func _apply_fonts(node: Node) -> void:
	if node is Control:
		var c := node as Control
		if c is Button or c is Label:
			c.add_theme_font_override("font", UI_FONT)
			c.add_theme_font_size_override("font_size", 11)
		elif c is ItemList:
			c.add_theme_font_override("font", UI_FONT)
			c.add_theme_font_size_override("font_size", 10)
	for ch in node.get_children():
		_apply_fonts(ch)


func is_open() -> bool:
	return _root.visible


func open_pause() -> void:
	_root.visible = true
	_leaderboard_layer.visible = false
	get_tree().paused = true


func close_pause() -> void:
	_root.visible = false
	_leaderboard_layer.visible = false
	get_tree().paused = false


func _on_resume_pressed() -> void:
	close_pause()


func _on_settings_pressed() -> void:
	(_settings_window as Node).call("open_settings")


func _on_leaderboard_pressed() -> void:
	_leaderboard_layer.visible = true
	_leaderboard_status.text = "Loading..."
	_leaderboard_list_base.clear()
	_leaderboard_list_endless.clear()
	_leaderboard_pending = 2
	Backend.get_top_10()
	Backend.get_top_10_endless()


func _on_quit_to_menu_pressed() -> void:
	get_tree().paused = false
	_root.visible = false
	Music.play_menu()
	get_tree().change_scene_to_file(MAIN_MENU)


func _on_close_leaderboard_pressed() -> void:
	_leaderboard_layer.visible = false


func _on_leaderboard_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close_leaderboard_pressed()


func _friendly_endless_leaderboard_error(raw: String) -> String:
	var r := raw.strip_edges()
	if r.length() > 160 or r.contains("function public.") or r.contains("PGRST"):
		return "Endless scores need the server script (leaderboard_endless_runs.sql)."
	return "Could not load endless list."


func _leaderboard_try_finish_status() -> void:
	if _leaderboard_pending > 0:
		return
	if _leaderboard_status.text == "Loading...":
		_leaderboard_status.text = "Top scores (best run per account, per mode)"


func _fill_leaderboard_rows_full(list: ItemList, rows: Array) -> void:
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


func _on_leaderboard_received(data: Variant) -> void:
	if typeof(data) != TYPE_ARRAY:
		_leaderboard_list_base.clear()
		_leaderboard_status.text = "Base game: unexpected response."
		_leaderboard_pending = maxi(0, _leaderboard_pending - 1)
		return
	var rows: Array = data
	if rows.is_empty():
		_leaderboard_list_base.clear()
		_leaderboard_list_base.add_item("(No scores yet)")
	else:
		_fill_leaderboard_rows_full(_leaderboard_list_base, rows)
	_leaderboard_pending -= 1
	_leaderboard_try_finish_status()


func _on_leaderboard_endless_received(data: Variant) -> void:
	if typeof(data) != TYPE_ARRAY:
		_leaderboard_list_endless.clear()
		_leaderboard_status.text = "Endless mode: unexpected response."
		_leaderboard_pending = maxi(0, _leaderboard_pending - 1)
		return
	var rows: Array = data
	if rows.is_empty():
		_leaderboard_list_endless.clear()
		_leaderboard_list_endless.add_item("(No scores yet)")
	else:
		_fill_leaderboard_rows_full(_leaderboard_list_endless, rows)
	_leaderboard_pending -= 1
	_leaderboard_try_finish_status()
