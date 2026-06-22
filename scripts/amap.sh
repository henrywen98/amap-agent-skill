#!/usr/bin/env bash
# amap.sh — MCP-free wrapper over the AMap (高德) Web Service REST API.
#
# Mirrors the maps_* tools of the amap MCP server using plain curl, so it runs
# under any harness with a shell (pi, Claude Code, …) — no MCP server required.
#
# Key resolution (系统环境变量 > .env):
#   1. $AMAP_KEY, then $AMAP_MCP_KEY (env)
#   2. nearest .env walking up from $PWD with AMAP_KEY= (then AMAP_MCP_KEY=)
#      → keep the key in your project's .env; it is NOT bundled with the skill.
#
# location params are always "经度,纬度" (longitude first). Output is raw AMap JSON
# (status:"1" == OK). Run with no args for full usage. `doctor` validates the key
# and caches the live tool list (self-describing, fetched once).
set -euo pipefail

BASE="https://restapi.amap.com"
MCP_URL="https://mcp.amap.com/mcp"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/amap-agent-skill"
CACHE="$CACHE_DIR/tools.json"

# --- resolve key: env first (AMAP_KEY, then AMAP_MCP_KEY), then nearest .env ---
_load_key_from_env_file() {
  local dir="$PWD" f line
  while :; do
    f="$dir/.env"
    if [ -f "$f" ]; then
      line="$(grep -E '^[[:space:]]*(AMAP_KEY|AMAP_MCP_KEY)=' "$f" 2>/dev/null | head -1 || true)"
      if [ -n "$line" ]; then
        line="${line#*=}"
        line="${line%\"}"; line="${line#\"}"
        line="${line%\'}"; line="${line#\'}"
        printf '%s' "$line" | tr -d ' \t\r\n'
        return 0
      fi
    fi
    [ "$dir" = "/" ] && break
    dir="$(dirname "$dir")"
  done
  return 1
}

KEY="${AMAP_KEY:-${AMAP_MCP_KEY:-}}"
[ -z "$KEY" ] && KEY="$(_load_key_from_env_file || true)"
if [ -z "$KEY" ]; then
  echo "ERROR: AMAP key not found." >&2
  echo "  Export it (export AMAP_KEY=...) or add AMAP_KEY=... to your project's .env." >&2
  exit 1
fi

# --- HTTP helper: _call <path> k1 v1 k2 v2 ...  (empty values are skipped) ---
_call() {
  local path="$1"; shift
  local args=()
  while [ "$#" -ge 2 ]; do
    if [ -n "$2" ]; then args+=(--data-urlencode "$1=$2"); fi
    shift 2
  done
  curl -s -G "$BASE$path" --data-urlencode "key=$KEY" "${args[@]+"${args[@]}"}"
}

