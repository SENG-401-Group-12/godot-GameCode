extends Node2D

const CUSTOMER_SCENE = preload("res://scenes/characters/customer/customer.tscn")

signal customer_spawned
signal customer_served
signal customer_expired

@export var slot_spacing := 80.0 # distance between customers

var customer_slots: Array = [null, null, null, null] # null is an empty slot
var customer_queue: Array = [] # holds config dicts

func queue_customers(configs: Array) -> void:
	customer_queue.append_array(configs)
	_fill_slots()
	
func _fill_slots() -> void:
	while customer_queue.size() > 0 and _get_free_slot() != -1:
		var config = customer_queue.pop_front()
		try_spawn_customer(config)
		customer_spawned.emit()
		await get_tree().create_timer(2, false).timeout # wait 2s between customer spawns

func try_spawn_customer(config: Dictionary) -> bool:
	var slot_index = _get_free_slot()
	if slot_index == -1:
		return false
	
	var customer = CUSTOMER_SCENE.instantiate()
	add_child(customer)
	customer.position = Vector2((slot_index * slot_spacing) + 125, 100)
	var base_tl: float = float(config.time_limit)
	var varied_time_limit: float = clampf(base_tl * randf_range(0.9, 1.12), maxf(12.0, base_tl * 0.82), base_tl * 1.25)
	customer.z_index = 10
	customer.configure_for_wave(
		config.wave, varied_time_limit, config.request_count, config.min_amount, config.max_amount
	)
	
	customer_slots[slot_index] = customer
	customer.served.connect(_on_customer_done.bind(slot_index))
	customer.expired.connect(_on_customer_done.bind(slot_index))
	
	# Pass signals up to GameManager
	customer.served.connect(func(_c): customer_served.emit())
	customer.expired.connect(func(_c): customer_expired.emit())
	return true

func _get_free_slot() -> int:
	for i in range(customer_slots.size()):
		if customer_slots[i] == null:
			return i
	return -1
	
func _on_customer_done(_customer, slot_index: int):
	customer_slots[slot_index] = null
	await get_tree().create_timer(0.5, false).timeout # wait a short time before filling the slot
	_fill_slots() # try to fill the free slot
	
func get_active_customer_count() -> int:
	return customer_slots.filter(func(s): return s != null).size()

func get_remaining_count():
	return customer_queue.size() + get_active_customer_count()
