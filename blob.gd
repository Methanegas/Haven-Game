
extends Node3D

# ---- Movement ----
@export var ground_speed := 2.0
@export var air_speed := 3.0
@export var control_gain := 8.0
@export var max_accel := 25.0
@export var jump_impulse := 6.5

# ---- Dash ----
@export var dash_impulse := 9.0
@export var dash_cooldown := 0.8
@export var dash_duration := 0.22

# ---- Grapple ----
@export var grapple_range := 25.0
@export var grapple_stiffness := 35.0
@export var grapple_damping := 8.0
@export var grapple_max_force := 100.0
@export var grapple_initial_slack := 0.5
@export var grapple_width := 0.09
@export var grapple_segments := 12

# ---- Adhesion ----
@export var stick_accel := 12.0
@export var bounce_damping := 10.0
@export var detach_grace := 0.12
@export var surface_turn_speed := 8.0
@export var attach_lockout_time := 0.2
@export var new_surface_angle := 0.3

# ---- Size / Tuning ----
@export var radius := 0.0
@export var force_scale := 1.0
@export var forces_enabled := true
@export var debug_print := false

# ---- Optional Goal ----
@export var goal: Node3D
@export var goal_radius := 1.0

# ---- Growth ----
@export var growth_per_cheese := 0.25
@export var max_growth := 2.5
@export var growth_speed := 1.5

var current_growth := 1.0
var target_growth := 1.0

@onready var body: BlobBody = $Body
@onready var camera: Camera3D = $Target/SpringArm3D/Camera3D
@onready var camera_rig: Node3D = $Target
@onready var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))

var surface_normal := Vector3.UP
var is_attached := false
var attach_lockout := 0.0
var attach_time := 0.0
var time_since_hit := 1.0
var debug_timer := 0.0

# Dash state
var dash_cooldown_remaining := 0.0
var dash_time_remaining := 0.0
var dash_direction := Vector3.ZERO

# Grapple state
var grapple_active := false
var grapple_point := Vector3.ZERO
var grapple_length := 0.0

# Grapple visual
var grapple_mesh_instance: MeshInstance3D
var grapple_material: StandardMaterial3D


# =========================================================
# GROWTH
# =========================================================

func eat_cheese() -> void:
	target_growth = minf(
		target_growth + growth_per_cheese,
		max_growth
	)


func _update_growth(delta: float) -> void:
	current_growth = move_toward(
		current_growth,
		target_growth,
		growth_speed * delta
	)

	body.shrinking_factor = 1.0 - current_growth


# READY / PHYSICS

