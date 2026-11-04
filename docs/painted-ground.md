# 可调的手绘色块地面

独立试验资源，未接入比赛地图。适用于 Godot 4 的 MeshInstance3D + PlaneMesh；无插件、外部噪声贴图或运行时控制脚本。

## 参考图取舍

参考地面以低饱和蓝灰色打底，灰紫、粉灰、灰绿色成片出现。色块有宽窄变化、凹凸轮廓和局部笔刷毛边；主要差异在色块之间，块内相对均匀。部分色块连成片，同时有较大的蓝灰留白。这里仅提取这套地面语言，不复现建筑、植物、石头、紫色照明或烛光。配色是对参考的视觉近似，未把受光后的截图颜色当作精确材质色值。

Shader 用低频噪声划分区域，坐标扰动打散规则轮廓，阈值把区域内部压成平色。较细的噪声只改变边界位置，不叠进内部颜色。三种辅色以窄过渡分区，不用连续噪声明暗制造云雾。默认不添加法线凹凸、动画、金属反射或自发光。

## 文件及实际引用

- `assets/shaders/painted_ground.gdshader`：spatial Shader，定义所有参数和地面绘制。
- `assets/materials/painted_ground.tres`：ShaderMaterial，引用上述 Shader，保存默认配色和形态参数。
- `scenes/tests/painted_ground_test.tscn`：独立测试场景，Ground 的 Material Override 引用上述材质。
- `docs/images/painted-ground-preview.png`：实际 Godot 渲染截图，非参考图或示意合成。

```text
PaintedGroundTest (Node3D)
├── WorldEnvironment    白色环境光、暗背景
├── KeyLight            白色方向光
├── Ground              MeshInstance3D，PlaneMesh 82×58
└── Camera3D            正交相机，向下俯视55°
```

这些节点、PlaneMesh 尺寸、相机位置和光照均保存在测试 `.tscn`，不会运行时创建。色块没有单独的场景节点，外观由 GPU 执行 Shader 绘制；美术可以直接调材质参数，也可在未来接入 Mask 指定留白位置，但无法像移动糖箱一样直接拖动某一个色块。

## 先打开现成场景

1. 在 Godot 左下方“文件系统”展开 `res://scenes/tests`，双击 `painted_ground_test.tscn`。
2. 切换顶部“3D”工作区；在左侧场景树选 `Ground`，鼠标移入视图后按 F 聚焦。
3. 在右侧检查器展开 GeometryInstance3D → Material Override，点击材质资源，再展开 Shader Parameters。可看到 Palette、Patches、Surface、DistributionMask 分组。也可以直接在文件系统中双击 `painted_ground.tres` 打开参数。
4. 先修改 Palette 下的 Rose Color，观察地面粉灰区域实时变色；再改 Patches 下的 Patch Scale，观察块的大小变化。Ctrl+S 保存材质。
5. 按 F6 运行当前测试场景。F5 会运行项目原来的比赛，比赛尚未引用这份材质。测试相机用于完整查看地板，周围少量暗框是场景背景。

若顶部没有“3D”，先检查“编辑器 → 管理编辑器功能”里的 3D 工作区是否被禁用。

编辑器里的材质参数会实时刷新。若游戏已经单独运行，修改磁盘材质后建议停止并重新按 F6；这里没有专门开发运行中的调参面板。

## 自己从空场景搭建

1. 场景菜单新建场景，选择“3D 场景”，根节点命名为 `PaintedGroundTest`。
2. 选根节点，Ctrl+A 添加 `MeshInstance3D`，命名 `Ground`。检查器 Mesh 下拉菜单 → 新建 PlaneMesh；点击 PlaneMesh，Size 设置 X=82、Y=58（这里表示地板在 X/Z 方向的长宽），Orientation 保持 Face Y，节点 Scale 保持 1、1、1。
3. 选 Ground，将文件系统中的 `painted_ground.tres` 拖入检查器 GeometryInstance3D → Material Override。可看到色块。
4. 根节点下添加 `DirectionalLight3D`，Rotation Degrees 设为 (-60, -25, 0)，Light Color 白色、Energy=0.8。
5. 添加 `WorldEnvironment`，Environment → 新建 Environment；Background Mode=Color，颜色用暗蓝灰；Ambient Light Source=Color、Color 白色、Energy=0.5。测试环境用中性光，方便判断材质本身的色相。
6. 添加 `Camera3D`，Transform → Position=(0, 58, 40.61)，Rotation Degrees=(-55, 0, 0)；Projection=Orthogonal、Size=54、Far=200，开启 Current。
7. 保存为一个新的 `.tscn`，按 F6 运行。

