# 立创 EDA 专业版 AI 环境

配置日期：2026-09-05。选择 `zhoushoujianwork/easyeda-agent` **v1.3.0**，连接本机嘉立创 EDA 专业版 **3.2.181**。这是第三方开源连接器，通过官方扩展 API 操作专业版；不是标准版 JSON 转换工具。

## 当前验收状态

| 项目 | 状态 |
|---|---|
| Windows CLI、连接器安装包 | 已下载并按 Release SHA256 校验 |
| daemon | 已启动，`127.0.0.1:60832`，`v1.3.0` |
| MCP | 已注册到 Codex 全局配置，独立 stdio 握手成功 |
| 工具发现 | 11 个 MCP 工具、118 个非 debug typed actions |
| 上游 MCP 测试 | 5 / 5 通过 |
| MCP 依赖审计 | 修复 3 个传递依赖后 `npm audit` 为 0 |
| 启动脚本 | Windows PowerShell 5.1 和 PowerShell 7 均运行通过；已验证 daemon 关闭后由 MCP 自动启动 |
| EDA 扩展实机连接 | **已通过**；专业版 3.2.181，连接器 1.3.0，`connectorVersionOk=true` |
| EDA 运行模式和权限 | 半离线；允许外部交互已开启；连接器自动更新已关闭 |
| easyeda-agent Skill | v1.3.0 已安装到 `C:\Users\Keven\.codex\skills\easyeda-agent` |
| 双电阻回归 S0 | `spec validate --strict` 通过：ERROR 0 / WARN 0 / INFO 1（单功能域，不评 PCB flow-order） |
| 原理图实际放件、连线、保存重开 | **已通过**；原生工程含 2 个真实 C25804 / 10k 电阻，保存并重新加载后四脚网络与黄金表一致 |
| 真实 MCP → EDA 读取 | **已通过**；`schematic.read` 经 MCP / CLI / daemon / connector 读取真实图页 |
| 原理图严格门 | **FAIL，明确保留**；布局、分组、结构、桥接检查全 PASS；原生 DRC 0 error / 2 warn |

本次客户端连接验收的 `windowId` 为 `a0579eb0-64fc-4f44-a394-720290ab912f`，CLI / daemon / connector 均为 v1.3.0。窗口 ID 会随客户端重启改变，不应固化在日常绘图脚本。

`daemon health` 在没有客户端连接时仍可能输出“版本一致”。后续自检必须同时检查 **windows 非空**，再读取目标工程/图页；不要仅凭 daemon 存活判定 EDA 已连接。

独立回归工程使用 **ASIO_AI_ENV_SMOKE**，S0 文件为 `hardware/ai-smoke/s0-smoke.json`：一张 A4 `DIVIDER` 页、两个 10k 电阻、VIN/VOUT/GND 三个网络，用于真实放件和持久化验收，不是声卡生产原理图。此文件的 `notes.goldenPinNets` 保存预期逐脚连接；`spec validate` 仅验证方案字段，不替代实机网表比对。

本次生成了原生工程 [ASIO_AI_ENV_SMOKE.eprj2](../hardware/ai-smoke/ASIO_AI_ENV_SMOKE.eprj2)，以及 [PNG 预览](../hardware/ai-smoke/divider.png)、[SVG 导出](../hardware/ai-smoke/divider.svg)和[原生网表](../hardware/ai-smoke/divider.enet)。[重新加载后的读取记录](../hardware/ai-smoke/read-after-reload.json)与[真实 MCP 回读验证](../hardware/ai-smoke/mcp-readback-verification.json)确认：`R1.1=VIN`、`R1.2=VOUT`、`R2.1=VOUT`、`R2.2=GND`。

[最终严格检查原始输出](../hardware/ai-smoke/gate-final.txt)保留 FAIL。客户端 DRC 面板已核实两条警告分别来自 VIN、GND 网络各只有一个元件引脚：它们是该独立分压回归的外部网络端口。此结果可以证明绘图、持久化和网表读取链路正常，**不宣称 strict gate 全通过，也不把警告泛化为生产电路可忽略**。

