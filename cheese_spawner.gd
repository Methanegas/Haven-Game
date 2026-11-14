extends Node3D

@export var cheese_scene: PackedScene
@export var cheese_count: int = 50
#@export var cheese_spawn_area := 15 # +/- in the x and y axis
@export var cheese_hover_height: float = .5

@onready var terrain: CSGCombiner3D = $Terrain

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	spawn_coins()

func spawn_coins() -> void:
	var space_state := get_world_3d().direct_space_state

	var meshes := terrain.get_meshes()
	if meshes.is_empty():
		print("No CSG meshes found!")
		return
		
	var combined_mesh: ArrayMesh = meshes[1]
	var aabb: AABB = combined_mesh.get_aabb()
	var min_bounds := terrain.to_global(aabb.position)
	var max_bounds := terrain.to_global(aabb.position + aabb.size)
	print("Terrain Bounds:")
	print("Min: ", min_bounds)
	print("Max: ", max_bounds)
	
	var spawned_count := 0
	var attempts := 0 # To prevent freezing if its not possible to spawn all
	
	while spawned_count < cheese_count and attempts < cheese_count + 500:
		attempts += 1
		
		#var random_x := randf_range(-cheese_spawn_area, cheese_spawn_area)
		#var random_z := randf_range(-cheese_spawn_area, cheese_spawn_area)
		
		var random_x := randf_range(min_bounds.x, max_bounds.x)
		var random_z := randf_range(min_bounds.z, max_bounds.z)
		
		var ray_origin := Vector3(random_x, max_bounds.y + 10.0, random_z)
		var ray_end := Vector3(random_x, min_bounds.y - 10.0, random_z)
		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		
		var result := space_state.intersect_ray(query)
		
		if result and result.position.y > 2:
			var new_cheese := cheese_scene.instantiate()
			new_cheese.position = result.position + Vector3(0, cheese_hover_height, 0)
			add_child(new_cheese)
			spawned_count += 1
	
	while spawned_count < cheese_count:
		
		#var random_x := randf_range(-cheese_spawn_area, cheese_spawn_area)
		#var random_z := randf_range(-cheese_spawn_area, cheese_spawn_area)
		
		var random_x := randf_range(min_bounds.x, max_bounds.x)
		var random_z := randf_range(min_bounds.z, max_bounds.z)
		
		var ray_origin := Vector3(random_x, max_bounds.y + 10.0, random_z)
		var ray_end := Vector3(random_x, min_bounds.y - 10.0, random_z)
		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		
		var result := space_state.intersect_ray(query)
		
		if result:
			var new_cheese := cheese_scene.instantiate()
			new_cheese.position = result.position + Vector3(0, cheese_hover_height, 0)
			add_child(new_cheese)
			spawned_count += 1
	
	
	
	print("Attempts: " + str(attempts))
	print("Spawed " + str(spawned_count) + " cheeses")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
