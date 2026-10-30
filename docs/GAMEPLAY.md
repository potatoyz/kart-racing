# 晴空疾驰 · Sunny Drift

Godot 4.5.1 的 Windows 单机赛车游戏。当前为多赛道 V11：新增中级「海湾港区」与高级「山岭发卡赛道」，保留初级「晴空海岸」。三图均支持竞速赛、道具赛、六车三圈和独立最佳成绩，并沿用 V10 动态破风、V8 喷气/胎痕/烟尘及 V7 驾驶骨骼。

## 开始玩

在本机双击 **start_game.cmd**。引擎已安装，启动脚本通过本仓库的公开 `GodotClient` 运行工程。双击 **open_editor.cmd** 可在 Godot 编辑器中继续修改。

脱离本仓库使用源码包时，可双击 `start_portable.cmd`；它通过本机安装路径、`A3GAME_GODOT_EXECUTABLE` 或 PATH 寻找 Godot，首次启动会导入素材。也可用 Godot 4.5.1 直接导入 **project/project.godot**，按 F6/F5 运行主场景。最新更新位于当前 `project/` 目录；`sunny_drift_maps_v11_source.zip` 是本轮可编辑 Godot 工程包。Godot 引擎与 Windows 导出 EXE 不在包内；旧 `sunny_drift_vfx_v8_source.zip` 保留为历史版本。

1. 在车库用左右按钮预览赛车和时装，可拖动展台旋转赛车；点击“装备当前搭配”。
2. 点击车库左下角赛道卡，选择初级海岸、中级港区或高级山岭；确认后点击“竞速赛”或“道具赛”，等待倒计时。
3. 完成三圈后查看排名、成绩与个人最佳；可重赛或回车库。

| 操作 | 按键 |
|---|---|
| 加速 / 刹车倒车 | W / S，或 ↑ / ↓ |
| 转向 | A / D，或 ← / → |
| 起漂 | Shift + 方向，需要一定速度；松 Shift 后仍保留侧滑 |
| 反打回正 | 松 Shift 后按相反方向，再放开方向恢复直行 |
| 小喷 / 空喷 / 落地喷 | 点按 J 或 W，按当前有效窗口触发 |
| 氮气大喷 | Space 或 Ctrl，消耗一罐，最多储存两罐 |
| 使用道具 | E |
| 回到安全检查点 | R，有短暂冷却，不增加圈数 |
| 暂停 / 继续 | Esc |

有效漂移会集气，达到 100 获得一罐氮气。松 Shift 后进入惯性收尾，速度方向逐渐向车头靠拢；反打可加快回正。小喷改为主动点按，不会在松 Shift 时自动消耗。离开路面会减速。换装只改变外观，三辆车的极速、加速和操控参数各不相同。

使用 **WASD 驾驶时推荐 J 小喷**；使用 **方向键驾驶时可用 W 小喷**。W 仍同时保留油门绑定。按住喷气键或操作系统的重复按键不会连续喷。

## 搓招方式

| 技巧 | 操作与窗口 |
|---|---|
| 小喷 | 有效漂移收尾后，1.15 秒内点 J/W |
| 双喷 | 有效长漂约 0.7 秒以上，反打收尾；HUD 显示“双喷已备好”后点 J/W，0.16–0.50 秒后再点一次 |
| 氮气大喷 | 有库存时点 Space/Ctrl，持续 2.1 秒 |
| CW | 大喷 → 小喷 |
| CWW | 准备双喷资格 → 大喷 → 小喷 → 第二喷 |
| WCW | 准备双喷资格 → 小喷 → 大喷 → 第二喷；两次小喷仍需符合 0.16–0.50 秒间隔 |
| 空中喷 | 经跳台真实腾空后，出现提示时点 J/W；每次飞行仅一次 |
| 落地喷 | 有效腾空着地后 0.55 秒内点 J/W |
| 空落连喷 | 空中点一次 → 着地后再点一次 |

