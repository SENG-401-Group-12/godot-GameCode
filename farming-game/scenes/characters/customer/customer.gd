extends Node2D

signal served(customer)
signal expired(customer)

const ItemSlot = preload("res://scenes/characters/customer/item_slot.tscn")

@onready var interaction_area: InteractionArea = $InteractionArea
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var request_container: VBoxContainer = $RequestList/RequestContainer
@onready var timer_label: Label = $TimerLabel

@export var requests: Array[ItemRequest] = []
@export var min_requests := 1
@export var max_request := 2
@export var min_amount := 2
@export var max_amount := 5
@export var time_limit := 20.0
## If greater than 0, this customer only asks for Turnips (this many) — hands-on tutorial.
@export var tutorial_turnip_amount: int = 0
## If true, skip initial order setup until `begin_with_single_request` (tutorial: appear after harvest).
@export var hold_until_configured: bool = false

const _URGENT_TIME_SEC := 10.0

var time_remaining := 0.0
var is_resolved := false
var _in_urgent_band := false

func _ready() -> void:
	requests = []
	interaction_area.interact = Callable(self, "_on_interact")
	choose_random_sprite()
	sprite.visible = true
	$NotEnoughLabel.hide()
	if hold_until_configured:
		set_process(false)
		interaction_area.monitorable = false
		interaction_area.monitoring = false
		timer_label.visible = false
		for child in request_container.get_children():
			child.queue_free()
		return
	_setup_customer()

func _process(delta: float) -> void:
	if is_resolved:
		return

	time_remaining = max(0.0, time_remaining - delta)
	_update_timer_label()
	var urgent := time_remaining > 0.0 and time_remaining <= _URGENT_TIME_SEC
	if urgent and not _in_urgent_band:
		_in_urgent_band = true
		Music.register_customer_urgency()
	elif not urgent and _in_urgent_band:
		_in_urgent_band = false
		Music.unregister_customer_urgency()
	if time_remaining <= 0.0:
		_resolve_expired()

func begin_with_single_request(crop_name: String, amount: int) -> void:
	var crop: CropData = null
	for c in Globals.game_crops:
		if c.crop_name == crop_name:
			crop = c
			break
	if crop == null:
		return

	requests.clear()
	var r := ItemRequest.new()
	r.item_name = crop.crop_name
	r.icon = crop.get_item_icon()
	r.amount = clampi(amount, 1, 99)
	requests.append(r)

	for child in request_container.get_children():
		child.queue_free()
	populate_display()

	time_remaining = time_limit
	is_resolved = false
	if _in_urgent_band:
		_in_urgent_band = false
		Music.unregister_customer_urgency()

	visible = true
	sprite.visible = true
	set_process(true)
	timer_label.visible = true
	interaction_area.monitorable = true
	interaction_area.monitoring = true
	_update_timer_label()


func configure_for_wave(wave_number: int, new_time_limit: float, request_count: int, amount_min: int, amount_max: int) -> void:
	min_requests = max(1, request_count)
	max_request = max(min_requests, request_count)
	min_amount = max(1, amount_min)
	max_amount = max(min_amount, amount_max)
	time_limit = maxf(10.0, new_time_limit)
	requests.clear()
	generate_random_requests(wave_number)
	_setup_customer()

func choose_random_sprite() -> void:
	if randi() % 2 == 0:
		sprite.play("chicken_idle")
	else:
		sprite.play("cow_idle")

func _setup_customer() -> void:
	if tutorial_turnip_amount > 0:
		requests.clear()
		var turnip_data: CropData = Globals.game_crops[0]
		var request := ItemRequest.new()
		request.item_name = turnip_data.crop_name
		request.icon = turnip_data.get_item_icon()
		request.amount = tutorial_turnip_amount
		requests.append(request)
		sprite.play(&"chicken_idle")
		for child in request_container.get_children():
			child.queue_free()
		populate_display()
		time_remaining = time_limit
		is_resolved = false
		if _in_urgent_band:
			_in_urgent_band = false
			Music.unregister_customer_urgency()
		interaction_area.monitorable = true
		interaction_area.monitoring = true
		_update_timer_label()
		return

	if requests.is_empty():
		generate_random_requests(1)

	for child in request_container.get_children():
		child.queue_free()

	populate_display()
	time_remaining = time_limit
	is_resolved = false
	if _in_urgent_band:
		_in_urgent_band = false
		Music.unregister_customer_urgency()
	interaction_area.monitorable = true
	interaction_area.monitoring = true
	_update_timer_label()

func _on_interact() -> void:
	if is_resolved:
		return

	for item in requests:
		if PlayerData.get_crop_amount(item.item_name) < item.amount:
			flash_sprite(Color.RED)
			show_not_enough_label()
			return

	for item in requests:
		PlayerData.remove_crop(item.item_name, item.amount)

	if _in_urgent_band:
		_in_urgent_band = false
		Music.unregister_customer_urgency()

	is_resolved = true
	interaction_area.monitorable = false
	interaction_area.monitoring = false
	await flash_sprite(Color.GREEN, _leave_scene).finished
	served.emit(self)

func _resolve_expired() -> void:
	if is_resolved:
		return

	if _in_urgent_band:
		_in_urgent_band = false
		Music.unregister_customer_urgency()

	is_resolved = true
	interaction_area.monitorable = false
	interaction_area.monitoring = false
	await flash_sprite(Color(0.65, 0.12, 0.12), _leave_scene).finished
	expired.emit(self)

func _leave_scene() -> void:
	queue_free()

func flash_sprite(color: Color, callback := Callable()) -> Tween:
	var tween = create_tween()
	for _i in range(3):
		tween.tween_property(sprite, "modulate", color, 0.08)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)
	if not callback.is_null():
		tween.tween_callback(callback)
	return tween

func show_not_enough_label() -> void:
	var label = $NotEnoughLabel
	label.show()
	label.modulate = Color(1, 1, 1, 1)

	var tween = create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.hide)

func generate_random_requests(wave_number: int) -> void:
	var crop_list = Globals.game_crops.duplicate()
	crop_list.shuffle()
	var request_count = min(randi_range(1, 2), crop_list.size())

	for i in range(request_count):
		var request = ItemRequest.new()
		request.item_name = crop_list[i].crop_name
		request.icon = crop_list[i].get_item_icon()
		request.amount = randi_range(min_amount, max_amount + max(0, wave_number - 3))
		requests.append(request)

func populate_display() -> void:
	for req in requests:
		var slot = ItemSlot.instantiate()
		slot.get_node("ItemContainer/ItemTexture").texture = req.icon
		slot.get_node("ItemContainer/ItemAmount").text = "x%d" % req.amount
		request_container.add_child(slot)

func _update_timer_label() -> void:
	timer_label.text = "%02d" % ceili(time_remaining)
