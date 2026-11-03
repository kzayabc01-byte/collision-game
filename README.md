# 不给糖就撞：驾驶与 AI V2

## 启动与操作
双击 `play.cmd`，或用 Godot 4.4+ 导入 `project.godot`。本机启动器使用 D:/Godot_v4.7.2-stable_win64.exe 下的程序。

- W/上：油门前进；S/下：先减速，停下后继续倒车，上限3.5。
- A/左、D/右：车辆自身的左/右转向。面向屏幕下方时仍遵循车辆方向；倒车遵循方向盘规则。
- Shift／手柄左扳机：制动；高速配合转向进入持续漂移。手柄左摇杆纵向控制油门/倒车、横向转向。
- 看到“弹射就绪”后，保持 W 松开 Shift，获得最多0.45秒弹射。冷却0.8秒；再刹车或撞击中断。
- Esc暂停、R重开；1/2/3选择小马/南瓜/史莱姆；F2能力试验。独立车型展示仍用空格暂停。

## 这一版的变化
基础驾驶不再受累计距离限制：0到7的加速度16，7到9为4，普通转向允许继续给油。极速仍为9，伤害公式未改变。
直线刹车减速度8，极速理想停止时间1.125秒。漂移净减速度3；车头与移动方向分开，漂移抓地系数6、普通18、侧滑角限制40度。松开方向后有0.22秒收正过渡，再转入直线制动。
弹射期间继续转向仍有推力；奖励目标不会低于普通全油门目标，最大9.45。临时速度结束后平滑回到9。
史莱姆滚动时加速度提高20%，替代旧的距离蓄速加成；保留滚动减伤和转弯保速。南瓜吞噬按车头而不是侧滑或倒车方向判断。

AI使用同一套油门/方向盘/刹车。移除四角巡航，改为拾糖、撞箱、接战、躲避、内圈重新选位和倒车脱困。每0.25秒评估，目标保持最少0.8秒（危险可打断）；无进展3秒或追击6秒后暂时屏蔽目标4秒。使用按车体半径扩张障碍的网格路线、三条前方射线和0.25—1秒的短期截击预测。

## 参数与验证
驾驶参数在 `scripts/game_tuning.gd`；角色参数在 `config/vehicles/`。设计说明见 [驾驶与AI](docs/driving-v2.md)。

Godot --headless --path . --fixed-fps 60 --script res://tests/test_runner.gd
Godot --headless --path . --fixed-fps 60 --script res://tests/vehicles.gd
Godot --headless --path . --fixed-fps 60 --script res://tests/regressions.gd
Godot --headless --path . --script res://tests/driving.gd
Godot --headless --path . --script res://tests/ai_behavior.gd
Godot --headless --path . --fixed-fps 60 --script res://tests/ai_soak.gd
Godot --headless --path . --fixed-fps 60 --script res://tests/maneuver_soak.gd

`brake_burst.gd` 兼容入口转到新驾驶测试，不是额外独立测试。`driven_distance` 仅保留为历史兼容统计，不再决定速度。漂移采用街机受控侧滑，非轮胎/悬架物理。自动测试不能替代真人手感调校。
