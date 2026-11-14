
class_name BlobBody
extends SoftBody3D

 
signal ready_to_drive
 
# ---- Shape-holding (set from here so you can tune them in the Inspector) ----
@export_range(0.0, 1.0) var stiffness := 0.9      # edge stiffness; higher = stiffer shell
@export var pressure := 50.0                     # "air" inside; this is what holds the ball's volume
@export var precision := 20                       # solver iterations; higher = more stable, costs CPU
@export var damping := 0.05                       # slows jiggle so it doesn't wobble itself apart
 
var center := Vector3.ZERO            # world-space centre of the blob
var center_velocity := Vector3.ZERO   # how fast that centre is moving
var is_ready := false
var rest_radius := 0.0                # measured from the mesh at start; the controller uses this
 
var _blob_material: ShaderMaterial
var _sample_points: Array[int] = []
var _last_center := Vector3.ZERO
 
 
func _ready() -> void:
	add_to_group("blob")  # lets pickups like the cheese find the blob without a hard-coded path
 
	linear_stiffness = stiffness
	pressure_coefficient = pressure
	simulation_precision = precision
	damping_coefficient = damping
 
	_blob_material = material_override as ShaderMaterial
	if _blob_material == null:
		_blob_material = get_active_material(0) as ShaderMaterial
 
	# Pick a spread of mesh points to average into a centre (cheaper than using all).
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var step := maxi(ceili(verts.size() / 128.0), 1)
	for i in range(0, verts.size(), step):
		_sample_points.append(i)
 
	# Wait one physics frame so the soft body exists before we read its points.
	await get_tree().physics_frame
	center = _compute_center()
	_last_center = center
 
	# Measure the resting radius so nothing depends on a hand-typed number
	var total := 0.0
	for i in _sample_points:
		total += to_global(get_point_transform(i)).distance_to(center)
	rest_radius = total / float(maxi(_sample_points.size(), 1))
 
	is_ready = true
	ready_to_drive.emit()
 
 
func _physics_process(delta: float) -> void:
	if not is_ready:
		return
 
	center = _compute_center()
	center_velocity = (center - _last_center) / maxf(delta, 0.0001)
	_last_center = center
 
	if _blob_material:
		_blob_material.set_shader_parameter("slime_center", center)
 
 
func _compute_center() -> Vector3:
	var sum := Vector3.ZERO
	for i in _sample_points:
		sum += to_global(get_point_transform(i))
	return sum / float(maxi(_sample_points.size(), 1))
 
