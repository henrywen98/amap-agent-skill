---
name: amap
description: 高德地图（无需 MCP，纯 REST/curl）：地理编码、逆地理、POI 周边/关键词搜索、POI 详情、天气、驾车/步行/骑行/公交路径规划、距离测算、IP 定位。当用户问基于位置的问题——「我在哪」「附近的…」「到 X 怎么走」「今天天气」「某地坐标」「两点距离」——时使用。没坐标时（macOS）可先用 whereami 取系统精确坐标再调本 skill 的 scripts/amap.sh。Use for any location / map / POI / weather / route / geocoding query; runs under pi, Claude Code, or any shell-capable agent — no MCP server needed.
---

# 高德地图（amap，无需 MCP）

纯 `curl` 调高德 Web 服务 REST，不依赖任何 MCP server，能力全部经 `scripts/amap.sh` 暴露。任何带 shell 的 agent（pi、Claude Code…）都能直接用。

## API Key

`scripts/amap.sh` 自己解析 key，优先级（系统环境变量 > .env）：

1. 环境变量 `$AMAP_KEY`（回退 `$AMAP_MCP_KEY`）
2. 从**当前工作目录向上最近的 `.env`** 里的 `AMAP_KEY=`（回退 `AMAP_MCP_KEY=`）—— 即把 key 放在**项目的 `.env`**，**不随 skill 分发**。

缺 key 时脚本报错并提示如何设置。去[高德开放平台](https://lbs.amap.com/)注册「Web 服务」类型的 key（需实名）。

## scripts/amap.sh 命令

`location` 一律 `经度,纬度`。返回原始高德 JSON（`status:"1"` 为成功）。无参运行打印完整用法。

| 命令 | 说明 | 原 MCP 工具 |
|---|---|---|
| `geo <address> [city]` | 地址→经纬度 | `maps_geo` |
| `regeocode <lng,lat>` | 经纬度→行政区划地址 | `maps_regeocode` |
| `around <lng,lat> [kw] [radius]` | 周边搜 POI | `maps_around_search` |
| `text <kw> [city] [citylimit]` | 关键词搜 POI | `maps_text_search` |
| `detail <poiid>` | POI 详情 | `maps_search_detail` |
| `weather <city\|adcode> [base\|all]` | 天气 | `maps_weather` |
| `driving <o> <d>` | 驾车路径 | `maps_direction_driving` |
| `walking <o> <d>` | 步行路径 | `maps_direction_walking` |
| `bicycling <o> <d>` | 骑行路径 | `maps_direction_bicycling` |
| `transit <o> <d> <city> [cityd]` | 公交/地铁（跨城需 city/cityd） | `maps_direction_transit_integrated` |
| `distance <origins> <dest> [type]` | 距离测算（type 0直线/1驾车/3步行） | `maps_distance` |
| `ip [ip]` | IP 定位 | `maps_ip_location` |
| `raw <path> [k v ...]` | 透传任意 v3/v4 接口 | — |
| `doctor [--refresh]` | 校验 key + 缓存实时工具清单 | — |

### 工作原理（重要）

- **热路径直连 REST**：`amap.sh weather 北京` 直接打 `restapi.amap.com`，**不碰 MCP、不拉接口文档**。上表的「命令 → REST 接口」映射是**打包时**由高德 MCP 的 `tools/list` 编译固化进脚本的。
- **`doctor` = 缓存式自描述**：想看高德当前暴露哪些工具/参数，跑 `amap.sh doctor`——它一次性向 `mcp.amap.com` 拉 `tools/list` 缓存到本地（`~/.cache/amap-agent-skill/tools.json`），`--refresh` 重拉。**仅用于发现，不在 query 主路径上**（`tools/list` 不返回 REST 地址，所以日常 query 无需它）。

## 定位规则（基于位置的问题）

用户需要基于位置的结果（「我在哪」「附近的…」「到 X 怎么走」「今天天气」）但**没给坐标**时，先拿到精确坐标再调 `amap.sh`。**别默认用 IP 定位**——挂代理/VPN 时公网 IP 在境外，高德 IP 定位会定到错误城市。

### 取坐标

- **macOS（推荐）**：用 [whereami](https://github.com/lassik/whereami) 走系统定位（CoreLocation，WiFi/GPS），**与代理/出口 IP 无关**，挂 VPN 也准：
  ```bash
  /Applications/whereami.app/Contents/MacOS/whereami --json
  # → {"latitude":31.246,"longitude":120.698,"accuracy":40,"address":{…}}
  ```
  binary 不在该路径时依次试 `$WHEREAMI_PATH` / `/opt/homebrew/bin/whereami` / `/usr/local/bin/whereami`。
- **非 macOS / 无 whereami**：让用户给坐标或地名（`amap.sh geo <地名>`），或**明确标注「基于 IP，挂代理可能不准」**后用 `amap.sh ip`。

### 喂给 amap.sh

⚠️ 高德 `location` 一律 **`经度,纬度`（longitude 在前）**，别写反。用坐标拼 `${longitude},${latitude}`：

```bash
S="$(dirname "$0")/scripts/amap.sh"   # 或 skill 内相对路径 scripts/amap.sh
LOC="120.698,31.246"
"$S" regeocode "$LOC"             # 我在哪：逆地理
"$S" around "$LOC" 咖啡 1000      # 附近的咖啡
```

### 坐标系注意

whereami/GPS 返回 **WGS-84**，高德用 **GCJ-02（火星坐标）**，国内两者有约几百米偏移：

- 市/区级（`regeocode`、`weather`）：偏移可忽略，直接用。
- 街道/门牌/POI 级（`around` 找最近的店）：可能偏几百米，精度要紧时跟用户说明或做 WGS-84→GCJ-02 转换。

## 可视化输出

需要对比/出图（如多套房子的通勤与价格对比、行程路线）时：

1. **优先生成 SVG 文件**（自包含、可双击打开，像 `examples/星合广场租房简图.svg` 那样：地铁示意 + 对比卡片）。
2. **降级**：若当前 harness/终端**无法内联渲染 SVG**，就在回复里**直接给简化版**——markdown 表格或 ASCII 示意图。
3. **始终附文本摘要**：无论是否出 SVG，回复都要带一段文字结论（哪个更优、关键数字），**绝不只依赖 SVG 被渲染**。