Windows PowerShell 5.1 的完整连接与 MCP 自检记录在 [environment-check.txt](../hardware/ai-smoke/environment-check.txt)。该文件是连续多段 JSON 的命令输出，不是单一 JSON 文档。

## 本机安装位置

运行时目录：`C:\Users\Keven\AppData\Local\easyeda-agent\v1.3.0`

| 文件/目录 | 用途 |
|---|---|
| `easyeda_windows_amd64.exe` | Go CLI / daemon，无需安装 Go |
| `easyeda-agent-connector.eext` | 需要导入专业版的扩展安装包 |
| `checksums.txt` | 上游 Release 校验清单 |
| `mcp/src/server.mjs` | v1.3.0 源码中的 MCP 适配器 |
| `mcp/launcher.mjs` | 本项目增加的启动入口：检查 daemon，必要时隐藏启动，再启动 MCP |
| `mcp/check-mcp.mjs` | 协议握手、工具清单、动作发现与 health 检查 |
| `start-easyeda-ai.ps1` | 与仓库脚本一致的运行时副本，避免 MCP 依赖仓库路径 |
| `logs/daemon.stdout.log`、`logs/daemon.stderr.log` | daemon 日志 |

EDA 程序：`C:\Program Files\lceda-pro\lceda-pro.exe`。
Node：`C:\nvm4w\nodejs\node.exe`，本次实测 `v24.2.0`；MCP 要求 Node ≥20.17。
源码参考固定在 `tools/ref/easyeda-agent` 的 `v1.3.0`，提交 `e1c5af7`。

Release 资产 SHA256：

```text
easyeda_windows_amd64.exe
e5369f6ca2f44a5f9d6d0ca20681f9d18853763fd34e3fbffba721acb4e9f7df

easyeda-agent-connector.eext
57ea2c4f1e84e3c0bab11695678efe2fff82308fc9ff7d466ddf62e311b58bf7
```

