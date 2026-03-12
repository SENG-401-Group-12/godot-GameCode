extends NinePatchRect

@onready var upgrade_title: Label = $MarginContainer/VBoxContainer/UpgradeTitle
@onready var upgrade_description: Label = $MarginContainer/VBoxContainer/UpgradeDescription

signal upgrade_selected(upgrade: CropUpgrade)

var _upgrade: CropUpgrade

func setup(upgrade: CropUpgrade):
	_upgrade = upgrade
	upgrade_title.text = build_title(_upgrade)
	upgrade_description.text = build_description(_upgrade)

func build_title(upgrade: CropUpgrade):
	var tier
	match upgrade.tier:
		1:
			tier = "I"
		2:
			tier = "II"
		3:
			tier = "III"
			
	var type
	match upgrade.upgrade_type:
		0:
			type = "Yield"
		1:
			type = "Growth Speed"
		2:
			return "%s Farm Size" % [upgrade.crop_name] # return early since farm size has no tiers
	
	return "%s %s %s" % [upgrade.crop_name, type, tier]
	
func build_description(upgrade: CropUpgrade):
	return upgrade.get_upgrade_description()

func _on_button_pressed() -> void:
	upgrade_selected.emit(_upgrade)
