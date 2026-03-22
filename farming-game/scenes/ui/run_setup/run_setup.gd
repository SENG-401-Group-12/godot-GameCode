extends Control

const MAIN_MENU := "res://scenes/ui/main_menu/main_menu.tscn"
const GAME_SCENE := "res://scenes/test/test_scene_gameloop.tscn"
const UI_FONT := preload("res://assets/game/ui/fonts/PixelOperator8.ttf")

const _TUTORIAL_PAGES: PackedStringArray = [
	"[b]Welcome![/b]\n\nYou run a small farm. Hungry customers arrive in [b]waves[/b]. Each shows crops they need and a timer.\n\nGoal: plant, grow, harvest, then stand next to them and press [b]E[/b] (or tap Interact) to hand food over.",
	"[b]Farming[/b]\n\n1) Pick a crop on the right panel.\n2) Stand on an empty plot and interact to [b]plant[/b].\n3) Wait for it to mature, then [b]harvest[/b] — you get a bundle based on plot size.\n\nYou can run multiple plots at once.",
	"[b]Shop & upgrades[/b]\n\nWhen the shop opens, pick [b]one[/b] upgrade. Each bonus has a cap per run — you will not see the same choice twice in one visit.\n\nPlan around what customers are asking for.",
	"[b]Waves & fairness[/b]\n\nYou can only miss so many customers per wave (shown in the HUD). If too many leave hungry, the run ends.\n\nTimers are a bit gentler early on — still stay quick!",
]

var _replay_only := false
var _tutorial_page := 0
var _tutorial_layer: CanvasLayer
var _page_label: RichTextLabel
var _main_panel: VBoxContainer


func _ready() -> void:
	_replay_only = GameProgress.open_tutorial_replay_from_menu
	GameProgress.open_tutorial_replay_from_menu = false
	_build_ui()
	if _replay_only:
		_main_panel.visible = false
		_open_tutorial(true)
	else:
		_refresh_preset_buttons()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.05, 0.12, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(center)

	_main_panel = VBoxContainer.new()
	_main_panel.add_theme_constant_override("separation", 10)
	_main_panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(_main_panel)

	var title := Label.new()
	title.text = "Before you play"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 16)
	_main_panel.add_child(title)

	var sub := Label.new()
	sub.text = "Choose a look (same farmer art — color style only)."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_override("font", UI_FONT)
	sub.add_theme_font_size_override("font_size", 9)
	_main_panel.add_child(sub)

	var preset_row := HBoxContainer.new()
	preset_row.alignment = BoxContainer.ALIGNMENT_CENTER
	preset_row.add_theme_constant_override("separation", 8)
	preset_row.name = "PresetRow"
	_main_panel.add_child(preset_row)

	for i in range(PlayerData.CHARACTER_PRESET_NAMES.size()):
		var b := Button.new()
		b.text = PlayerData.CHARACTER_PRESET_NAMES[i]
		b.custom_minimum_size = Vector2(96, 32)
		b.add_theme_font_override("font", UI_FONT)
		b.add_theme_font_size_override("font_size", 8)
		b.pressed.connect(_on_preset_chosen.bind(i))
		preset_row.add_child(b)

	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 12)
	_main_panel.add_child(row2)

	var cont := Button.new()
	cont.text = "Continue"
	cont.custom_minimum_size = Vector2(160, 36)
	cont.add_theme_font_override("font", UI_FONT)
	cont.add_theme_font_size_override("font_size", 10)
	cont.pressed.connect(_on_continue_pressed)
	row2.add_child(cont)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(100, 36)
	back.add_theme_font_override("font", UI_FONT)
	back.add_theme_font_size_override("font_size", 9)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_MENU))
	row2.add_child(back)

	_tutorial_layer = CanvasLayer.new()
	_tutorial_layer.layer = 50
	_tutorial_layer.visible = false
	add_child(_tutorial_layer)

	var t_margin := MarginContainer.new()
	t_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	t_margin.add_theme_constant_override("margin_left", 12)
	t_margin.add_theme_constant_override("margin_top", 12)
	t_margin.add_theme_constant_override("margin_right", 12)
	t_margin.add_theme_constant_override("margin_bottom", 12)
	_tutorial_layer.add_child(t_margin)

	var t_overlay_root := Control.new()
	t_overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	t_overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	t_margin.add_child(t_overlay_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.75)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	t_overlay_root.add_child(dim)

	var t_center := CenterContainer.new()
	t_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	t_center.mouse_filter = Control.MOUSE_FILTER_STOP
	t_overlay_root.add_child(t_center)

	var t_panel := PanelContainer.new()
	t_panel.custom_minimum_size = Vector2(440, 280)
	t_center.add_child(t_panel)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 14)
	inner.add_theme_constant_override("margin_top", 12)
	inner.add_theme_constant_override("margin_right", 14)
	inner.add_theme_constant_override("margin_bottom", 12)
	t_panel.add_child(inner)

	var tvbox := VBoxContainer.new()
	tvbox.add_theme_constant_override("separation", 8)
	inner.add_child(tvbox)

	var tt := Label.new()
	tt.text = "How to play"
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tt.add_theme_font_override("font", UI_FONT)
	tt.add_theme_font_size_override("font_size", 14)
	tvbox.add_child(tt)

	_page_label = RichTextLabel.new()
	_page_label.bbcode_enabled = true
	_page_label.fit_content = true
	_page_label.scroll_active = true
	_page_label.custom_minimum_size = Vector2(400, 160)
	_page_label.add_theme_font_override("normal_font", UI_FONT)
	_page_label.add_theme_font_size_override("normal_font_size", 9)
	tvbox.add_child(_page_label)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 10)
	tvbox.add_child(nav)

	var prev_b := Button.new()
	prev_b.text = "Prev"
	prev_b.add_theme_font_override("font", UI_FONT)
	prev_b.add_theme_font_size_override("font_size", 9)
	prev_b.pressed.connect(_on_tutorial_prev)
	nav.add_child(prev_b)

	var skip_b := Button.new()
	skip_b.text = "Skip"
	skip_b.add_theme_font_override("font", UI_FONT)
	skip_b.add_theme_font_size_override("font_size", 9)
	skip_b.pressed.connect(_on_tutorial_skip)
	nav.add_child(skip_b)

	var next_b := Button.new()
	next_b.text = "Next"
	next_b.add_theme_font_override("font", UI_FONT)
	next_b.add_theme_font_size_override("font_size", 9)
	next_b.pressed.connect(_on_tutorial_next)
	nav.add_child(next_b)


