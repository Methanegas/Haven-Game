
# Vishwesh
extends Area3D

@export var spin_speed: float = 2.0
## How close the blob's surface has to get to the cheese to collect it.
@export var collect_radius: float = 0.5

var _blob: BlobBody
var _collected := false


func _process(delta: float) -> void:
	# Slowly rotate.
	rotate_y(spin_speed * delta)

	if _collected:
		return

	# Find the blob.
	if _blob == null:
		_blob = get_tree().get_first_node_in_group("blob") as BlobBody
		return

	# Check whether the blob touches the cheese.
	if _blob.is_ready:
		var distance := global_position.distance_to(_blob.center)

		if distance < collect_radius + _blob.rest_radius:
			_collect()


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_collect()


func _collect() -> void:
	if _collected:
		return

	_collected = true

	print("Collected")

	# Find the player's movement controller.
	var player = _blob.get_parent()

	if player and player.has_method("eat_cheese"):
		player.eat_cheese()

	# Update score.
	ScoreCounter.add_score(1)

	# Remove cheese.
	queue_free()
