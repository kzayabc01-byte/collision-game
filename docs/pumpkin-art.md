# 南瓜车美术样板与吞噬动画

日期：2026-11-08。使用 Blender 4.5.4 LTS 建模，Godot 4.7.2 Compatibility 验证。

这是参考图方向的第一辆完整样板：圆润分瓣壳体、真实口腔、可转动下颚、四个小轮、卷曲藤蔓、叶子、悬挂灯笼、口内糖果。材质是可编辑的基础色、粗糙度、金属度与发光材质；目前没有手绘纹理，视觉仍可进一步打磨。2026-11-09 小马与史莱姆也已完成同一流程，见 [三车模型交接](three-car-art.md)。

## 立即查看

- 双击根目录 `pumpkin.cmd`，首次会先导入模型。拖动空白处转动镜头，空格/按钮播放真实吞车过程，R 重置。
- “进入能力试验”打开现有南瓜 F2 场景。车辆数值、吞噬条件、驾驶和地图都使用工程当前版本。
- 正常 `play.cmd` 的选车界面选择南瓜，可见可旋转模型；进入对局后使用同一外观。
- Godot 打开 `scenes/pumpkin_studio.tscn`，F6 可运行预览。

## 文件与所有权

| 文件 | 修改内容 |
|---|---|
| `art_source/pumpkin.blend` | Blender 主源文件，100 个模型对象，保留单独叶子、藤蔓、轮件、灯笼等；附独立摄影棚 |
| `assets/models/pumpkin/pumpkin.glb` | 游戏导出，合并静止部件后 18 个对象，9 个网格节点，四轮和下颚仍独立 |
| `assets/models/pumpkin/pumpkin_animations.tres` | Godot 可直接编辑的 `swallow` 与 `RESET` 动画库 |
| `assets/models/pumpkin/model_info.json` | 模型统计，当前约 56,332 个三角形，不含摄影棚 |
| `scenes/vehicles/pumpkin_visual.tscn` | 视觉包装场景：GLB、动画播放器、嘴部/拾取/尾迹挂点 |
| `scenes/pumpkin_studio.tscn` | 独立检查场景、灯光、镜头和操作按钮 |
| `config/selection/pumpkin.tres` | 选车预览的模型、尺寸、朝向 |
| `art_source/build_pumpkin.py` | 初始建模过程记录；手工修改 .blend 后不要重跑它覆盖修改 |
| `art_source/extract_pumpkin_animation.gd` | 从重新导出的 GLB 提取外部动画库；只在有意覆盖动画库时执行 |

`art_source/.gdignore` 防止 Godot 自动导入整个 Blender 摄影棚。游戏只使用 GLB，不依赖 Blender 或建模脚本运行。基础色等材质已包含在 GLB 中，没有外部贴图路径依赖。

## 节点结构

```text
CharacterVisual
├─ Motion
│  └─ Model (pumpkin.glb，绕 Y 旋转 180°，使车头朝 Godot -Z)
│     ├─ PumpkinArt
│     │  ├─ BodyDeform
│     │  │  ├─ BodyDeformMesh
│     │  │  ├─ Jaw / JawMesh
│     │  │  └─ Vines / LanternSwing
│     │  ├─ PumpkinArtMesh
│     │  └─ WheelFL / WheelFR / WheelBL / WheelBR
│     └─ AnimationPlayer (GLB 原始片段，运行时不驱动)
├─ Sockets / MouthSocket / PickupSocket / TrailSocket
└─ AnimationPlayer (使用外部动画库，负责实际播放)
```

Blender 源文件内的静态零件保留独立对象，导出时才按运动部件合并。Godot 包装场景允许编辑实例子节点；改材质可使用材质覆盖，改网格回 Blender 主文件。避免重命名 BodyDeform、Jaw、Vines、LanternSwing 和四个 Wheel 枢轴；若需改名，要同步动画轨道与 Inspector 的路径。

## 吞噬时序

| 时间 | 表现 |
|---|---|
| 0—0.15 秒 | 下颚打开、壳体微胀、藤蔓蓄力 |
| 0.08—0.40 秒 | 目标外观跟随实时嘴部挂点飞入并缩小 |
| 0.43—0.57 秒 | 下颚咬合，车身鼓胀，灯笼滞后摆动 |
| 0.57—0.82 秒 | 回弹、恢复静止姿势 |

保留现有条件：正面接触，目标逻辑线性尺寸不超过自身 50%。确认吞噬时立刻结算一次并关闭目标碰撞；动画只处理外观。连续吞噬会重新开始张嘴阶段；重置/重生会取消飞入 Tween 并复位。目标先消失，下颚再完成闭合，避免目标被嘴穿过。

`swallow_pull_delay` 和 `swallow_pull_seconds` 在外观场景 Inspector 中控制飞入时段。下颚和轮子节点路径同样可编辑。碰撞体只由糖果体型控制，张嘴、鼓胀和藤蔓摆动都不修改它。

## 后续修改与导出

1. 用 Blender 打开 `art_source/pumpkin.blend`。源文件时间线 1—49 帧、60 fps；NLA 的 `swallow` 轨道在四个运动对象上共同组成一次动作。`RESET` 轨道在源文件中静音，以便直接播放吞噬。
2. 修改网格、材质或关键帧。保留轮心枢轴、下颚铰点与命名。另存文件后再做导出，防止丢失源文件。
3. 导出选中的 PumpkinArt 和所有子对象为 GLB，不包含 Studio 集合；启用动画，以 NLA Tracks 导出。替换 `assets/models/pumpkin/pumpkin.glb` 后让 Godot 重新导入。
4. 只改模型时，现有 `.tres` 动画库继续可用。改过 Blender 动画后，有意运行下面的提取命令，它会覆盖外部库；如果动画师已在 Godot 改过轨道，应先保留那份库并合并改动。

```powershell
$godotArt = 'E:\jam game\godot\Godot_v4.7.2-stable_win64_console.exe'
Set-Location 'C:\Users\Kzay\Desktop\suger'
& $godotArt --headless --editor --path . --import --quit
& $godotArt --headless --path . --script res://art_source/extract_pumpkin_animation.gd
& $godotArt --headless --path . --fixed-fps 60 --script res://tests/pumpkin_art.gd
& $godotArt --headless --path . --fixed-fps 60 --script res://tests/vehicles.gd
```

## 验收范围

新检查覆盖导出节点、四轮/下颚、动画轨道、5/20/80/135 糖四档体型、张嘴/咬合/RESET、物理根节点稳定、连续吞噬重播、中途重置与重复预览。原车辆检查继续覆盖吞噬去重、50% 条件、糖果转移及其他角色规则。

本次检查结果：南瓜动画 28 项、车辆 55 项、基础规则 55 项、回归 77 项、界面流程 48 项，共 263 项通过。静态场景检查 150 个文件，0 错误、0 警告。已实际渲染并查看 Blender 模型、Godot 吞噬关键帧和选车界面。源 .blend 已重新打开，确认 100 个分件与 NLA 动画轨道可用。

当前先服务桌面原型。大量同屏模型或移动端需要额外做网格、材质批次和真实设备性能预算，不能把这份近景样板直接当成已经完成的移动端优化资产。
