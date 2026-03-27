extends Node2D

const CUSTOMER_SCENE := preload("res://scenes/characters/customer/customer.tscn")
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu/main_menu.tscn"
const GAME_SCENE := "res://scenes/test/test_scene_gameloop.tscn"

enum TutorialStep { PLANT, HARVEST, FEED, SHOP, DONE }

@export var start_time_buffer := 18
@export var time_between_waves := 6
@export var victory_after_wave: int = 12

@onready var customer_spawner: Node2D = $CustomerSpawner
@onready var game_ui = $"../UserInterface/InGameUI"
@onready var shop: Node2D = $"../Shop"
@onready var shop_ui: Control = $"../UserInterface/ShopUI"

var current_wave := 0
var wave_customer_count := 0
var wave_fed_count := 0
var total_fed_count := 0
var wave_missed_count := 0
var total_missed_count := 0
var allowed_misses := 0
var waiting_for_next_wave := false
var game_finished := false
var run_start_msec: int = 0
var _loss_finalized := false
var _win_finalized := false
var _wave_advance_in_progress := false

var _tutorial_mode := false
var _tutorial_step: int = TutorialStep.PLANT
var _tutorial_customer: Node2D
var _tutorial_waiting_for_exit_click := false
var _endless_run := false
var _difficulty_bias: float = 0.0
var _combo_streak: int = 0
var _combo_bonus_score: int = 0
var _last_serve_msec: int = -999999
var _endless_mutator_name: String = ""
var _mutator_customer_mult: float = 1.0
var _mutator_time_mult: float = 1.0
var _mutator_amount_mult: float = 1.0
var _mutator_reward_mult: float = 1.0
var _mutator_shop_cooldown_mult: float = 1.0

const STARTING_SEEDS := 0
const COMBO_WINDOW_MSEC := 6000
const COMBO_BONUS_MAX := 3
## Seed multiplier from how fast you fed them: ratio = time_left / order_time. Lerp between these.
const FEED_SPEED_MULT_MIN := 0.5
const FEED_SPEED_MULT_MAX := 1.35
## Endless only: lose the run after this many missed customers total (across all waves).
const ENDLESS_MAX_TOTAL_MISSES := 10


func _max_misses_before_fail() -> int:
	# Game ends when wave_missed_count > allowed_misses, so displayed cap is allowed + 1.
	return maxi(0, allowed_misses + 1)


func _world() -> Node:
	return get_parent()


func _resolve_game_ui() -> Node:
	if is_instance_valid(game_ui):
		return game_ui
	var w := _world()
	if w == null:
		return null
	return w.get_node_or_null("UserInterface/InGameUI")


func _set_tutorial_objective(title: String, body: String) -> void:
	var ui := _resolve_game_ui()
	if ui and ui.has_method(&"set_tutorial_objective"):
		ui.set_tutorial_objective(title, body)


func _clear_tutorial_objective() -> void:
	var ui := _resolve_game_ui()
	if ui and ui.has_method(&"clear_tutorial_objective"):
		ui.clear_tutorial_objective()


func _ready() -> void:
	customer_spawner.customer_served.connect(_on_customer_served)
	customer_spawner.customer_expired.connect(_on_customer_expired)
	customer_spawner.customer_spawned.connect(_refresh_ui_status)
	Backend.run_submitted.connect(_on_run_submitted)
	Backend.run_submit_failed.connect(_on_run_submit_failed)
	Backend.personal_best_received.connect(_on_personal_best_received)
	Backend.personal_best_failed.connect(_on_personal_best_failed)
	Backend.personal_best_endless_received.connect(_on_personal_best_endless_received)
	Backend.personal_best_endless_failed.connect(_on_personal_best_endless_failed)
	randomize()
	PlayerData.reset_run_state()
	Music.enter_gameplay()

	_tutorial_mode = GameProgress.tutorial_mode or GameProgress.exit_tutorial_to_main_menu
	_endless_run = GameProgress.endless_mode and not _tutorial_mode
	if _endless_run:
		victory_after_wave = 0
		_pick_endless_mutator()
	if _tutorial_mode:
		# Wait until the full level (farms, shop, UI) has finished _ready so frees/timer flags stick.
		call_deferred("_bootstrap_tutorial_run")
		return

	call_deferred("_start_game")


