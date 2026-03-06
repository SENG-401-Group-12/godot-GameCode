extends Node2D

const ItemSlot = preload("res://scenes/characters/customer/item_slot.tscn")
@onready var interaction_area: InteractionArea = $InteractionArea
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var requests: Array[ItemRequest] = []
@export var min_requests := 1
@export var max_request := 3 

func _ready():
	interaction_area.interact = Callable(self, "_on_interact") # link the "_on_interact" function
	#choose_random_sprite()
	generate_random_requests()
	populate_display()
	
#func choose_random_sprite():
	#var chosen_sprite = randi_range(0, 1)
	#if chosen_sprite == 0:
		#sprite.play("chicken_idle")
	#else:
		#sprite.play("cow_idle")

func _on_interact():
	var have_all_items = true
	for item in requests:
		if PlayerData.inventory.get(item.item_name, 0) < item.amount:
			have_all_items = false
			break
			
	if have_all_items:
		for item in requests:
			PlayerData.inventory[item.item_name] -= item.amount
		flash_sprite(Color.GREEN, queue_free)
	else:
		flash_sprite(Color.RED)
		show_not_enough_label()
		
func flash_sprite(color: Color, callback := Callable()):
	var tween = create_tween()
	# Repeat the flash 3 times
	for i in range(3):
		tween.tween_property(sprite, "modulate", color, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	if not callback.is_null():
		tween.tween_callback(callback)

func show_not_enough_label():
	var label = $NotEnoughLabel
	label.show()
	label.modulate.a = 1.0
	
	var tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.hide)

func generate_random_requests():
	var crop_list = Globals.game_crops.duplicate()
	crop_list.shuffle() # randomize order
	var request_count = randi_range(min_requests, max_request) # TODO: implement wave difficulty (higher chance for more requests)
	for i in range(min(request_count, crop_list.size())):
		var request = ItemRequest.new()
		request.item_name = crop_list[i].crop_name
		request.icon = crop_list[i].get_item_icon()
		request.amount = randi_range(10, 15) # TODO: Implement wave difficulty 
		
		requests.append(request)
	
func populate_display():
	var container = $RequestList/RequestContainer
	for req in requests:
		var slot = ItemSlot.instantiate() # create an item slot node
		slot.get_node("ItemContainer/ItemTexture").texture = req.icon
		slot.get_node("ItemContainer/ItemAmount").text = "x%d" % req.amount
		container.add_child(slot)