func _refresh_preset_buttons() -> void:
	var row := _main_panel.get_node_or_null("PresetRow") as HBoxContainer
	if row == null:
		return
	var idx := 0
	for b in row.get_children():
		if b is Button:
			var sel := idx == PlayerData.character_preset_index
			(b as Button).modulate = Color(1.2, 1.15, 0.85) if sel else Color.WHITE
			idx += 1


func _on_preset_chosen(i: int) -> void:
	PlayerData.set_character_preset(i)
	_refresh_preset_buttons()


func _on_continue_pressed() -> void:
	if _replay_only:
		return
	if not GameProgress.tutorial_completed:
		_open_tutorial(false)
	else:
		_go_game()


func _open_tutorial(from_replay_menu: bool) -> void:
	_tutorial_page = 0
	if from_replay_menu:
		_replay_only = true
	_tutorial_layer.visible = true
	_update_tutorial_page()


func _update_tutorial_page() -> void:
	_page_label.text = _TUTORIAL_PAGES[_tutorial_page]


func _on_tutorial_prev() -> void:
	_tutorial_page = maxi(0, _tutorial_page - 1)
	_update_tutorial_page()


func _on_tutorial_next() -> void:
	if _tutorial_page >= _TUTORIAL_PAGES.size() - 1:
		_finish_tutorial()
	else:
		_tutorial_page += 1
		_update_tutorial_page()


func _on_tutorial_skip() -> void:
	_finish_tutorial()


func _finish_tutorial() -> void:
	_tutorial_layer.visible = false
	if _replay_only:
		get_tree().change_scene_to_file(MAIN_MENU)
		return
	if not GameProgress.tutorial_completed:
		GameProgress.mark_tutorial_completed()
	_go_game()


func _go_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
