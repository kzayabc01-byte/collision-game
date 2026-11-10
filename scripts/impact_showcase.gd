extends Node3D

var tier: int = 2
var elapsed: float = 6.0
@onready var first: CrashCar = $Vehicles/Pony
@onready var second: CrashCar = $Vehicles/Slime
@onready var resolver: CollisionResolver = $CollisionResolver
@onready var candies: CandySystem = $CandySystem
@onready var status: Label = $UI/Status

func _ready() -> void:
	resolver.candy_system = candies
	resolver.impact_visualized.connect(_show_effect)
	$UI/Hit.pressed.connect(play_hit)
	$UI/Play.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/ui/start_screen.tscn"))
	_reset_cars()

func _process(delta: float) -> void:
	elapsed += delta
	candies.tick(delta)
	status.text = "%s · 糖汁%s" % [["轻碰", "中撞", "重撞"][tier], "已清除" if elapsed >= 5.0 else " %.1f 秒后消失" % (5.0 - elapsed)]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_3:
			tier = event.keycode - KEY_1
			play_hit()
		elif event.keycode == KEY_SPACE:
			play_hit()

func _reset_cars() -> void:
	first.reset_at(Vector3(-1.8, 0, 1.3))
	second.reset_at(Vector3(1.8, 0, 1.3))
	for car: CrashCar in [first, second]:
		car.set_candy(45)
		car.name_label.pixel_size = 0.003
		car.growth_root.scale = Vector3.ONE * CollisionMath.scale_for(45, car.tuning)
		resolver.clear_for(car)
	first._heading = Vector3.RIGHT
	second._heading = Vector3.LEFT

func play_hit() -> void:
	for child: Node in candies.get_children():
		child.free()
	for child: Node in $Effects.get_children():
		child.free()
	_reset_cars()
	var speed: float = [2.0, 4.5, 7.0][tier]
	first.velocity = Vector3.RIGHT * speed
	second.velocity = Vector3.LEFT * speed * 0.3
	first.snapshot()
	second.snapshot()
	resolver._resolve_car(first, second, Vector3.RIGHT, resolver.pair_key(first, second), Vector3(0, 0.5, 1.3))
	first.velocity = Vector3.ZERO
	second.velocity = Vector3.ZERO
	first.update_roll_state()
	second.update_roll_state()
	elapsed = 0.0

func _show_effect(point: Vector3, direction: Vector3, strength: int, _player: bool, _defeated: bool, color: Color) -> void:
	var effect: SugarImpactEffect = CrashMatch.IMPACT_SCENE.instantiate() as SugarImpactEffect
	$Effects.add_child(effect)
	effect.position = Vector3(point.x, 0.0, point.z)
	effect.setup(direction, color, strength)
