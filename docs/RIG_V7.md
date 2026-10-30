# 驾驶骨骼 V7

用户授权：配置 Blender 便携版；先用海岸领航员与晴空 GT 验证绑骨和方向盘双手约束，再扩展至三套车手、三辆车。

保留 V6 Mivo 源网格和 PBR 材质。用仓库 Vibe Motion 的标定投影、关节重建和约束蒙皮函数生成骨架与权重，交互式视觉标注保留在新输出目录；Blender 负责制作可编辑骨架文件与导出真正带 Skin 的 GLB。原静态模型不覆盖。骨盆、脊柱、头部与双臂/腿部都绑定，手套先作为刚性握持部位；这一轮不做逐指动画。

每辆车独立设置方向盘轴、左右握点和肘部参考方向。Godot SkeletonModifier3D 在动画之后解算双臂与手腕姿态，握点随方向盘旋转。转向源与车辆前轮使用同一呈现状态，不更改驾驶物理。座位和方向盘校准写入资产配置。

验收：原始材质保留，GLB 中存在骨架、蒙皮权重；九种搭配直行/左右转向/反打的掌心误差、手腕姿态、肘部稳定性与最大伸展报告；近景录制检查手臂形变和握盘；暂停/继续与菜单/比赛切换；现有规则、技巧和完整双模式回归。Blender 文件、原生录制、校准、标注及源码包随交付保留。

## 重建与验收入口

在仓库根目录运行 `python test_data/outputs/sunny_drift/20261021/pipeline/playable/rig_driver_v7.py bind --index 0` 重建指定车手，`import --index 0` 通过 GodotClient 导入。已有标定与标注会保留，不重复生成或冒充新视觉测量。

共享 Pipeline 支持 `--task-type seated_rig --calibration-dir <目录> --binding-config <显式参数 JSON> --blender-executable <blender.exe>`；也可使用含这些字段的 motion JSONL。输入源网格或投影变更后需要重新标注。

`python test_data/outputs/sunny_drift/20261021/pipeline/playable/review_visuals.py rig --all-rigs` 运行九种组合的实际渲染与骨骼测量。`run.py test` 和 `run.py qa` 分别运行原生测试与完整双模式回归。
