
extends Camera3D

@export var min_distance := 0.5
@export var max_distance := 5.0
@export var angle_v_adjust := 0.0
@export var mouse_sensitivity := 0.005

# Over-the-shoulder settings
@export var shoulder_offset := 0.8
@export var height_offset := 1.5

# Camera look limits
@export var min_pitch := -85.0
@export var max_pitch := 85.0

var yaw := 0.0
var pitch := 0.0

@onready var target_node: Node3D = get_parent()

func _ready() -> void:
	top_level = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity

		pitch = clamp(
			pitch,
			deg_to_rad(min_pitch),
			deg_to_rad(max_pitch)
		)

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


@export_group("Camera Collision")
@export var collision_margin := 0.2
@export var collision_mask := 1

func _physics_process(_delta: float) -> void:
	var target_pos = target_node.global_position + Vector3.UP * height_offset

	var rot = Basis.from_euler(Vector3(pitch, yaw, 0.0))

	var backward = rot.z * max_distance
	var right = rot.x * shoulder_offset

	var desired_pos = target_pos + backward + right

	# Check for obstacles between the player and camera.
	var space_state = get_world_3d().direct_space_state

	var query = PhysicsRayQueryParameters3D.create(
		target_pos,
		desired_pos
	)

	query.collision_mask = collision_mask
	var player = target_node.get_parent()

	if player is CollisionObject3D:
		query.exclude = [player.get_rid()]

	var result = space_state.intersect_ray(query)

	var camera_pos = desired_pos

	if result:
		var hit_position: Vector3 = result.position
		var hit_normal: Vector3 = result.normal

		camera_pos = hit_position + hit_normal * collision_margin

	look_at_from_position(camera_pos, target_pos, Vector3.UP)


	look_at_from_position(camera_pos, target_pos, Vector3.UP)
