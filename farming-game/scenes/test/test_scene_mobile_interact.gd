extends Node2D

const CUSTOMER_SCENE = preload("res://scenes/characters/customer/customer.tscn")
const UI_FONT = preload("res://assets/game/ui/fonts/PixelOperator8.ttf")
const FED_TARGET := 12
const MAX_MISSED := 3

@onready var active_customers: Node2D = $Customers/ActiveCustomers
@onready var customer_slots: Array[Node2D] = [
	$Customers/Slot1,
	$Customers/Slot2,
	$Customers/Slot3,
	$Customers/Slot4
]
@onready var wave_label: Label = $HUD/StatusPanel/WaveLabel
@onready var progress_label: Label = $HUD/StatusPanel/ProgressLabel
@onready var missed_label: Label = $HUD/StatusPanel/MissedLabel
@onready var active_label: Label = $HUD/StatusPanel/ActiveLabel
@onready var selected_crop_label: Label = $HUD/CropPanel/SelectedCropLabel
@onready var summary_label: Label = $HUD/CropPanel/SummaryLabel
@onready var crop_buttons: HBoxContainer = $HUD/CropPanel/CropButtons
@onready var message_label: Label = $HUD/CenterMessage

var crop_button_nodes: Array[Button] = []
var current_wave := 0
var fed_count := 0
var missed_count := 0
var active_customer_count := 0
var waiting_for_next_wave := false
var game_finished := false

func _ready() -> void:
	randomize()
	PlayerData.reset_run_state()
	_build_crop_buttons()
	PlayerData.inventory_changed.connect(_refresh_crop_ui)
	PlayerData.selected_crop_changed.connect(_on_selected_crop_changed)
	_refresh_crop_ui()
	_on_selected_crop_changed(PlayerData.get_selected_crop_name())
	_update_status()
	_show_message("Feed the town: click a crop, plant an empty plot, harvest it, then press E on a customer.")
	_start_next_wave()

func _build_crop_buttons() -> void:
	for child in crop_buttons.get_children():
		child.queue_free()

	crop_button_nodes.clear()
	for index in range(Globals.game_crops.size()):
		var crop: CropData = Globals.game_crops[index]
		var button := Button.new()
		button.icon = crop.get_item_icon()
		button.custom_minimum_size = Vector2(110, 42)
		button.add_theme_font_override("font", UI_FONT)
		button.add_theme_font_size_override("font_size", 8)
		button.add_theme_constant_override("h_separation", 6)
		button.pressed.connect(_on_crop_button_pressed.bind(index))
		crop_buttons.add_child(button)
		crop_button_nodes.append(button)

func _on_crop_button_pressed(index: int) -> void:
	if game_finished:
		return
	PlayerData.set_selected_crop_index(index)

func _refresh_crop_ui() -> void:
	var total_inventory := 0
	for index in range(Globals.game_crops.size()):
		var crop: CropData = Globals.game_crops[index]
		var amount = PlayerData.get_crop_amount(crop.crop_name)
		total_inventory += amount
		var button = crop_button_nodes[index]
		var is_selected = index == PlayerData.selected_crop_index
		button.text = "%s\n%d" % [crop.crop_name, amount]
		button.modulate = Color(1.0, 0.95, 0.75) if is_selected else Color(0.85, 0.85, 0.85)
		button.disabled = game_finished

	summary_label.text = "Stored crops: %d" % total_inventory

func _on_selected_crop_changed(crop_name: String) -> void:
	selected_crop_label.text = "Selected seed: %s" % crop_name
	_refresh_crop_ui()

func _start_next_wave() -> void:
	if game_finished:
		return

	waiting_for_next_wave = false
	current_wave += 1
	var customer_total = min(customer_slots.size(), 1 + current_wave)
	var request_count = 1 if current_wave < 3 else 2
	var time_limit = max(10.0, 24.0 - float(current_wave - 1) * 1.5)
	var min_amount = 2 + int((current_wave - 1) / 3)
	var max_amount = 4 + int((current_wave - 1) / 2)

	for index in range(customer_total):
		var customer = CUSTOMER_SCENE.instantiate()
		customer.configure_for_wave(current_wave, time_limit, request_count, min_amount, max_amount)
		customer.position = customer_slots[index].position
		customer.served.connect(_on_customer_served)
		customer.expired.connect(_on_customer_expired)
		active_customers.add_child(customer)
		active_customer_count += 1

	_update_status()
	_show_message("Wave %d started. %d hungry customers are waiting." % [current_wave, customer_total])

func _on_customer_served(_customer: Node) -> void:
	if game_finished:
		return

	fed_count += 1
	active_customer_count = max(0, active_customer_count - 1)
	_update_status()
	if fed_count >= FED_TARGET:
		_finish_game(true)
		return
	_maybe_start_following_wave()

func _on_customer_expired(_customer: Node) -> void:
	if game_finished:
		return

	missed_count += 1
	active_customer_count = max(0, active_customer_count - 1)
	_update_status()
	if missed_count >= MAX_MISSED:
		_finish_game(false)
		return
	_maybe_start_following_wave()

func _maybe_start_following_wave() -> void:
	if game_finished or waiting_for_next_wave or active_customer_count > 0:
		return

	waiting_for_next_wave = true
	_show_message("Wave clear. The next group is on the way.")
	await get_tree().create_timer(2.0).timeout
	if not game_finished:
		_start_next_wave()

func _finish_game(player_won: bool) -> void:
	game_finished = true
	waiting_for_next_wave = false

	for customer in active_customers.get_children():
		customer.queue_free()

	active_customer_count = 0
	_update_status()
	if player_won:
		_show_message("The town is fed. You win.")
	else:
		_show_message("Too many customers left hungry. Restart to try again.")

func _update_status() -> void:
	wave_label.text = "Wave %d" % current_wave
	progress_label.text = "Fed: %d / %d" % [fed_count, FED_TARGET]
	missed_label.text = "Missed: %d / %d" % [missed_count, MAX_MISSED]
	active_label.text = "Waiting now: %d" % active_customer_count

func _show_message(text: String) -> void:
	message_label.text = text
	message_label.modulate = Color(1, 1, 1, 1)
	var tween = create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(message_label, "modulate:a", 0.0, 0.5)
