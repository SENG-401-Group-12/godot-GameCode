extends Area2D
class_name InteractionArea

@export var action_name: String = "INTERACT"
@onready var player = get_tree().get_first_node_in_group("Player")

var interact: Callable = func(): # Override this function with the behavior to implement
	pass

func _on_body_entered(body: Node2D) -> void:
	if(body == player):
		InteractionManager.register_area(self)

func _on_body_exited(body: Node2D) -> void:
	if(body == player):
		InteractionManager.unregister_area(self)
