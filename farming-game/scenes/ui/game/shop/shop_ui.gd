extends Control

signal upgrade_purchased

const UI_FONT := preload("res://assets/game/ui/fonts/PixelOperator8.ttf")

@onready var card_container: HBoxContainer = $MarginContainer/RootVBox/CardContainer
@onready var main_hud: Control = $"../InGameUI"
@onready var shop = $"../../Shop"
@onready var currency_label: Label = $MarginContainer/RootVBox/HeaderPanel/HeaderVBox/TopRow/CurrencyLabel
@onready var reroll_button: Button = $MarginContainer/RootVBox/HeaderPanel/HeaderVBox/TopRow/RerollButton
@onready var hint_label: Label = $MarginContainer/RootVBox/HeaderPanel/HeaderVBox/HintLabel
@onready var buy_button: Button = $MarginContainer/RootVBox/Footer/BuyButton
@onready var back_button: Button = $MarginContainer/RootVBox/Footer/BackButton

const UpgradeCard = preload("res://scenes/ui/game/shop/upgrade_card.tscn")
const REROLL_BASE_COST := 12

var _current_choices: Array[CropUpgrade] = []
var _use_costs: bool = true
var _allow_reroll: bool = true
var _shop_opened_from_stall: bool = true
var _selected_upgrade: CropUpgrade = null
## Rerolls already paid for this shop visit; next reroll costs REROLL_BASE_COST * 2^depth. Resets when shop closes.
var _reroll_depth: int = 0


func _ready() -> void:
	hide()
	shop.shop_opened.connect(open_shop)
	reroll_button.pressed.connect(_on_reroll_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
	back_button.pressed.connect(_on_back_pressed)
	PlayerData.currency_changed.connect(_on_currency_changed)
	_refresh_currency_ui()
	_apply_pixel_font_recursive(self)
	_update_buy_button()


func open_shop() -> void:
	_use_costs = not GameProgress.tutorial_mode
	_allow_reroll = not GameProgress.tutorial_mode
	_shop_opened_from_stall = true
	_selected_upgrade = null
	_reroll_depth = 0
	shop.set_opened(true)
	Music.enter_shop()
	_set_hud_hidden_for_shop(true)
	get_tree().paused = true
	show()
	populate_upgrades(_generate_shop_choices())
	hint_label.text = "Select a perk, then tap Buy or Back."


func populate_upgrades(choices: Array[CropUpgrade]) -> void:
	for child in card_container.get_children():
		child.queue_free()
	_current_choices = choices
	_selected_upgrade = null
	for upgrade in _current_choices:
		var card = UpgradeCard.instantiate()
		card_container.add_child(card)
		card.setup(upgrade, _use_costs, _use_costs)
		card.perk_selected.connect(_on_perk_selected)
	_refresh_all_cards()
	_refresh_currency_ui()
	_apply_pixel_font_recursive(self)
	_update_buy_button()


func _on_perk_selected(upgrade: CropUpgrade) -> void:
	if _selected_upgrade == upgrade:
		_selected_upgrade = null
	else:
		_selected_upgrade = upgrade
	_update_selection_highlights()
	_update_buy_button()


func _update_selection_highlights() -> void:
	for c in card_container.get_children():
		if c.has_method("get_upgrade") and c.has_method("set_highlighted"):
			c.set_highlighted(c.get_upgrade() == _selected_upgrade)


func _on_buy_pressed() -> void:
	if _selected_upgrade == null:
		return
	if _use_costs:
		var cost := _selected_upgrade.get_cost()
		if not PlayerData.can_afford(cost):
			return
		if not PlayerData.spend_currency(cost):
			return
	var u := _selected_upgrade
	if not u.apply_upgrade():
		if _use_costs:
			PlayerData.add_currency(u.get_cost())
		populate_upgrades(_current_choices)
		return
	upgrade_purchased.emit()
	close_shop()


func _on_back_pressed() -> void:
	close_shop()


func close_shop() -> void:
	_selected_upgrade = null
	_reroll_depth = 0
	for child in card_container.get_children():
		child.queue_free()
	hide()
	get_tree().paused = false
	Music.exit_shop()
	if _shop_opened_from_stall:
		shop.set_opened(false)
	_set_hud_hidden_for_shop(false)


## During tutorial the objective panel lives under InGameUI; hiding the whole control removed it. Only hide gameplay chrome.
func _set_hud_hidden_for_shop(hidden: bool) -> void:
	if GameProgress.tutorial_mode:
		main_hud.get_node("MarginContainer").visible = not hidden
		var joy := main_hud.get_node_or_null("Joystick")
		if joy:
			joy.visible = not hidden
		var ib := main_hud.get_node_or_null("InteractButton")
		if ib:
			ib.visible = not hidden
	else:
		main_hud.visible = not hidden


func _on_reroll_pressed() -> void:
	if not _allow_reroll:
		return
	var cost := _reroll_cost_next()
	if not PlayerData.spend_currency(cost):
		_refresh_currency_ui()
		return
	_reroll_depth += 1
	populate_upgrades(_generate_shop_choices())


func _on_currency_changed(_new_amount: int) -> void:
	_refresh_currency_ui()


func _refresh_currency_ui() -> void:
	if currency_label:
		currency_label.text = "Seeds: %d" % PlayerData.run_currency
	if reroll_button:
		reroll_button.visible = _allow_reroll
		var next_cost := _reroll_cost_next()
		reroll_button.disabled = not PlayerData.can_afford(next_cost)
		if _allow_reroll:
			reroll_button.text = "Reroll (%d)" % next_cost
	_refresh_all_cards()
	_update_buy_button()


func _refresh_all_cards() -> void:
	for c in card_container.get_children():
		if c.has_method("refresh_affordability"):
			c.refresh_affordability(PlayerData.run_currency, _use_costs)
	_update_selection_highlights()


func _update_buy_button() -> void:
	if buy_button == null:
		return
	var can_buy := false
	if _selected_upgrade != null:
		if not _use_costs:
			can_buy = true
		else:
			can_buy = PlayerData.can_afford(_selected_upgrade.get_cost())
	buy_button.disabled = not can_buy


func _generate_shop_choices() -> Array[CropUpgrade]:
	return UpgradeManager.generate_upgrade_choices()


func _reroll_cost_next() -> int:
	return REROLL_BASE_COST * (1 << _reroll_depth)


func _apply_pixel_font_recursive(node: Node) -> void:
	if node is Control:
		var c := node as Control
		if c is Label or c is Button:
			c.add_theme_font_override("font", UI_FONT)
			c.add_theme_font_size_override("font_size", 8)
		elif c is LineEdit:
			c.add_theme_font_override("font", UI_FONT)
			c.add_theme_font_size_override("font_size", 8)
	for ch in node.get_children():
		_apply_pixel_font_recursive(ch)