下载出处：[v1.3.0 Release](https://github.com/zhoushoujianwork/easyeda-agent/releases/tag/v1.3.0)。Windows 直接使用 Release exe；上游 `install.sh` 只接受 Linux/macOS。

## 使用

启动本地 daemon：

```powershell
powershell -NoProfile -File C:\workdir\asio-sound-card\scripts\start-easyeda-ai.ps1
```

检查文件校验值、版本、连接以及 MCP：

```powershell
powershell -NoProfile -File C:\workdir\asio-sound-card\scripts\check-easyeda-ai.ps1 -McpSmokeTest -NodePath C:\nvm4w\nodejs\node.exe
```

要求客户端真正连上才通过：

```powershell
powershell -NoProfile -File C:\workdir\asio-sound-card\scripts\check-easyeda-ai.ps1 -RequireConnector
```

MCP 入口会自动检查和启动 daemon，无需每次手工打开终端。没有设置登录启动项或系统服务。daemon 使用 `--auto-update-skill=false`，避免以后启动时擅自升级 Skill、造成组件版本漂移。

## EDA 客户端步骤

1. 打开专业版 3.2.181，进入“高级 → 扩展管理器”。
2. 导入 `C:\Users\Keven\AppData\Local\easyeda-agent\v1.3.0\easyeda-agent-connector.eext`，启用 **EDA Agent Connector**。
3. 在该扩展权限中允许外部交互。根据客户端界面，检查全局相关设置是否开启。
4. 在 **EDA Agent → Reconnect** 连接；扩展 UUID 为 `4dae27407c1d43be98e8e210d45fe587`。
5. 打开或创建一个原理图工程，运行上面的 `-RequireConnector` 验收。

扩展 manifest 声明 `eda: ~3.2.0`，覆盖本机 3.2.181；最终兼容性以实机操作为准。升级侧载扩展后需要完全退出 EDA 再打开。

官方步骤：[扩展的获取和使用](https://prodocs.lceda.cn/cn/api/user-guide/using-extension.html)；连接器声明：[v1.3.0 extension.json](https://github.com/zhoushoujianwork/easyeda-agent/blob/v1.3.0/extension/extension.json)。

本次使用**半离线模式**：工程和个人库在本地，能使用云系统器件库，官方说明无需登录。全离线模式也能保存本地工程，但云系统库不可用。[官方客户端说明](https://prodocs.lceda.cn/cn/faq/client/)

本机 3.2.181 实际生成的原生工程后缀为 **`.eprj2`**，由客户端编辑保存；应保留真实后缀，不改名为文档中旧式 `.eprj`。`.epro` 是导入/导出工程包用途，CLI/MCP 的编辑动作仍需连接正在运行的 EDA 客户端。

## Codex MCP 配置

已由 `codex mcp add easyeda-agent` 写入 `C:\Users\Keven\.codex\config.toml`，条目如下。未修改其他 MCP 服务。

```toml
[mcp_servers.easyeda-agent]
startup_timeout_sec = 30
tool_timeout_sec = 300
command = 'C:\nvm4w\nodejs\node.exe'
args = ['C:\Users\Keven\AppData\Local\easyeda-agent\v1.3.0\mcp\launcher.mjs']

[mcp_servers.easyeda-agent.env]
EASYEDA_BIN = 'C:\Users\Keven\AppData\Local\easyeda-agent\v1.3.0\easyeda_windows_amd64.exe'
```

原配置备份：`C:\Users\Keven\.codex\config.toml.before-easyeda-agent-20260905-215419.bak`。若当前会话没有发现新工具，在 Codex 的 MCP 设置中重启服务，或重启 Codex 后进入任务。

MCP 工具：`easyeda_health`、`easyeda_actions`、`easyeda_artifact`、`easyeda_board`、`easyeda_document`、`easyeda_pcb`、`easyeda_project`、`easyeda_schematic`、`easyeda_system`、`easyeda_blocks`、`easyeda_workflow`。

先通过 `easyeda_actions` 查询准确 action 和 payload，再调用领域工具。写操作需明确 `project` 和 `doc`；多窗口要提供 `window`。此适配器不暴露任意 JS 调试入口。上游 MCP 自身的版本字段仍是 `0.18.3`，这是 v1.3.0 tag 原有元数据，不代表 CLI/连接器装错版本。[上游 MCP 说明](https://github.com/zhoushoujianwork/easyeda-agent/blob/v1.3.0/mcp/README.md)；[OpenAI MCP 配置说明](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)。

## 已知边界与维护

- v1.3.0 有 `createNetLabel` 超时报告；先使用真实导线加 `netport` / `netflag`，并读回网表验证。[上游 #191](https://github.com/zhoushoujianwork/easyeda-agent/issues/191)
- 原理图放件、导线、网络和文档生命周期可走类型化动作；自动布局后仍要运行 `sch check`、`bridge-check`、官方 DRC，并保存、重开、对比网表。不能把几何相邻当成电气连接。[原理图动作参考](https://github.com/zhoushoujianwork/easyeda-agent/blob/v1.3.0/docs/cli/schematic.md)
- PowerShell 5.1 直接传 JSON 给 exe 有引号问题。MCP 使用 Node `execFile` 参数数组，已通过结构化 payload 测试。直接 CLI 操作优先用明确 flag。
- 自检脚本针对 PowerShell 5.1 的 `NativeCommandError` 行为作了局部处理：CLI health 的成功提示会写入 stderr，仅在该调用期间忽略此流，立即捕获原生退出码后恢复严格错误处理；失败退出码、JSON 解析或版本不一致仍会失败。
- 本次在 v1.3.0 MCP 安装副本里更新兼容传递依赖：`fast-uri 3.1.5 → 3.1.7`、`hono 4.12.33 → 4.13.7`、`qs 6.15.3 → 6.16.0`。SDK 保持 `1.30.0`。上游源码未改，实际依赖锁文件位于运行时 `mcp/package-lock.json`。
- CLI、连接器和 Skill 应按同一 Release 升级；市场扩展可能滞后，先检查版本，不能只更新其中一项。[上游快速开始](https://github.com/zhoushoujianwork/easyeda-agent/blob/v1.3.0/docs/quick-start.md)

本环境安装及协议验收不会改变 ASIO 声卡的电路。进入正式绘图前，以整理后的设计基线、器件数据手册和逐脚连接表为输入；原理图可编辑、ERC/DRC 通过与可投板是不同验收阶段。
