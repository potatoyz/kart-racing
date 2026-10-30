# 可选素材生产工具

当前游戏需要的模型、贴图、绑定和特效均已在 `project/assets/` 内，运行、测试与源码打包不调用这些脚本。

这些脚本保留原素材生产流程，重新生成时需要原 GameFactory 工具、相应 Python/Blender 依赖、原始生成资产，云端生成还需要服务凭证。显式指定原工作区：

```powershell
$env:GAMEFACTORY_ROOT = '<path-to-GameFactory-3A>'
python tools/asset_pipeline/visual_assets.py --help
```

游戏输出写到本仓库；原始素材按 GameFactory 的 `pipeline.common.paths` 查找。不要将凭证、缓存或原始大模型提交到游戏仓库。
