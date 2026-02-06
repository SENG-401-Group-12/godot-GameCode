@tool
extends Node2D

@export var crop_data: CropData

@export var farm_size: Vector2i = Vector2i(3, 5):
	set(value):
		farm_size = value
		_update_farm_preview()

var _preview_cells: Array[Vector2i] = [] # used for showing the crop area in the 2D editor

@onready var interaction_area: InteractionArea = $InteractionArea
@onready var dirt_tilemap: TileMapLayer = $Tilled_Dirt
@onready var crops: TileMapLayer = $Crops
@onready var farm_area: CollisionShape2D = $InteractionArea/CollisionShape2D
@onready var label_anchor: Node2D = $InteractionArea/LabelAnchor

var growth_timer := 0.0
var growth_stage := 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_editor_hint(): #if in the editor
		dirt_tilemap.clear()
		crops.clear()
		_update_farm_preview()
		return
	
	# Runtime setup
	interaction_area.interact = Callable(self, "_on_interact") # link the "_on_interact" function
	
	dirt_tilemap.clear()
	crops.clear()
	
	growth_stage = 0
	growth_timer = 0
	farm_area.disabled = true
	
	_update_collision_shape()
	_update_label_anchor()
	place_dirt()
	place_crop()


func _process(delta: float) -> void:
	if Engine.is_editor_hint(): # if in the editor, do nothing
		return
	growth_timer += delta 
	if growth_timer > crop_data.growth_time_per_stage:
		# Advance to next crop stage
		growth_stage = min(growth_stage + 1, crop_data.growth_stages - 1) 
		growth_timer = 0
		place_crop()
		
		# If at the final growth stage, enable the InteractionArea
		if(growth_stage == crop_data.growth_stages - 1):
			farm_area.disabled = false
		else:
			farm_area.disabled = true

func _on_interact(): # Function called when harvesting fully grown farm
	growth_stage = 0;
	growth_timer = 0;
	farm_area.disabled = true
	place_crop()
	# Once game is further developed, we will want to replace this with a signal to update inventory
	# Likely will be something like signal.emit(crop_data.crop_name)
	print("INTERACTION") 

func _update_farm_preview(): 
	if !Engine.is_editor_hint(): # if not in editor, do nothing
		return
	# Check scene tree to make sure that we aren't trying to create a preview when the farm is not added to the tree
	if not is_inside_tree():
		return
	if not dirt_tilemap or not farm_area:
		return

	# Clear old preview
	if _preview_cells.size() > 0:
		for cell in _preview_cells:
			dirt_tilemap.erase_cell(cell)
			crops.erase_cell(cell)

	_update_collision_shape()
	_update_label_anchor()
	_preview_cells = get_farm_cells()
	place_dirt()
	place_crop()

func _update_collision_shape(): # Function to resize the InteractionArea for the farm
	var tile_size := dirt_tilemap.tile_set.tile_size
	var shape := RectangleShape2D.new()

	shape.size = Vector2(
		farm_size.x * tile_size.x,
		farm_size.y * tile_size.y
	)

	farm_area.shape = shape
	farm_area.position = shape.size * 0.5

func _update_label_anchor(): # Repositions the LabelAnchor to the center of the farm area
	label_anchor.position = Vector2((farm_size.x * 16) * 0.5, (farm_size.y * 16) * 0.5)

func get_farm_cells() -> Array[Vector2i]:
	# Returns all TileMap cells currently occupied by the farm
	var cells: Array[Vector2i] = []

	var origin := dirt_tilemap.local_to_map(dirt_tilemap.to_local(global_position))

	for x in range(farm_size.x):
		for y in range(farm_size.y):
			cells.append(origin + Vector2i(x, y))

	return cells

func place_dirt(): # Place dirt terrain
	var tiles := get_farm_cells()
	dirt_tilemap.set_cells_terrain_connect(tiles, 0, 1)

func place_crop(): # Place crop tiles on top of dirt
	var tiles := get_farm_cells()
	
	for cell in tiles:
		# Get the current crop growth stage sprite and draw it on the farm
		var crop_atlas_coords = Vector2i(growth_stage, crop_data.row_on_spritesheet)
		crops.set_cell(cell, 3, crop_atlas_coords)
