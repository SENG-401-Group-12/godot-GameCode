extends Control

const MAIN_MENU := "res://scenes/ui/main_menu/main_menu.tscn"
const GAME_SCENE := "res://scenes/test/test_scene_gameloop.tscn"
const TUTORIAL_SCENE := "res://scenes/tutorial/tutorial_lesson.tscn"
const UI_FONT := preload("res://assets/game/ui/fonts/PixelOperator8.ttf")
const PLAYER_SCENE := preload("res://scenes/characters/player/player.tscn")

var _main_panel: VBoxContainer
var _preview_holder: CharacterBody2D
var _preview_sprite: AnimatedSprite2D


func _ready() -> void:
	_build_ui()
	_refresh_skin_grid_selection()


func _process(_delta: float) -> void:
	if _preview_sprite and _preview_sprite.sprite_frames:
		if _preview_sprite.animation != &"walk_right" or not _preview_sprite.is_playing():
			_preview_sprite.play(&"walk_right")


func _make_skin_thumbnail(index: int) -> Texture2D:
	var at := AtlasTexture.new()
	var tex := PlayerData.get_character_texture(index)
	at.atlas = tex
	at.region = Rect2(0, 0, 64, 64)
	return at


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

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	center.add_child(row)

	var preview_col := VBoxContainer.new()
	preview_col.add_theme_constant_override("separation", 6)
	row.add_child(preview_col)

	var preview_title := Label.new()
	preview_title.text = "Preview"
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_title.add_theme_font_override("font", UI_FONT)
	preview_title.add_theme_font_size_override("font_size", 10)
	preview_col.add_child(preview_title)

	var vp_container := SubViewportContainer.new()
	vp_container.custom_minimum_size = Vector2(120, 152)
	vp_container.stretch = true
	preview_col.add_child(vp_container)

	var vp := SubViewport.new()
	vp.size = Vector2i(120, 152)
	vp.transparent_bg = true
	vp.handle_input_locally = false
	vp_container.add_child(vp)

	_preview_holder = PLAYER_SCENE.instantiate() as CharacterBody2D
	_preview_holder.position = Vector2(60, 130)
	_preview_holder.collision_layer = 0
	_preview_holder.collision_mask = 0
	_preview_holder.set_physics_process(false)
	vp.add_child(_preview_holder)
	_preview_sprite = _preview_holder.get_node("AnimatedSprite2D") as AnimatedSprite2D

	_main_panel = VBoxContainer.new()
	_main_panel.add_theme_constant_override("separation", 10)
	_main_panel.custom_minimum_size = Vector2(400, 0)
	row.add_child(_main_panel)

	var title := Label.new()
	title.text = "Before you play"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 16)
	_main_panel.add_child(title)

	var sub := Label.new()
	sub.text = "Click a look to select it — the preview updates on the left."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_override("font", UI_FONT)
	sub.add_theme_font_size_override("font_size", 9)
	_main_panel.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 210)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_main_panel.add_child(scroll)

	var grid := GridContainer.new()
	grid.name = "SkinGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	for i in range(PlayerData.CHARACTER_PRESET_NAMES.size()):
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)

		var tb := TextureButton.new()
		tb.texture_normal = _make_skin_thumbnail(i)
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		tb.custom_minimum_size = Vector2(78, 78)
		tb.modulate = Color.WHITE
		tb.pressed.connect(_on_preset_chosen.bind(i))
		cell.add_child(tb)

		var lbl := Label.new()
		lbl.text = PlayerData.CHARACTER_PRESET_NAMES[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size = Vector2(96, 0)
		lbl.add_theme_font_override("font", UI_FONT)
		lbl.add_theme_font_size_override("font_size", 7)
		cell.add_child(lbl)

		grid.add_child(cell)

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


func _refresh_skin_grid_selection() -> void:
	var grid := _main_panel.find_child("SkinGrid", true, false) as GridContainer
	if grid == null:
		return
	var idx := 0
	for cell in grid.get_children():
		if not (cell is VBoxContainer):
			continue
		if cell.get_child_count() < 1:
			continue
		var tb := cell.get_child(0) as TextureButton
		if tb:
			tb.self_modulate = Color(1.12, 1.08, 0.92) if idx == PlayerData.character_preset_index else Color.WHITE
		idx += 1

	if _preview_holder and _preview_holder.has_method(&"refresh_appearance_from_data"):
		_preview_holder.refresh_appearance_from_data()
	if _preview_sprite:
		_preview_sprite.play(&"walk_right")


func _on_preset_chosen(i: int) -> void:
	PlayerData.set_character_preset(i)
	_refresh_skin_grid_selection()


func _on_continue_pressed() -> void:
	GameProgress.tutorial_mode = false
	GameProgress.exit_tutorial_to_main_menu = false
	if not GameProgress.tutorial_completed:
		GameProgress.tutorial_mode = true
		get_tree().change_scene_to_file(GAME_SCENE)
	else:
		get_tree().change_scene_to_file(GAME_SCENE)
