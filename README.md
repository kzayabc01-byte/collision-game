# 不给糖就撞：开始界面与选人 UI 整合版

以最新整理后的源工程为基础，接入开始界面、三种座驾选择、对局及返回流程。双击 `play.cmd` 启动。小马、南瓜、史莱姆均已接入 Blender 模型、选车预览和正式对局，第四张卡片为敬请期待。

2026-11-10：已接入约 9.87 秒的开场视频（保留原声）。每次启动播放一次；播完或跳过后，开始界面立即淡入 MP3 的有声段并循环。源 MP3 开头有约 9.89 秒静音，首次播放与循环均跳过，实际音乐每轮约 46.3 秒。进入选车时音乐淡出，返回开始界面重新播放音乐且不重播片头。素材与修改入口见 [片头与音乐](assets/cinematics/README.md)。

2026-11-09：补齐小马灯笼车厢、小轮、点头拾糖，以及史莱姆巫师帽、渐变胶体、小脚走路、收帽团球翻滚。双击 `vehicles.cmd` 查看三车与动画。可编辑源文件位于 `art_source/pony.blend`、`pumpkin.blend`、`slime.blend`；维护与验证见 [三车模型交接](docs/three-car-art.md)。

2026-11-08：南瓜美术样板与吞噬动画已接入。双击 `pumpkin.cmd` 可近距离查看、拖动旋转、按空格吞车，或进入能力试验。可编辑 `.blend`、导出的 `.glb`、Godot 动画轨道及维护步骤见 [南瓜模型交接](docs/pumpkin-art.md)。

完整接入说明见 [UI 接入](docs/ui-integration.md)，验证记录见 [UI 验证](docs/validation-ui.md)。

# 不给糖就撞：驾驶与 AI V2

## 启动与操作
双击 `play.cmd`，或用 Godot 导入 `project.godot`。本次验证使用 Godot 4.7.2。本机启动器优先使用原 D 盘路径，找不到时使用 E:/jam game/godot 下的 4.7.2。

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
竞技场目录、糖屋/教堂节点、接口原理及编辑器复现步骤见 [场景框架说明](docs/arena-scenes.md)。建筑目前只接入视觉占位，没有新增玩法。

驾驶参数在 `scripts/game_tuning.gd`；角色参数在 `config/vehicles/`。设计说明见 [驾驶与AI](docs/driving-v2.md)。

Godot --headless --path . --fixed-fps 60 --script res://tests/test_runner.gd
Godot --headless --path . --fixed-fps 60 --script res://tests/vehicles.gd
Godot --headless --path . --fixed-fps 60 --script res://tests/regressions.gd
Godot --headless --path . --script res://tests/driving.gd
Godot --headless --path . --script res://tests/ai_behavior.gd
Godot --headless --path . --fixed-fps 60 --script res://tests/ai_soak.gd
Godot --headless --path . --fixed-fps 60 --script res://tests/maneuver_soak.gd

`brake_burst.gd` 兼容入口转到新驾驶测试，不是额外独立测试。`driven_distance` 仅保留为历史兼容统计，不再决定速度。漂移采用街机受控侧滑，非轮胎/悬架物理。自动测试不能替代真人手感调校。
