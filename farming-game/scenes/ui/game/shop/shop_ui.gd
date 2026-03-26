extends Control

signal upgrade_purchased

@onready var card_container: HBoxContainer = $MarginContainer/CardContainer
@onready var main_hud: Control = $"../InGameUI"
@onready var shop = $"../../Shop"

const UpgradeCard = preload("res://scenes/ui/game/shop/upgrade_card.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide()
	shop.shop_opened.connect(open_shop)

func open_shop():
	shop.set_opened(true)
	Music.enter_shop()
	_set_hud_hidden_for_shop(true)
	get_tree().paused = true # pause the game while the shop is open
	show()
	populate_upgrades()
	
func populate_upgrades():
	# Clear old cards
	for child in card_container.get_children():
		child.queue_free()
		
	var choices: Array[CropUpgrade] = UpgradeManager.generate_upgrade_choices()
	for upgrade in choices:
		var card = UpgradeCard.instantiate()
		card_container.add_child(card)
		card.setup(upgrade) # populates card text
		card.upgrade_selected.connect(_on_upgrade_selected)
		
func _on_upgrade_selected(upgrade: CropUpgrade):
	if not upgrade.apply_upgrade():
		populate_upgrades()
		return
	upgrade_purchased.emit()
	close_shop()
	
func close_shop():
	for child in card_container.get_children():
		child.queue_free()
	hide()
	get_tree().paused = false
	Music.exit_shop()
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
