# Vishwesh
extends Area3D

@export var spin_speed: float = 2.0

func _process(delta: float) -> void:
	# Slowly rotate
	rotate_y(spin_speed * delta)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		print("Collected")
		ScoreCounter.add_score(1)
		queue_free()
		
