# 驾驶骨骼 V7 验收

2026-10-26。Blender 4.5.12 LTS / Godot 4.5.1 / Windows / RTX 3070。

## 交付内容

- 三套 Mivo 车手均绑定 21 个骨骼节点，包含躯干、头、四肢及左右握点。GLB 有真实 Skin、JOINTS 和 WEIGHTS，每顶点最多四个权重；保留原始网格与 PBR 贴图。
- 三辆车从原网格分离方向盘和相连轮辐，保留车轮、车体及 UV。方向盘有独立转轴、支撑柱和左右握点，转角范围 ±32°。
- Godot `SkeletonModifier3D` 实时求解双臂和手腕姿态；骨骼长度保持不变。前轮和方向盘读取同一转向呈现状态，停车时也响应转向。`snapshot().cars[].steer_input` 为新增只读字段，驾驶物理未改。
- 星兔车手按资产配置前移 0.09 m，使较短的手臂在所有车型中可达。海燕 R 的方向盘中心高度独立校准为 1.28 m，其余两辆为 0.94 m。
- Blender 便携版安装到用户的 `AppData/Local/A3Game/Blender/4.5.12/`，校验官方 SHA-256 后验证 `bpy`。未改系统 PATH 或文件关联。

三个可编辑文件位于仓库 `test_data/outputs/sunny_drift/20261026_rig_v7/assets/motion/driver_0..2/driver_rig.blend`。逐个在 Blender 中重新打开，确认 21 骨骼及三张贴图均已内嵌。游戏运行无需 Blender 或 Mivo 网络连接。

## 骨骼与权重来源

先用仓库 `prepare_projection` 对每个原始网格独立生成五张标定投影，记录源文件和处理后几何摘要。通过当前交互式视觉模型逐链观察、标注内部关节中心，保留每个观察视图、置信度、推断标记、阶段说明及原始标注。没有把一个角色的关节坐标镜像或复制给另一个角色，也没有把本地测试伪称为远程 VLM 调用。

随后调用 Vibe Motion 的多视图重建、关节拟合和带约束的拓扑扩散蒙皮；只在原网格边上传播权重。头盔和握持手套设置刚性锚点，肩肘区域平滑过渡。显式参数在 `rig_binding_v7.json`，所有重建、权重和导出记录在本轮 `assets/motion/`。Blender 构建 Armature、顶点组、Skin 并导出 GLB。该流程已接入 `GenMotionOperator` 的 `seated_rig` 分支和原生 motion CLI。

## 验证结果

| 检查 | 结果 | 证据 |
|---|---|---|
| motion、绑定与回归 | 87 项通过、4 项跳过、276 个子检查通过 | `test_gen_motion.py`、`test_vibe_rigging.py`、`test_vibe_motion.py`、`test_seated_driver.py` |
| Godot 原生测试 | 11 / 11 组通过，含三个真实 Skin 的四权重归一性检查 | `project/reports/tests.json` |
| 9 种搭配的动态握盘 | 每组 121 次采样，包含 ±32° 转向和车身平移、偏航、俯仰、侧倾 | `evidence/rig_v7/qa/report.json` |
| 掌心控制点距离误差 | 最大约 0.817 mm；其余八组均小于 0.007 mm | 同上 |
| 手腕方向误差 | 最大约 0.056° | 同上 |
| 骨骼长度变化 | 最大约 0.00022 mm，无拉伸补偿 | 同上 |
| 肘部连续性 | 相邻采样最大位移约 8.42 mm，未超过 60 mm 的跳变阈值 | 同上 |
| UI 与切换 | 换车换装、装备、展台拖动、暂停/继续、设置、返回通过 | `evidence/visual_qa/report.json` |
| 完整实际比赛 | 竞速与道具各完成一局，总计约 119.44 秒、464 帧 | `evidence/qa/report.json` |
| 实际驾驶握盘 | 53,196 次左右手测量，最大控制点误差约 0.026 mm，无超出伸展范围 | 同上 |
| 退出日志 | 比赛、UI、握盘检查均无 ERROR | `qa.log`、`evidence/visual-ui.log`、`evidence/visual-rig.log` |

误差针对所定义的掌心控制点与方向盘目标，不表示每个手指表面都完成碰撞约束。近景检查分别查看了直行、左转、右转的手套、手腕、肩肘和驾驶舱交叠。手套采用现有握持形状，未添加逐指动画、上下车或表情动画。

## 本轮修复与证据

- 第一套验证通过后，扩展九种搭配时发现星兔车手在部分极限转角存在 2–5 cm 超距；通过座位前移解决，没有延长手臂骨骼。
- 新旧资产注册需要独立 ID，使用 `rig_v7_driver_*` / `rig_v7_car_*`，保留 V6 原资产。
- 本机 SciPy 1.18.1 的单轴批量欧拉角接口要求显式 `(frames, 1)` 形状；修复 motion 的三个调用后，原有动作与蒙皮回归全部通过。
- 权重计算不再依赖测试目录内的默认配置，绑定参数由项目显式提供；源网格或投影被修改时会在导出前拒绝旧标注。

录像：`evidence/driver-rig-v7.mp4` 展示九种搭配近景握盘，源采样每四个渲染帧取一帧、按 15 fps 编码到 30 fps；`evidence/racing-rig-v7.mp4` 为两模式实际视口约 4 fps 采样、编码到 24 fps。两者不含音轨，也不是人工手感或性能基准。

V6 脚本、目录配置和比赛证据保留在 `history/v6-rig-baseline/`；V6 原始生成文件和源码包保持可用。本轮没有重新调用付费模型生成。
