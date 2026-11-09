extends SceneTree
## Editor-time export of editable tracks. Run again deliberately after changing the Blender clip.

func _initialize() -> void:
	var model: Node = (load("res://assets/models/pumpkin/pumpkin.glb") as PackedScene).instantiate()
	var player: AnimationPlayer = model.get_node("AnimationPlayer") as AnimationPlayer
	var clip: Animation = player.get_animation("swallow").duplicate(true) as Animation
	var library: AnimationLibrary = AnimationLibrary.new()
	var reset: Animation = Animation.new()
	reset.length = 0.001
	for index: int in range(clip.get_track_count()):
		var path: NodePath = clip.track_get_path(index)
		var new_path: NodePath = NodePath("Motion/Model/" + String(path))
		clip.track_set_path(index, new_path)
		clip.track_set_imported(index, false)
		var reset_track: int = reset.add_track(clip.track_get_type(index))
		reset.track_set_path(reset_track, new_path)
		reset.track_insert_key(reset_track, 0.0, clip.track_get_key_value(index, 0))
	library.add_animation("swallow", clip)
	library.add_animation("RESET", reset)
	var result: Error = ResourceSaver.save(library, "res://assets/models/pumpkin/pumpkin_animations.tres")
	model.free()
	print("EXTRACTED editable pumpkin animations: ", result)
	quit(0 if result == OK else 1)
