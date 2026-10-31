extends DriveInput

func sample_direction(_position: Vector3, _context: Dictionary, _delta: float) -> Vector3:
	var axis: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return Vector3(axis.x, 0.0, axis.y)
