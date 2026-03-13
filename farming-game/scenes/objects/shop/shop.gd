extends Node2D

@onready var interaction_area: InteractionArea = $InteractionArea

signal shop_opened

func _ready() -> void:
	interaction_area.interact = Callable(self, "_on_interact") # link the "_on_interact" function

func _on_interact():
	shop_opened.emit()
