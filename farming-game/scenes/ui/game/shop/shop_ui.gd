extends Control

signal upgrade_purchased

const UI_FONT := preload("res://assets/game/ui/fonts/PixelOperator8.ttf")

@onready var card_container: HBoxContainer = $MarginContainer/RootVBox/CardContainer
@onready var main_hud: Control = $"../InGameUI"
@onready var shop = $"../../Shop"
@onready var currency_label: Label = $MarginContainer/RootVBox/HeaderPanel/HeaderVBox/TopRow/CurrencyLabel
@onready var reroll_button: Button = $MarginContainer/RootVBox/HeaderPanel/HeaderVBox/TopRow/RerollButton
@onready var hint_label: Label = $MarginContainer/RootVBox/HeaderPanel/HeaderVBox/HintLabel
@onready var crop_stats_row: HBoxContainer = $MarginContainer/RootVBox/CropStatsPanel/CropStatsInner/CropStatsRow
@onready var crop_stats_title: Label = $MarginContainer/RootVBox/CropStatsPanel/CropStatsInner/CropStatsTitle
@onready var buy_button: Button = $MarginContainer/RootVBox/Footer/BuyButton
@onready var back_button: Button = $MarginContainer/RootVBox/Footer/BackButton
@onready var shop_root_margin: MarginContainer = $MarginContainer

const UpgradeCard = preload("res://scenes/ui/game/shop/upgrade_card.tscn")
const REROLL_BASE_COST := 12

var _current_choices: Array[CropUpgrade] = []
var _use_costs: bool = true
var _allow_reroll: bool = true
var _shop_opened_from_stall: bool = true
var _selected_upgrade: CropUpgrade = null
## Rerolls already paid for this shop visit; next reroll costs REROLL_BASE_COST * 2^depth. Resets when shop closes.
var _reroll_depth: int = 0

var _crop_tooltip_panel: PanelContainer = null
var _crop_tooltip_label: Label = null
var _shop_margin_top_base: int = -1
var _tooltip_crop_hover: CropData = null


