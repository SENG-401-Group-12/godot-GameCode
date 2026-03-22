extends Node

signal farm_size_changed(crop_name)
signal inventory_changed
signal selected_crop_changed(crop_name)

## Soft caps per run so the shop cannot stack the same bonus forever.
const MAX_YIELD_MULTIPLIER := 2.2
const MAX_GROWTH_SPEED_BONUS := 2.5
const MAX_FARM_SIZE_BONUS_PER_AXIS := 2

var inventory := {}
var crop_upgrades := {}
var selected_crop_index := 0
## 0..n — tint presets applied to the player sprite (same art, different palette feel).
var character_preset_index: int = 0
const CHARACTER_PRESET_MODULATES: Array[Color] = [
	Color(1.0, 1.0, 1.0, 1.0),
	Color(1.0, 0.92, 0.85, 1.0),
	Color(0.9, 0.95, 1.0, 1.0),
	Color(0.88, 1.0, 0.9, 1.0),
]
const CHARACTER_PRESET_NAMES: PackedStringArray = ["Classic", "Warm", "Cool", "Meadow"]

func _make_default_upgrade_state() -> Dictionary:
	return {
		yield_multiplier = 1.0,
		growth_speed_bonus = 0.0,
		size_bonus = Vector2i.ZERO
	}

func _ensure_crop_registered(crop_name: String) -> void:
	if not inventory.has(crop_name):
		inventory[crop_name] = 0
	if not crop_upgrades.has(crop_name):
		crop_upgrades[crop_name] = _make_default_upgrade_state()

func reset_run_state() -> void:
	inventory.clear()
	crop_upgrades.clear()

	for crop in Globals.game_crops:
		_ensure_crop_registered(crop.crop_name)

	selected_crop_index = clampi(selected_crop_index, 0, max(Globals.game_crops.size() - 1, 0))
	inventory_changed.emit()
	selected_crop_changed.emit(get_selected_crop_name())

func get_selected_crop() -> CropData:
	if Globals.game_crops.is_empty():
		return null
	return Globals.game_crops[selected_crop_index]

func get_selected_crop_name() -> String:
	var crop = get_selected_crop()
	if crop == null:
		return ""
	return crop.crop_name

func set_selected_crop_index(index: int) -> void:
	if Globals.game_crops.is_empty():
		return

	selected_crop_index = wrapi(index, 0, Globals.game_crops.size())
	selected_crop_changed.emit(get_selected_crop_name())

func cycle_selected_crop(direction: int) -> void:
	set_selected_crop_index(selected_crop_index + direction)

func get_crop_amount(crop_name: String) -> int:
	_ensure_crop_registered(crop_name)
	return inventory.get(crop_name, 0)

func add_crop(crop_name: String, amount: int) -> void:
	if amount <= 0:
		return

	_ensure_crop_registered(crop_name)
	inventory[crop_name] += amount
	inventory_changed.emit()

func remove_crop(crop_name: String, amount: int) -> bool:
	if amount <= 0:
		return true

	_ensure_crop_registered(crop_name)
	if inventory[crop_name] < amount:
		return false

	inventory[crop_name] -= amount
	inventory_changed.emit()
	return true

func get_growth_speed_bonus(crop_name: String) -> float:
	_ensure_crop_registered(crop_name)
	return crop_upgrades.get(crop_name).growth_speed_bonus

func get_yield_bonus(crop_name: String) -> float:
	_ensure_crop_registered(crop_name)
	return crop_upgrades.get(crop_name).yield_multiplier

func get_size_bonus(crop_name: String) -> Vector2i:
	_ensure_crop_registered(crop_name)
	return crop_upgrades.get(crop_name).size_bonus


func set_character_preset(index: int) -> void:
	character_preset_index = clampi(index, 0, maxi(0, CHARACTER_PRESET_MODULATES.size() - 1))


func get_character_modulate() -> Color:
	return CHARACTER_PRESET_MODULATES[character_preset_index]


func can_apply_upgrade(u: CropUpgrade) -> bool:
	if u == null:
		return false
	_ensure_crop_registered(u.crop_name)
	var st: Dictionary = crop_upgrades[u.crop_name]
	match u.upgrade_type:
		CropUpgrade.UpgradeType.YIELD:
			var next_mult: float = st.yield_multiplier + Globals.base_yield_upgrade * u.tier
			return next_mult <= MAX_YIELD_MULTIPLIER + 0.001
		CropUpgrade.UpgradeType.GROWTH_SPEED:
			var next_bonus: float = st.growth_speed_bonus + Globals.base_growth_upgrade * u.tier
			return next_bonus <= MAX_GROWTH_SPEED_BONUS + 0.001
		CropUpgrade.UpgradeType.FARM_SIZE:
			var b: Vector2i = st.size_bonus
			return b.x < MAX_FARM_SIZE_BONUS_PER_AXIS and b.y < MAX_FARM_SIZE_BONUS_PER_AXIS
	return false


func upgrade_fingerprint(u: CropUpgrade) -> String:
	return "%s:%d" % [u.crop_name, u.upgrade_type]
