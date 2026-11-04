class_name VehicleSelectionEntry
extends Resource
## Presentation data; ratings never write back into gameplay tuning.

@export var profile: VehicleProfile
@export var title: String = ""
@export var card_title: String = ""
@export_multiline var introduction: String = ""
@export_range(0, 5) var growth_rating: int = 3
@export_range(0, 5) var collision_rating: int = 3
@export var thumbnail: Texture2D
@export var locked: bool = false
@export_group("后续模型接入")
## A visual-only Node3D scene, never a car controller or a complete level.
@export var preview_scene: PackedScene
@export var preview_scale: float = 1.0
@export var preview_offset: Vector3 = Vector3.ZERO
@export var preview_yaw_degrees: float = 155.0
@export var preview_idle_animation: StringName = &"idle"

func trait_text() -> String:
	if profile == null:
		return "更多座驾，敬请期待。"
	match profile.kind:
		VehicleProfile.Kind.PONY:
			return "少于%d颗糖时，拾取收益翻倍。\n自己掉落的糖果不翻倍。" % profile.double_below
		VehicleProfile.Kind.PUMPKIN:
			return "车头可吞下尺寸≤自身%d%%的对手，\n并获得对方全部糖果。" % roundi(profile.swallow_size_ratio * 100.0)
		VehicleProfile.Kind.SLIME:
			return "速度＞%s时滚动：受伤−%s%%，\n加速＋%s%%；转90°仅减速%s%%。" % [_number(profile.roll_threshold), _number((1.0 - profile.rolling_damage_multiplier) * 100.0), _number((profile.rolling_acceleration_multiplier - 1.0) * 100.0), _number((1.0 - profile.rolling_turn_retention) * 100.0)]
	return profile.description

func _number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else String.num(value, 1)
