extends DriveInput

func sample_controls(_position: Vector3, _context: Dictionary, _delta: float) -> Dictionary:
	return {
		"throttle": Input.get_axis("move_down", "move_up"),
		"steer": Input.get_axis("move_left", "move_right"),
		"brake": Input.get_action_strength("brake") > 0.5,
	}
