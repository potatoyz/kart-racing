# 晴空疾驰 V11 多地图实现

晴空海岸保留原有曲线与操控，新增海湾港区和山岭发卡赛道。玩家在同一个车库选图，沿用已有车辆、装束、漂移、连喷、氮气与道具规则，完成本图三圈后记录独立成绩。

| 地图 ID | 名称 / 难度 | 中心线 | 路宽 | 检查点 / 圈 | 跳台 |
|---|---|---|---|---|---|
| sunny_coast | 晴空海岸 / 初级 | 682.69 m | 18 m | 12 | 2 |
| harbor_loop | 海湾港区 / 中级 | 1095.34 m | 15 m | 16 | 1 |
| ridge_hairpins | 山岭发卡赛道 / 高级 | 1410.19 m | 12 m | 20 | 1 |

港区用连续左右换向、港湾长弯和出弯直道组织节奏，仓库、集装箱、港机、灯杆与货驳形成地标。山岭的紧弯半径约 21 m，要求提前制动；岩体、松树、观景台、山口门架与远山构成与海岸不同的场景。两图仍有连续路面及空气墙，无强制断路跳跃、立体交叉或解锁门槛。白盒实测后调整了最初路段比例与跳台位置，最终路线以地图定义和实机轮廓为准。

## 一份几何同时服务规则与画面

`project/mechanic/tracks/catalog.gd` 保存三图的稳定 ID、名称、难度、路宽、门数、闭合路线与跳台/道具行位置。`course.gd` 为新图构造圆角闭合贝塞尔路线，按弧长采样；海岸继续使用原始周期公式。路面、路肩、护栏和空气墙共享烘焙数据；新增道路有独立承重碰撞，跳台尺寸随地图路宽缩放。

比赛以有序检查点及合法区间内的弧长计算进度，起终线与复位不再依赖固定 96/8/12 索引。最近点查询限制在合法路段附近，避免山岭相邻回头路段串线。六车在新图使用米制前视、弯前速度约束和原有车辆物理；海岸保留原 AI 行为。新图 AI 以稳定抓地驾驶为主，玩家的漂移与连喷规则不变。

组装层向比赛、场景和特效注入当前 Course；HUD 从公开快照读取路线轮廓、包围盒和圈数。切图仅在车库接受，校验 ID 后加载场景，再更新选择、车辆和道具。非法 ID 或加载回调拒绝时保留原选择。重赛、切图、回车库会清理临时状态、胎痕、粒子与速度特效，重赛清除旧圈数提示。

公开接口已更新为 `mechanic_contract.json` 版本 4。新增 `select_track`、`track_changed`，以及 `track_catalog`、`selected_track_id`、`active_track_id`、`track`、`lap_count`、`cars[].lap`、`best_by_track` 等字段。

## 成绩迁移保留旧记录

`user://profile.cfg` 升级为版本 2。新成绩结构为 `best_by_track[地图ID][speed/item]`，旧 `best` 只迁移到 `sunny_coast`，不会复制到新图，也不会覆盖已有新版记录。车辆、装束、静音和低动态设置保留；未知地图回退海岸，损坏成绩按项恢复默认。所有本轮自动验证均禁用玩家存档或使用独立临时文件。

## 资源可编辑且来源明确

六种刚性构件由 `prepare_maps_assets.py` 的规格数据生成：仓库、集装箱、港机、码头灯、观景台、山口门架。自然素材取自 Kenney Nature Kit 2.1：两种松树、宽岩石与高岩体，许可证为 CC0。它们均经过原生多方向渲染检查。自然素材的金属属性被关闭，叶片与岩体调整为适合当前场景的哑光配色。

`map_props.gd` 按材质合并静态表面，再通过 MultiMesh 绘制重复物体。布置时检查物体完整水平包围范围，保留路面及相机净空。新增素材清单为 `project/assets/maps_v11.json`，来源与处理记录在 `ASSET_PROVENANCE.json`，许可证在 `project/assets/imported/maps_v11/KENNEY_LICENSE.txt`。本轮没有付费生成调用。

选图照片来自实际 Godot 视口，路线轮廓由同一几何数据绘制。三图仍共用原有驾驶角色、赛车、骨骼、声音与 V10 特效。整个工程通过 `start_game.cmd` 或 Godot 4.5.1 运行；源码包不包含 Godot 本体或 Windows 导出 EXE。

## 验证入口

在仓库根目录运行 `python test_data/outputs/sunny_drift/20261021/pipeline/playable/maps_ops.py test` 执行自动化测试。`maps_batch.py` 运行 40 场比赛矩阵；`maps_ops.py` 还提供 `checks`、`ui`、`visual`、`assets`、`record`、`performance`、`techniques` 原生验证入口，`ui --large` 验证 1600×900，`techniques --track=harbor_loop` 指定技巧专项地图。每轮证据写入独立目录，详见 [QA_MAPS_V11.md](QA_MAPS_V11.md)。
