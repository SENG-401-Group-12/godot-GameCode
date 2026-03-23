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
var character_preset_index: int = 0
const CHARACTER_PRESET_KEYS: PackedStringArray = [
	"seedcap",
	"butter_bean",
	"dawn_sprout",
	"river_field",
	"cinder_patch",
	"mist_orchard",
]
const CHARACTER_PRESET_NAMES: PackedStringArray = [
	"Seedcap",
	"Butter Bean",
	"Dawn Sprout",
	"River Field",
	"Cinder Patch",
	"Mist Orchard",
]
const CHARACTER_PRESET_TEXTURE_PATHS: PackedStringArray = [
	"res://assets/game/character/mana_seed_farmer.png",
	"res://assets/game/character/basic_character_spritesheet.png",
	"res://assets/game/character/dawn_sprout.png",
	"res://assets/game/character/river_field.png",
	"res://assets/game/character/cinder_patch.png",
	"res://assets/game/character/mist_orchard.png",
]
const SOURCE_PALETTE := {
	"hat_dark": Color8(183, 67, 123),
	"hat_mid": Color8(215, 110, 162),
	"hat_light": Color8(250, 182, 193),
	"cloth_dark": Color8(32, 80, 64),
	"cloth_mid": Color8(40, 152, 96),
	"cloth_light": Color8(88, 224, 160),
	"accent_dark": Color8(96, 24, 88),
	"accent_mid": Color8(91, 42, 84),
	"accent_shadow": Color8(80, 56, 80),
	"skin_dark": Color8(136, 88, 72),
	"skin_mid": Color8(216, 152, 120),
	"skin_light": Color8(248, 216, 184),
}
const CHARACTER_PRESET_PALETTES := {
	"butter_bean": {
		"hat_dark": Color8(110, 74, 24),
		"hat_mid": Color8(188, 142, 60),
		"hat_light": Color8(243, 222, 150),
		"cloth_dark": Color8(76, 54, 102),
		"cloth_mid": Color8(142, 104, 186),
		"cloth_light": Color8(215, 190, 240),
		"accent_dark": Color8(71, 92, 42),
		"accent_mid": Color8(118, 149, 70),
		"accent_shadow": Color8(62, 72, 42),
		"skin_dark": Color8(110, 74, 54),
		"skin_mid": Color8(181, 126, 94),
		"skin_light": Color8(232, 194, 154),
	},
	"dawn_sprout": {
		"hat_dark": Color8(126, 55, 24),
		"hat_mid": Color8(216, 128, 58),
		"hat_light": Color8(246, 203, 136),
		"cloth_dark": Color8(43, 88, 56),
		"cloth_mid": Color8(92, 170, 104),
		"cloth_light": Color8(188, 229, 154),
		"accent_dark": Color8(94, 48, 36),
		"accent_mid": Color8(151, 93, 72),
		"accent_shadow": Color8(74, 48, 39),
		"skin_dark": Color8(103, 69, 52),
		"skin_mid": Color8(181, 123, 95),
		"skin_light": Color8(236, 191, 157),
	},
	"river_field": {
		"hat_dark": Color8(38, 70, 121),
		"hat_mid": Color8(83, 135, 199),
		"hat_light": Color8(175, 209, 245),
		"cloth_dark": Color8(34, 110, 111),
		"cloth_mid": Color8(62, 169, 170),
		"cloth_light": Color8(159, 224, 215),
		"accent_dark": Color8(75, 58, 21),
		"accent_mid": Color8(140, 110, 44),
		"accent_shadow": Color8(54, 61, 44),
		"skin_dark": Color8(89, 63, 50),
		"skin_mid": Color8(152, 112, 89),
		"skin_light": Color8(219, 181, 149),
	},
	"cinder_patch": {
		"hat_dark": Color8(111, 36, 40),
		"hat_mid": Color8(180, 78, 64),
		"hat_light": Color8(238, 170, 124),
		"cloth_dark": Color8(66, 43, 84),
		"cloth_mid": Color8(124, 79, 153),
		"cloth_light": Color8(199, 164, 224),
		"accent_dark": Color8(172, 96, 35),
		"accent_mid": Color8(223, 151, 72),
		"accent_shadow": Color8(87, 56, 30),
		"skin_dark": Color8(70, 45, 34),
		"skin_mid": Color8(113, 79, 60),
		"skin_light": Color8(170, 126, 96),
	},
	"mist_orchard": {
		"hat_dark": Color8(143, 96, 94),
		"hat_mid": Color8(210, 150, 143),
		"hat_light": Color8(247, 214, 203),
		"cloth_dark": Color8(52, 104, 89),
		"cloth_mid": Color8(103, 182, 160),
		"cloth_light": Color8(204, 240, 224),
		"accent_dark": Color8(120, 78, 92),
		"accent_mid": Color8(187, 135, 154),
		"accent_shadow": Color8(84, 62, 72),
		"skin_dark": Color8(129, 92, 74),
		"skin_mid": Color8(199, 150, 122),
		"skin_light": Color8(242, 208, 179),
	},
}
var _character_texture_cache: Dictionary = {}

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
	character_preset_index = clampi(index, 0, maxi(0, CHARACTER_PRESET_NAMES.size() - 1))


func get_character_preset_key() -> String:
	return CHARACTER_PRESET_KEYS[character_preset_index]


func get_character_texture(index: int = -1) -> Texture2D:
	var resolved := character_preset_index if index < 0 else index
	resolved = clampi(resolved, 0, maxi(0, CHARACTER_PRESET_TEXTURE_PATHS.size() - 1))
	var path := CHARACTER_PRESET_TEXTURE_PATHS[resolved]
	if _character_texture_cache.has(path):
		return _character_texture_cache[path] as Texture2D
	var tex := load(path) as Texture2D
	if tex == null:
		tex = load(CHARACTER_PRESET_TEXTURE_PATHS[0]) as Texture2D
	_character_texture_cache[path] = tex
	return tex


func uses_builtin_mana_frames() -> bool:
	return get_character_preset_key() == "seedcap"


func character_uses_mirrored_side_frames() -> bool:
	return true


func get_character_palette() -> Dictionary:
	return CHARACTER_PRESET_PALETTES.get(get_character_preset_key(), {})


func get_character_modulate() -> Color:
	return Color.WHITE


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
