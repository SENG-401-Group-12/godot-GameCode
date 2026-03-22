class_name CropUpgrade
extends Resource


enum UpgradeType {
	YIELD,
	GROWTH_SPEED,
	FARM_SIZE
}

@export var crop_name: String
@export var upgrade_type: UpgradeType
@export var tier: int

func apply_upgrade() -> bool:
	if not PlayerData.can_apply_upgrade(self):
		return false
	match upgrade_type:
		UpgradeType.YIELD:
			PlayerData.crop_upgrades[crop_name].yield_multiplier += Globals.base_yield_upgrade * tier
		
		UpgradeType.GROWTH_SPEED:
			PlayerData.crop_upgrades[crop_name].growth_speed_bonus += Globals.base_growth_upgrade * tier
			
		UpgradeType.FARM_SIZE:
			PlayerData.crop_upgrades[crop_name].size_bonus += Globals.base_farm_size_upgrade
			PlayerData.farm_size_changed.emit(crop_name)
	return true

func get_upgrade_description() -> String:
	var base_string = ""
	match upgrade_type:
		UpgradeType.YIELD:
			base_string = "Upgrade %s harvest yield by %d%%" % [crop_name, Globals.base_yield_upgrade * tier * 100]
		UpgradeType.GROWTH_SPEED:
			base_string = "Decrease %s growth time by %0.2fs" % [crop_name, Globals.base_growth_upgrade * tier]
		UpgradeType.FARM_SIZE:
			base_string = "Upgrade %s farm size" % [crop_name]
	
	return base_string
