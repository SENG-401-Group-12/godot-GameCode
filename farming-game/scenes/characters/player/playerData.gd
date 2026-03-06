extends Node

signal farm_size_changed(crop_name)

var inventory := {}

var crop_upgrades := {
	"Tomato": {
		yield_multiplier = 1.0,
		growth_speed_bonus = 0.0,
		size_bonus = Vector2i(0,0)
	}, 
	"Eggplant": {
		yield_multiplier = 1.0,
		growth_speed_bonus = 0.0,
		size_bonus = Vector2i(0,0)
	} # EXPAND WITH WHATEVER CROPS ARE ADDED
}

func get_growth_speed_bonus(crop_name: String) -> float:
	if(!crop_upgrades.has(crop_name)):
		return 0.0
	else:
		return crop_upgrades.get(crop_name).growth_speed_bonus

func get_yield_bonus(crop_name: String) -> float:
	if(!crop_upgrades.has(crop_name)):
		return 1.0
	else:
		return crop_upgrades.get(crop_name).yield_multiplier

func get_size_bonus(crop_name: String) -> Vector2i:
	if(!crop_upgrades.has(crop_name)):
		return Vector2i(0,0)
	else:
		return crop_upgrades.get(crop_name).size_bonus
