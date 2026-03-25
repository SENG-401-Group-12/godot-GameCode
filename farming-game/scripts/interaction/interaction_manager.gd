extends Node2D

@onready var player = get_tree().get_first_node_in_group("Player")
@onready var label = $Label

func _is_touch_device() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("('ontouchstart' in window) || (navigator.maxTouchPoints > 0)", true)
	return false

var base_text = "[INTERACT] TO " if _is_touch_device() else "[E] TO "

const LABEL_OFFSET = 36

var active_areas: Array[Area2D] = [] # Will hold all active interaction areas
var can_interact = true

func register_area(area: InteractionArea):
	active_areas.push_back(area)
	
func unregister_area(area: InteractionArea):
	var index = active_areas.find(area)
	if index != -1:
		active_areas.remove_at(index)
		
func _process(_delta: float) -> void:
	if active_areas.size() > 0 && can_interact: # If the player is in an interactable area
		active_areas.sort_custom(_sort_by_distance_to_player) # prioritize the closer interaction area
		var area := active_areas[0]
		label.text = base_text + area.action_name
		
		# prioritize centering the label around LabelAnchor if it exists
		var anchor := area.get_node_or_null("LabelAnchor")
		if anchor: # if LabelAnchor exists, center the label on top of it
			label.global_position = anchor.global_position
			label.global_position.y -= label.size.y / 2 
		else: # it LabelAnchor doesn't exist, center the label on the area center
			label.global_position = area.global_position
			label.global_position.y -= LABEL_OFFSET # Position label above asset
			
		label.global_position.x -= label.size.x / 2 # Center text
		label.show()
	else:
		label.hide()
		
func _sort_by_distance_to_player(area1, area2):
	# Reorder to whichever object is closer to the player
	var area1_to_player = player.global_position.distance_to(area1.global_position)
	var area2_to_player = player.global_position.distance_to(area2.global_position)
	return area1_to_player < area2_to_player
	
func _input(event: InputEvent) -> void:
	# On interaction button pressed
	if event.is_action_pressed("interact") && can_interact:
		try_interact()

func try_interact(): # If the area is valid to interact with, call the method attatched to it
	if not can_interact:
		return
	if active_areas.is_empty():
		return
		
	can_interact = false
	label.hide()
	
	await active_areas[0].interact.call() # Call the interaction function for the area
	
	can_interact = true
