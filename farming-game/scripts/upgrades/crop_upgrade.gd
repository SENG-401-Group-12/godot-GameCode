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


func get_cost() -> int:
	var base := 8 + (tier * 8)
	match upgrade_type:
		UpgradeType.YIELD:
			base += 4
		UpgradeType.GROWTH_SPEED:
			base += 5
		UpgradeType.FARM_SIZE:
			base += 8
	return base


static func growth_time_per_stage_for_crop_name(p_name: String) -> float:
	for c in Globals.game_crops:
		if c != null and c.crop_name == p_name:
			return c.growth_time_per_stage
	return 5.0


static func growth_speed_bonus_delta_for_upgrade(u: CropUpgrade) -> float:
	if u == null or u.upgrade_type != UpgradeType.GROWTH_SPEED:
		return 0.0
	return growth_time_per_stage_for_crop_name(u.crop_name) * Globals.base_growth_stage_fraction * float(u.tier)


func _growth_transitions_for_crop(p_crop_name: String) -> int:
	for c in Globals.game_crops:
		if c != null and c.crop_name == p_crop_name:
			return maxi(1, c.growth_stages - 1)
	# Default crop growth_stages is 5 → four stage timers from plant to mature.
	return 4


func apply_upgrade() -> bool:
	if not PlayerData.can_apply_upgrade(self):
		return false
	match upgrade_type:
		UpgradeType.YIELD:
			PlayerData.crop_upgrades[crop_name].yield_multiplier += Globals.base_yield_upgrade * tier
		
		UpgradeType.GROWTH_SPEED:
			PlayerData.crop_upgrades[crop_name].growth_speed_bonus += growth_speed_bonus_delta_for_upgrade(self)
			
		UpgradeType.FARM_SIZE:
			PlayerData.crop_upgrades[crop_name].size_bonus += Globals.base_farm_size_upgrade
			PlayerData.farm_size_changed.emit(crop_name)
	return true

func get_upgrade_description() -> String:
	match upgrade_type:
		UpgradeType.YIELD:
			var pct := int(round(Globals.base_yield_upgrade * float(tier) * 100.0))
			return "%s crops yield +%d%% more." % [crop_name, pct]
		UpgradeType.GROWTH_SPEED:
			var delta: float = growth_speed_bonus_delta_for_upgrade(self)
			var n_stages: int = _growth_transitions_for_crop(crop_name)
			var total_faster: float = delta * float(n_stages)
			if total_faster < 0.095:
				return "~%.2fs faster growth for %s." % [total_faster, crop_name]
			return "~%.1fs faster growth for %s." % [total_faster, crop_name]
		UpgradeType.FARM_SIZE:
			return "Bigger %s plot — more room to plant." % crop_name
	return ""