双喷还要求足够的真实侧滑与反打时间；原地转向、低速轻点 Shift 不会刷出资格。可提前 0.12 秒点喷作为输入容错。HUD 显示可用窗口与确认后的连招，暂停菜单左侧有速查表。详细规则见 `DRIVING_V2.md`。

道具赛可取得追踪导弹、护盾、推进器。导弹要求前方范围内存在对手，否则保留道具；护盾挡一次命中或到期失效。竞速赛不出现道具箱。

车辆装束、已选赛道、设置和按地图/模式划分的最佳成绩保存到 Godot 的 `user://profile.cfg`。旧版成绩自动归入晴空海岸，其余地图从空纪录开始。暂停菜单可切换声音与低动态模式；窗口失焦会暂停比赛。低动态默认开启，不产生额外镜头抖动。

## 已验证与当前边界

当前 17 个自动化测试组通过，覆盖规则、存档及多图迁移、动力学、转向响应、镜头、技巧、空中检查点、地图曲线与新模型组合。动力学同一输入序列检查了 30/60/120 Hz。空气墙专项覆盖 96 项地面/空中横撞、首尾接缝和两侧贴边滑行。完整原生运行覆盖两种比赛、跳台、空喷/落地喷、道具、复位、暂停和结算；另有独立原生按键专项验证双喷、CW/CWW/WCW 和空落连喷。视频是实际 Godot 视口低帧率录制，不含音轨，也不是人工手感评测。

- `evidence/gameplay-review.mp4`：完整两局验收视频。
- `evidence/skills-review.mp4`：驾驶 V2 的原生搓招与跳台专项视频。
- `evidence/boundary-review.mp4`：赛道 V3 的空气墙与贴边滑行专项。
- `evidence/boundary_qa/track-overview.png`：实际游戏场景的赛道俯视图。
- `evidence/skills_qa/report.json`：技巧专项结果；测试明确设置了初始位置、速度，组合大喷案例预置一罐氮气；其余驾驶和按键使用实际逻辑。
- `evidence/qa/report.json`、`events.jsonl`：运行报告和事件证据。
- `project/reports/tests.json`：原生测试报告。
- `QA.md`：发现、修复与尚未覆盖的验收内容。
- `QA_DRIVING_V2.md`：本轮动力学、喷气和跳台验证。
- `TRACK_V3.md`、`QA_TRACK_V3.md`：平滑曲线、空气墙与碰撞验收记录。
- `HANDLING_V4.md`、`QA_RESPONSE_V4.md`：普通转向迟滞的原因、修改及前后测量对比。
- `CAMERA_V5.md`、`QA_CAMERA_V5.md`：收漂接喷的镜头闪动复现、修复与逐帧验收。
- `evidence/camera-before-after.mp4`：镜头修复对比，左旧右新、半速播放。
- `DESIGN.md`、`layout.json`、`tasks.json`：设计、界面布局和进度记录。

这是可玩切片：三条赛道（海岸两座跳台，港区与山岭各一座）、三辆 Mivo 赛车、三套 Mivo 车手装束及各自场景。新增场景包含六种本地规格模型和四种 Kenney CC0 自然素材。车手已有程序化双臂和手腕骨骼动作，尚未制作逐指、上下车或表情动画；道路与碰撞保持原生曲线网格。音效仍为简单合成音色，尚未实现赛道解锁进度、真实引擎音效或联网。Windows 导出安装包也未制作；当前通过已安装的 Godot 运行。没有使用 QQ 飞车的角色、标识、贴图或音频。

## 动态破风 V10

重启游戏即可加载。完整效果可在 **Esc → 低动态模式：关闭** 下体验；原有默认值和玩家保存的设置继续生效。低动态模式减少气流数量和亮度，仍保留实际前后移动，关闭气浪和边缘模糊，并保持比赛视野为 65°。