func _bootstrap_tutorial_run() -> void:
	var ui := _resolve_game_ui()
	if ui and ui.has_signal(&"tutorial_box_hidden"):
		if not ui.is_connected(&"tutorial_box_hidden", Callable(self, "_on_tutorial_box_hidden")):
			ui.connect(&"tutorial_box_hidden", Callable(self, "_on_tutorial_box_hidden"))
	_setup_tutorial_layout()
	_start_tutorial_game()


func _setup_tutorial_layout() -> void:
	var w := _world()
	if w == null:
		return
	for extra_name in ["Farm2", "Farm3"]:
		var extra := w.get_node_or_null(extra_name)
		if extra:
			extra.queue_free()
	var farm := w.get_node_or_null("Farm") as Node2D
	if is_instance_valid(farm):
		farm.growth_time_scale = 0.2
		if not farm.crop_planted.is_connected(_on_tutorial_crop_planted):
			farm.crop_planted.connect(_on_tutorial_crop_planted)
		if not farm.crop_harvested.is_connected(_on_tutorial_crop_harvested):
			farm.crop_harvested.connect(_on_tutorial_crop_harvested)
	var sh := w.get_node_or_null("Shop")
	if is_instance_valid(sh) and sh.has_method(&"set_tutorial_skip_timer"):
		sh.set_tutorial_skip_timer(true)
	if is_instance_valid(shop_ui) and not shop_ui.upgrade_purchased.is_connected(_on_tutorial_upgrade_bought):
		shop_ui.upgrade_purchased.connect(_on_tutorial_upgrade_bought)


func _start_tutorial_game() -> void:
	var ui := _resolve_game_ui()
	if ui and ui.has_method(&"begin_tutorial_hud"):
		ui.begin_tutorial_hud()
	current_wave = 1
	wave_customer_count = 1
	allowed_misses = 99
	_refresh_ui_status()
	_tutorial_step = TutorialStep.PLANT
	_set_tutorial_objective(
		"Welcome to Harvest For All!",
		"This game is about Zero Hunger (UN SDG 2): you grow food and help feed people who need it.\n\nStep 1 - Plant: On the RIGHT, click a crop to choose your seed. Walk onto the brown farm plot and press E to plant. Go at your own pace - the next message waits until you finish this step."
	)


func _on_tutorial_crop_planted(_crop_name: String) -> void:
	if _tutorial_mode and _tutorial_step == TutorialStep.PLANT:
		_tutorial_step = TutorialStep.HARVEST
		_set_tutorial_objective(
			"Help someone eat today",
			"Step 2 - Grow food: Wait on the plot until your crop is ready. Press E on the plot again to harvest. That food is what you will share with someone who is hungry. There is no timer pressure here."
		)


func _on_tutorial_crop_harvested(crop_name: String) -> void:
	if not (_tutorial_mode and _tutorial_step == TutorialStep.HARVEST):
		return
	_tutorial_step = TutorialStep.FEED
	_spawn_tutorial_customer(crop_name)
	_set_tutorial_objective(
		"Share your harvest",
		"Step 3 - Feed them: A hungry visitor wants the crop you grew. Walk up to them and press E to give them food from your stash.\n\nSeeds: the faster you feed them (more time left on their timer), the more seeds you earn for the shop. Slow feeds still pay, but quick serves pay best."
	)


func _spawn_tutorial_customer(crop_name: String) -> void:
	if is_instance_valid(_tutorial_customer):
		_tutorial_customer.queue_free()
	var c := CUSTOMER_SCENE.instantiate()
	add_child(c)
	c.position = Vector2(125, 100)
	c.z_index = 10
	c.time_limit = 180.0
	c.begin_with_single_request(crop_name, 1)
	var tutorial_timer := c.get_node_or_null("TimerLabel")
	if tutorial_timer:
		tutorial_timer.visible = false
	c.served.connect(_on_tutorial_customer_served)
	_tutorial_customer = c


