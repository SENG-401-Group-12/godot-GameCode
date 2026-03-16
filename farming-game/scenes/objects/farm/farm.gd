@tool
extends Node2D

enum FarmState {
	EMPTY,
	GROWING,
	READY
}

@export var crop_data: CropData
@export var starts_planted := false

var _base_farm_size: Vector2i
@export var base_farm_size = Globals.default_farm_size:
	get:
		return _base_farm_size
	set(value):
		_base_farm_size = value
		_update_farm_preview()

var _preview_cells: Array[Vector2i] = []
var growth_timer := 0.0
var growth_stage := 0
var state := FarmState.EMPTY

@onready var interaction_area: InteractionArea = $InteractionArea
@onready var dirt_tilemap: TileMapLayer = $Tilled_Dirt
@onready var crops: TileMapLayer = $Crops
@onready var farm_area: CollisionShape2D = $InteractionArea/CollisionShape2D
@onready var label_anchor: Node2D = $InteractionArea/LabelAnchor

func get_farm_size() -> Vector2i:
	if Engine.is_editor_hint():
		return base_farm_size
	if crop_data == null:
		return base_farm_size
	return base_farm_size + PlayerData.get_size_bonus(crop_data.crop_name)

func _ready() -> void:
	if _base_farm_size == Vector2i.ZERO:
		base_farm_size = Globals.default_farm_size

	if Engine.is_editor_hint():
		dirt_tilemap.clear()
		crops.clear()
		_update_farm_preview()
		return

	interaction_area.interact = Callable(self, "_on_interact")
	PlayerData.farm_size_changed.connect(_on_farm_size_changed)
	PlayerData.selected_crop_changed.connect(_on_selected_crop_changed)

	dirt_tilemap.clear()
	crops.clear()
	_update_collision_shape()
	_update_label_anchor()
	place_dirt()

	if starts_planted and crop_data != null:
		plant_crop(crop_data)
	else:
		clear_plot()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if state != FarmState.GROWING or crop_data == null:
		return

	growth_timer += delta
	var growth_time = max(0.15, crop_data.growth_time_per_stage - PlayerData.get_growth_speed_bonus(crop_data.crop_name))
	if growth_timer < growth_time:
		return

	growth_stage = min(growth_stage + 1, crop_data.growth_stages - 1)
	growth_timer = 0.0
	place_crop()

	if growth_stage == crop_data.growth_stages - 1:
		state = FarmState.READY
		farm_area.disabled = false
		interaction_area.action_name = "HARVEST %s" % crop_data.crop_name.to_upper()

func _on_interact() -> void:
	match state:
		FarmState.EMPTY:
			var selected_crop = PlayerData.get_selected_crop()
			if selected_crop != null:
				plant_crop(selected_crop)
		FarmState.READY:
			harvest_crop()

func plant_crop(new_crop: CropData) -> void:
	crop_data = new_crop
	growth_stage = 0
	growth_timer = 0.0
	state = FarmState.GROWING
	farm_area.disabled = true
	interaction_area.action_name = "GROWING %s" % crop_data.crop_name.to_upper()
	_update_collision_shape()
	_update_label_anchor()
	place_dirt()
	place_crop()

func harvest_crop() -> void:
	if crop_data == null:
		return

	var crop_name = crop_data.crop_name
	var base_harvest = get_farm_size().x * get_farm_size().y
	var harvest_total = roundi(base_harvest * PlayerData.get_yield_bonus(crop_name))
	PlayerData.add_crop(crop_name, harvest_total)
	clear_plot()

func clear_plot() -> void:
	growth_stage = 0
	growth_timer = 0.0
	state = FarmState.EMPTY
	reset_dirt()
	crop_data = null
	place_dirt()
	crops.clear()
	farm_area.disabled = false
	_update_action_name()

func _update_action_name() -> void:
	if Engine.is_editor_hint():
		return
	match state:
		FarmState.EMPTY:
			var selected_crop_name = PlayerData.get_selected_crop_name()
			if selected_crop_name.is_empty():
				interaction_area.action_name = "PLANT"
			else:
				interaction_area.action_name = "PLANT %s" % selected_crop_name.to_upper()
		FarmState.GROWING:
			if crop_data == null:
				interaction_area.action_name = "GROWING"
			else:
				interaction_area.action_name = "GROWING %s" % crop_data.crop_name.to_upper()
		FarmState.READY:
			if crop_data == null:
				interaction_area.action_name = "HARVEST"
			else:
				interaction_area.action_name = "HARVEST %s" % crop_data.crop_name.to_upper()

func _update_farm_preview() -> void:
	if not Engine.is_editor_hint():
		return
	if not is_inside_tree():
		return
	if not dirt_tilemap or not farm_area:
		return

	if _preview_cells.size() > 0:
		for cell in _preview_cells:
			dirt_tilemap.erase_cell(cell)
			crops.erase_cell(cell)

	_update_collision_shape()
	_update_label_anchor()
	_preview_cells = get_farm_cells()
	place_dirt()

	if crop_data != null:
		place_crop()

func _update_collision_shape() -> void:
	var tile_size := dirt_tilemap.tile_set.tile_size
	var shape := RectangleShape2D.new()
	shape.size = Vector2(
		get_farm_size().x * tile_size.x,
		get_farm_size().y * tile_size.y
	)

	farm_area.shape = shape
	farm_area.position = shape.size * 0.5

func _update_label_anchor() -> void:
	label_anchor.position = Vector2((get_farm_size().x * 16) * 0.5, (get_farm_size().y * 16) * 0.5)

func get_farm_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var origin := dirt_tilemap.local_to_map(dirt_tilemap.to_local(global_position))

	for x in range(get_farm_size().x):
		for y in range(get_farm_size().y):
			cells.append(origin + Vector2i(x, y))

	return cells

func place_dirt() -> void:
	var tiles := get_farm_cells()
	dirt_tilemap.set_cells_terrain_connect(tiles, 0, 1)
	_update_collision_shape()
	_update_label_anchor()

func reset_dirt() -> void:
	var tiles := get_farm_cells()
	for tile in tiles:
		dirt_tilemap.erase_cell(tile)

func place_crop() -> void:
	crops.clear()
	if crop_data == null:
		return

	var tiles := get_farm_cells()
	for cell in tiles:
		var crop_atlas_coords = Vector2i(growth_stage, crop_data.row_on_spritesheet)
		crops.set_cell(cell, 3, crop_atlas_coords)

func _on_farm_size_changed(crop_name: String) -> void:
	if crop_data == null:
		return
	if crop_name == crop_data.crop_name:
		update_farm_size_from_upgrade()

func _on_selected_crop_changed(_crop_name: String) -> void:
	if state == FarmState.EMPTY:
		_update_action_name()

func update_farm_size_from_upgrade() -> void:
	dirt_tilemap.clear()
	crops.clear()
	_update_collision_shape()
	_update_label_anchor()
	place_dirt()
	place_crop()
