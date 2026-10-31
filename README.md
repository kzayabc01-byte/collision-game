# 不给糖就撞 原型

本工程是 Godot 4.4.1 验证过的 3D 俯视单机原型。1 名玩家与 3 个 AI 进行 180 秒糖果争夺；当前版本用几何模型、程序生成的短音效和纸屑粒子验证玩法。原有策划文档无需移动或修改。

## 启动

- 本机双击 `play.cmd` 开始游戏，双击 `edit.cmd` 打开编辑器。这两个入口使用本机已安装的 `E:\jam game\godot\Godot_v4.4.1-stable_win64.exe`，不存在时自动尝试 console 版本。
- 也可以在 Godot 中导入本目录的 `project.godot`，按 F5 运行。
- 换电脑时用 Godot 4.4 或更新版本打开 `project.godot`；本项目未使用外部插件或下载依赖。

操作：WASD / 方向键 / 手柄左摇杆移动；松开减速；Esc 暂停或继续；R 重新开始。绿色圈标出玩家。试玩 HUD 显示糖果、质量、尺寸、速度、排名和剩余时间。

## 项目架构

```text
project.godot
scenes/
  match.tscn             主场景：比赛流程、4 辆实例化车辆、相机、HUD
  arena.tscn             编辑器里摆好的场地、固定墙、16 个糖箱和出生点
  car.tscn               玩家与 AI 共用的车辆节点结构
  ai_car.tscn            继承车辆场景，只替换 Driver 脚本
  solid_wall.tscn        不可破坏墙体
  candy_obstacle.tscn    可撞碎糖箱，独立模型/碰撞体/爆糖位置/粒子
  candy.tscn             糖果外观、拾取区域和合并数量标签
  hud.tscn               可编辑的调试界面、暂停和结算面板
scripts/
  match.gd               对局、重生、中立糖果、最终排名
  car.gd                 车辆运动、糖果状态、质量与尺寸
  drive_input.gd         输入控制接口
  player_driver.gd       玩家输入
  ai_driver.gd           拾取、外圈蓄速、择机撞箱、躲避与追逐
  collision_math.gd      不依赖场景的数值公式
  collision_resolver.gd  撞前快照、接触去重、双方扣糖和障碍结算
  candy_system.gd        糖果生成、容量控制、批次生命周期
  candy.gd               抛出、弹跳、拾取保护、消失和拾取动画
  car_feedback.gd        车辆形变、纸屑、尾迹和音效
  camera_rig.gd          可关闭的撞击震动
  hud.gd                 界面显示与按钮事件
  game_tuning.gd         Inspector 参数定义
config/prototype.tres    当前测试参数
assets/                  图标和场地网格材质
tests/                   数值、实际物理、控制和整局自动测试
```

```text
Car (CharacterBody3D)
├── BodyCollision
├── GrowthRoot                   成长尺寸
│   └── HitPivot                 撞击挤压
│       └── Model                可替换的模型
├── PlayerRing
├── NameLabel
├── Driver                       玩家 / AI 控制器
├── AnimationPlayer
└── Feedback
    ├── PaperParticles
    ├── SpeedTrail
    └── Sound
```

固定地图、车辆、界面、碰撞形状和表现节点均保存在 `.tscn`，不是运行时用脚本拼装。运行时只实例化数量动态变化的糖果场景。没有全局单例，重新开始会完整重载本局状态。

车辆采用 `CharacterBody3D` 的扫掠碰撞检测；统一结算器按质量计算街机式反弹和伤害，以精确实现撞墙减速 5% 与撞碎后继续前进。它不是真实轮胎/悬挂模拟。物理根节点不做成长缩放，独立调整每辆车自己的碰撞形状，模型在 `GrowthRoot` 上平滑缩放。

## 已采用的规则

