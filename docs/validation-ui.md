# UI 整合验证记录

2026-11-04，Windows，Godot 4.7.2，Compatibility 渲染器。

- `tests/ui_flow.gd`：48 项通过，0 失败。覆盖开始界面进入选人、真实鼠标点击、键盘切换、三种车型分别进入对局、锁定卡位、快速切换数据同步、暂停与结算返回、重复确认、重新开局、空模型展示区、未来模型接口加载和清理、四种宽高比。
- `tests/regressions.gd`：77 项通过，0 失败。覆盖三种车型输入隔离、HUD 不抢驾驶输入、成长与碰撞边界、拾糖反馈清理。
- 原始场景、建筑、材质和 shader 哈希比对一致；UI 启动后的对局确认包含 Church 和 CandyHouse 节点；独立地板测试仍可加载。
- 实际图形渲染检查小马和史莱姆的信息布局；不是将参考图整体贴入界面。文字和数值来自实时数据。

当前没有正式车辆模型或片头成片。模型接口使用测试中的临时外观场景验证，默认配置仍为空；片头保留接入口，不代表已完成视频制作。

复现：先导入项目，再运行：

```
Godot --headless --path . --fixed-fps 60 --script res://tests/ui_flow.gd
Godot --headless --path . --fixed-fps 60 --script res://tests/regressions.gd
```