func _ready() -> void:
	hide()
	shop.shop_opened.connect(open_shop)
	reroll_button.pressed.connect(_on_reroll_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
	back_button.pressed.connect(_on_back_pressed)
	PlayerData.currency_changed.connect(_on_currency_changed)
	_ensure_crop_tooltip_ui()
	_build_crop_stat_slots()
	_refresh_currency_ui()
	_apply_pixel_font_recursive(self)
	_style_crop_stats_header()
	_update_buy_button()
	_refresh_crop_stat_tooltips()


func _style_crop_stats_header() -> void:
	if crop_stats_title:
		crop_stats_title.add_theme_font_size_override("font_size", 7)


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
	hint_label.text = "Select a perk, tap or hover a crop icon to preview, then Buy or Back."
	_refresh_crop_stat_tooltips()
	if GameProgress.tutorial_mode:
		if is_instance_valid(main_hud) and main_hud.has_method("refresh_tutorial_layout_for_shop"):
			main_hud.refresh_tutorial_layout_for_shop(true)
		call_deferred("_deferred_apply_tutorial_top_inset")


func _deferred_apply_tutorial_top_inset() -> void:
	_apply_tutorial_top_inset()


func _apply_tutorial_top_inset() -> void:
	if not GameProgress.tutorial_mode or not visible:
		return
	if shop_root_margin == null or not is_instance_valid(main_hud):
		return
	if main_hud.has_method("is_tutorial_banner_visible") and not main_hud.is_tutorial_banner_visible():
		clear_tutorial_top_inset()
		return
	if _shop_margin_top_base < 0:
		_shop_margin_top_base = int(shop_root_margin.get_theme_constant("margin_top", "MarginContainer"))
	var target_top := 80.0
	if main_hud.has_method("get_shop_top_inset_for_tutorial_shop"):
		target_top = main_hud.get_shop_top_inset_for_tutorial_shop()
	var new_margin := maxi(_shop_margin_top_base, int(ceil(target_top)))
	shop_root_margin.add_theme_constant_override("margin_top", new_margin)
	if main_hud.has_method("set_tutorial_shop_upgrade_dock_pushed"):
		main_hud.set_tutorial_shop_upgrade_dock_pushed(true)


func clear_tutorial_top_inset() -> void:
	if is_instance_valid(main_hud) and main_hud.has_method("set_tutorial_shop_upgrade_dock_pushed"):
		main_hud.set_tutorial_shop_upgrade_dock_pushed(false)
	if shop_root_margin != null and _shop_margin_top_base >= 0:
		shop_root_margin.add_theme_constant_override("margin_top", _shop_margin_top_base)
	_shop_margin_top_base = -1


## Called when the tutorial banner resizes or toggles while the shop is open.
func refresh_tutorial_top_inset() -> void:
	if not visible or not GameProgress.tutorial_mode:
		return
	if is_instance_valid(main_hud) and main_hud.has_method("is_tutorial_banner_visible") and not main_hud.is_tutorial_banner_visible():
		clear_tutorial_top_inset()
		return
	_apply_tutorial_top_inset()


func populate_upgrades(choices: Array[CropUpgrade]) -> void:
	_tooltip_crop_hover = null
	_hide_crop_tooltip()
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
	_style_crop_stats_header()
	_update_buy_button()
	_refresh_crop_stat_tooltips()


func _on_perk_selected(upgrade: CropUpgrade) -> void:
	if _selected_upgrade == upgrade:
		_selected_upgrade = null
	else:
		_selected_upgrade = upgrade
	_update_selection_highlights()
	_update_buy_button()
	_refresh_visible_crop_tooltip()


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
	clear_tutorial_top_inset()
	_tooltip_crop_hover = null
	_hide_crop_tooltip()
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
	_refresh_crop_stat_tooltips()
	# Resize tutorial after crop HUD is visible again (otherwise width uses wide no-crop fallback).
	if is_instance_valid(main_hud) and main_hud.has_method("refresh_tutorial_layout_for_shop"):
		main_hud.call_deferred("refresh_tutorial_layout_for_shop", false)


## During tutorial the objective panel lives under InGameUI; hiding the whole control removed it. Only hide gameplay chrome.
func _set_hud_hidden_for_shop(hidden: bool) -> void:
	var hud_margin := main_hud.get_node_or_null("MarginContainer")
	if hud_margin:
		hud_margin.visible = not hidden
	var joy := main_hud.get_node_or_null("Joystick")
	if joy:
		joy.visible = not hidden
	var ib := main_hud.get_node_or_null("InteractButton")
	if ib:
		ib.visible = not hidden
	# Keep upgrade dock visible so players can inspect active perks while shopping.
	var upgrade_dock := main_hud.get_node_or_null("UpgradeDock")
	if upgrade_dock:
		upgrade_dock.visible = true
		upgrade_dock.process_mode = Node.PROCESS_MODE_ALWAYS
		upgrade_dock.z_index = 350
		upgrade_dock.mouse_filter = Control.MOUSE_FILTER_PASS


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
	_refresh_crop_stat_tooltips()


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


func _upgrade_choice_short_label(u: CropUpgrade) -> String:
	var tier_roman := "I" if u.tier == 1 else ("II" if u.tier == 2 else "III")
	match u.upgrade_type:
		CropUpgrade.UpgradeType.FARM_SIZE:
			return "%s Farm Size %s" % [u.crop_name, tier_roman]
		CropUpgrade.UpgradeType.GROWTH_SPEED:
			return "%s Growth %s" % [u.crop_name, tier_roman]
		_:
			return "%s Yield %s" % [u.crop_name, tier_roman]


func _crop_shop_preview_text(crop: CropData, u: CropUpgrade) -> String:
	var current_block := _crop_stat_tooltip_text(crop)
	if u.crop_name != crop.crop_name:
		return "%s\n\n—\nSelected: %s\nHover %s to preview this perk." % [
			current_block,
			_upgrade_choice_short_label(u),
			u.crop_name,
		]
	var base_tiles: Vector2i = Globals.default_farm_size
	var size_bonus: Vector2i = PlayerData.get_size_bonus(crop.crop_name)
	var y_mult: float = PlayerData.get_yield_bonus(crop.crop_name)
	var g_bonus: float = PlayerData.get_growth_speed_bonus(crop.crop_name)
	var n_stages: int = maxi(1, crop.growth_stages - 1)
	var tiles_now: int = (base_tiles.x + size_bonus.x) * (base_tiles.y + size_bonus.y)
	match u.upgrade_type:
		CropUpgrade.UpgradeType.YIELD:
			var d_y: float = Globals.base_yield_upgrade * float(u.tier)
			var h_now: int = roundi(float(tiles_now) * y_mult)
			var h_new: int = roundi(float(tiles_now) * (y_mult + d_y))
			return "%s\n\nIf bought: harvest %d → %d" % [current_block, h_now, h_new]
		CropUpgrade.UpgradeType.GROWTH_SPEED:
			var d_g: float = CropUpgrade.growth_speed_bonus_delta_for_upgrade(u)
			var stage_now: float = maxf(0.08, crop.growth_time_per_stage - g_bonus)
			var stage_new: float = maxf(0.08, crop.growth_time_per_stage - (g_bonus + d_g))
			var t_now: float = float(n_stages) * stage_now
			var t_new: float = float(n_stages) * stage_new
			return "%s\n\nIf bought: grow %.1fs → %.1fs" % [current_block, t_now, t_new]
		CropUpgrade.UpgradeType.FARM_SIZE:
			var add: Vector2i = Globals.base_farm_size_upgrade
			var sz_new: Vector2i = size_bonus + add
			var tiles_new: int = (base_tiles.x + sz_new.x) * (base_tiles.y + sz_new.y)
			var h_now: int = roundi(float(tiles_now) * y_mult)
			var h_new: int = roundi(float(tiles_new) * y_mult)
			return "%s\n\nIf bought: %d → %d tiles, harvest %d → %d" % [
				current_block, tiles_now, tiles_new, h_now, h_new,
			]
	return current_block


func _tooltip_text_for_hovered_crop(crop: CropData) -> String:
	if _selected_upgrade != null:
		return _crop_shop_preview_text(crop, _selected_upgrade)
	return _crop_stat_tooltip_text(crop)


func _refresh_visible_crop_tooltip() -> void:
	if _tooltip_crop_hover == null:
		return
	if not is_instance_valid(_crop_tooltip_panel) or not _crop_tooltip_panel.visible:
		return
	_show_crop_tooltip(_tooltip_text_for_hovered_crop(_tooltip_crop_hover))


func _crop_stat_tooltip_text(crop: CropData) -> String:
	if crop == null:
		return ""
	var base_tiles: Vector2i = Globals.default_farm_size
	var size_bonus: Vector2i = PlayerData.get_size_bonus(crop.crop_name)
	var current_tiles := base_tiles + size_bonus
	var base_harvest := base_tiles.x * base_tiles.y
	var current_harvest := roundi(float(current_tiles.x * current_tiles.y) * PlayerData.get_yield_bonus(crop.crop_name))
	var stage_count := maxi(1, crop.growth_stages - 1)
	var base_growth_total := float(stage_count) * crop.growth_time_per_stage
	var stage_after_bonus := maxf(0.08, crop.growth_time_per_stage - PlayerData.get_growth_speed_bonus(crop.crop_name))
	var current_growth_total := float(stage_count) * stage_after_bonus
	return "%s\nHarvest (tiles × yield): %d → %d\nGrow time (total): %.1fs → %.1fs" % [
		crop.crop_name,
		base_harvest,
		current_harvest,
		base_growth_total,
		current_growth_total,
	]


func _build_crop_stat_slots() -> void:
	if crop_stats_row == null:
		return
	for ch in crop_stats_row.get_children():
		ch.queue_free()
	# Same visual language as the in-game upgrade dock (bottom-right circles), slightly larger for touch.
	const SLOT_PX := 22
	const ICON_PX := 16
	const PAD := (SLOT_PX - ICON_PX) / 2
	for crop in Globals.game_crops:
		if crop == null:
			continue
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var slot_bg := StyleBoxFlat.new()
		slot_bg.bg_color = Color(0.08, 0.08, 0.1, 0.62)
		slot_bg.border_width_left = 1
		slot_bg.border_width_top = 1
		slot_bg.border_width_right = 1
		slot_bg.border_width_bottom = 1
		slot_bg.border_color = Color(1, 1, 1, 0.24)
		slot_bg.set_corner_radius_all(SLOT_PX / 2)
		slot.add_theme_stylebox_override(&"panel", slot_bg)
		slot.set_meta(&"crop", crop)

		var icon := TextureRect.new()
		icon.texture = crop.get_item_icon()
		icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
		icon.position = Vector2(PAD, PAD)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		slot.add_child(icon)

		slot.mouse_entered.connect(_on_crop_slot_mouse_entered.bind(crop))
		slot.mouse_exited.connect(_on_crop_slot_mouse_exited)
		slot.gui_input.connect(_on_crop_slot_gui_input.bind(crop))
		crop_stats_row.add_child(slot)


func _refresh_crop_stat_tooltips() -> void:
	if crop_stats_row == null:
		return
	# Only use the custom pixel tooltip on hover; native Control.tooltips stack as a second "OS" popup.
	for slot in crop_stats_row.get_children():
		slot.tooltip_text = ""


func _ensure_crop_tooltip_ui() -> void:
	if is_instance_valid(_crop_tooltip_panel):
		return
	_crop_tooltip_panel = PanelContainer.new()
	_crop_tooltip_panel.visible = false
	_crop_tooltip_panel.top_level = true
	_crop_tooltip_panel.z_index = 600
	_crop_tooltip_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_crop_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.08, 0.94)
	bg.set_corner_radius_all(6)
	bg.content_margin_left = 8
	bg.content_margin_top = 6
	bg.content_margin_right = 8
	bg.content_margin_bottom = 6
	_crop_tooltip_panel.add_theme_stylebox_override("panel", bg)
	add_child(_crop_tooltip_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 2)
	_crop_tooltip_panel.add_child(margin)

	_crop_tooltip_label = Label.new()
	_crop_tooltip_label.add_theme_font_override("font", UI_FONT)
	_crop_tooltip_label.add_theme_font_size_override("font_size", 8)
	_crop_tooltip_label.add_theme_constant_override("outline_size", 2)
	_crop_tooltip_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_crop_tooltip_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02))
	_crop_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_crop_tooltip_label.custom_minimum_size.x = 268
	margin.add_child(_crop_tooltip_label)


