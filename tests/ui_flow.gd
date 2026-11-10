extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count: int = 6) -> void:
	for index: int in range(count):
		await process_frame

func key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames()

func click(button: Control) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = button.get_global_transform() * (button.size * 0.5)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	root.push_input(event, true)
	await frames()

func _run() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/ui/start_screen.tscn", "Boot uses UI folder")
	StartScreen.intro_checked_this_launch = false
	CrashMatch.selected_vehicle = 0
	var menu: StartScreen = load("res://scenes/ui/start_screen.tscn").instantiate() as StartScreen
	# Keep the missing-video fallback test independent of shipped media.
	menu.intro_video_path = "res://assets/cinematics/missing-test.ogv"
	menu.fade_seconds = 0.0
	root.add_child(menu)
	current_scene = menu
	await frames()
	check(menu.stage == StartScreen.Stage.MENU, "Missing film enters menu")
	check(menu.title_art is Sprite2D, "Smooth title rendering retained")
	await key(KEY_ENTER)
	check(current_scene is VehicleSelect, "Start enters vehicle selection")
	if not current_scene is VehicleSelect:
		quit(1)
		return
	var screen: VehicleSelect = current_scene as VehicleSelect
	screen.transition_seconds = 0.0
	check(screen.cards.size() == 4 and screen.cards[3].disabled, "Three available plus locked upcoming card")
	check(screen.preview.visible and screen.preview.model != null, "Initial pony selection shows the imported model")
	check(screen.preview.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Active model preview renders")
	check(root.find_children("Match", "Node3D", true, false).is_empty(), "No match timer behind selection")
	screen.cycle(-1)
	check(screen.selected_index == 2, "Previous wraps past locked card")
	screen.cycle(1)
	check(screen.selected_index == 0, "Next wraps to first available")
	screen.select_entry(3)
	check(screen.selected_index == 0, "Locked selection rejected")
	await click(screen.cards[1])
	check(screen.selected_index == 1 and screen.trait_label.text.contains("50%"), "Click selects pumpkin with actual swallow ratio")
	await click(screen.right_button)
	check(screen.selected_index == 2 and screen.trait_label.text.contains("7.5%"), "Arrow selects slime with actual turning retention")
	check(screen.trait_label.text.contains("30%") and screen.trait_label.text.contains("20%"), "Slime reads actual defense and acceleration")
	await key(KEY_A)
	check(screen.selected_index == 1, "A selects previous")
	await key(KEY_D)
	check(screen.selected_index == 2, "D selects next")
	await key(KEY_1)
	check(screen.selected_index == 0 and screen.trait_label.text.contains("40") and screen.trait_label.text.contains("翻倍"), "Pony reads current pickup rule")
	for size_value: Vector2 in [Vector2(1672, 941), Vector2(1280, 800), Vector2(1024, 768), Vector2(2560, 1080)]:
		screen.size = size_value
		screen._layout()
		var rect: Rect2 = Rect2(screen.composition.position, screen.composition.size * screen.composition.scale)
		check(rect.position.x >= -0.01 and rect.position.y >= -0.01 and rect.end.x <= size_value.x + 0.01 and rect.end.y <= size_value.y + 0.01, "Responsive composition fits " + str(size_value))
	screen.size = root.get_visible_rect().size
	screen._layout()
	for count: int in range(20):
		screen.cycle(1)
	var selected_count: int = 0
	for card: VehicleCard in screen.cards:
		selected_count += int(card.selected)
	check(selected_count == 1 and screen.name_label.text == (screen.entries[screen.selected_index] as VehicleSelectionEntry).title, "Rapid switching keeps card and information synchronized")
	var fixture: VehicleSelectionEntry = (screen.entries[0] as VehicleSelectionEntry).duplicate() as VehicleSelectionEntry
	fixture.preview_scene = load("res://scenes/vehicles/pony_visual.tscn") as PackedScene
	screen.preview.set_vehicle(fixture)
	await frames()
	check(screen.preview.model != null and screen.preview.visible and screen.preview.viewport.own_world_3d, "Future model hook creates isolated preview")
	fixture.preview_scene = null
	screen.preview.set_vehicle(fixture)
	await frames()
	check(screen.preview.model == null and screen.preview.mount.get_child_count() == 0 and not screen.preview.visible, "Switch clears old model and restores empty stage")
	check(screen.preview.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Empty fallback consumes no rendering updates")
	screen.preview.set_vehicle(screen.entries[0] as VehicleSelectionEntry)
	await frames()
	check(screen.preview.visible and screen.preview.mount.get_child_count() == 1, "Restoring a model creates exactly one preview")
	await key(KEY_ESCAPE)
	check(current_scene is StartScreen and (current_scene as StartScreen).stage == StartScreen.Stage.MENU, "Esc returns to menu without replay")
	menu = current_scene as StartScreen
	menu.fade_seconds = 0.0
	await key(KEY_ENTER)
	screen = current_scene as VehicleSelect
	screen.transition_seconds = 0.0
	check(screen.selected_index == CrashMatch.selected_vehicle, "Selection remembered within session")
	for kind: int in range(3):
		screen.select_entry(kind)
		await click(screen.start_button)
		check(current_scene is CrashMatch, "Confirm starts match for vehicle " + str(kind))
		if not current_scene is CrashMatch:
			quit(1)
			return
		var game: CrashMatch = current_scene as CrashMatch
		check(int(game.player.profile.kind) == kind, "Chosen vehicle actually spawned " + str(kind))
		check(game.has_node("Arena/Scenery/Buildings/Church") and game.has_node("Arena/Scenery/Buildings/CandyHouse"), "Updated arena buildings retained " + str(kind))
		game.toggle_pause()
		var music = root.get_node("Music")
		var settings_button := game.hud.get_node("%MusicSettingsButton") as Button
		check(settings_button.visible, "Pause exposes music settings")
		settings_button.pressed.emit()
		await frames()
		check(music.settings_open and game.phase == CrashMatch.Phase.PAUSED, "Music opens without resuming")
		await key(KEY_R)
		check(current_scene == game and music.settings_open, "Settings blocks match restart shortcut")
		await key(KEY_ESCAPE)
		check(not music.settings_open and game.phase == CrashMatch.Phase.PAUSED and game.hud.overlay.visible, "Esc closes only music settings")
		check(game.hud.overlay.visible and (game.hud.get_node("%SelectVehicleButton") as Button).visible, "Pause exposes selection return")
		(game.hud.get_node("%SelectVehicleButton") as Button).pressed.emit()
		await frames()
		check(current_scene is VehicleSelect, "Match returns to selection")
		screen = current_scene as VehicleSelect
		screen.transition_seconds = 0.0
		check(screen.selected_index == kind, "Returning preserves selected vehicle")
	screen.start_match()
	screen.start_match()
	await frames()
	check(root.find_children("Match", "Node3D", false, false).size() == 1, "Double confirm creates only one match")
	var game: CrashMatch = current_scene as CrashMatch
	game.restart()
	await frames()
	check(current_scene is CrashMatch and int((current_scene as CrashMatch).player.profile.kind) == 2, "Restart retains vehicle and stays in match")
	game = current_scene as CrashMatch
	game.finish_round()
	(game.hud.get_node("%MenuButton") as Button).pressed.emit()
	await frames()
	check(current_scene is StartScreen, "Results return to main menu")
	var ground_test: Node = load("res://scenes/tests/painted_ground_test.tscn").instantiate()
	check(ground_test.has_node("Ground") and ground_test.has_node("Camera3D"), "Independent ground shader test still loads")
	ground_test.free()
	current_scene.free()
	# Audio playback is released by the mix thread after scene teardown.
	await create_timer(0.25).timeout
	print("UI_FLOW_CHECKS ", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
