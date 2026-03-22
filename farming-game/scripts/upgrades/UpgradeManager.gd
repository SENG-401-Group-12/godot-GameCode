extends Node

func generate_upgrade() -> CropUpgrade:
	var upgrade = CropUpgrade.new()
	
	upgrade.crop_name = Globals.game_crops.pick_random().crop_name
	
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
	var upgrades: Array[CropUpgrade] = []
	var seen: Dictionary = {}
	var guard := 0
	while upgrades.size() < count and guard < 100:
		guard += 1
		var u := generate_upgrade()
		if not PlayerData.can_apply_upgrade(u):
			continue
		var fp := PlayerData.upgrade_fingerprint(u)
		if seen.has(fp):
			continue
		seen[fp] = true
		upgrades.append(u)
	return upgrades
