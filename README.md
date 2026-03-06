# godot-GameCode

## Notes about some features:

### Global Variables
- Constants are stored in `res://scripts/globals.gd`.

### Crop Upgrades:
- `res://scripts/upgrades/crop_upgrade.gd` defines upgrade types. Adding more upgrades is done here. The base multipliers for each upgrade are stored in `res://scripts/globals.gd`
- `res://scripts/upgrades/UpgradeManager.gd` needs a list of all crop types in the game. This list is stored in `res://scripts/globals.gd`

### Crop Types:
- `res://scripts/crops/` stores the crop types, along with the data about each crop (growth speed, sprite location, etc). When adding new crops, this is where they are added.