PlaneMesh 不需要碰撞体就能显示。未来接入可驾驶地图时，地面碰撞应另行保留或配置。

## 参数表

Inspector 会将下划线名称显示为空格分词。颜色参数的 Alpha 不参与混色，保持1即可。

| 参数 | 默认值 | 调整后的效果与建议 |
|---|---|---|
| Base Color | RGB (0.24, 0.29, 0.35) | 蓝灰底色，也决定无色块的平静区域。先定底色，再定辅色。 |
| Violet Color | RGB (0.30, 0.29, 0.36) | 灰紫区域颜色。 |
| Rose Color | RGB (0.34, 0.30, 0.35) | 粉灰区域颜色；避免调成鲜粉，以免抢过车辆。 |
| Sage Color | RGB (0.26, 0.32, 0.33) | 灰绿色区域颜色。 |
| Patch Scale | 8.5 | 大尺度噪声的世界单位尺度，不是每块精确直径。增大后块更大、数量更少；建议先试8～14。 |
| Coverage | 0.53 | 提高后出现更多、连通更广的色块；0时只显示底色。它是阈值控制，不等于精确面积百分比；建议0.42～0.60。 |
| Edge Softness | 0.010 | 提高后边缘过渡变宽；建议0.006～0.025。太大会出现雾状晕边，不能用于给内部增加纹理。 |
| Warp Strength | 0.35 | 增大后大轮廓更弯曲、拉伸，0时更规整；建议0.2～0.55，过高会形成扭曲条带。 |
| Edge Irregularity | 0.05 | 控制轮廓上的小凹凸和笔刷毛边；0更光滑，过大会长碎斑；建议0.025～0.065。 |
| Calm Amount | 0.28 | 提高后让一部分大范围区域更倾向保留底色。它不固定在地图中心；要精确指定位置可用Mask。 |
| Pattern Seed | 7 | 改变整体分布；固定值不会每次开局随机。选好布局后保持不变。 |
| Pattern Offset | (0, 0) | 在世界X/Z方向平移整个纹理，单位为米；不会移动网格。 |
| Surface Roughness | 0.95 | 越高越哑光，越低越光滑。 |
| Surface Specular | 0.12 | 高光强度，较低值避免地板像塑料。 |
| Use Distribution Mask | false | 关闭时完全不使用Mask；开启后白色允许现有色块，黑色只保留底色。 |
| Distribution Mask | 未指定，默认白色 | 可拖入黑白纹理；使用PlaneMesh的UV，完整图覆盖完整平面。它只裁减已有色块，不凭空增加色块。 |
| Mask Strength | 1 | 0不受Mask限制，1完全受Mask限制；中间值部分抑制。 |

地面坐标取世界 X/Z，因此更改 PlaneMesh Size 会露出更多图案，色块不会随平面尺寸自动拉大。这个版本面向水平地面；不作为任意方向墙面或斜坡的通用贴图方案。

## 人工调节顺序

先保持中性灯光，依次调底色和三个辅色 → Patch Scale → Coverage/Calm Amount → Warp Strength → Edge Irregularity/Edge Softness。最后再换到实际游戏光照判断颜色。一次只改一组，满意后保存材质。

- 像迷彩：先降低Coverage、减少颜色差异，再增大Patch Scale；不要继续堆细噪声。
- 边缘像融化或出现条带：降低Warp Strength。
- 像云雾：降低Edge Softness；内部始终应主要是平色。
- 色块太碎：降低Edge Irregularity，并增大Patch Scale。
- 需要让中心道路或战斗区固定留白：未来绘制一张黑白Mask，黑色画留白区，启用对应开关即可。

该 `.tres` 当前只由测试场景使用。以后复制一份材质再另存为新的 `.tres`，可让不同关卡独立调色；直接修改同一份材质会影响所有引用它的节点。当前游戏没有引用它。

## 验证记录

已在本机Godot 4.7.2、Compatibility/OpenGL渲染器实际运行并截图，未发现Shader编译错误。已验证覆盖率和尺度在运行时修改会改变输出；黑色Mask会恢复底色；关闭环境光和方向光后地面变暗，确认正常接受场景光照。尚未接入比赛地图，尚未做手机端性能验收。

官方接口参考：[spatial Shader与ALBEDO](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html)、[PlaneMesh](https://docs.godotengine.org/en/4.2/classes/class_planemesh.html)。