- 高速效果从约 72 km/h 开始渐入，随车速增强；前方道路保持清楚，屏幕边缘呈现向外掠过的气流。
- 气流以不对称的短束随机生成，具有独立位置、方向、长度和寿命。赛车超过气流，气流从前向后掠过；转弯时，旧气流沿原有轨迹继续移动。没有固定附着在车上的长弧线。
- 每束气流仅持续约 0.18–0.8 秒，呈现小幅弯曲和逐渐消散。普通高速约每秒 17 束，大喷最高约每秒 100 束；低动态约为三分之一。
- 屏幕速度线每次生成都会改变落点、长度和亮度，并加速向边缘掠出。
- 大喷启动时扩散一圈短促气浪，持续期间增强速度线和轻微径向模糊，镜头视野逐步扩展至约 76°；小喷使用较轻的反馈。氮气结束后平滑收回。
- 效果位于 HUD 下方；暂停冻结动画和视野，复位、回车库及结算会清理残留。道具推进器也能触发加速反馈。

实现入口为 `project/presentation/vfx/speed_feel.gd`。`wind_pool.gd` 使用容量 80 的世界空间 MultiMesh 粒子池，着色器按粒子寿命弯曲、渐隐，并使丝带面向镜头。气浪复用两个网格；屏幕效果仅在有效车速下启用，不需要外部素材。V9 源码快照保存在 `history/v9-speed-baseline/`。

验证：14 组自动化测试通过，新测试覆盖气流相对车辆的真实位移、转向不拖动旧尾流、寿命回收、容量限制、静止抑制和 30/60/120 Hz 发射量一致性。原生 OpenGL 的 12 场景检查另跟踪同一粒子在连续帧中的车身相对位移，检查普通/低动态模式均实际掠过车辆，并验证暂停冻结粒子位置和寿命。截图和录像使用预置初始速度/氮气库存及内置 AI 驾驶，未修改玩家存档。

- `evidence/speed-v10-review.mp4`：本轮原生视口录制，720p / 60 fps，无音轨。
- `evidence/speed_v10/motion_0.png`、`motion_1.png`、`motion_2.png`：间隔 0.1 秒的连续画面。
- `evidence/speed_v10/report.json`：12 场景运行报告与粒子位移记录。
- `review_speed.py`：从仓库根目录运行 `python test_data/outputs/sunny_drift/20261021/pipeline/playable/review_speed.py` 重跑本轮原生检查；覆盖本轮 `speed_v10` 证据目录。旧版 `speed_v9` 证据仍保留。

## 特效 V8

- `VFX_V8.md`、`QA_VFX_V8.md`：实现范围、性能和验证。
- `evidence/vfx-v8-before-after.mp4`：同输入的原生前后对比。
- `evidence/vfx-v8-cars.mp4`：三辆车的大喷和短喷近景。
- `evidence/vfx-v8-racing.mp4`：两模式完整实际运行。
- `evidence/vfx_v8/performance.json`：无录帧配对计时。
- `review_vfx.py`：技巧、生命周期、压力和性能重跑入口。

## 驾驶骨骼 V7

- `RIG_V7.md`、`QA_RIG_V7.md`：绑定方案、实现和验证记录。
- `evidence/driver-rig-v7.mp4`：九种组合的近景转向握盘。
- `evidence/racing-rig-v7.mp4`：本轮两模式完整运行。
- `evidence/rig_v7/qa/report.json`：掌心距离、手腕角度、骨长与肘部连续性。
- `rig_driver_v7.py`、`rig_binding_v7.json`：可重建绑定的项目任务与显式参数。

## 视觉 V6

- `VISUAL_V6.md`：视觉方向与资产计划。
- `QA_VISUAL_V6.md`：模型、菜单和实际运行验收。
- `evidence/visual_qa/garage_0.png`：新主界面。
- `evidence/visual_qa/garage_1600.png`：1600×900 布局。
- `evidence/visual-v6-menu.mp4`：真实菜单操作与短程驾驶录制。
- `evidence/visual-v6-racing.mp4`：两种模式完整比赛录制。
- `evidence/art_review/`：模型多角度与九种驾驶舱组合检查。

## 多地图 V11

