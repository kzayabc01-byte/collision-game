extends MeshInstance3D
## Visual-only backdrop. UVs continue the existing ground without resizing
## its paint, changing its material, or expanding gameplay collision.
@export var extent: float = 512.0

func _ready() -> void:
	var reference: MeshInstance3D = get_parent() as MeshInstance3D
	if reference == null or not reference.mesh is PlaneMesh:
		return
	var original_size: Vector2 = (reference.mesh as PlaneMesh).size
	var half: float = maxf(extent, maxf(original_size.x, original_size.y)) * 0.5
	var vertices: PackedVector3Array = PackedVector3Array([
		Vector3(-half, 0, -half), Vector3(half, 0, -half),
		Vector3(half, 0, half), Vector3(-half, 0, half)])
	var uv: PackedVector2Array = PackedVector2Array()
	for point: Vector3 in vertices:
		uv.append(Vector2(point.x / original_size.x + 0.5, point.z / original_size.y + 0.5))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var plane: ArrayMesh = ArrayMesh.new()
	plane.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = plane
	material_override = reference.material_override
	position.y = -0.025
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
