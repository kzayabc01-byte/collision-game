# 竞技场、糖屋与教堂场景说明

> 2026-11-11：此页记录旧版场景整理。当前地图已换成 [参考图布局](reference-arena.md)，教堂、糖屋源文件保留，但不再实例化到当前竞技场。

日期：2026-11-04。本轮范围：归拢竞技场文件，建立糖屋和教堂的独立节点框架，摆放视觉占位，记录未来连接约定。用户已确认是“糖屋（糖果房屋）”。

## 1. 当前结构，以及为什么会套几层

Godot 的节点是一个有名字、承担一种职责的对象。例如 `MeshInstance3D` 显示一个三维形状，`Marker3D` 记录一个位置。`.tscn` 场景文件保存一棵节点树，也能包含其他场景的实例。

“实例”可以理解为把一份场景装配到另一份场景里。修改糖屋的源场景，引用它的布景就能使用修改后的糖屋；布景仍可单独决定每栋糖屋放在哪里。

目录是磁盘上的分类，节点树是运行时的装配关系。移动文件不等于给节点再套一层。本轮保留 `Match/Arena/Ground`、`Match/Arena/SolidWalls`、车辆出生点等现有路径，因为镜头、比赛逻辑正在读取它们。

```text
scenes/
├─ match.tscn                       整局比赛入口：装配地图、车辆、镜头、HUD和系统
├─ maps/
│  └─ arena/
│     ├─ arena.tscn                 竞技场：地面、灯光、围墙、障碍、出生点、布景
│     ├─ arena_scenery.tscn         建筑排版：决定糖屋、教堂放在哪里
│     ├─ buildings/
│     │  ├─ candy_house.tscn        糖屋本体：外观、空容器、位置标记
│     │  └─ church.tscn             教堂本体：外观、空容器、位置标记
│     └─ props/
│        ├─ solid_wall.tscn         原有不可破坏墙
│        └─ candy_obstacle.tscn     原有可撞碎礼盒；不是糖屋
├─ vehicles/                       现有三种车型及各自外观
├─ car.tscn                        现有基础车辆，被三种车型复用
├─ ai_car.tscn                     现有通用AI车辆场景
├─ vehicle_showcase.tscn           现有三车展示入口
├─ candy.tscn                      现有可拾取糖果
├─ hud.tscn                        现有比赛界面
└─ tests/painted_ground_test.tscn   已有地面材质试验，保持原位
```

本轮只归拢竞技场。基础车辆、车辆展示、HUD、糖果及脚本目录没有搬迁；三种车型仍在原来的 `vehicles/`。地图资源使用 `assets/` 中的已有材质/着色器，不因场景搬家复制资源。

运行时的主要装配关系如下：

```text
Match                             scenes/match.tscn
├─ Arena                          maps/arena/arena.tscn 的实例
│  ├─ WorldEnvironment / Sun       原有环境与灯光
│  ├─ Ground / CenterRing          原有地面与中心圈
│  ├─ SolidWalls                   原有围墙及两根柱
│  ├─ CandyObstacles               原有16个礼盒
│  ├─ VehicleSpawnPoints          原有车辆出生点
│  ├─ CandySpawnPoints            原有中立糖果生成位置
│  └─ Scenery                      arena_scenery.tscn 的实例（本轮新增）
│     └─ Buildings
│        ├─ CandyHouse             candy_house.tscn 的实例
│        └─ Church                 church.tscn 的实例
├─ Vehicles                       原有四辆车
├─ CollisionResolver              原有碰撞结算
├─ CandySystem                    原有糖果系统
├─ CameraRig                      原有镜头
└─ HUD                            原有比赛界面
```

这几层分别解决“比赛装配、地图内容、建筑排版、单栋建筑”的问题。以后改教堂模型不用修改比赛系统；移动整栋教堂只需改布景内的教堂实例。当前没有额外建立建筑内部场景。

## 2. 两栋建筑已经建了什么

两栋建筑具有相同的挂载节点和标记名称，方便以后使用同一种连接方式：

