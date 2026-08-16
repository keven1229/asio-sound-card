# 模块二：XU316 核心（USB / 时钟 / Flash / I2S / UART）

## 2.1 器件清单

| 位号 | 型号 | 说明 | 立创 | 参考价 |
|---|---|---|---|---|
| U10 | XU316-1024-QF60A-C24 | 主控，QFN-60 | item 6234669（C5375653） | ¥41.07 |
| Y1 | 24MHz 无源晶振 3225（18pF 级） | XU316 系统时钟 | 立创 | ¥0.8 |
| U11 | W25Q16JVSNIQ | QSPI Flash 16Mbit，固件存储 | 立创 | ¥1.3 |
| U12 | TPD4E05U06DQAR（或 PRTR5V0U2X×2） | USB D± ESD 防护 | 立创 | ¥1.5 |
| J2 | xSYS 5-pin 排针（2.54mm） | XTAG 调试口 | | ¥0.5 |
| SW1 | 轻触按键 | 复位 | | ¥0.2 |
| — | 串阻/电容若干 | 见 2.3 | | ¥3 |

## 2.2 引脚功能分配（画图核对表）

> ⚠️ 下表是**功能分配**，具体接到 QF60A 哪个引脚**以 XU316 datasheet 与 xmos/xk_audio_316_mc 官方原理图为准**（官方板的电源/晶振/Flash/USB 接线直接照抄，不会错）。

| 功能 | 网络名 | 方向 | 备注 |
|---|---|---|---|
| USB D+ / D− | `USB_DP/DN`（经 U12） | I/O | 直连 J1；ESD 就近 J1 放置 |
| USB VBUS 检测 | `VBUS_SENSE` | 入(1bit) | V5D 经 2×100k 分压 + 10nF |
| 晶振 | `XTAL_IN/OUT` | — | 24MHz，负载电容按 datasheet |
| QSPI Flash | `QSPI_CS/CLK/D0..D3` | I/O | W25Q16，Flash 型号需 xflash 支持 |
| I2S→ADC | `ADC_BCLK / ADC_LRCK / ADC_MCLK` | 出 | 22Ω 串阻 → ES9822 |
| I2S←ADC | `ADC_DOUT` | 入 | 22Ω 串阻 ← ES9822 |
| I2S→DAC | `DAC_BCLK / DAC_LRCK / DAC_DIN` | 出 | 22Ω 串阻 → ES9039 |
| UART→ESP32 | `CTRL_TX` | 出 | 921600-8N1 |
| UART←ESP32 | `CTRL_RX` | 入 | 921600-8N1 |
| xSYS 调试 | `RST_N / TDI / TDO / TCK / TMS` | I/O | 2×3 排针，XTAG3 |
| 复位 | `RST_N` | 入 | 10k 上拉 V3V3D + 100nF + SW1 到地 |

**引脚预算（QF60A 可用 IO 按 datasheet 实际为准，约 32 个）**：USB 3~4 + 晶振 2 + QSPI 6 + I2S 出 6 + I2S 入 1 + UART 2 + xSYS 5 + RST 1 ≈ 27。**剩余 IO 全部引出到测试排针**（预留：LED 直驱、SPDIF 输出、第二 I2S 扩展）。

> 若 datasheet 实际可用 IO 不足上述预算：优先把 `VBUS_SENSE` 挪给 ESP32（它同样能检测 USB 掉线），或砍 xSYS 的 TDI/TMS 复用。仍不够 → 换 XU216-512-TQ128（TQFP 好焊，淘宝 ¥60-90，固件同一套 sw_usb_audio）。

## 2.3 关键电路

### 电源与去耦（照抄官方板）
- VDD=**V1V0**、VDDIO=**V3V3D**、USB PHY 供电按 datasheet（多为 V3V3D 经磁珠）；
- PLL 供电脚：**V1V0 经磁珠 + 2.2µF + 0.1µF**（模拟敏感点）；
- 每个电源引脚 0.1µF 就近；芯片底部 GND 焊盘按 datasheet 打过孔阵列到地平面。

### 晶振
- 24MHz 基频、CL 按 datasheet（参考官方板取值，一般 18pF 级）；晶振紧贴引脚，下方不穿线。

### QSPI Flash
- W25Q16JVSNIQ：`CS/CLK/D0-D3` 直连，**串阻 22Ω** 于 CLK；`WP#/HOLD#` 上拉 V3V3D。
- ⚠️ 首次焊接后用 `xflash --list-devices` 确认支持；备选：官方板同款 IS25LP080D。

### USB
- U12 TPD4E05U06：DP/DN 各一路对 GND，紧贴 J1；线宽差分走线，等长、包地。

### 复位与启动
- RST_N：10k 上拉 + 100nF 到地 + SW1；上电后 ESP32 亦可经开漏输出拉低（程序下载/复位联动）。
- 启动模式：QF60A 由 ROM 引导，默认从 QSPI 启动；如 datasheet 有 boot-select 引脚，按官方板接法加跳线。

## 2.4 固件侧对应关系（sw_usb_audio）

| 固件模块 | 内容 |
|---|---|
| 描述符 | 4 路输入 / 2 路输出，192kHz/32bit，异步模式（反馈端点） |
| Mixer | 在默认 mixer 应用基础上改：`话筒+备用+USB播放 → 监听`；`USB播放回灌 → 捕获ch3/4（loopback）` |
| DSP | lib_dsp：Mix 总线限幅器（阈值 -3dBFS、软拐点），话筒通道可选 EQ/压缩 |
| 控制通道 | UART 任务接收 `CTRL_RX` 协议（见 05-control），上报 VU 电平 30~50Hz |
| MCLK | 内部 PLL 输出到 `ADC_MCLK`，随采样率族自动 24.576/22.5792MHz |

**端口映射**：I2S/UART 具体用哪些 xCORE port（`X0Dxx`）在 `sw_usb_audio` 的端口定义文件中配置，与本文 2.2 表一一对应即可；画图时把最终映射表回填到原理图注释里，方便日后维护。

## 2.5 布局红线

1. 24MHz 晶振与 QSPI CLK 远离模拟区；
2. USB D± 差分对等长，参考地完整，ESD 先于走线；
3. XU316 底部散热/地焊盘密集过孔；
4. I2S 信号组等长（±2mm 内），串阻 22Ω 放在源端。
