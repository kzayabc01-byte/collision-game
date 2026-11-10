# 开始界面与选人 UI 接入

本版以 2026-11-04 接入时的 `D:/peng/collision-game-start` 为源工程，并移入已修复浮动卡顿的开始界面。地图继续使用 `scenes/maps/arena/arena.tscn`，教堂、糖屋和独立地板 shader 测试完整保留。

## 运行流程

双击 `play.cmd`。首次运行先导入图片及脚本，然后进入开始界面。

开始界面 → 选择座驾 → 开始游戏 → 对局。Esc 暂停或比赛结算后，可以“更换座驾”或“返回主菜单”。返回菜单不重复播放片头。按 R 重新开始仍使用当前座驾。

选人界面支持鼠标卡片及左右箭头、A/D 或方向键切换、1/2/3 直接选择、Enter/空格确认、Esc 返回。手柄可使用方向键或左摇杆横向切换、确认键开始、取消键返回。

当前三种座驾全部可选，第四格为不可选的“敬请期待”。2026-11-09 三辆车均已配置独立 3D 外观预览，石台来自背景图。展示灯光已适配模型，卡片使用独立矢量图标与名称，正式缩略图可随时替换。模型源文件与动画维护见 [三车模型交接](three-car-art.md)。

## 场景与文件组织

- `scenes/ui/start_screen.tscn`：开始界面。
- `scenes/ui/vehicle_select.tscn`：选人界面，在根节点的 entries 中配置卡片。
- `scenes/ui/components/vehicle_preview.tscn`：透明的 3D 模型展示接口；包含独立灯光、镜头和 ModelMount。
- `scripts/ui/`：界面脚本、卡片、属性格、车型展示数据及模型展示逻辑。
- `assets/menu/`：开始界面原始素材，标题使用支持小数像素位移的 Sprite2D。
- `assets/selection/`：提供的五张原始素材；`icons/` 为当前可替换图标。
- `config/selection/`：三种车型与预留卡位的资料。

改动的原有运行文件仅为 `project.godot`、`play.cmd`、`scenes/hud.tscn`、`scripts/hud.gd`、`scripts/match.gd`；README 增加本版入口说明。地图、建筑、地板材质与 shader、车辆物理和 AI 沿用源工程。

## 动态信息

车型名、介绍、能力格、图标和专属特性单独显示。`config/selection/*.tres` 可修改标题、介绍、缩略图与五格评分；评分只表示定位，不参与实战计算，也不是对精确伤害或加速度的承诺。

专属特性读取关联 `VehicleProfile` 的实际参数：

- 小马：低于 40 颗糖时拾取翻倍，自己掉落的糖不翻倍。
- 南瓜：车头吞噬尺寸不超过自身一半的对手并获得其糖果。
- 史莱姆：速度超过 4 时滚动，受伤减少 30%、加速提高 20%，转 90° 仅减速 7.5%。

能力格初值：小马发育 4 / 碰撞 3，南瓜发育 4 / 碰撞 4，史莱姆发育 3 / 碰撞 3。它们是设计定位，可独立调整。底部第四格不对应已实现的车型，没有虚构解锁条件。

## 后续接入模型

1. 准备一个以 Node3D 为根的**纯外观场景**，不包含车辆控制器、比赛逻辑或碰撞体。约定脚底中心为原点，正前方为本地 -Z。
2. 打开对应 `config/selection/pony.tres`、`pumpkin.tres` 或 `slime.tres`，将外观场景拖入 `preview_scene`。
3. 用 `preview_scale`、`preview_offset`、`preview_yaw_degrees` 对齐石台。默认朝向为面向镜头的三分之四视角。
4. 若有待机动画，将名称填入 `preview_idle_animation`，默认查找 `idle`。
5. 替换 `thumbnail`，即可更新卡片与信息区图标。

接入后自动启用独立透明 3D 预览，可缓慢旋转、鼠标拖动旋转，并在切换时清除旧模型、播放轻微缩放入场。没有模型时不创建占位车、不显示开发提示，并关闭模型预览的渲染更新。比赛中使用的车型和预览模型分开配置。

## 片头与开始界面音乐

2026-11-10 已接入提供的 `11月10日.mp4` 和 `后段.mp3`。视频转为 `assets/cinematics/intro.ogv`（Ogg Theora + Vorbis，1920×1080、30 fps、约 9.87 秒），保留原有画面比例和声音。MP3 原样复制为 `assets/audio/menu_loop.mp3`。源音频前约 9.89 秒为静音，导入设置 `loop=true`、`loop_offset=9.89`；首次播放也从该偏移开始。

每次启动播放一次片头；可按 Esc、Enter、空格或点击“跳过片头”。自然结束或跳过后先停掉视频声音，再随开始界面淡入音乐。有效音乐每约 46.3 秒从有声段开头循环；进入选车时随画面淡出并释放播放器，返回开始界面重新播放有声段，不重播片头。缺少视频时直接显示菜单并播放音乐。

`scenes/ui/start_screen.tscn` 中的 `MenuMusic` 为实际保存的 AudioStreamPlayer 节点，可直接替换 Stream、调整音量，默认 -4 dB；淡入淡出跟随根节点 `fade_seconds`，默认 0.35 秒。开始界面的音乐不带入选车或对局。

替换视频时更新 `assets/cinematics/intro.ogv`，或在根节点设置 `intro_video_path` / `intro_stream`。需转码为真正的 Ogg Theora，不能只改 MP4 后缀。源素材信息见 [片头与音乐说明](../assets/cinematics/README.md)。

`tests/menu_media.gd` 验证实际解码、自然结束、跳过、循环跨越结尾、离开/返回菜单和缺失素材回退。新增 Master 总线音频采样检查，确认自然结束、跳过和循环后均立即输出有声样本，而非只检查 playing 标记。应使用 `--max-fps 60` 实时运行，不能用 `--fixed-fps` 加速媒体时钟。原有 `tests/ui_flow.gd` 的无片头检查使用独立缺失路径，以免随正式素材变化失效。

## 保留的源工程改动

- `scenes/maps/arena/arena.tscn` 及 `props/` 的整理结果。
- `scenes/maps/arena/arena_scenery.tscn` 的建筑摆放。
- `scenes/maps/arena/buildings/church.tscn` 与 `candy_house.tscn`。
- `scenes/tests/painted_ground_test.tscn`。
- `assets/shaders/painted_ground.gdshader` 与 `assets/materials/painted_ground.tres`。

以上文件均与接入前的源文件逐字节一致，未将测试地板擅自替换进正式地图。
