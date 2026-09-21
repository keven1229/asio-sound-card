# AI 绘图环境验收

2026-09-05 在本机嘉立创 EDA 专业版 3.2.181 半离线模式中，由 easyeda-agent v1.3.0 生成。

这是独立的**环境测试工程**，电路为两个 10kΩ 电阻的分压器。它不属于声卡电路，没有制造用途。

| 产物 | 用途 |
|---|---|
| [ASIO_AI_ENV_SMOKE.eprj2](ASIO_AI_ENV_SMOKE.eprj2) | 可直接在专业版打开的原生工程；图页 `DIVIDER` |
| [divider.svg](divider.svg) | EDA 官方导出的原理图预览 |
| [divider.enet](divider.enet) | EDA 原生网表 |
| [s0-smoke.json](s0-smoke.json) | 放件前保存并通过 strict 校验的测试方案 |
| [read-after-reload.json](read-after-reload.json) | 保存、关闭图页、重新打开后的实际元件与网络读回 |
| [mcp-readback-verification.json](mcp-readback-verification.json) | 经MCP调用真实EDA读取，验证2件器件、3个网络及4个引脚匹配 |
| [gate-final.txt](gate-final.txt) | 最终检查原文，保留 strict 未过及原因 |

实际验证：云系统库精确查到 LCSC `C25804`（10kΩ/0603），放置 R1/R2，添加真实导线及 VIN/VOUT/GND 标记，填写图签、分区和说明，保存后通过 `doc reload` 关闭并重开图页。重新读回四个引脚与事前黄金表一致：

| 引脚 | 网络 |
|---|---|
| R1.1 | VIN |
| R1.2 | VOUT |
| R2.1 | VOUT |
| R2.2 | GND |

最终 `layout-lint`、`clusters`、`check`、`bridge-check` 均通过。原生 DRC **0 致命、0 错误、2 告警**，在客户端 DRC 面板核实为 VIN 和 GND 各只有一个元件引脚。两者是此独立测试电路的外部端口，未配置实体接插件；没有忽略/关闭 DRC 规则。由于 `--strict` 将告警视为失败，完整 strict gate 仍为 **FAIL**；本结果证明环境可绘图和读回，不是可投板验收。

初始检查与放件阶段记录保留在本目录供排查；`read-before-wiring.json` 的悬空脚和初始版式检查失败是已修复的中间状态。自动放说明文字时出现框外布局，本轮通过精简说明并指定实际框内位置修正；再次结构检查为零问题。

保持此原生工程在EDA中打开，可重复运行只读MCP验收：

```powershell
node C:\workdir\asio-sound-card\scripts\easyeda-ai\verify-smoke.mjs
```
