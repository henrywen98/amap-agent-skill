# Changelog

本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [0.1.0] - 2026-06-22

首个公开版本。

### 新增
- 纯 `curl` 封装高德 Web 服务 REST 的 Agent Skill，**无需 MCP**，可在 pi / Claude Code / 任意带 shell 的 agent 里运行。
- 12 个命令：`geo` / `regeocode` / `around` / `text` / `detail` / `weather` / `driving` / `walking` / `bicycling` / `transit` / `distance` / `ip` / `raw`。
- `doctor`：校验 key + 缓存式自描述（一次性拉 `tools/list` 缓存到本地，`--refresh` 重拉）。
- key 解析：环境变量 `AMAP_KEY`（回退 `AMAP_MCP_KEY`）> 项目 `.env`，密钥不入库。
- `SKILL.md`：定位规则（whereami → 坐标，WGS-84↔GCJ-02 注意）+ SVG 可视化降级策略。
- 示例：找房前的地段决策（`examples/`）。
- CI：`bash -n` + `shellcheck` 检查。
