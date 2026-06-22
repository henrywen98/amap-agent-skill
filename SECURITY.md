# 安全策略

## API Key 处理

- 本仓库**不含**任何真实高德 key，只有 `.env.example` 占位。
- key 解析优先级：环境变量 `AMAP_KEY`（回退 `AMAP_MCP_KEY`）> 项目 `.env`。`.env` 已在 `.gitignore`，不会入库。
- **不要**把真实 key 写进任何会提交的文件、命令历史或截图。
- 强烈建议在[高德控制台](https://console.amap.com/)给你的 key 设置**域名/服务白名单 + 配额**，即使泄露也能限制被盗刷。
- 若 key 曾意外暴露（提交历史、聊天、日志），到控制台**重置/轮换**即可。

## 报告漏洞

请通过 GitHub 的 **Security → Report a vulnerability**（私有 Security Advisory）私下报告，**不要**在公开 issue 里贴 PoC 细节。
