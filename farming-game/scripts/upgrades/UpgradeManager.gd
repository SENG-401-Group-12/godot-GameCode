extends Node

func generate_upgrade() -> CropUpgrade:
	var upgrade = CropUpgrade.new()
	
	upgrade.crop_name = Globals.game_crops.pick_random()
	
	# Weighted tier upgrade probablitiy
	# Tier 1 = 60% , Tier 2 = 30%, Tier 3 = 10%
	var tier_select = randf()
	if tier_select <= 0.6:
		upgrade.tier = 1
	elif tier_select <= 0.9:
		upgrade.tier = 2
	else:
		upgrade.tier = 3
	
	var upgrade_types = CropUpgrade.UpgradeType.values()
	upgrade.upgrade_type = upgrade_types.pick_random()
	
	return upgrade
	
func generate_upgrade_choices(count := 3) -> Array[CropUpgrade]:
	var upgrades = []
	
	while upgrades.size() < count:
		upgrades.append(generate_upgrade())
	
	return upgrades
