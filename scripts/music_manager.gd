extends Node
## One soundtrack across scenes; separate buses leave video audio untouched.
signal changed
const TITLES = ["水族馆", "糖梅仙子之舞", "狂喜之诗"]
const PATHS = ["res://assets/audio/music/aquarium.mp3", "res://assets/audio/music/sugar_plum.mp3", "res://assets/audio/music/ecstasy.mp3"]
const MODES = ["按场景播放", "列表循环", "随机播放", "单曲循环"]
var enabled := true
var music_volume := 0.55
var sfx_volume := 0.8
var mode := 0
var selected := 0
var current := -1
var context := "intro"
var ducked := false
var players: Array[AudioStreamPlayer] = []
var active := 0
var transition: Tween
var panel: CanvasLayer
var settings_open: bool:
	get: return is_instance_valid(panel)
var config_path := "user://music_settings.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_environment("MUSIC_SETTINGS_PATH"):
		config_path = OS.get_environment("MUSIC_SETTINGS_PATH")
	for bus_name: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		add_child(player)
		player.finished.connect(_finished.bind(i))
		players.append(player)
	var cfg := ConfigFile.new()
	if cfg.load(config_path) == OK:
		enabled = bool(cfg.get_value("audio", "enabled", true))
		music_volume = clampf(float(cfg.get_value("audio", "music_volume", 0.55)), 0, 1)
		sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", 0.8)), 0, 1)
		mode = clampi(int(cfg.get_value("audio", "mode", 0)), 0, 3)
		selected = clampi(int(cfg.get_value("audio", "selected", 0)), 0, 2)
	apply_volume()

func save() -> void:
	var cfg := ConfigFile.new()
	for key: String in ["enabled", "music_volume", "sfx_volume", "mode", "selected"]:
		cfg.set_value("audio", key, get(key))
	if cfg.save(config_path) != OK:
		push_warning("音乐设置保存失败")

func apply_volume() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, music_volume * (0.4 if ducked else 1.0))))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not enabled or music_volume <= 0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, sfx_volume)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), sfx_volume <= 0)
	changed.emit()

func set_paused(value: bool) -> void:
	ducked = value
	apply_volume()

func set_context(value: String) -> void:
	var different := context != value
	context = value
	set_paused(false)
	if value == "intro":
		if transition: transition.kill()
		for player in players: player.stop()
		current = -1
	elif current < 0 or (different and mode == 0):
		play_track((2 if value == "battle" else 0) if mode == 0 else selected)

func play_track(index: int, restart := false) -> void:
	index = clampi(index, 0, 2)
	if context == "intro": return
	if current == index and players[active].playing and not restart: return
	var stream := load(PATHS[index]) as AudioStreamMP3
	if stream == null:
		push_warning("无法播放音乐：" + TITLES[index])
		return
	stream.loop = false
	if transition: transition.kill()
	var previous := players[active]
	active = 1 - active
	var incoming := players[active]
	incoming.stop()
	incoming.stream = stream
	incoming.volume_db = -60
	incoming.play()
	current = index
	transition = create_tween().set_parallel(true)
	transition.tween_property(incoming, "volume_db", 0.0, 0.65)
	transition.tween_property(previous, "volume_db", -60.0, 0.65)
	transition.chain().tween_callback(previous.stop)
	changed.emit()

func next_track() -> void:
	var index := (current + 1) % 3
	if mode == 2:
		index = (maxi(0, current) + randi_range(1, 2)) % 3
	selected = index
	play_track(index)
	save()

func _finished(channel: int) -> void:
	if channel != active or context == "intro": return
	if mode == 0 or mode == 3:
		play_track(current, true)
	else:
		next_track()

func set_mode(value: int) -> void:
	mode = clampi(value, 0, 3)
	play_track((2 if context == "battle" else 0) if mode == 0 else selected)
	save()
	changed.emit()

func open_settings() -> void:
	if settings_open: return
	panel = CanvasLayer.new()
	panel.layer = 100
	add_child(panel)
	var ui := Control.new()
	ui.set_script(load("res://scripts/ui/music_settings.gd"))
	panel.add_child(ui)

func close_settings() -> void:
	if settings_open:
		panel.queue_free()
		panel = null
	save()
