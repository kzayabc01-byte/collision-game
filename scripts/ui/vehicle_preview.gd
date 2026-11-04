class_name VehiclePreview
extends SubViewportContainer
## Empty by default. Assign a visual scene in config/selection/*.tres when ready.

@export var idle_rotation_degrees: float = 12.0
var model: Node3D
var _entry: VehicleSelectionEntry
var _dragging: bool = false
var _entrance: Tween
@onready var viewport: SubViewport = $Viewport
@onready var mount: Node3D = $Viewport/ModelMount

func _ready() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func set_vehicle(entry: VehicleSelectionEntry) -> void:
	_entry = entry
	_dragging = false
	if _entrance != null:
		_entrance.kill()
	if is_instance_valid(model):
		mount.remove_child(model)
		model.queue_free()
	model = null
	if entry == null or entry.preview_scene == null:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		hide()
		return
	var candidate: Node = entry.preview_scene.instantiate()
	if not candidate is Node3D:
		candidate.free()
		push_warning("Vehicle preview needs a visual Node3D scene.")
		hide()
		return
	model = candidate as Node3D
	mount.add_child(model)
	model.position = entry.preview_offset
	model.scale = Vector3.ONE * maxf(entry.preview_scale, 0.01) * 0.92
	mount.rotation_degrees.y = entry.preview_yaw_degrees
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	show()
	_entrance = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_entrance.tween_property(model, "scale", Vector3.ONE * maxf(entry.preview_scale, 0.01), 0.3)
	var animations: AnimationPlayer = model.find_child("*", true, false) as AnimationPlayer
	for child: Node in model.find_children("*", "AnimationPlayer", true, false):
		animations = child as AnimationPlayer
		if animations.has_animation(entry.preview_idle_animation):
			animations.play(entry.preview_idle_animation)
			break

func _process(delta: float) -> void:
	if is_instance_valid(model) and not _dragging:
		mount.rotation.y += deg_to_rad(idle_rotation_degrees) * delta

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		mount.rotation.y += event.relative.x * 0.008
		accept_event()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_dragging = false
