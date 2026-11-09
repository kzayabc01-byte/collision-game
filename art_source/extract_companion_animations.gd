extends SceneTree
## Explicit authoring operation. Does not run when the game starts.

func _initialize() -> void:
	for model_name: String in ["pony", "slime"]:
		var base: String = "res://assets/models/%s/" % model_name
		var model: Node = (load(base + model_name + ".glb") as PackedScene).instantiate()
		var player: AnimationPlayer = model.get_node("AnimationPlayer") as AnimationPlayer
		var library: AnimationLibrary = AnimationLibrary.new()
		var reset: Animation = Animation.new()
		reset.length = 0.001
		var reset_paths: Dictionary = {}
		print(model_name, " clips: ", player.get_animation_list())
		model.print_tree_pretty()
		for clip_name: String in player.get_animation_list():
			if clip_name == "RESET":
				continue
			var clip: Animation = player.get_animation(clip_name).duplicate(true) as Animation
			# glTF adds rest tracks for other objects; locomotion must keep owning those.
			if model_name == "slime" and clip_name != "movement_demo":
				for index: int in range(clip.get_track_count() - 1, -1, -1):
					var raw_path: String = String(clip.track_get_path(index))
					var keep: bool = raw_path.ends_with("/Face") if clip_name == "pickup" else (raw_path.ends_with("/Hat") or raw_path.contains("/JellyBody:"))
					if not keep:
						clip.remove_track(index)
			for index: int in range(clip.get_track_count()):
				var path: NodePath = NodePath("Motion/Model/" + String(clip.track_get_path(index)))
				var key: String = str(clip.track_get_type(index)) + String(path)
				clip.track_set_path(index, path)
				clip.track_set_imported(index, false)
				print("  ", clip_name, " ", path)
				if not reset_paths.has(key):
					reset_paths[key] = true
					var track: int = reset.add_track(clip.track_get_type(index))
					reset.track_set_path(track, path)
					reset.track_insert_key(track, 0.0, clip.track_get_key_value(index, 0))
			library.add_animation(clip_name, clip)
		library.add_animation("RESET", reset)
		var error: Error = ResourceSaver.save(library, base + model_name + "_animations.tres")
		model.free()
		if error != OK:
			quit(1)
			return
	quit()
