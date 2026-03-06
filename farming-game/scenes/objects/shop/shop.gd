extends Node2D

@onready var interaction_area: InteractionArea = $InteractionArea

func _ready() -> void:
	interaction_area.interact = Callable(self, "_on_interact") # link the "_on_interact" function

func _on_interact():
	# TODO: Should generate 3 upgrades and be offered to pick one
	print("UPGRADE")
	var upgrade = UpgradeManager.generate_upgrade()
	print(upgrade.crop_name, upgrade.upgrade_type, upgrade.tier)
	upgrade.apply_upgrade()