func _on_tutorial_customer_served(_c: Node2D) -> void:
	if not (_tutorial_mode and _tutorial_step == TutorialStep.FEED):
		return
	total_fed_count += 1
	wave_fed_count += 1
	_refresh_ui_status()
	_tutorial_step = TutorialStep.SHOP
	_set_tutorial_objective(
		"Grow more, grow faster",
		"Great work - you helped feed someone!\n\nStep 4 - Shop: Walk to the shop stall and press E to open it. Pick one upgrade - a bigger garden or faster crops - so you can grow more food for more people later."
	)


func _on_tutorial_upgrade_bought() -> void:
	if not (_tutorial_mode and _tutorial_step == TutorialStep.SHOP):
		return
	_tutorial_step = TutorialStep.DONE
	_tutorial_waiting_for_exit_click = true
	_set_tutorial_objective(
		"Tutorial complete",
		"You planted food, shared it with someone who was hungry, and saw how upgrades help you feed even more people.\n\nClick this tutorial box once to continue."
	)


func _on_tutorial_box_hidden() -> void:
	if not _tutorial_mode:
		return
	if _tutorial_step != TutorialStep.DONE:
		return
	if not _tutorial_waiting_for_exit_click:
		return
	_tutorial_waiting_for_exit_click = false
	_finish_tutorial_flow()


func _finish_tutorial_flow() -> void:
	_clear_tutorial_objective()
	GameProgress.tutorial_mode = false
	if GameProgress.exit_tutorial_to_main_menu:
		GameProgress.exit_tutorial_to_main_menu = false
		Music.play_menu()
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return
	if not GameProgress.tutorial_completed:
		GameProgress.mark_tutorial_completed()
	get_tree().change_scene_to_file(GAME_SCENE)


func _start_game() -> void:
	game_finished = false
	if not _tutorial_mode:
		PlayerData.add_currency(STARTING_SEEDS)
	if game_ui and game_ui.has_method(&"set_mutator_name"):
		var mutator_short := _endless_mutator_name
		var paren_idx := mutator_short.find(" (")
		if paren_idx >= 0:
			mutator_short = mutator_short.substr(0, paren_idx)
		game_ui.set_mutator_name(mutator_short if _endless_run else "")
	var intro := "Hungry customers will be coming in %d seconds! Prepare your crops before they show up!" % [start_time_buffer]
	if _endless_run:
		intro = "Endless mode — survive as many waves as you can.\nYou can miss at most %d customers total this run.\nMutator: %s\n\n%s" % [ENDLESS_MAX_TOTAL_MISSES, _endless_mutator_name, intro]
	game_ui._show_message(intro, 6.0 if _endless_run else 2.2)
	while start_time_buffer >= 0:
		await get_tree().create_timer(1.0, false).timeout
		start_time_buffer -= 1
		game_ui._show_message("Hungry customers will be coming in %d seconds! Prepare your crops before they show up!" % [start_time_buffer], 1.0)
	_start_next_wave()


func _start_next_wave() -> void:
	if game_finished:
		return
	Music.reset_wave_urgency()
	waiting_for_next_wave = false
	current_wave += 1
	wave_fed_count = 0
	wave_missed_count = 0
	#var cust_lo := clampi(2 + (current_wave - 1) / 3, 2, 4)
	#var cust_hi := clampi(3 + (current_wave - 1) / 2, cust_lo, 6)
	#wave_customer_count = randi_range(cust_lo, cust_hi)
	
	var wave_pressure := 1.0 + _difficulty_bias
	var scaled_wave: float = float(current_wave) * wave_pressure
	if scaled_wave <= 13.0:
		wave_customer_count = roundi(0.55 * scaled_wave + 1.0)
	else:
		wave_customer_count = roundi(0.4 * scaled_wave + 3.0)
	wave_customer_count = max(1, roundi(float(wave_customer_count) * _mutator_customer_mult))
	
	allowed_misses = clampi(int(float(wave_customer_count) / 3.5), 0, maxi(0, wave_customer_count - 1))
	if current_wave == 1:
		run_start_msec = Time.get_ticks_msec()
	var req_hi := mini(3, 1 + int(round(scaled_wave + 1.0)) / 2)
	req_hi = max(1, req_hi)
	var request_count := randi_range(1, req_hi)
	var wave_time_limit := maxf(12.0, (28.0 - float(current_wave - 1) * 1.15) * (1.0 - (_difficulty_bias * 0.12)))
	wave_time_limit *= _mutator_time_mult
	var min_amount := maxi(1, roundi((1.2 * float(current_wave) + 1) * (1.0 + _difficulty_bias * 0.18) * _mutator_amount_mult))
	var max_amount := maxi(min_amount + 1, roundi((1.4 * float(current_wave) + 1) * (1.0 + _difficulty_bias * 0.2) * _mutator_amount_mult))
	var config = {
		"wave": current_wave,
		"request_count": request_count,
		"time_limit": wave_time_limit,
		"min_amount": min_amount,
		"max_amount": max_amount
	}
	var configs: Array = []
	for _i in range(wave_customer_count):
		configs.append(config.duplicate())
	customer_spawner.queue_customers(configs)
	_wave_advance_in_progress = false
	game_ui._update_status(current_wave, wave_fed_count, wave_customer_count, wave_missed_count, _max_misses_before_fail(), customer_spawner.get_active_customer_count(), total_missed_count)
	game_ui._show_message("Wave %d started. %d hungry customers are waiting." % [current_wave, wave_customer_count], 3.0)


