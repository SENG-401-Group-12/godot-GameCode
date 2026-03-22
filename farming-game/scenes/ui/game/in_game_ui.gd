extends Control

const UI_FONT = preload("res://assets/game/ui/fonts/PixelOperator8.ttf")

@onready var wave_label: Label = $MarginContainer/HBoxContainer/StatusPanel/MarginContainer/VBoxContainer/WaveLabel
@onready var progress_label: Label = $MarginContainer/HBoxContainer/StatusPanel/MarginContainer/VBoxContainer/ProgressLabel
@onready var missed_label: Label = $MarginContainer/HBoxContainer/StatusPanel/MarginContainer/VBoxContainer/MissedLabel
@onready var active_label: Label = $MarginContainer/HBoxContainer/StatusPanel/MarginContainer/VBoxContainer/ActiveLabel
@onready var selected_crop_label: Label = $MarginContainer/HBoxContainer/CropPanel/MarginContainer/VBoxContainer/SelectedCropLabel
@onready var summary_label: Label = $MarginContainer/HBoxContainer/CropPanel/MarginContainer/VBoxContainer/SummaryLabel
@onready var crop_buttons: VBoxContainer = $MarginContainer/HBoxContainer/CropPanel/MarginContainer/VBoxContainer/ScrollContainer/CropButtons
@onready var message_label: Label = $MarginContainer/HBoxContainer/CenterMessage
@onready var game_over_layer: ColorRect = $GameOverLayer
@onready var game_over_body: Label = $GameOverLayer/CenterContainer/Panel/Margin/VBox/BodyLabel
@onready var game_over_submit: Label = $GameOverLayer/CenterContainer/Panel/Margin/VBox/SubmitStatusLabel
@onready var game_over_menu_button: Button = $GameOverLayer/CenterContainer/Panel/Margin/VBox/MenuButton

var _message_tween: Tween = null

var crop_button_nodes: Array[Button] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if OS.get_name() == "Android" or OS.get_name() == "iOS" or OS.has_feature("mobile"):
		pass
	else: # If not on mobile, remove joystick and interact button from UI
		$Joystick.queue_free()
		$InteractButton.queue_free()
	game_over_layer.visible = false
	game_over_menu_button.pressed.connect(_on_game_over_menu_pressed)
	get_parent().show()
	_build_crop_buttons()
	PlayerData.inventory_changed.connect(_refresh_crop_ui)
	PlayerData.selected_crop_changed.connect(_on_selected_crop_changed)
	_refresh_crop_ui()
	_on_selected_crop_changed(PlayerData.get_selected_crop_name())
	_update_status(0, 0, 0, 0, 0, 0)
	_show_message("Tip: pick a crop → plant a plot → harvest → stand by a customer and press E to feed them.")

func _build_crop_buttons() -> void:
	for child in crop_buttons.get_children():
		child.queue_free()

	crop_button_nodes.clear()
	for index in range(Globals.game_crops.size()):
		var crop: CropData = Globals.game_crops[index]
		var button := Button.new()
		button.icon = crop.get_item_icon()
		button.custom_minimum_size = Vector2(142, 45)
		button.add_theme_font_override("font", UI_FONT)
		button.add_theme_font_size_override("font_size", 8)
		button.add_theme_constant_override("h_separation", 6)
		var new_stylebox_normal = button.get_theme_stylebox("normal").duplicate()
		new_stylebox_normal.bg_color = Color(0.0, 0.0, 0.0, 0.157)
		button.add_theme_stylebox_override("normal", new_stylebox_normal)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_crop_button_pressed.bind(index))
		crop_buttons.add_child(button)
		crop_button_nodes.append(button)
		
func _on_crop_button_pressed(index: int) -> void:
	PlayerData.set_selected_crop_index(index)
	_on_selected_crop_changed(Globals.game_crops[index].crop_name)

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

	summary_label.text = "\nStored crops: %d" % total_inventory

func _on_selected_crop_changed(crop_name: String) -> void:
	selected_crop_label.text = "Selected seed:\n%s" % crop_name
	_refresh_crop_ui()

func _show_message(text: String, display_time: float = 2.2) -> void:
	if _message_tween:
		_message_tween.kill()
	message_label.text = text
	message_label.modulate = Color(1, 1, 1, 1)
	_message_tween = create_tween()
	_message_tween.tween_interval(display_time)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.5)

func _update_status(current_wave, fed_count, fed_target, missed_count, allowed_misses, active_customer_count) -> void:
	wave_label.text = "Wave %d" % current_wave
	progress_label.text = "Fed: %d / %d" % [fed_count, fed_target]
	missed_label.text = "Missed: %d / %d" % [missed_count, allowed_misses]
	active_label.text = "Waiting now: %d" % active_customer_count


func show_game_over(body_text: String, submit_status: String) -> void:
	game_over_body.text = body_text
	game_over_submit.text = submit_status
	game_over_layer.visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true


func set_run_submit_status(text: String) -> void:
	game_over_submit.text = text


func _on_game_over_menu_pressed() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_INHERIT
	game_over_layer.visible = false
	Music.play_menu()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")
