extends NinePatchRect

@onready var upgrade_title: Label = $MarginContainer/VBoxContainer/UpgradeTitle
@onready var upgrade_description: Label = $MarginContainer/VBoxContainer/UpgradeDescription
@onready var cost_label: Label = $MarginContainer/VBoxContainer/CostLabel

signal perk_selected(upgrade: CropUpgrade)

var _upgrade: CropUpgrade
var _can_afford: bool = true
var _show_cost: bool = true
var _highlighted: bool = false


func get_upgrade() -> CropUpgrade:
	return _upgrade


func setup(upgrade: CropUpgrade, use_costs: bool = true, show_cost: bool = true) -> void:
	_upgrade = upgrade
	_show_cost = show_cost
	upgrade_title.text = build_title(_upgrade)
	upgrade_description.text = build_description(_upgrade)
	cost_label.visible = show_cost
	if show_cost:
		cost_label.text = "Cost: %d seeds" % _upgrade.get_cost()
	set_highlighted(false)
	refresh_affordability(PlayerData.run_currency, use_costs)


func refresh_affordability(currency: int, use_costs: bool) -> void:
	if _upgrade == null:
		return
	_can_afford = true
	if use_costs and _show_cost:
		_can_afford = currency >= _upgrade.get_cost()
	if _show_cost:
		cost_label.text = "Cost: %d seeds" % _upgrade.get_cost()
		cost_label.modulate = Color(0.22, 0.72, 0.42) if _can_afford else Color(0.92, 0.28, 0.28)
	_apply_visual_state()


func set_highlighted(on: bool) -> void:
	_highlighted = on
	_apply_visual_state()


func _apply_visual_state() -> void:
	if _upgrade == null:
		return
	if _highlighted:
		modulate = Color(1.08, 1.12, 1.18) if _can_afford else Color(0.95, 0.72, 0.72)
		return
	if not _can_afford:
		modulate = Color(0.55, 0.55, 0.55)
	else:
		modulate = Color.WHITE


func build_title(upgrade: CropUpgrade):
	var tier
	match upgrade.tier:
		1:
			tier = "I"
		2:
			tier = "II"
		3:
			tier = "III"

	var type
	match upgrade.upgrade_type:
		0:
			type = "Yield"
		1:
			type = "Growth Speed"
		2:
			return "%s Farm Size" % [upgrade.crop_name]

	return "%s %s %s" % [upgrade.crop_name, type, tier]


func build_description(upgrade: CropUpgrade):
	return upgrade.get_upgrade_description()


func _on_button_pressed() -> void:
	if _upgrade == null:
		return
	perk_selected.emit(_upgrade)