```text
CandyHouse 或 Church              Node3D，地面中心为原点，正门朝本地 +Z
├─ VisualRoot                     Node3D，外观容器
│  ├─ Placeholder                 Node3D，临时体块的总开关
│  │  ├─ Base                     MeshInstance3D，薄底座
│  │  ├─ Body                     MeshInstance3D，建筑主体
│  │  ├─ RoofLeft / RoofRight     MeshInstance3D，两块斜放的屋顶
│  │  ├─ Tower / TowerCap         MeshInstance3D，仅教堂有的塔楼体块
│  │  ├─ Door                     MeshInstance3D，正门方向示意
│  │  └─ NameLabel                Label3D，建筑名称与“占位”提示
│  └─ ModelRoot                   Node3D，空，留给正式模型
├─ CollisionRoot                  Node3D，空，留给以后确定的碰撞结构
├─ EffectsRoot                    Node3D，空，留给粒子等表现
└─ Sockets                        Node3D，位置标记分类
   ├─ EntrancePoint               Marker3D，门前地面参考位置
   ├─ FocusPoint                  Marker3D，建筑焦点参考位置
   └─ EffectsPoint                Marker3D，特效参考位置
```

所有新增节点都保存在 `.tscn` 中。没有新增脚本，没有在运行时拼装建筑，也没有代码绘图。占位外观由场景内的 `BoxMesh` 资源构成；颜色来自场景内的 `StandardMaterial3D`；名称文字直接来自 `NameLabel.text`。没有新增共享主题或共享材质，改糖屋的材质不会同时改教堂。

根节点和主要空节点写了 `editor_description`，在检查器的 Node 描述属性中可查看用途。它是给编辑者读的说明，不是程序执行指令。

糖屋主体暂定 8×4×6，教堂主体暂定 8×5×10，教堂塔楼高8，单位均为项目中的三维单位。这些只是可调体块尺寸，不是最终美术要求。糖屋摆在 `(-18, 0, -35)`，教堂摆在 `(18, 0, -36)`，在北侧围墙外；两者都朝 +Z，也就是朝竞技场方向。

这些建筑是比赛边界外的视觉占位，不占用车辆活动路线。原有地面并未向建筑下方扩建；薄底座仅用于体块展示。主镜头跟随玩家并限制在原竞技场范围内，因此日常试玩不保证能看到两栋建筑全貌；请在编辑器打开竞技场查看整体布景。

**已接入：**竞技场加载布景、布景加载两栋建筑、编辑器和运行时加载视觉占位。

**未接入：**建筑物理碰撞、车辆检测、交互、进门、室内、跳转、奖励、破坏、动画、声音、特效、镜头聚焦。`CollisionRoot` 只是普通 `Node3D`，不是实际碰撞体；`EntrancePoint` 也不是触发区。糖屋没有复用礼盒脚本，不会因为名字带“糖”就自动产糖。

## 3. “留接口”究竟是什么意思

接口的核心是双方先约好：通过什么入口交流、传什么内容、谁来处理。例如美术与程序约好“正式模型放进 `VisualRoot/ModelRoot`，门口位置读 `Sockets/EntrancePoint`”，以后就不用猜模型里的哪一块是门。

接口没有统一的外形。它可以是节点路径、位置标记、脚本函数、信号或可编辑参数。本轮实际建立的是“挂载位置和空间位置约定”，还没有实现建筑的行为接口。

| 形式 | 本项目中的例子 | 发生了什么 |
|---|---|---|
| 节点挂载位置 | 本轮的 `VisualRoot/ModelRoot` | 美术把正式模型放在约定节点下面，外部结构可保持稳定 |
| 位置标记 | 本轮的 `Sockets/EntrancePoint` | 保存门前的位置；将来脚本可读取它的世界坐标 |
| 函数 | 现有 `CandySystem.spawn_drop(...)` | 调用方主动提出一次生成糖果请求，糖果系统根据参数执行 |
| 信号 | 现有 HUD 的 `restart_requested` | HUD 发出“请求重开”的通知，比赛脚本连接到 `restart` 后处理 |
| 可编辑参数 | 现有 `@export var tuning` | 在检查器指定规则资源，脚本读取这份配置 |

### 从“有标记”到“真的工作”还差哪一步

假设以后要让一个特效出现在门前，需要按以下顺序完成：

1. 建筑提供 `Sockets/EntrancePoint`，美术在编辑器把它摆在正确位置。这一步本轮已做。
2. 负责特效的脚本拿到这栋建筑的引用，再取得这个标记。
3. 某个明确事件触发后，特效脚本读取标记的 `global_position`（世界坐标），创建或移动特效。
4. 运行并检查特效的位置是否正确。移动建筑或旋转建筑后也要检查。