func _check_wave_complete() -> void:
	if game_finished or _wave_advance_in_progress:
		return
	# Endless uses only the global 10-miss cap; per-wave miss limit does not end the run.
	if not _endless_run and wave_missed_count > allowed_misses:
		game_finished = true
		game_ui._show_message("Wave failed - too many hungry customers left.", 5.0)
		_finalize_loss()
		return
	if customer_spawner.get_remaining_count() != 0:
		return
	if wave_fed_count + wave_missed_count < wave_customer_count:
		return
	_wave_advance_in_progress = true
	waiting_for_next_wave = true
	_update_adaptive_difficulty()
	if victory_after_wave > 0 and current_wave >= victory_after_wave:
		game_finished = true
		_finalize_victory()
		_wave_advance_in_progress = false
		return
	var wave_countdown := time_between_waves
	game_ui._show_message("Wave complete! Next wave in %ds." % [wave_countdown], 5.0)
	for _i in range(wave_countdown):
		await get_tree().create_timer(1.0, false).timeout
		wave_countdown -= 1
		if wave_countdown > 0:
			game_ui._show_message("Wave complete! Next wave in %ds." % [wave_countdown], 1.0)
	_wave_advance_in_progress = false
	if not game_finished:
		_start_next_wave()


func _on_customer_served(customer: Node2D = null) -> void:
	if _tutorial_mode:
		return
	total_fed_count += 1
	wave_fed_count += 1
	var now := Time.get_ticks_msec()
	if now - _last_serve_msec <= COMBO_WINDOW_MSEC:
		_combo_streak += 1
	else:
		_combo_streak = 1
	_last_serve_msec = now
	var combo_bonus := clampi(_combo_streak - 1, 0, COMBO_BONUS_MAX)
	var speed_ratio := 0.85
	if customer != null and customer.has_method(&"get_feed_speed_ratio"):
		speed_ratio = customer.get_feed_speed_ratio()
	var speed_mult: float = lerpf(FEED_SPEED_MULT_MIN, FEED_SPEED_MULT_MAX, speed_ratio)
	# Seed income vs upgrade costs (see CropUpgrade.get_cost): wave + combo + feed speed.
	var wave_part: int = (current_wave + 1) / 3
	var combo_part: int = mini(combo_bonus, COMBO_BONUS_MAX) / 3
	var base_seeds: int = 2 + wave_part + combo_part
	var mutator_seed_tint: float = 1.0 + (_mutator_reward_mult - 1.0) * 0.35
	var seeds_earned: int = maxi(1, int(round(float(base_seeds) * mutator_seed_tint * speed_mult)))
	PlayerData.add_currency(seeds_earned)
	if combo_bonus > 0:
		_combo_bonus_score += combo_bonus * 6
		game_ui._show_message("Combo x%d! +%d seeds" % [_combo_streak, seeds_earned], 1.2)
	elif speed_ratio >= 0.65:
		game_ui._show_message("+%d seeds (quick serve)" % seeds_earned, 1.0)
	_refresh_ui_status()
	_check_wave_complete()