| 赛道 | 难度 | 中心线长度 | 路宽 | 驾驶特点 |
|---|---|---|---|---|
| 晴空海岸 | 初级 | 682.69 m | 18 m | 长弯与双跳台 |
| 海湾港区 | 中级 | 1095.34 m | 15 m | S 弯换向、港湾漂移和接喷 |
| 山岭发卡赛道 | 高级 | 1410.19 m | 12 m | 发卡制动、窄路控线和出弯加速 |

三图直接开放。选图页支持鼠标、左右键、Enter 确认和 Esc 取消，预览不会立即改变赛道；重赛保留地图与模式。地图名称、小地图、圈数、起终门、暂停与结算均来自当前地图。山岭通过岩体、植被和远景塑造地形，驾驶路面为平面闭环，跳台提供局部腾空。

- [MAPS_V11.md](MAPS_V11.md)：实现范围、数据结构与资源说明。
- [QA_MAPS_V11.md](QA_MAPS_V11.md)：实际运行、边界、存档、性能与验收证据。
- [evidence/maps-v11-racing.mp4](evidence/maps-v11-racing.mp4)：新图各两模式的四场完整三圈录像，800×450 / 10 fps，无音轨。
- [evidence/maps-v11-techniques.mp4](evidence/maps-v11-techniques.mp4)：港区与山岭的双喷、CWW/WCW、空落喷专项。
- [MAP_EXPANSION_V11.md](MAP_EXPANSION_V11.md)：本轮原始规划；最终实测参数以实现说明和 QA 为准。

本轮 40 场原生比赛覆盖三图/两模式/三车型、新图五随机种子及基础驾驶。240 辆参赛车辆均完成三圈，自动复位为 0。录像使用原生键鼠事件加 AI 驾驶，明确预置少量资源做按键专项；它不代表真人主观手感评测。既有功能回归及最终验证详见 QA 文档。

## 继续开发

车辆接触采用等质量、低回弹的相对速度冲量：追尾时后车减速、前车获得推力，同速接触不额外刹车，轻碰保留氮气；护栏仍按静态障碍处理。原生物理回归脚本为 `project/tests/collision_qa.gd`，覆盖追尾、更新顺序、静止车辆、连续顶推、侧擦、连环碰撞、对撞和顶墙，结果写入 `project/reports/collisions.json`。可用 `engine.json` 中的 Godot 执行文件运行 `--headless --path project --fixed-fps 60 --script res://tests/collision_qa.gd`。

`project/mechanic/` 负责动力学、AI、检查点、道具、存档和比赛状态；`project/presentation/` 负责模型、场景、相机、HUD 与声音。界面通过 `snapshot()`、`command()`、`event_emitted` 访问规则模块，接口在 `mechanic_contract.json` 中列出。主场景只组装模块。适配器和示例工程保持原样。

在仓库根目录运行：

```powershell
python test_data/outputs/sunny_drift/20261021/pipeline/playable/run.py test
python test_data/outputs/sunny_drift/20261021/pipeline/playable/run.py qa
python test_data/outputs/sunny_drift/20261021/pipeline/playable/run.py skills
python test_data/outputs/sunny_drift/20261021/pipeline/playable/run.py boundary
python test_data/outputs/sunny_drift/20261021/pipeline/playable/run.py camera
```

QA 会打开独立游戏窗口、自动操作并录制帧，然后自行退出；测试模式不覆盖玩家存档。重跑前应把已有 `evidence/qa` 留档，避免覆盖验收记录。生成的视频使用本地 FFmpeg 从实际采集帧编码。

素材来源：车辆、角色、海岸道具与菜单图片使用 Mivo GPT Image 2 / Tripo P1 生成，任务 ID、提示词和加工记录见 `ASSET_PROVENANCE.json`、`visual_asset_plan.json`。车轮从生成网格分离，贴图缩至 1536 / 1024 像素；车手肖像由生成参考图裁切。道路、碰撞、图形控件、着色器和音色由本工程构造。生成素材使用条件以 Mivo 及上游服务条款为准。音效事件分发使用仓库自带 A3GamePlayable，随源码包保留仓库 Apache-2.0 许可证。Godot 本体单独安装，不打入源码包。
