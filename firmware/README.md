# XU316 固件开发指南（ASIO-CARD · 直播声卡）

> **2026-09-05 审阅：编译成功不代表整机控制链可用。** 实际实现、二进制证据、跨tile/VU/UART缺陷及检查边界统一见[固件审阅](../docs/firmware-review-2026-09-05.md)。

> 基线：官方参考项目 [xmos/sw_usb_audio](https://github.com/xmos/sw_usb_audio) **v9.2.0**（已克隆至 `firmware/sw_usb_audio`，只读上游）。
> 官方说明：v9.2.0 使用 **XTC Tools 15.3.1** 构建与测试，其他版本不保证可用。
> 配套文档：硬件方案在 `../docs/`（原理图分模块 + BOM），控制协议见 `../docs/schematic/05-control.md` §5.4。

---

## 0. 环境选型结论（Linux or Windows）

**推荐：Windows 原生为主，WSL2 只做可选编译备用通道。** 理由：

1. **ASIO 是 Windows 主机侧技术**。XMOS 的 ASIO 驱动（Thesycon 提供、XMOS 签名）只运行在 Windows；Linux/macOS 走内核 UAC2（ALSA），没有 ASIO 概念。你要验证 ASIO，主机必须是 Windows。
2. **xTAG 烧录/调试走 USB，Windows 即插即用**。WSL2 里访问 xTAG 要 usbipd-win 透传，每次插拔都要重新 attach，XMOS 官方明确不支持 WSL2。
3. **XTC 工具链 Windows 版官方完整支持**（含 VS Code 扩展的一键构建/烧录/调试）；Linux 版官方只支持 Ubuntu 20.04/22.04 x64——你现有 WSL 发行版是 **Arch Linux，不受支持**。

| 场景 | 结论 |
|---|---|
| 日常固件开发（编译/烧录/调试） | **Windows 原生**（本指南主线） |
| ASIO 验证（控制面板/REAPER/DAW） | **Windows 原生**（驱动只在这） |
| WSL2 编译（可选） | 需另装 Ubuntu-22.04 发行版，见 `../scripts/setup-wsl-ubuntu.sh`；不建议日常使用 |
| Linux 主机听声测试（可选） | 任意 Linux 免驱识别 UAC2，但与 ASIO 无关 |

---

## 1. 目录结构

```
asio-sound-card/
├── docs/                    硬件方案（原理图分模块、BOM、数据手册）
├── firmware/
│   ├── sw_usb_audio/        官方 v9.2.0 上游（分支 asiocard-dev，含定制应用）
│   │   └── app_usb_aud_asiocard/   定制应用脚手架（6×6 虚拟通道，阶段 2 主体）
│   ├── DESIGN.md            固件设计文档（架构/数据流/混音回环方案/阶段计划）
│   └── README.md            本文档
├── scripts/                 环境与构建脚本（build/setup-xtc/flash + WSL 通道）
├── tools/                   （下载后放这里）XTC 安装包、XMOS USB Audio 驱动；ref/ 参考库
└── host/                    Windows 主机侧资料：ASIO 驱动说明、测试工具清单
```

---

## 2. 工具链安装清单（本机状态 2026-08）

| 组件 | 状态 | 安装方式 |
|---|---|---|
| Git 2.48 | ✅ | 已有 |
| CMake 4.4.2 | ✅ | 已装（winget）。若 XCommon 报兼容错误，降级：`winget install Kitware.CMake --version 3.31.9` |
| Ninja 1.13.2 | ✅ | 已装（winget） |
| VS Code + **XMOS 扩展 `xmos.xtc-tools` v2.12.5** | ✅ | 已装 |
| **XTC Tools 15.3.1**（xcc/xmake/xflash/xrun/xgdb） | ✅ | **已安装**（C:\Program Files\XMOS\XTC\15.3.1）。注意环境变量由 `SetEnv.bat` 提供；`scripts/build.ps1` 已自动处理（普通 PowerShell 直接跑） |
| **XMOS USB Audio 驱动**（Thesycon，含 ASIO + 控制面板） | ❌ **需你操作** | 登录 [xmos.com/software/usb-audio/driver-support/](https://www.xmos.com/software/usb-audio/driver-support/) 下载 Windows 版 |
| **XTAG4 调试器**（硬件） | ❓ 待确认 | **XU316(xcore.ai) 必须用 XTAG4**；XTAG3 只支持 xcore-200 及更早，不支持 XS3 |

> XTC 下载/激活需要一个免费的 xmos.com 账号。安装向导会引导完成 license 激活（免费）。
> 官方安装文档：[XTC Tools Installation Guide](https://www.xmos.com/documentation/XM-014363-PC/html/installation/index.html)。

---

## 3. 首次构建（验证工具链）

安装 XTC 后，打开开始菜单的 **XTC Tools 15.3.1 Command Prompt**，执行：

```bat
cd /d C:\workdir\asio-sound-card\firmware\sw_usb_audio\app_usb_aud_xk_316_mc
cmake -G Ninja -B build
cmake --build build --target app_usb_aud_xk_316_mc_2AMi8o8xxxxxx -j 8
```

- 产出：`build/bin/app_usb_aud_xk_316_mc_2AMi8o8xxxxxx.xe`
- 首次 configure 会自动从 xmos.com 拉取依赖（`lib_xua 5.2.0`、`lib_i2s 6.0.1`、`lib_i2c 6.4.0`、`lib_board_support 1.3.0`，见 `deps.cmake`），**需要联网**（库文件公开，无需登录）。
- 可选配置名（见 `app_usb_aud_xk_316_mc/configs_*.cmake`）：
  - `2AMi8o8xxxxxx`：UAC2/异步/I2S 主，8进8出（官方已测试，**推荐起步**）
  - `2AMi10o10xssxxx`：10进10出 + S/PDIF 收发
  - `2AMi16o16xxxaax`：16进16出 + ADAT 收发
  - `2AMi8o8xxxxxx_mix8_vol_after` / `_mix8_vol_before`：8进8出 + 混音器（MAX_MIX_COUNT=8，混音前后音量两种拓扑）
- 一键等效脚本：`powershell ../scripts/build.ps1 -Config 2AMi8o8xxxxxx`
- 用 VS Code 打开 `app_usb_aud_xk_316_mc` 目录，XMOS 扩展会自动接管构建/烧录/调试（官方流程：[VS Code + USB Audio](https://www.xmos.com/documentation/XM-014363-PC/html/tools-guide/vscode-guide/next-steps/index.html#using-vs-code-with-xmos-usb-multichannel-audio)）。

---

## 4. 烧录与调试

```bat
:: 列出已连接的调试器/目标
xflash -l

:: 工厂镜像（量产/首次烧录，QSPI 启动）
xflash --factory build\bin\app_usb_aud_xk_316_mc_2AMi8o8xxxxxx.xe

:: 升级镜像（保留 DFU 区，可现场升级；需固件带 DFU 支持）
xflash --upgrade 1 build\bin\app_usb_aud_xk_316_mc_2AMi8o8xxxxxx.xe
```

- 运行时调试：`xrun --xscope build\bin\....xe`（xSCOPE 实时流），VS Code 扩展支持断点调试（xgdb）。
- 板上另有 **CH343P-B → XU316 调试 UART**（xSCOPE UART 1-bit 打印），配合 `xscope` 库的 `debug_printf`。
- **W25Q16JVSNIQ（2MB）注意**：官方 316-MC 的 XN 里 Flash 参数（`NumPages=16384`≈4MB）对应官方板器件；我们 2MB 器件需把 XN 中 `SQIFlash` 的 `NumPages` 改为 `8192`（PageSize=256 / SectorSize=4096 不变），并在首次烧录后核对。XN 的 Flash 段参数在 `app_usb_aud_xk_316_mc/src/core/xk-audio-316-mc.xn` 的 `<ExternalDevices>`。
- xSYS 排针接法：XU316 的 xSYS = RST_N/TDI/TDO/TCK/TMS（+GND），**调试器用 XTAG4**。

---

## 5. ASIO 关键事项（本项目的硬需求）

1. **固件侧不需要"实现 ASIO"**：ASIO 由 Windows 主机驱动提供。固件只要按标准 UAC2.0（异步模式 + 反馈端点）枚举即可——sw_usb_audio 默认即此形态。
2. **评估驱动匹配**：XMOS 评估驱动（Thesycon 5.70.0，含 ASIO 与 XMOS USB Audio Control Panel）匹配 **VID 0x20B1 + XMOS 标准 PID**。316-MC 应用默认 `PID_AUDIO_2=0x0016`（见 `xua_conf.h`），开发阶段**保持默认 VID/PID 即可免改 INF 直接装驱动**。
3. Windows 10/11 自带 UAC2 驱动也能出声（WDM 路径），但**没有 ASIO、没有控制面板**；装 XMOS 驱动后：设备管理器确认 "XMOS USB Audio 2.0 ST..."，控制面板可调采样率/音量/DFU 升级。
4. **验证 ASIO**：REAPER（免费评估版）或 foobar2000 + ASIO 插件，ASIO 设备列表里出现 "XMOS USB Audio 2.0 ST 309x" 类条目即通过。测 44.1/48/96/192k 切换与延迟。
5. **不要用 ASIO4ALL**：官方已知问题（sw_usb_audio#120）——44.1/48k 有 glitch，且 ASIO4ALL 只是 WDM 包装层，用 Thesycon ASIO。
6. **生产许可**：评估驱动仅限开发。量产须向 XMOS（或其 VAR）购买 USB Audio 商用授权 + Thesycon 定制驱动（按你的 VID/PID 签名、通道命名、品牌字符串）。固件源码本身为 XMOS Public Licence v1，开发免费。
7. 通道规划（6进6出）依赖 Thesycon 驱动"按立体声对拆分独立 WDM 设备"的行为——这正是 `docs/schematic/README.md` §4.1 的方案，无需固件额外实现；每对通道的**语义化命名**（Main Monitor/Backing/...）需要在描述符字符串层定制（阶段 5）。

---

## 6. 硬件方案 → 固件配置映射（定制清单）

| # | 硬件事实（来自 docs/） | 固件侧动作（sw_usb_audio） |
|---|---|---|
| 1 | 6进6出虚拟通道（192k/32bit） | `xua_conf.h`：`NUM_USB_CHAN_IN=6`、`NUM_USB_CHAN_OUT=6`、`I2S_CHANS_ADC=2`、`I2S_CHANS_DAC=2`、`MAX_FREQ=192000` |
| 2 | ES9822 2ch ADC，I2S 从模式，MCLK 由 XU316 PLL 输出 | 保持默认 `MCLK_48=512*48000` / `MCLK_441=512*44100`（= 24.576/22.5792MHz，随采样率族自动切换，与文档 D7 一致）；MCLK 输出引脚在 XN 映射到原理图引脚 |
| 3 | ES9039Q2M 带 ASRC（100MHz 晶振），无需 MCLK | 固件不输出 MCLK 给 DAC；DAC 侧 I2S 主模式输出即可。DAC 寄存器配置全由 ESP32 管，**XU316 不碰 I2C** |
| 4 | ESP32-S3 承担全部慢速控制（I2C 配置 ES 芯片、PGA2500 SPI、继电器） | 删除/重写官方 `audiohw.xc` 中的 codec I2C 初始化（`xk_audio_316_mc_ab_AudioHwInit`）；XU316 只保留 I2S + MCLK + UART |
| 5 | XU316↔ESP32 UART 协议（05-control §5.4：混音矩阵/VU/事件） | 新增控制任务：921600-8N1 帧解析（0xAA/CMD/LEN/CRC8/0x55）、混音电平 0~255→系数、VU 上报 30~50Hz、限幅参数 |
| 6 | 混音矩阵 5源×2目的地 + 双回环（Stream Mix、Host Loopback） | `MIXER=1` + `MAX_MIX_COUNT>0`（参考官方 mix8 配置）；USB→USB 回环需定制 audiostream 路由（框架默认不提供，属核心开发项） |
| 7 | 总线限幅器（-3dBFS 软拐点）、话筒 EQ/压缩（可选） | lib_dsp：混音总线后接 limiter（参考 AN02026 Blocked DSP 模式） |
| 8 | XU316-1024-**QF60A**（QFN-60）封装 | XN 的 `Package` 类型改为 QF60A（官方 316-MC XN 是 TQ128！）。参考 XK-EVK-XU316 的 XN（在 lib_board_support 里，首次 cmake 配置后见 `build/_deps`） |
| 9 | 24MHz 无源晶振 | XN `Oscillator="24MHz"` 不变（与官方板一致） |
| 10 | W25Q16JVSNIQ 2MB QSPI Flash | XN `SQIFlash` 参数 `NumPages=8192`；首次焊接后 `xflash` 实测支持（Winbond 系需 QE 位，libquadflash 通常自动处理，烧录后回读验证） |
| 11 | USB 经 CH334U Hub 下游1 进 XU316 | 固件无感（Hub 透明）；描述符保持总线供电 `XUA_POWERMODE_BUS`、最大电流按功率预算 |
| 12 | 产品字符串 | `PRODUCT_STR_A2` → `"ASIO-CARD (UAC2.0)"` 等 |
| 13 | 调试串口 CH343P-B ↔ XU316 2 个 1-bit 端口 | xSCOPE UART 端口映射在 XN/任务配置（引脚未定，等原理图定稿回填） |

> ⚠️ **前置依赖**：I2S/UART/QSPI/xSYS 的**最终引脚映射以原理图定稿为准**（`docs/schematic/02-xu316-core.md` §2.2 目前是功能分配）。XN 端口表要等画完 S3 页后一次性回填，期间可先用 XK-AUDIO-316-MC 官方 XN 做软件功能开发（阶段 1-3 不依赖自己的板子）。

---

## 7. 开发路线图

| 阶段 | 内容 | 验证标准 |
|---|---|---|
| 0 ✅ | 环境 + 上游基线 v9.2.0 + 设计文档 `DESIGN.md` + 定制应用脚手架 `app_usb_aud_asiocard`（分支 `asiocard-dev`，未编译验证） | 结构齐备 |
| 1 | 官方 `2AMi8o8xxxxxx` 原样构建 → xflash 烧录（先可用 XK-AUDIO-316-MC 开发板，或等自己的板子最小系统）；随后构建 `app_usb_aud_asiocard` 2AMi6o6xxxxxx | Windows 枚举出 UAC2 设备 + XMOS 驱动装好 + REAPER 出 ASIO |
| 2 | 定制 app 收尾：XN 引脚回填（原理图 S3 定稿后，现为占位 `asiocard.xn`）、W25Q16JV 实测、audiohw 核对（`sw_pll_fixed_clock` 路径） | 自板出声、48k/192k 切换正常 |
| 3 | 混音器配置 + 双回环路由（audiostream 定制） | OBS 采 Stream Mix 得到全混合流；DAW 采 Mic 得干声 |
| 4 | UART 控制任务（协议 05-control §5.4）+ xSCOPE 调试打印 | ESP32 联调：电平/增益/预设/VU 全通 |
| 5 | 通道语义命名、限幅器调参、DFU 升级镜像、稳定性（断连/挂起/爆音） | 6.5 打样验证清单全绿 |

---

## 8. 关键参考链接

- 源码仓库：[xmos/sw_usb_audio](https://github.com/xmos/sw_usb_audio)（v9.2.0，本机已克隆）
- 工具下载：[XMOS Software Tools](https://www.xmos.com/software-tools/)（登录，XTC 15.3.1）
- 安装文档：[XTC Tools Installation Guide](https://www.xmos.com/documentation/XM-014363-PC/html/installation/index.html)
- 构建系统：[XCommon CMake 文档](https://www.xmos.com/view/xcommon-cmake-Documentation)
- ASIO 驱动：[USB Audio Driver Support](https://www.xmos.com/software/usb-audio/driver-support/)（登录）
- 官方板原理图（S3 页金标准）：[xmos/xk_audio_316_mc](https://github.com/xmos/xk_audio_316_mc)
- DFU 应用笔记：AN02019；DSP 应用笔记：AN02026（xmos.com 文档中心）
