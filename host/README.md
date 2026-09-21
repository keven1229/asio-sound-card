# 主机侧（Windows）资料

> **2026-09-05 审阅：下文驱动版本和多设备行为是旧方案记录，未完成本机设备验收。** 当前状态与需验证项见[固件审阅](../docs/firmware-review-2026-09-05.md)，不要把6ch UAC2直接等同三个独立Windows设备。

> 本目录放主机侧工具与说明：ASIO 驱动、验证软件、截图记录。

## 1. ASIO 驱动（必需，登录下载）

- 下载：https://www.xmos.com/software/usb-audio/driver-support/ （xmos.com 账号登录）
- 包内含：
  - **XMOS USB Audio 2.0 Driver**（Thesycon 5.70.0，WDM + **ASIO**）
  - **XMOS USB Audio Control Panel**（采样率/音量/DFU 升级入口）
- 匹配条件：设备 VID=0x20B1 + XMOS 标准 PID（开发阶段保持固件默认 PID 0x0016 即可免改 INF）。
- 安装顺序：先装驱动 → 再插设备（或设备管理器里右键更新驱动指向安装目录）。

## 2. ASIO 验证工具（免登录）

| 工具 | 用途 |
|---|---|
| REAPER（reaper.fm，免费评估） | ASIO 设备选择、采样率切换、往返延迟实测 |
| foobar2000 + foo_out_asio | 播放路径 ASIO 验证 |
| XMOS USB Audio Control Panel | 设备状态、DFU 固件升级 |

## 3. 验证清单（阶段 1 完成标准）

- [ ] 设备管理器：XMOS USB Audio 2.0 ST 309x（无黄色感叹号）
- [ ] 控制面板：采样率 44.1/48/96/192k 可切换
- [ ] REAPER：ASIO 设备出现且可出声/录音
- [ ] 直播链路：OBS 选 "Stream Mix" 录音设备能采到混音流（阶段 3 后）
