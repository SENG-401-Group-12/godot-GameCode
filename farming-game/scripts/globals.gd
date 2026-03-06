extends Node

const player_speed := 100 # movement speed

const game_crops := [ # crops used in the game
	preload("res://scripts/crops/tomato.tres"), 
	preload("res://scripts/crops/eggplant.tres")
	] 
const default_farm_size := Vector2i(3, 5)

# Crop upgrade base values
const base_yield_upgrade := 0.1
const base_growth_upgrade := 0.25
const base_farm_size_upgrade := Vector2i(1, 1)