# --- doctor: validate key + cache the live MCP tool list (self-describing) ---
_doctor() {
  local refresh=0
  [ "${1:-}" = "--refresh" ] && refresh=1
  echo "amap doctor"

  # 1. validate key with a cheap geocode call
  local vstatus
  vstatus="$(_call /v3/geocode/geo address 北京 2>/dev/null | sed -n 's/.*"status":"\([0-9]*\)".*/\1/p' | head -1 || true)"
  if [ "$vstatus" = "1" ]; then
    echo "  key       : OK（geo 测试通过）"
  else
    echo "  key       : FAILED（geo 返回 status=${vstatus:-?}）— 检查 key / 配额 / 白名单" >&2
  fi

  # 2. fetch tools/list once → cache (refresh on demand). The mapping name→REST
  #    is already baked into this script; the cache is for discovery only.
  if [ "$refresh" = "1" ] || [ ! -f "$CACHE" ]; then
    mkdir -p "$CACHE_DIR"
    if curl -s -H "Content-Type: application/json" \
            -H "Accept: application/json, text/event-stream" \
            -X POST "$MCP_URL?key=$KEY" \
            -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' > "$CACHE.tmp" 2>/dev/null \
       && grep -q '"tools"' "$CACHE.tmp"; then
      mv "$CACHE.tmp" "$CACHE"
      echo "  tools/list: 已刷新缓存 → $CACHE"
    else
      rm -f "$CACHE.tmp"
      echo "  tools/list: 拉取失败（不影响日常 query，热路径直连 REST）" >&2
    fi
  else
    echo "  tools/list: 命中缓存 → ${CACHE}（--refresh 重拉）"
  fi

  # 3. summarize (no python: grep tool names out of the cached JSON)
  if [ -f "$CACHE" ]; then
    local n
    n="$(grep -o '"name":"[^"]*"' "$CACHE" 2>/dev/null | wc -l | tr -d ' ')" || n=0
    echo "  工具数    : ${n:-0}"
    grep -o '"name":"[^"]*"' "$CACHE" 2>/dev/null | sed 's/"name":"/    - /; s/"$//' || true
  fi
}

usage() {
  cat >&2 <<'EOF'
amap.sh — 高德 REST 封装（无需 MCP）。location 一律 "经度,纬度"（lng,lat）。

  geo        <address> [city]                 结构化地址 → 经纬度          (/v3/geocode/geo)
  regeocode  <lng,lat>                         经纬度 → 行政区划地址         (/v3/geocode/regeo)
  around     <lng,lat> [keywords] [radius]     周边搜 POI（默认 1000m）      (/v3/place/around)
  text       <keywords> [city] [citylimit]     关键词搜 POI                 (/v3/place/text)
  detail     <poiid>                           POI 详情                     (/v3/place/detail)
  weather    <city|adcode> [base|all]          天气（默认 all=预报）         (/v3/weather/weatherInfo)
  driving    <o_lng,lat> <d_lng,lat>           驾车路径                     (/v3/direction/driving)
  walking    <o_lng,lat> <d_lng,lat>           步行路径                     (/v3/direction/walking)
  bicycling  <o_lng,lat> <d_lng,lat>           骑行路径                     (/v4/direction/bicycling)
  transit    <o> <d> <city> [cityd]            公交/地铁（跨城需 city/cityd）(/v3/direction/transit/integrated)
  distance   <origins> <dest> [type]           距离 type 0直线/1驾车/3步行   (/v3/distance)
  ip         [ip]                              IP 定位（省略=按出口 IP）      (/v3/ip)
  raw        <path> [k v ...]                  透传任意 v3/v4 接口
  doctor     [--refresh]                       校验 key + 缓存实时工具清单（自描述）

Key: $AMAP_KEY（回退 $AMAP_MCP_KEY）优先，否则读 $PWD 起向上最近的 .env。
EOF
}

cmd="${1:-}"
if [ "$#" -gt 0 ]; then shift; fi
case "$cmd" in
  geo)        _call /v3/geocode/geo                   address "${1:?address required}" city "${2:-}" ;;
  regeocode)  _call /v3/geocode/regeo                 location "${1:?location \"lng,lat\" required}" ;;
  around)     _call /v3/place/around                  location "${1:?location required}" keywords "${2:-}" radius "${3:-1000}" ;;
  text)       _call /v3/place/text                    keywords "${1:?keywords required}" city "${2:-}" citylimit "${3:-}" ;;
  detail)     _call /v3/place/detail                  id "${1:?poi id required}" ;;
  weather)    _call /v3/weather/weatherInfo           city "${1:?city or adcode required}" extensions "${2:-all}" ;;
  driving)    _call /v3/direction/driving             origin "${1:?origin required}" destination "${2:?destination required}" ;;
  walking)    _call /v3/direction/walking             origin "${1:?origin required}" destination "${2:?destination required}" ;;
  bicycling)  _call /v4/direction/bicycling           origin "${1:?origin required}" destination "${2:?destination required}" ;;
  transit)    _call /v3/direction/transit/integrated  origin "${1:?origin required}" destination "${2:?destination required}" city "${3:?city required}" cityd "${4:-${3}}" ;;
  distance)   _call /v3/distance                      origins "${1:?origins required}" destination "${2:?destination required}" type "${3:-1}" ;;
  ip)         _call /v3/ip                             ip "${1:-}" ;;
  raw)        p="${1:?path required}"; shift; _call "$p" "$@" ;;
  doctor)     _doctor "${1:-}"; exit 0 ;;
  ""|-h|--help|help) usage; if [ -z "$cmd" ]; then exit 1; else exit 0; fi ;;
  *) echo "unknown command: $cmd" >&2; usage; exit 1 ;;
esac
echo