func _show_crop_tooltip(text: String) -> void:
	if not is_instance_valid(_crop_tooltip_panel) or not is_instance_valid(_crop_tooltip_label):
		return
	_crop_tooltip_label.text = text
	_crop_tooltip_panel.reset_size()
	var min_size := _crop_tooltip_panel.get_combined_minimum_size()
	_crop_tooltip_panel.size = min_size
	var mouse := get_viewport().get_mouse_position()
	var pos := mouse + Vector2(12, -min_size.y - 8)
	var vis := get_viewport_rect().size
	pos.x = clampf(pos.x, 4.0, maxf(4.0, vis.x - min_size.x - 4.0))
	pos.y = clampf(pos.y, 4.0, maxf(4.0, vis.y - min_size.y - 4.0))
	_crop_tooltip_panel.position = pos
	_crop_tooltip_panel.visible = true


func _hide_crop_tooltip() -> void:
	if is_instance_valid(_crop_tooltip_panel):
		_crop_tooltip_panel.visible = false


func _on_crop_slot_mouse_entered(crop: CropData) -> void:
	_tooltip_crop_hover = crop
	_ensure_crop_tooltip_ui()
	_show_crop_tooltip(_tooltip_text_for_hovered_crop(crop))


func _on_crop_slot_gui_input(event: InputEvent, crop: CropData) -> void:
	# Touch: mouse_entered is unreliable on phones; show the same preview on tap.
	if event is InputEventScreenTouch and event.pressed:
		_on_crop_slot_mouse_entered(crop)


func _on_crop_slot_mouse_exited() -> void:
	_tooltip_crop_hover = null
	_hide_crop_tooltip()