| 项目 | 当前值 |
|---|---|
| 初始糖果 | 20 |
| 基础 / 最高速度 | 3 / 9 |
| 蓄速 | 实际主动行驶距离驱动，系数 L=18；转向、顶墙、被推不计蓄速 |
| 转向 | 累计转 90° 保留 85% 速度；明显转向期间暂停提速 |
| 质量 | `0.5 + 0.025 × 糖果数` |
| 尺寸 | `clamp(sqrt(糖果数 / 20), 0.5, 2.2)`，倍率指车身线性尺寸 |
| 车对车伤害 | 相对接近速度、约化质量和双方主动冲撞能力；系数 k=1 |
| 单次伤害上限 | 仅以现有糖果数为限；已取消 35% 上限，可一撞清空 |
| 撞墙 | 速度保留 95%；掉落 `floor(糖果数 × 5%)` |
| 糖箱 | 正面冲击能量 `0.5 × 质量 × 法线速度² ≥ 22.5` 撞碎；只产糖一次 |
| 糖箱奖励 | 12；成功撞碎时仍扣自身 5% 糖果和速度，但不反弹 |
| 连续接触 | 分离后才重新允许伤害；同一对接触还需间隔 0.5 秒 |
| 散落糖果 | 8 秒消失，原主人前 0.5 秒不能捡；其他车可抢 |
| 爆糖表现 | 按损失比例区分三档；主方向 70%，其余随机；落地弹跳、拾取飞入 |
| 数量上限 | 最多 240 个糖果节点；合并时保留总价值与各批次保护/寿命 |
| 重生 | 3 秒后寻找空闲出生点；恢复 20 颗，清除速度、蓄速、接触和旧形变 |
| 比赛结束 | 完成本物理帧后固定成绩，同糖数量并列获胜 |

30 颗、速度 6 正面撞糖箱可以破坏。拾完糖箱奖励且暂不收回自己的掉糖时，连续增长为 `30 → 41 → 51 → 61`。两辆初始车中，A 以速度 9 撞静止 B，A 掉 4 颗、B 掉 20 颗；两车满速正面对撞可同时出局。

## 在编辑器中修改

所有平衡参数集中在 `config/prototype.tres`。选择资源，在 Inspector 中展开 Driving、Candy and growth、Impact、Round、Drops 修改。资源只存配置，当前糖果和速度存在每辆车自己的实例中。

- 改布局：打开 `scenes/arena.tscn`，移动或复制 `SolidWalls` / `CandyObstacles` 下的场景实例。
- 改初始位置：调整 `scenes/match.tscn` 中 `Vehicles` 下实例的位置。重生位置独立存放在 `arena.tscn` 的 `VehicleSpawnPoints`。
- 改出生点和中立糖位置：移动对应 Marker3D。移动地图边界时还需同步 `ai_driver.gd` 的外圈路径与 `candy.gd` 的场内限制；本原型按固定 40×28 场地制作。
- 替换车辆素材：在 `car.tscn` 的 `GrowthRoot/HitPivot/Model` 下放入自己的模型。模型前方朝 -Z、底部贴 y=0。保留 `GrowthRoot`、`HitPivot`、碰撞和 Driver 等功能节点。
- 换模型后调整根节点 Inspector 的 `paint_mesh_paths`，选择需要着色的网格；留空即可保留导入模型原材质。失效路径会安全跳过。
- 替换障碍素材：修改各障碍场景的 `VisualRoot`，并调整 `BodyCollision`。墙体是灰色固定物，糖箱是金色礼盒占位素材。
- 爆糖位置预留 `CandySpawn` Marker3D；实际逻辑使用该位置的平面坐标，飞行高度由三档散射参数控制。
- 关闭镜头震动：选择主场景的 `CameraRig`，取消 `shake_enabled`。

## 验证

在 PowerShell 中，先将 `$godotExe` 设为你实际的 Godot 程序路径，再运行：

```powershell
$godotExe = 'E:/jam game/godot/Godot_v4.4.1-stable_win64_console.exe'
& $godotExe --headless --path . --import
& $godotExe --headless --path . --script res://tests/test_runner.gd
& $godotExe --headless --path . --fixed-fps 60 --script res://tests/driving.gd
& $godotExe --headless --path . --fixed-fps 60 --script res://tests/soak.gd
```

测试失败返回非零退出码。整局测试将 180 秒模拟时间加速运行；实际游戏仍使用正常时间。正式素材、联网、复杂导航和完整无文字教学不在这版原型内。
