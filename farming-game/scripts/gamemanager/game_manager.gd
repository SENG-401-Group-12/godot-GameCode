extends Node2D

@export var start_time_buffer := 15 # amount of time before first wave starts
@export var time_between_waves := 5

@onready var customer_spawner: Node2D = $CustomerSpawner
@onready var game_ui = $"../UserInterface/InGameUI"

var current_wave := 0
var wave_customer_count := 0
var wave_fed_count := 0
var total_fed_count := 0
var wave_missed_count := 0
var total_missed_count := 0
var allowed_misses := 0
var active_customer_count := 0
var waiting_for_next_wave := false
var game_finished := false

func _ready() -> void:
	customer_spawner.customer_served.connect(_on_customer_served)
	customer_spawner.customer_expired.connect(_on_customer_expired)
	customer_spawner.customer_spawned.connect(_refresh_ui_status)
	randomize()
	PlayerData.reset_run_state()
	call_deferred("_start_game") # wait until all _ready() calls are finished before starting
	
func _start_game() -> void:
	game_finished = false
	game_ui._show_message("Hungry customers will be coming in %d seconds! Prepare your crops before they show up!" % [start_time_buffer])
	while start_time_buffer >= 0:
		await get_tree().create_timer(1.0).timeout
		start_time_buffer -= 1
		game_ui._show_message("Hungry customers will be coming in %d seconds! Prepare your crops before they show up!" % [start_time_buffer], 1.0)
	
	_start_next_wave()

func _start_next_wave() -> void:
	if game_finished:
		return
	waiting_for_next_wave = false
	current_wave += 1
	wave_fed_count = 0
	wave_missed_count = 0
	
	wave_customer_count = randi_range(max(2, current_wave), max(4, current_wave + 3)) # we may want to change these numbers
	allowed_misses = floor(wave_customer_count / 3.0)
	var config = {
		"wave": current_wave,
		"request_count": randi_range(1, min(3, current_wave + 1)), # generate 1-3 requests
		"time_limit": max(10.0, 24.0 - float(current_wave - 1) * 1.5),
		"min_amount": roundi(2 + (current_wave - 1) / 3.0),
		"max_amount": roundi(4 + (current_wave - 1) / 2.0)
	}
	
	var configs: Array = []
	for i in range(wave_customer_count):
		configs.append(config.duplicate())
		
	customer_spawner.queue_customers(configs)

	game_ui._update_status(current_wave, wave_fed_count, wave_customer_count, wave_missed_count, allowed_misses, customer_spawner.get_active_customer_count())
	game_ui._show_message("Wave %d started. %d hungry customers are waiting." % [current_wave, wave_customer_count], 3.0)

func _check_wave_complete():
	if allowed_misses > 0 and wave_missed_count >= allowed_misses:
		game_finished = true
		game_ui._show_message("Wave Failed. Too many customers left hungry.", 5.0)
		
	if customer_spawner.get_remaining_count() == 0 and !game_finished:
		waiting_for_next_wave = true
		var wave_countdown = time_between_waves
		game_ui._show_message("Wave Complete! %ds until next wave." % [wave_countdown], 5.0)
		for i in range(wave_countdown):
			await get_tree().create_timer(1.0).timeout
			wave_countdown -= 1
			game_ui._show_message("Wave Complete! %ds until next wave." % [wave_countdown], 1.0)
			
		_start_next_wave()

func _on_customer_served():
	total_fed_count += 1
	wave_fed_count += 1
	_refresh_ui_status()
	_check_wave_complete()
	
func _on_customer_expired():
	total_missed_count += 1
	wave_missed_count += 1
	_refresh_ui_status()
	_check_wave_complete()

func _refresh_ui_status():
	game_ui._update_status(current_wave, wave_fed_count, wave_customer_count, wave_missed_count, allowed_misses, customer_spawner.get_active_customer_count())