下面是说明原理的示例，**没有加入任何项目脚本**：

```gdscript
# building 是调用方已经拿到的那栋建筑。
var point := building.get_node("Sockets/EntrancePoint") as Marker3D
effect.global_position = point.global_position
```

标记负责“位置在哪里”，调用方负责“什么时候发生、生成什么”。如果没有第二、三步，就只是一个静止的位置记录。使用世界坐标是因为建筑本身可能被移动、旋转，标记在建筑内部的局部位置不会等于它在整张地图里的实际位置。

### 如果是你亲手设计接口

先写一句明确需求，例如“粒子要从门前冒出来”。然后确定由建筑提供门前位置、由特效系统决定何时播放，给位置统一起名 `EntrancePoint`，创建对应标记，并记录它的用途、朝向和坐标含义。到真正开发该功能时，再由调用方读取标记并验证。

如果以后要“按键进入建筑”，只有这个标记还不够：还需要确定接近检测、输入、进入条件、目标场景和过渡方式，再设计相应参数、函数或信号。当前规则尚未确定，因此本轮没有创建空的 `enter()` 函数或场景切换信号。

现有 HUD 是一个完整的事件接口案例：`scripts/hud.gd` 声明 `restart_requested`，按钮按下时发出它；`scripts/match.gd` 通过 `hud.restart_requested.connect(restart)` 连接处理函数；最后 `restart()` 执行重开。声明通知、发出通知、连接处理、执行行为，这些环节共同让接口工作。本轮没有改这部分。

节点路径也是约定，改名会影响以后按路径查找的代码。目前没有脚本使用建筑标记，所以现在仍适合调整框架；功能接入后，改名就需要同步修改调用方。文件夹移动修改的是 `res://...` 资源路径；节点改名修改的是 `Sockets/EntrancePoint` 这类节点路径，两者不要混淆。

## 4. 在 Godot 里怎样亲手复现

### 整理竞技场目录

1. 在左下方“文件系统”面板找到 `res://scenes`，右键新建文件夹 `maps`，在其中建立 `arena`，再建立 `props` 和 `buildings`。
2. 在 Godot 的“文件系统”面板内，把原 `arena.tscn` 移入 `maps/arena`，把 `solid_wall.tscn` 和 `candy_obstacle.tscn` 移入 `props`。在编辑器内移动便于 Godot 更新它掌握的引用；如果显示更新依赖提示，确认更新。
3. 搜索旧的三个 `res://scenes/...` 路径，检查 `match.tscn`、`tests/test_runner.gd`、`tests/vehicles.gd` 等文本引用是否全部同步。脚本里的字符串不能只靠拖文件后就假设全部改好了。
4. 打开 `match.tscn`，确认 `Arena` 实例及其地面、墙和出生点仍能加载。保持既有节点名称和父子关系。

上述是从本轮修改前复现的方法；当前文件已经移动完，不需要重复操作。

### 新建糖屋节点

1. 顶部选择“场景 → 新建场景”，选择“3D 场景”，将根节点改名为 `CandyHouse`，按 Ctrl+S 保存到 `scenes/maps/arena/buildings/candy_house.tscn`。
2. 在左侧场景树选中根节点，按 Ctrl+A 添加 `Node3D`，命名为 `VisualRoot`。选中 `VisualRoot`，分别添加 `Placeholder`、`ModelRoot` 两个 `Node3D`。它们应当是兄弟节点，不要把正式模型容器放进占位容器里。
3. 选中 `Placeholder`，添加 `MeshInstance3D`，命名 `Body`。在右侧检查器的 `Mesh` 下拉框选择“新建 BoxMesh”，展开资源，将 `Size` 设为 `(8, 4, 6)`。
4. 保持选中 `Body`，在检查器展开 `Transform → Position`，设为 `(0, 2, 0)`。盒子的中心在中间，把它抬到半高，底面才会落在地面上。
5. 在 BoxMesh 资源的 `Material` 处新建 `StandardMaterial3D`，展开 `Albedo → Color` 选占位色。需要不同颜色时使用不同材质资源。
6. 在 `Placeholder` 下继续添加底座、门和左右屋顶的 `MeshInstance3D`。屋顶用两块薄 BoxMesh；糖屋每块尺寸 `(4.7, 0.35, 7)`，位置分别为 `(-2, 4.85, 0)`、`(2, 4.85, 0)`。检查器的旋转以角度显示，分别将 `Rotation Degrees → Z` 设为约 `22.92`、`-22.92` 度。
7. 在 `Placeholder` 下添加 `Label3D`，命名 `NameLabel`。检查器中设置 `Text` 为“糖屋 · 占位”，`Position` 为 `(0, 6.6, 0)`，`Font Size` 为64，`Pixel Size` 为0.01；把 `Billboard` 设为 Enabled，使文字面向观察方向。
8. 回到根节点，添加三个 `Node3D`，分别命名 `CollisionRoot`、`EffectsRoot`、`Sockets`。前两个先留空。
9. 选中 `Sockets`，添加三个 `Marker3D`，命名 `EntrancePoint`、`FocusPoint`、`EffectsPoint`。在各自的 `Transform → Position` 设置 `(0, 0, 4)`、`(0, 2.5, 0)`、`(0, 3, 3.2)`。编辑器能看到标记，游戏运行时标记本身不会绘制成建筑或触发区。
10. 按 Ctrl+S。选中 `Body` 后，在三维视图按 F，可让编辑器聚焦到它，方便检查体块。