func _on_customer_expired() -> void:
	if _tutorial_mode:
		return
	total_missed_count += 1
	wave_missed_count += 1
	_combo_streak = 0
	_refresh_ui_status()
	if _endless_run and total_missed_count >= ENDLESS_MAX_TOTAL_MISSES:
		game_finished = true
		game_ui._show_message("Endless run over — %d misses total (no more allowed)." % ENDLESS_MAX_TOTAL_MISSES, 5.0)
		_finalize_loss()
		return
	_check_wave_complete()


func _refresh_ui_status() -> void:
	game_ui._update_status(current_wave, wave_fed_count, wave_customer_count, wave_missed_count, _max_misses_before_fail(), customer_spawner.get_active_customer_count(), total_missed_count)


func _compute_score() -> int:
	return total_fed_count * 100 + max(0, current_wave - 1) * 50 + _combo_bonus_score


func _finalize_victory() -> void:
	if _win_finalized or _loss_finalized:
		return
	_win_finalized = true
	Music.play_max_win_sting()
	var duration_ms := int(Time.get_ticks_msec() - run_start_msec) if run_start_msec > 0 else 0
	var waves_cleared: int = current_wave
	var score := _compute_score()
	var body := "You fed the whole town - victory!\n\nFed (total): %d\nMissed (total): %d\nWaves cleared: %d\nScore: %d" % [total_fed_count, total_missed_count, waves_cleared, score]
	var status := ""
	if Backend.is_logged_in():
		status = "Saving score to leaderboard..."
		Backend.submit_run(score, duration_ms, waves_cleared, total_fed_count, total_missed_count, _endless_run)
	else:
		status = "This run is saved on your device. Sign in from the main menu and it will upload automatically."
		Backend.save_pending_run_if_guest(
			score, duration_ms, waves_cleared, total_fed_count, total_missed_count, _endless_run
		)
	game_ui.show_game_over(body, status)


func _finalize_loss() -> void:
	if _loss_finalized or _win_finalized:
		return
	_loss_finalized = true
	Music.play_run_loss_sting()
	var duration_ms := int(Time.get_ticks_msec() - run_start_msec) if run_start_msec > 0 else 0
	var waves_cleared: int = max(0, current_wave - 1)
	var score := _compute_score()
	var body := "You were overwhelmed this wave.\n\nFed (total): %d\nMissed (total): %d\nWaves cleared: %d\nScore: %d" % [total_fed_count, total_missed_count, waves_cleared, score]
	var status := ""
	if Backend.is_logged_in():
		status = "Saving score to leaderboard..."
		Backend.submit_run(score, duration_ms, waves_cleared, total_fed_count, total_missed_count, _endless_run)
	else:
		status = "This run is saved on your device. Sign in from the main menu and it will upload automatically."
		Backend.save_pending_run_if_guest(
			score, duration_ms, waves_cleared, total_fed_count, total_missed_count, _endless_run
		)
	game_ui.show_game_over(body, status)


func _on_run_submitted(_data: Variant) -> void:
	var ui := _resolve_game_ui()
	if ui and ui.has_method(&"set_run_submit_status"):
		ui.call("set_run_submit_status", "Score saved. Thanks for playing!")


func _on_run_submit_failed(_reason: String) -> void:
	var ui := _resolve_game_ui()
	if ui and ui.has_method(&"set_run_submit_status"):
		ui.call("set_run_submit_status", "Could not save score. Check connection.")


func _on_personal_best_received(data: Variant) -> void:
	var ui := _resolve_game_ui()
	if ui == null or not ui.has_method(&"set_game_over_personal_best"):
		return
	var row: Dictionary = {}
	if typeof(data) == TYPE_ARRAY:
		var rows: Array = data
		if not rows.is_empty() and typeof(rows[0]) == TYPE_DICTIONARY:
			row = rows[0]
	if row.is_empty():
		ui.call("set_game_over_personal_best", "Account best (base): —")
		return
	var score := int(row.get("score_total", 0))
	var waves := int(row.get("waves_completed", 0))
	var fed := int(row.get("total_fed", 0))
	var missed := int(row.get("total_missed", 0))
	ui.call(
		"set_game_over_personal_best",
		"Account best (base): %d pts (Wave %d) | Fed: %d | Missed: %d" % [score, waves, fed, missed]
	)


