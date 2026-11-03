extends SceneTree

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("PASS " if ok else "FAIL ", label)

func _run() -> void:
	var ai: DriveInput = load("res://scripts/ai_driver.gd").new() as DriveInput
	ai.set("random_seed", 1234)
	root.add_child(ai)
	var context: Dictionary = {"mass": 1.0, "radius": 0.76, "scale": 1.0, "heading": Vector3.RIGHT, "velocity": Vector3.RIGHT * 9.0, "bounds": Rect2(-40, -28, 80, 56), "tuning": load("res://config/prototype.tres"), "candies": [], "obstacles": [Vector3(30, 0, 0)], "opponents": [{"id": 7, "position": Vector3(10, 0, 0), "velocity": Vector3.ZERO, "mass": 1.0, "scale": 1.0}]}
	ai.sample_controls(Vector3.ZERO, context, 0.1)
	check(ai.get("intent") == 2 and ai.get("target_id") == 7, "AI hunts nearby opponent while crates remain")
	ai.reset_driver()
	context["opponents"] = []
	context["obstacles"] = []
	context["candies"] = [Vector3(20, 0, 0)]
	ai.sample_controls(Vector3.ZERO, context, 0.1)
	check(ai.get("intent") == 0, "light car sees candy at 20 units")
	ai.reset_driver()
	context["mass"] = 2.0
	context["candies"] = [Vector3(12, 0, 0)]
	ai.sample_controls(Vector3.ZERO, context, 0.1)
	check(ai.get("intent") == 0, "heavy car sees candy beyond old four-unit range")
	ai.reset_driver()
	context["mass"] = 1.0
	context["candies"] = []
	for i: int in range(36):
		var position: Vector3 = Vector3.RIGHT * i * 0.15
		context["opponents"] = [{"id": 8, "position": position + Vector3.RIGHT * 20.0, "velocity": Vector3.RIGHT * 9.0, "mass": 1.0, "scale": 1.0}]
		ai.sample_controls(position, context, 0.1)
	check((ai.get("_blocked") as Dictionary).has("h8") and ai.get("target_key") != "h8", "unchanging chase distance abandons and blacklists target")
	ai.reset_driver()
	context["opponents"] = []
	context["velocity"] = Vector3.ZERO
	var reversed: bool = false
	for i: int in range(20):
		var controls: Dictionary = ai.sample_controls(Vector3.ZERO, context, 0.1)
		reversed = reversed or float(controls["throttle"]) < 0.0
	check(reversed, "stuck vehicle backs out instead of renewing corner patrol")
	ai.reset_driver()
	var point: Vector3
	ai.sample_controls(Vector3.ZERO, context, 0.1)
	point = ai.get("target")
	check(absf(point.x) <= 24.0 and absf(point.z) <= 16.8, "fallback goal lies in inner arena")
	ai.reset_driver()
	ai.set("_clock", 50.0)
	ai.notify_encounter(9)
	context["opponents"] = [{"id": 9, "position": Vector3(8, 0, 0), "velocity": Vector3.ZERO, "mass": 1.0}, {"id": 10, "position": Vector3(35, 0, 0), "velocity": Vector3.ZERO, "mass": 1.0}]
	ai.sample_controls(Vector3.ZERO, context, 0.1)
	check(ai.get("target_id") == 10, "long-unmet opponent outranks repeated local encounter")
	ai.queue_free()
	await process_frame
	var game: CrashMatch = (load("res://scenes/match.tscn") as PackedScene).instantiate() as CrashMatch
	root.add_child(game)
	game.set_physics_process(false)
	var route: PackedVector3Array = ArenaRoute.path(self, game.player.play_bounds, Vector3(-18, 0, -4), Vector3(-4, 0, -4), 0.76, false)
	var avoids_pillar: bool = not route.is_empty()
	for waypoint: Vector3 in route:
		avoids_pillar = avoids_pillar and not Rect2(-12.81, -6.21, 3.62, 4.42).has_point(Vector2(waypoint.x, waypoint.z))
	check(avoids_pillar and route.size() > 2, "route goes around physical pillar with vehicle clearance")
	# Facing and contact velocity are different during drift/reverse.
	var pumpkin: CrashCar = game.cars[1]
	pumpkin.set_candy(80)
	pumpkin._heading = Vector3.FORWARD
	pumpkin.velocity = Vector3.RIGHT * 8.0
	pumpkin.snapshot()
	game.player.set_candy(20)
	game.player.snapshot()
	check(pumpkin.can_swallow(game.player, Vector3.FORWARD) and not pumpkin.can_swallow(game.player, Vector3.RIGHT), "pumpkin mouth follows heading rather than slide velocity")
	game.queue_free()
	await process_frame
	print("AI BEHAVIOR: ", passed, " passed, ", failed, " failed")
	quit(0 if failed == 0 else 1)