func _ready() -> void:
	camera_rig.top_level = true

	if not body.is_ready:
		await body.ready_to_drive

	camera_rig.global_position = body.center

	_update_growth(0.0)
	_setup_grapple_visual()


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed(&"exit"):
		get_tree().quit()

	if not body.is_ready:
		return

	# Update slime size.
	_update_growth(delta)

	var center: Vector3 = body.center
	var vel: Vector3 = body.center_velocity

	if Input.is_action_just_pressed(&"reset_position") or center.y < -6.0:
		get_tree().reload_current_scene()
		return

	# ---- Timers ----
	dash_cooldown_remaining = maxf(dash_cooldown_remaining - delta, 0.0)
	dash_time_remaining = maxf(dash_time_remaining - delta, 0.0)
	attach_lockout = maxf(attach_lockout - delta, 0.0)

	# ---- Grapple input ----
	if Input.is_action_just_pressed(&"grapple"):
		_try_grapple(center)

	if Input.is_action_just_released(&"grapple"):
		grapple_active = false

	# ---- Surface detection ----
	var hit := _find_surface(center, _get_move_dir())

	if hit.is_empty():
		time_since_hit += delta
	else:
		time_since_hit = 0.0

	var can_stick := attach_lockout <= 0.0 and (
		not hit.is_empty() or (is_attached and time_since_hit < detach_grace)
	)

	if can_stick and not grapple_active:
		is_attached = true

		if not hit.is_empty():
			var hit_normal: Vector3 = hit["normal"]

			surface_normal = _follow_normal(
				surface_normal,
				hit_normal,
				minf(delta * surface_turn_speed, 1.0)
			)
	else:
		is_attached = false

		if not grapple_active:
			surface_normal = Vector3.UP

	attach_time = attach_time + delta if is_attached else 0.0

	var m: float = (body.total_mass * force_scale) if forces_enabled else 0.0

	# ---- Jump ----
	if is_attached and Input.is_action_just_pressed(&"jump"):
		body.apply_central_impulse(surface_normal * jump_impulse * m)

		is_attached = false
		surface_normal = Vector3.UP
		attach_lockout = attach_lockout_time
		attach_time = 0.0

	# ---- Movement direction ----
	var dir := _get_move_dir()

	if dir.length_squared() > 1.0:
		dir = dir.normalized()

	# ---- Dash ----
	if Input.is_action_just_pressed(&"dash") and dash_cooldown_remaining <= 0.0:
		var dash_dir := dir

		if dash_dir.length_squared() < 0.01:
			dash_dir = vel.slide(surface_normal)

		if dash_dir.length_squared() < 0.01:
			dash_dir = (-camera.global_basis.z).slide(surface_normal)

		if dash_dir.length_squared() > 0.01:
			dash_direction = dash_dir.normalized()

			body.apply_central_impulse(
				dash_direction * dash_impulse * m
			)

			dash_cooldown_remaining = dash_cooldown
			dash_time_remaining = dash_duration

	# ---- Adhesion and movement ----
	if is_attached:
		body.apply_central_force(Vector3.UP * gravity * m)

		var stick_ramp := clampf(attach_time / 0.2, 0.0, 1.0)

		body.apply_central_force(
			-surface_normal * stick_accel * m * stick_ramp
		)

		var away: float = vel.dot(surface_normal)

		if away > 0.0:
			body.apply_central_force(
				-surface_normal * minf(away * bounce_damping, max_accel) * m
			)

		var along: Vector3 = vel.slide(surface_normal)
		var accel: Vector3 = (dir * ground_speed - along) * control_gain

		body.apply_central_force(
			accel.limit_length(max_accel) * m
		)
	else:
		var flat := Vector3(vel.x, 0.0, vel.z)
		var accel: Vector3 = (dir * air_speed - flat) * control_gain * 0.3

		body.apply_central_force(
			accel.limit_length(max_accel) * m
		)

	# ---- Grapple physics ----
	if grapple_active:
		_apply_grapple_force(center, vel, m)

	# ---- Grapple visual ----
	_update_grapple_visual(center)

	# ---- Camera ----
	camera_rig.global_position = camera_rig.global_position.lerp(
		center, minf(delta * 10.0, 1.0)
	)

	# ---- Goal ----
	if goal and center.distance_to(goal.global_position) < goal_radius:
		var win_text := get_node_or_null("WinText")

		if win_text:
			win_text.show()

	# ---- Debug ----
	if debug_print:
		debug_timer += delta

		if debug_timer > 0.5:
			debug_timer = 0.0

			print(
				"attached=", is_attached,
				" grapple=", grapple_active,
				" grapple length=", grapple_length,
				" growth=", current_growth,
				" target growth=", target_growth,
				" center=", center
			)


# =========================================================
# GRAPPLE
# =========================================================

func _try_grapple(center: Vector3) -> void:
	var origin := camera.global_position
	var direction := -camera.global_basis.z
	var end := origin + direction * grapple_range

	var query := PhysicsRayQueryParameters3D.create(
		origin,
		end,
		body.collision_mask,
		[body.get_physics_rid()]
	)

	var result := get_world_3d().direct_space_state.intersect_ray(query)

	if result.is_empty():
		return

	grapple_point = result["position"]

	var distance := center.distance_to(grapple_point)

	grapple_length = maxf(
		distance - grapple_initial_slack,
		1.0
	)

	grapple_active = true

	# Grappling detaches the slime from its current surface.
	is_attached = false
	surface_normal = Vector3.UP
	attach_time = 0.0


func _apply_grapple_force(
	center: Vector3,
	vel: Vector3,
	mass: float
) -> void:
	var to_anchor := grapple_point - center
	var distance := to_anchor.length()

	if distance < 0.01:
		return

	var direction := to_anchor / distance

	# Only pull when the tether is stretched.
	var extension := distance - grapple_length

	if extension <= 0.0:
		return

	# Velocity moving away from the anchor.
	var outward_velocity := -vel.dot(direction)

	var tension := (
		extension * grapple_stiffness
		+ outward_velocity * grapple_damping
	)

	tension = clampf(tension, 0.0, grapple_max_force)

	body.apply_central_force(direction * tension * mass)


