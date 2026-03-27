extends Node2D

const MAIN_MENU := "res://scenes/ui/main_menu/main_menu.tscn"
const GAME_SCENE := "res://scenes/test/test_scene_gameloop.tscn"
const UI_FONT := preload("res://assets/game/ui/fonts/PixelOperator8.ttf")

enum Step { PLANT, HARVEST, FEED, SHOP, DONE }

var _step: int = Step.PLANT

@onready var farm: Node2D = $Farm
@onready var shop: Node2D = $Shop
@onready var customer: Node2D = $Customer
@onready var shop_ui: Control = $UserInterface/ShopUI
@onready var in_game_ui: Control = $UserInterface/InGameUI
@onready var step_label: Label = $StepBanner/Margin/StepLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerData.reset_run_state()
	Music.enter_gameplay()

	farm.crop_planted.connect(_on_crop_planted)
	farm.crop_harvested.connect(_on_crop_harvested)
	customer.served.connect(_on_customer_served)
	shop_ui.upgrade_purchased.connect(_on_upgrade_purchased)

	step_label.add_theme_font_override("font", UI_FONT)
	step_label.add_theme_font_size_override("font_size", 10)

	await get_tree().process_frame
	shop.timer_count = 99999.0
	_clear_hud_tip()
	_set_step(Step.PLANT)


func _clear_hud_tip() -> void:
	var msg: Label = in_game_ui.get_node_or_null("MarginContainer/HBoxContainer/CenterMessage") as Label
	if msg:
		msg.text = ""
		msg.modulate = Color(1, 1, 1, 1)


func _set_step(s: int) -> void:
	_step = s
	match s:
		Step.PLANT:
			step_label.text = "Pick a seed, stand on soil, then interact to plant."
		Step.HARVEST:
			step_label.text = "Wait for growth, then interact with the plot to harvest."
		Step.FEED:
			step_label.text = "Stand by the visitor and interact to feed. Faster serve = more seeds."
		Step.SHOP:
			step_label.text = "Open shop and buy one upgrade."
		Step.DONE:
			step_label.text = "All set!"


func _on_crop_planted(_crop_name: String) -> void:
	if _step != Step.PLANT:
		return
	_set_step(Step.HARVEST)


func _on_crop_harvested(crop_name: String) -> void:
	if _step != Step.HARVEST:
		return
	var have := PlayerData.get_crop_amount(crop_name)
	var ask := mini(2, have)
	if ask < 1:
		return
	customer.begin_with_single_request(crop_name, ask)
	_set_step(Step.FEED)


func _on_customer_served(_c: Node2D) -> void:
	if _step != Step.FEED:
		return
	shop.timer_count = 0.0
	_set_step(Step.SHOP)


func _on_upgrade_purchased() -> void:
	if _step != Step.SHOP:
		return
	_step = Step.DONE
	step_label.text = "Great job! Loading next screen…"
	await get_tree().create_timer(1.4).timeout
	_finish_lesson()


func _finish_lesson() -> void:
	if GameProgress.exit_tutorial_to_main_menu:
		GameProgress.exit_tutorial_to_main_menu = false
		Music.play_menu()
		get_tree().change_scene_to_file(MAIN_MENU)
		return
	if not GameProgress.tutorial_completed:
		GameProgress.mark_tutorial_completed()
	get_tree().change_scene_to_file(GAME_SCENE)