教堂按相同方法另建 `Church` 场景，保持挂载节点和标记名称一致。主体尺寸设为 `(8, 5, 10)`，位置 `(0, 2.5, 0)`；另加塔楼和顶盖体块。精确尺寸和位置可查看 `church.tscn` 及其检查器，本轮没有制作最终建筑造型。

### 把建筑摆到竞技场

1. 新建3D场景，根节点命名 `ArenaScenery`，保存为 `scenes/maps/arena/arena_scenery.tscn`。根下添加 `Node3D`，命名 `Buildings`。
2. 从“文件系统”面板把两个建筑场景分别拖到场景树的 `Buildings` 上，生成建筑实例。
3. 在场景树选中糖屋实例，在检查器设置 `Transform → Position` 为 `(-18, 0, -35)`；选中教堂实例，设置为 `(18, 0, -36)`。
4. 保存布景，打开 `arena.tscn`，把 `arena_scenery.tscn` 拖到竞技场根节点下，将该实例命名为 `Scenery`，位置保持 `(0, 0, 0)`。
5. 双击建筑源场景编辑建筑内部；在布景场景编辑建筑整体摆放。通常不需要把实例“设为本地”或拆开，这样能保留对子场景的引用。
6. 在竞技场三维视图中选中建筑实例按 F 查看。当前布景和单栋建筑没有独立运行镜头、灯光或预览脚本，按 F6 不会自动获得完整展示画面；用竞技场的编辑器视图查看即可。

### 下一步替换模型

1. 先在编辑器确认体块大小、门朝向、建筑距离和俯视轮廓。建筑与玩法区的关系还可继续讨论，此时无需急着完成精细模型。
2. 若体量方向认可，在 Blender 中先做低细节模型。导出时约定地面中心为原点、Y向上，进入 Godot 后门朝 +Z。糖屋主体可先按8宽、4高、6深制作；教堂按现有体块对齐。不同软件导出后务必实测方向和比例。
3. 源模型和导出资源以后可另建 `assets/models/buildings/` 管理。本轮没有创建这组资产目录或模型文件。
4. 把 `.glb` 放入项目，等待 Godot 导入。打开糖屋源场景，在场景树选中 `VisualRoot/ModelRoot`，从文件系统把模型拖到这个节点下。
5. 选中 `VisualRoot/Placeholder`，在右侧检查器 `Visibility → Visible` 取消勾选，整体关闭临时体块和占位标签。不要隐藏 `VisualRoot`，否则正式模型也会一起隐藏。
6. 在 `ModelRoot` 下调整模型偏移、旋转和比例，使模型对齐地面中心及门前标记，然后保存。回到竞技场检查地图中的效果。
7. 模型负责“看起来是什么”。实体阻挡要另外添加物理节点和形状，交互要另外接事件；建模完成不代表这些功能已完成。先确定建筑是否只是背景、能否接近、能否进入，再安排相应功能。

如果未来只是背景摆设，可能始终不需要碰撞或进门功能。预留空节点并不要求将来全部使用。

## 5. 本轮文件清单

