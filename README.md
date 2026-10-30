# 跑跑卡丁车 · 晴空疾驰

独立的 Godot 4.5.1 单机卡丁车游戏，原项目名 **Sunny Drift / 晴空疾驰**。包含三条赛道、竞速与道具模式、六车三圈、换装、漂移与连喷。游戏内名称和存档位置沿用原项目。

## 开始玩

安装 Godot **4.5.1** 和 Python **3.10+**，双击 `start_game.cmd`；编辑工程用 `open_editor.cmd`。无需 GameFactory 父仓库，也不需要安装 Python 第三方依赖。没有 Python 时可使用 `start_portable.cmd` 或直接在 Godot 中导入 `project/project.godot`。

命令行启动：

```powershell
python run.py play
python run.py editor
```

Godot 按环境变量 `A3GAME_GODOT_EXECUTABLE`、`engine.json`、PATH、当前 Windows 用户的 A3Game 安装目录依次定位。需要手动指定时：

```powershell
$env:A3GAME_GODOT_EXECUTABLE = 'D:\Tools\Godot\Godot_v4.5.1-stable_win64.exe'
python run.py import
python run.py play
```

首次启动会生成 `.godot/` 素材缓存。`WASD` 或方向键驾驶，`Shift` 漂移，`J/W` 小喷，`Space/Ctrl` 氮气，`E` 道具，`R` 复位，`Esc` 暂停。完整玩法与历史迭代见 [GAMEPLAY.md](docs/GAMEPLAY.md)。

## 目录

| 路径 | 内容 |
|---|---|
| `project/` | 可直接导入的完整 Godot 工程 |
| `project/mechanic/` | 动力学、AI、规则与存档 |
| `project/presentation/` | 模型、地图、UI、相机及特效 |
| `project/assets/` | 已处理好的全部游戏素材与来源说明 |
| `project/tests/` | Godot 原生测试及运行验收场景 |
| `tools/` | 地图、视觉、特效验收与源码打包脚本 |
| `tools/vendor/` | GameFactory Godot 工具及其最小路径模块，随库内置 |
| `tools/asset_pipeline/` | 可选的素材重新生成工具，见其 README |
| `docs/` | 原设计、来源清单、历史验证文档和拆分记录 |

## 验证与打包

```powershell
python run.py import     # 全新导入素材并检查脚本错误
python run.py validate
python run.py test       # 17 个原生测试组
python run.py smoke      # 无界面启动 90 帧，禁用玩家存档
python tools/maps_ops.py checks
python tools/package_maps.py --output release/kart-racing-source.zip
```

`python run.py qa/skills/boundary/camera` 保留原生交互验收入口；`tools/review_visuals.py`、`tools/review_vfx.py`、`tools/review_speed.py` 保留专项检查。运行产物写入 `evidence/` 和 `project/reports/`，均不提交 Git。历史视频和缓存留在原 GameFactory 工作区；`docs/` 内的旧验证结果不代表本次重跑，旧文档中的路径按原目录记载。

本仓库来自原工作区的当前游戏源码快照，不包含父仓库的 Git 历史。游戏在提取时未被原仓库跟踪，来源和文件 SHA256 见 [Y-split-manifest.json](docs/Y-split-manifest.json)。许可和素材来源见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
