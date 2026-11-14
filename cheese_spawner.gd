extends Node3D

@export var cheese_scene: PackedScene
@export var cheese_count: int = 15

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in range(cheese_count):
		var new_cheese = cheese_scene.instantiate()
		
		var random_x := randf_range(-9.0, 9.0)
		var random_z := randf_range(-9.0, 9.0)
		new_cheese.position = Vector3(random_x, 1.0, random_z)
		
		add_child(new_cheese)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
