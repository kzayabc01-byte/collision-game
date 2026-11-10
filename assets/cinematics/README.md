# 开场视频与菜单音乐

2026-11-10 接入。

| 用途 | 用户源素材 | 工程资源 |
|---|---|---|
| 开场视频 | `C:/Users/Kzay/Desktop/11月10日/11月10日.mp4` | `assets/cinematics/intro.ogv` |
| 开始界面循环音乐 | `C:/Users/Kzay/Desktop/后段/后段.mp3` | `assets/audio/menu_loop.mp3` |

视频由 H.264/AAC 转为 Godot 可直接播放的 Theora/Vorbis，1920×1080、30 fps、约 9.87 秒，保留原声音轨。MP3 直接复制、没有剪辑或重新编码，总长约 56.19 秒。检测发现前 9.893 秒为静音，因此 Godot 导入选项启用循环，Loop Offset 设置为 9.89 秒，首次播放也从同一位置开始。每轮有效音乐约 46.3 秒，避免片头之后或循环间再次等待近 10 秒。源文件均保留在原位置。

播放器行为：每次启动先播放一次片头，音乐不提前响起。播放完成或跳过后进入开始界面，MP3 随画面在 0.35 秒内淡入并循环。进入选车时音乐淡出并停止；从选车或对局返回主菜单，恢复音乐但不重播片头。关闭整个游戏后再次运行，片头会重新播放。

编辑器打开 `scenes/ui/start_screen.tscn`，选 `MenuMusic` 可换音乐或调整音量（当前 -4 dB）；根节点 `fade_seconds` 控制过渡时间。替换 MP3 后，重新确认 Loop 和 Loop Offset；新音乐若没有开头静音，将 Loop Offset 改回 0。当前仅跳过源文件前导静音，不额外剪辑有声段或进行跨段混音。

重新转码片头可使用独立 FFmpeg：

```powershell
ffmpeg -i '11月10日.mp4' -map 0:v:0 -map 0:a:0 -map_metadata -1 -c:v libtheora -q:v 7 -pix_fmt yuv420p -c:a libvorbis -q:a 5 'intro.ogv'
```

视频与 MP3 都属于游戏资源，运行时不需要 FFmpeg。预览视频用 `play.cmd`；`vehicles.cmd` 和 `pumpkin.cmd` 是独立展示场景，不播放主菜单片头。

```powershell
$godotExe = 'E:/jam game/godot/Godot_v4.7.2-stable_win64_console.exe'
& $godotExe --headless --editor --path . --import --quit
& $godotExe --headless --audio-driver Dummy --max-fps 60 --path . --script res://tests/menu_media.gd
```
