class_name GamePauseLayer
extends CanvasLayer

const MAIN_MENU := "res://scenes/ui/main_menu/main_menu.tscn"
const UI_FONT := preload("res://assets/game/ui/fonts/PixelOperator8.ttf")

@onready var _root: Control = $PauseRoot
@onready var _leaderboard_window: Window = $PauseRoot/LeaderboardWindow
@onready var _leaderboard_list: ItemList = $PauseRoot/LeaderboardWindow/Margin/VBox/LeaderboardList
@onready var _leaderboard_status: Label = $PauseRoot/LeaderboardWindow/Margin/VBox/LeaderboardStatus


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_leaderboard_window.process_mode = Node.PROCESS_MODE_ALWAYS
	_leaderboard_window.hide()
	_apply_fonts(_root)
	var title: Label = _root.get_node("Center/Panel/Margin/VBox/Title") as Label
	if title:
		title.add_theme_font_size_override("font_size", 22)
	var hint: Label = _root.get_node("Center/Panel/Margin/VBox/Hint") as Label
	if hint:
		hint.add_theme_font_size_override("font_size", 8)
		hint.modulate = Color(0.85, 0.85, 0.85)
	Backend.leaderboard_received.connect(_on_leaderboard_received)
	Backend.leaderboard_failed.connect(_on_leaderboard_failed)


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
	_leaderboard_window.hide()
	get_tree().paused = true


func close_pause() -> void:
	_root.visible = false
	_leaderboard_window.hide()
	get_tree().paused = false


func _on_resume_pressed() -> void:
	close_pause()


func _on_leaderboard_pressed() -> void:
	_leaderboard_window.popup_centered_ratio(0.85)
	_leaderboard_status.text = "Loading..."
	_leaderboard_list.clear()
	Backend.get_top_10()


func _on_quit_to_menu_pressed() -> void:
	get_tree().paused = false
	_root.visible = false
	get_tree().change_scene_to_file(MAIN_MENU)


func _on_close_leaderboard_pressed() -> void:
	_leaderboard_window.hide()


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
