# 跑跑卡丁车仓库拆分验证

日期：2026-10-30。

独立仓库：`${KART_RACING_ROOT}`。源目录：`GameFactory-3A/test_data/outputs/sunny_drift/20261021/pipeline/playable`。保留 Sunny Drift 的游戏名称、存档路径和全部游戏逻辑；游戏逻辑、模型和贴图与提取源一致，资源来源元数据中的本机路径已脱敏。原目录保留为备份。

`project/` 存放完整 Godot 工程；文档和历史清单归入 `docs/`；运行验收工具归入 `tools/`；可选生成脚本归入 `tools/asset_pipeline/`。Godot Python SDK 及其路径模块随库保存在 `tools/vendor/`，运行和测试无需父仓库。素材重新生成仍通过显式的 `GAMEFACTORY_ROOT` 使用原生产环境和生成原料。

已完成：

- 从无 `.godot` 缓存的目录导入全部素材，未出现引擎或脚本错误。
- `python run.py validate` 成功。
- `python run.py test`：17 / 17 原生测试组通过，stderr 为空。
- `python run.py smoke`：90 帧无界面启动通过，使用 `--maps-qa` 禁用玩家存档。
- `python tools/package_maps.py --output ...`：源码 ZIP 创建成功，CRC 完整，包含项目、素材、启动器、内置 SDK 和许可。
- Git 文件清单包含全部提取文件，未包含导入缓存、历史证据、发布包和 Python 缓存。源码约 191.6 MiB，最大单文件约 12.81 MiB。

本次未重跑历史全部录像和人工驾驶验收，也没有制作 Windows 导出 EXE。既有原文件的空白格式保持原样，包括 Kenney 许可文本、project.godot 末尾空行及第三方 recorder.gd 的空白行；新改写文件通过 whitespace 检查。

来源清单见 `Y-split-manifest.json`：同时记录源文件和迁移后文件哈希，区分路径适配。原游戏是未跟踪/被忽略的工作区内容，故新仓库建立独立初始快照，没有伪造游戏提交历史。远程仓库已配置为 https://github.com/potatoyz/kart-racing（私有），使用 HTTPS 连接。