# =========================================================
# GRAPPLE VISUAL
# =========================================================

func _setup_grapple_visual() -> void:
	grapple_mesh_instance = MeshInstance3D.new()
	grapple_mesh_instance.name = "GooGrapple"
	grapple_mesh_instance.top_level = true
	grapple_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(grapple_mesh_instance)

	grapple_material = StandardMaterial3D.new()
	grapple_material.albedo_color = Color(0.03, 0.35, 1.0, 0.9)
	grapple_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grapple_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	grapple_material.roughness = 0.2
	grapple_material.metallic = 0.05
	grapple_material.emission_enabled = true
	grapple_material.emission = Color(0.02, 0.2, 1.0)
	grapple_material.emission_energy_multiplier = 0.7
	grapple_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _update_grapple_visual(center: Vector3) -> void:
	if not grapple_active:
		grapple_mesh_instance.mesh = null
		return

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var rope_direction := (grapple_point - center).normalized()

	var view_direction := camera.global_position.direction_to(
		camera.global_position + camera.global_basis.z
	)

	var width_direction := rope_direction.cross(view_direction).normalized()

	if width_direction.length_squared() < 0.01:
		width_direction = camera.global_basis.x.normalized()

	# Build a slightly curved goo strand.
	for i in range(grapple_segments + 1):
		var t := float(i) / float(grapple_segments)

		var pos := center.lerp(grapple_point, t)

		# Small curve in the rope.
		var curve := sin(t * PI) * minf(
			center.distance_to(grapple_point) * 0.025,
			0.4
		)

		pos += view_direction * curve

		var width := grapple_width * (
			0.75 + sin(t * PI) * 0.25
		)

		vertices.append(pos - width_direction * width)
		vertices.append(pos + width_direction * width)

		normals.append(view_direction)
		normals.append(view_direction)

		var color := Color(0.02, 0.3, 1.0, 0.9)
		colors.append(color)
		colors.append(color)

		if i < grapple_segments:
			var index := i * 2

			indices.append(index)
			indices.append(index + 1)
			indices.append(index + 2)

			indices.append(index + 1)
			indices.append(index + 3)
			indices.append(index + 2)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, grapple_material)

	grapple_mesh_instance.mesh = mesh


# =========================================================
# SURFACE / MOVEMENT HELPERS
# =========================================================

func _radius() -> float:
	var base_radius := radius if radius > 0.0 else maxf(body.rest_radius, 0.1)
	return base_radius * current_growth


func _find_surface(center: Vector3, move_dir: Vector3) -> Dictionary:
	var reach := _radius() * 1.6
	var moving := move_dir.length_squared() > 0.01
	var heading := move_dir.normalized()

	if moving and attach_lockout <= 0.0:
		var ahead := _cast(center, center + heading * reach)

		if not ahead.is_empty():
			var ahead_normal: Vector3 = ahead["normal"]

			if ahead_normal.angle_to(surface_normal) > new_surface_angle:
				return ahead

	var below := _cast(center, center - surface_normal * reach)

	if not below.is_empty():
		return below

	if moving and is_attached and attach_lockout <= 0.0:
		var under := center - surface_normal * reach
		var wrapped := _cast(under, under - heading * reach * 1.5)

		if not wrapped.is_empty():
			return wrapped

	return {}


func _cast(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		from,
		to,
		body.collision_mask,
		[body.get_physics_rid()]
	)

	var result := get_world_3d().direct_space_state.intersect_ray(query)

	if result.is_empty():
		return {}

	return {
		"point": result["position"],
		"normal": result["normal"]
	}


func _follow_normal(from: Vector3, to: Vector3, t: float) -> Vector3:
	if from.dot(to) < -0.999:
		return to

	return from.slerp(to, t).normalized()


func _get_move_dir() -> Vector3:
	var input_x := Input.get_axis(&"move_left", &"move_right")
	var input_z := Input.get_axis(&"move_forward", &"move_back")

	var cam := camera.global_basis
	var n := surface_normal

	var right := cam.x.slide(n).normalized()
	var forward := (-cam.z).slide(n).normalized()
	var climb := cam.y.slide(n).normalized()

	var facing := absf(cam.z.dot(n))
	forward = forward.lerp(climb, smoothstep(0.55, 0.9, facing))

	return right * input_x + forward * -input_z