| 操作 | 文件 | 用途和具体变化 |
|---|---|---|
| 移动并修改 | `scenes/arena.tscn` → `scenes/maps/arena/arena.tscn` | 竞技场归入地图目录；墙和礼盒改为新路径；增加布景资源及 `Scenery` 实例；保留所有原有节点和参数 |
| 移动并加说明 | `scenes/solid_wall.tscn` → `scenes/maps/arena/props/solid_wall.tscn` | 归拢墙场景，加编辑器用途说明；原有物理、脚本和外观参数不变 |
| 移动并加说明 | `scenes/candy_obstacle.tscn` → `scenes/maps/arena/props/candy_obstacle.tscn` | 归拢礼盒场景，加说明区分礼盒与糖屋；原有破坏和产糖设置不变 |
| 新建 | `scenes/maps/arena/arena_scenery.tscn` | 两栋建筑的摆放层，通过实例引用各自源场景 |
| 新建 | `scenes/maps/arena/buildings/candy_house.tscn` | 糖屋独立框架、可编辑占位体块、挂载容器、三个位置标记 |
| 新建 | `scenes/maps/arena/buildings/church.tscn` | 教堂独立框架、可编辑占位体块和塔楼、挂载容器、三个位置标记 |
| 修改 | `scenes/match.tscn` | 只把竞技场资源引用改为新路径；未改车辆、系统、镜头和 HUD 节点 |
| 修改 | `tests/test_runner.gd` | 只同步墙、礼盒两个场景的预加载路径；测试内容未改 |
| 修改 | `tests/vehicles.gd` | 只同步车辆撞墙测试使用的墙资源路径；测试内容未改 |
| 修改 | `README.md` | 增加本说明的入口，标明建筑仅接入视觉占位 |
| 新建 | `docs/arena-scenes.md` | 本说明：场景梳理、节点职责、接口解释、手动复现、文件清单及验证结果 |

没有修改 `project.godot`、任何 `scripts/*.gd`、车辆场景、HUD、规则资源，也没有修改已有手绘地面相关未提交文件。原三个场景文件已经移动，旧路径不再保留第二份，避免以后编辑错副本。

验证的缓存、日志和临时预览产物使用被 Git 忽略的 `test-results/arena-scaffold/`；Godot 项目缓存使用已有 `.godot/`。它们不属于新的游戏功能文件。

## 6. 验证记录

使用本机 Godot 4.7.2 完成以下验证：

| 检查 | 结果 |
|---|---|
| 无界面编辑器导入项目 | 退出码0，场景和脚本导入完成 |
| `tests/test_runner.gd` | 55项通过，0项失败；覆盖现有规则、碰撞、礼盒破坏、暂停、重生和重开 |
| `tests/vehicles.gd` | 55项通过，0项失败；覆盖车型、技能和选择流程 |
| 默认主场景启动10帧 | 退出码0，最终日志无错误 |
| 临时结构检查 | 两栋建筑各自所需挂载节点和标记齐全；无脚本、无碰撞对象；模型和碰撞容器仍为空 |
| 原地图结构数量 | 仍有6个墙/柱实例、16个礼盒、6个车辆出生标记、3个中立糖果标记 |
| 实际三维渲染 | 已生成并查看 `test-results/arena-scaffold/preview.png`，两栋建筑可见，位于北侧围墙外 |

临时预览脚本 `test-results/arena-scaffold/preview.gd` 仅用于结构检查、加临时镜头和截图，不被正式场景引用；同目录 `.gdignore` 避免编辑器把这些验证工具当游戏资源扫描。`core.log`、`vehicles.log`、`main.log`、`preview.log` 分别记录最终测试和预览结果。预览使用临时镜头，不代表已经修改正式比赛镜头。

本次执行环境限制写入用户系统目录，所以验证进程的 Godot 用户数据重定向到 `test-results/arena-scaffold/appdata/`；初次默认目录写入报错已通过此方式解决。日志参数最终使用本机绝对路径，修正首次使用 `res://` 日志路径引起的目录错误。没有为此改动项目设置或用户的全局 Godot 配置。

如果你在正常桌面环境亲手验证，从项目目录启动 Godot，执行已有测试即可：

```powershell
& 'D:/TA and personal presentation/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --fixed-fps 60 --script res://tests/test_runner.gd
& 'D:/TA and personal presentation/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --fixed-fps 60 --script res://tests/vehicles.gd
```

以上验证不代表建筑玩法已实现，也未检查正式模型、贴图或建筑交互效果，因为它们尚未制作或接入。