func _on_personal_best_failed(_reason: String) -> void:
	var ui := _resolve_game_ui()
	if ui and ui.has_method(&"set_game_over_personal_best"):
		ui.call("set_game_over_personal_best", "Account best (base): could not load.")


func _on_personal_best_endless_received(data: Variant) -> void:
	var ui := _resolve_game_ui()
	if ui == null or not ui.has_method(&"set_game_over_personal_best"):
		return
	var row: Dictionary = {}
	if typeof(data) == TYPE_ARRAY:
		var rows: Array = data
		if not rows.is_empty() and typeof(rows[0]) == TYPE_DICTIONARY:
			row = rows[0]
	if row.is_empty():
		ui.call("set_game_over_personal_best", "Account best (endless): —")
		return
	var score := int(row.get("score_total", 0))
	var waves := int(row.get("waves_completed", 0))
	var fed := int(row.get("total_fed", 0))
	var missed := int(row.get("total_missed", 0))
	ui.call(
		"set_game_over_personal_best",
		"Account best (endless): %d pts (Wave %d) | Fed: %d | Missed: %d" % [score, waves, fed, missed]
	)


func _on_personal_best_endless_failed(_reason: String) -> void:
	var ui := _resolve_game_ui()
	if ui and ui.has_method(&"set_game_over_personal_best"):
		ui.call("set_game_over_personal_best", "Account best (endless): could not load.")


func _update_adaptive_difficulty() -> void:
	if wave_customer_count <= 0:
		return
	var served_ratio := float(wave_fed_count) / float(wave_customer_count)
	var miss_pressure := 0.0
	if _max_misses_before_fail() > 0:
		miss_pressure = float(wave_missed_count) / float(_max_misses_before_fail())
	var delta := 0.0
	if served_ratio >= 0.92 and miss_pressure <= 0.2:
		delta = 0.08
	elif served_ratio >= 0.8 and miss_pressure <= 0.35:
		delta = 0.04
	elif served_ratio <= 0.6 or miss_pressure >= 0.75:
		delta = -0.08
	elif served_ratio <= 0.72:
		delta = -0.04
	_difficulty_bias = clampf(_difficulty_bias + delta, -0.35, 0.6)


func _pick_endless_mutator() -> void:
	var roll := randi_range(0, 2)
	match roll:
		0:
			_endless_mutator_name = "Rush Hour (+customers, shorter timers)"
			_mutator_customer_mult = 1.3
			_mutator_time_mult = 0.88
			_mutator_amount_mult = 1.0
			_mutator_reward_mult = 1.2
			_mutator_shop_cooldown_mult = 1.0
		1:
			_endless_mutator_name = "Fast Fields (faster growth, tougher orders)"
			_mutator_customer_mult = 1.15
			_mutator_time_mult = 1.0
			_mutator_amount_mult = 1.22
			_mutator_reward_mult = 1.15
			_mutator_shop_cooldown_mult = 0.85
			_apply_growth_time_scale_to_all_farms(0.8)
		_:
			_endless_mutator_name = "Long Queue (more time, heavier volume)"
			_mutator_customer_mult = 1.22
			_mutator_time_mult = 1.24
			_mutator_amount_mult = 1.1
			_mutator_reward_mult = 1.05
			_mutator_shop_cooldown_mult = 1.2
	if is_instance_valid(shop):
		shop.shop_timer = maxf(8.0, float(shop.shop_timer) * _mutator_shop_cooldown_mult)


func _apply_growth_time_scale_to_all_farms(scale_mult: float) -> void:
	var w := _world()
	if w == null:
		return
	for farm_name in ["Farm", "Farm2", "Farm3"]:
		var farm := w.get_node_or_null(farm_name)
		if is_instance_valid(farm) and farm.has_method(&"_get_growth_time_per_stage"):
			farm.growth_time_scale = maxf(0.25, float(farm.growth_time_scale) * scale_mult)
