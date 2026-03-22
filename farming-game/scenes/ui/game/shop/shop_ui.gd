extends Control

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
	main_hud.hide()
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
	close_shop()
	
func close_shop():
	for child in card_container.get_children():
		child.queue_free()
	hide()
	get_tree().paused = false
	shop.set_opened(false)
	main_hud.show()
