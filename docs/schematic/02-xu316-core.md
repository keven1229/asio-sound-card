# 模块二：XU316 核心（USB / 时钟 / Flash / I2S / UART）

> **2026-09-06 参数勘误已回写；完整电路仍未冻结。** 核心0.900V（0.855–0.945V）、全部IO为1.8V；逐参数/引脚证据见[数字器件核验](../datasheet-audit/digital-protection.md)，全量入口见[datasheet核验](../datasheet-audit/README.md)。

## 2.1 器件清单

| 位号 | 型号 | 说明 | 立创 | 参考价 |
|---|---|---|---|---|
| U10 | XU316-1024-QF60A-C24 | 主控，QFN-60 | item 6234669（C5375653） | ¥41.07 |
| Y1 | 24MHz 无源晶振 3225（18pF 级） | XU316 系统时钟 | 立创 | ¥0.8 |
| U11 | 待选1.8V QSPI Flash | 旧W25Q16JV为3V器件，不能直接使用；待完整手册与xflash启动核验 | 待定 | 待定 |
| U12 | PRTR5V0U2X（友台 UMW，双通道仅 D±，上游 J1 处统一做，见 07-usb-c） | USB D± ESD 防护 | C5158049 | ¥0.13 |
| J2 | **xSYS2 排针 1.27mm(0.05") 2×5**（JTAG 半尺寸）或 2×10（含 xSCOPE 全尺寸） | XTAG4 调试口（**仅 XTAG4 及以上，1.8V 电平**） | | ¥0.5 |
| SW1 | 轻触按键 | 复位 | | ¥0.2 |
| — | 串阻/电容若干 | 见 2.3 | | ¥3 |

## 2.2 引脚功能分配（画图核对表）

> 下表是功能规划。精确封装须限定QF60A，不能把QF60B/TQ128/参考板的3.3V IO等接法直接搬入；固定电源与启动脚已在下文核对，音频/UART最终port映射仍需和固件逐脚签核。

| 功能 | 网络名 | 方向 | 备注 |
|---|---|---|---|
| USB D+ / D− | `USB_DP/DN`（经内置 Hub 下游1） | I/O | ← CH334U 下游1（90Ω 差分，短而直）；ESD 在 J1 上游统一做（07-usb-c） |
| USB VBUS 检测 | `VBUS_SENSE` | 入(1bit) | 检测真实VUSB；原厂1.8V示例上臂220k/下臂100k，5V时约1.5625V；另核泄放、入口电容和掉电反灌 |
| 晶振 | `XTAL_IN/OUT` | — | 24MHz，负载电容按 datasheet |
| QSPI Flash | `QSPI_CS/CLK/D0..D3` | I/O | W25Q16，Flash 型号需 xflash 支持 |
| I2S→ADC | `ADC_BCLK / ADC_LRCK / ADC_MCLK` | 出 | 22Ω 串阻 → ES9822。**⚠️ ADC_MCLK 网络需同时连到 XU316 两个 tile 各一个引脚**：tile1 输出 MCLK（固件 `PORT_MCLK_IN`），tile0 收同一 MCLK 作 USB 反馈计数时钟（固件 `PORT_MCLK_IN_USB` + `PORT_MCLK_COUNT`，框架硬要求，见 firmware/DESIGN.md §2.1 事实 #6/#7；官方 316-MC 板即此接法） |
| I2S←ADC | `ADC_DOUT` | 入 | 22Ω 串阻 ← ES9822 |
| I2S→DAC | `DAC_BCLK / DAC_LRCK / DAC_DIN` | 出 | 22Ω 串阻 → ES9039 |
| UART→ESP32 | `CTRL_TX` | 出 | 921600-8N1 |
| UART←ESP32 | `CTRL_RX` | 入 | 921600-8N1 |
| 调试 UART | `DEBUG_TX/DEBUG_RX` | 出/入 | CH343P-B独立COM日志；XU侧1.8V电平必须匹配。这不是xLINK/XTAG形式的xSCOPE，RX功能尚未实现 |
| xSYS2 调试 | `TMS/TCK/TDO/TDI/RST_N/VREF` | I/O | **⚠️ 不是老 xSYS 2.54mm！** xSYS2 = 1.27mm(0.05")、1.8V 电平、仅 XTAG4（XTAG3 不支持 XS3 也不支持 xSYS2）。JTAG 半尺寸 2×5 接法（官方 QF60A datasheet）：**pin1→VDDIOB18(V1V8, 就近去耦), pin2→TMS, pin3/5/7/9→GND, pin4→TCK, pin6→TDO, pin8→TDI, pin10→RST_N**。xSCOPE 全尺寸再加：pin11→VDDIOR、pin12→XL0in1、pin14→XL0in0、pin16→XL0out0、pin18→XL0out1（XL0out× 各串 43Ω 近芯片）。最小方案可选 TAG-connect 6 测试点（TC2030-IDC 线） |
| 复位 | `RST_N` | 入 | pin21，拉至V1V8；低脉冲至少5µs，释放前所有IO轨有效；外部MCU仅用合规开漏/转换接口控制 |

**引脚预算**：QF60A手册列34个GPIO；USB、晶振、JTAG等专用脚不能与GPIO混为一个数量相加。必须建立physical pin→tile→port→功能映射，检查多bit端口复用、USB占用与MCLK反馈；预算完成前不承诺“剩余IO全部可用”。

> ⚠️ **官方 QF60A datasheet 检查清单补充**（画 S3 页前逐项打勾）：
> 1. **POR 条件**：所有IO域都是1.8V。若共用单一1.8V轨，原厂允许依靠内部POR；若多轨，RST_N必须保持到IOL/R/T有效。VDD与IO轨单调爬升，建议相差不超过50ms；
> 2. **PLL_AVDD**：0.9V；原厂例为600Ω@100MHz、DCR<1Ω磁珠配1µF低通，不能把600Ω当串联直流电阻；
> 3. **晶振**：24MHz ✓（USB 设备支持 12/24MHz，24MHz 合规）；
> 4. **QSPI 启动**：Flash接X0D01/X0D04..07/X0D10；电压必须匹配1.8V，300µs内就绪或延长外部复位，Quad模式/0xEB读取需验证。xflash列出型号不代表电压兼容；
> 5. **xSYS2 电平**：1.8V——XTAG4 的 VREF 来自板子 pin1（VDDIOB18），**不要接 3.3V**；
> 6. GPIO 不混用同一多 bit 端口的输入输出（画引脚分配时注意）。

> 若 datasheet 实际可用 IO 不足上述预算：优先把 `VBUS_SENSE` 挪给 ESP32（它同样能检测 USB 掉线），或砍 xSYS 的 TDI/TMS 复用。仍不够 → 换 XU216-512-TQ128（TQFP 好焊，淘宝 ¥60-90，固件同一套 sw_usb_audio）。

## 2.3 关键电路

### 电源与去耦（供电域清单，逐脚对照 datasheet/官方板）

| 供电域 | 接法 |
|---|---|
| VDD（核） | **V0V9=0.900V，工作范围0.855–0.945V**；周边pin4/12/19/27/34/42/49/57及底部61–64全部接入 |
| VDDIOL/VDDIOR/VDDIOT | **V1V8**，工作范围1.62–1.98V；pin8/38/52 |
| **VDDIOB18** | **V1V8**，pin17/26都接；复位释放前满足全部IO域时序 |
| **USB_VDD33（USB PHY 3.3V）** | V3V3D 经磁珠 |
| **USB_VDD18（USB PHY 1.8V）** | V1V8 经磁珠 |
| PLL_AVDD（pin22） | **V0V9，工作0.855–0.945V**；原厂滤波例为磁珠+1µF，局部有效容量/布局须核验 |

- 原厂要求VDD至少8颗100nF低电感去耦；IO各供电脚就近100nF；VDD/VDDIO各配≥10µF bulk。不要给高电流核心支路盲目串任意磁珠。
- **删除“挂起态0.85V／电压选择strap”假设**：本型号手册未建立其适用依据；不得把工作下限0.855V以外的电压写成正常模式。
- **底部61–64为VDD，65为GND**，须分别接对应平面；pin25为NC。QF60A无独立OTP_VCC外部引脚，不从其他封装补画。

### 晶振
- 无源晶体限定24MHz、±500ppm；CL/ESR及两侧电容按选定晶体与板级寄生计算，不能直接把“18pF级”视为已核值。晶体紧贴XIN16/XOUT15。

### QSPI Flash
- 1.8V QSPI Flash待选：CS pin3、CLK pin5、IO0/1/2/3 pin59/1/60/2。上拉须回到兼容电源域；串阻取值需配实际时序和驱动验证。
- W25Q16JV与IS25LP等3V系列不能作为当前1.8V域的直接备选。选定精确型号后再核数据手册、xflash、QE与上电启动。

### USB
- USB_DP/DN ← **CH334U 下游1**（板内 Hub 拓扑见 07-usb-c）；到 XU316 的差分对短而直、90Ω、参考地完整；ESD 已由上游 PRTR5V0U2X 统一处理。

### 复位与启动
- RST_N上拉至V1V8；10k/100nF仅原候选，必须验证实际释放边沿与全部电源就绪条件。ESP32控制须避免3.3V上拉或掉电反灌。
- 启动模式：QF60A 由 ROM 引导，默认从 QSPI 启动；如 datasheet 有 boot-select 引脚，按官方板接法加跳线。

## 2.4 固件侧对应关系（sw_usb_audio）

| 固件模块 | 内容 |
|---|---|
| 描述符 | **6 路输入 / 6 路输出**，192kHz/32bit，异步模式（反馈端点）；每对立体声被 Thesycon 驱动拆分为独立播放/录音设备（见 README 4.1 通道规划） |
| 通道命名 | 描述符通道名定制：`Main Monitor/Backing/Game Voice`（播放）、`Mic/Line/Stream Mix/Host Loopback`（捕获）——OBS/DAW 里直接看到语义化名字 |
| Mixer | 在默认 mixer 应用基础上改：① 5 源（Mic/Line/Main/Backing/Game）→ 监听输出；② 同 5 源 → 直播混音；③ **直播混音回灌捕获 ch3/4、PC 播放干声回灌 ch5/6（loopback，样本拷贝级路由）** |
| DSP | lib_dsp：Mix 总线限幅器（阈值 -3dBFS、软拐点），话筒通道可选 EQ/压缩 |
| 控制通道 | UART 任务接收 `CTRL_RX` 协议（见 05-control，混音矩阵 10 电平 + 限幅），上报 VU 电平 30~50Hz |
| 调试通道 | xSCOPE UART：printf 日志经 `DEBUG_TX`（1-bit 端口）→ CH343P-B 独立 COM 口；`DEBUG_RX` 接收 CLI 命令（可选） |
| MCLK | 内部 PLL 输出到 `ADC_MCLK`，随采样率族自动 24.576/22.5792MHz |
| 带宽 | 12ch × 192kHz × 32bit ≈ 74Mbps（占 USB2.0 HS ~15%），无压力 |

**端口映射**：I2S/UART 具体用哪些 xCORE port（`X0Dxx`）在 `sw_usb_audio` 的端口定义文件中配置，与本文 2.2 表一一对应即可；画图时把最终映射表回填到原理图注释里，方便日后维护。

## 2.5 布局红线

1. 24MHz 晶振与 QSPI CLK 远离模拟区；
2. USB D± 差分对等长，参考地完整，ESD 先于走线；
3. XU316 底部散热/地焊盘密集过孔；
4. I2S 信号组等长（±2mm 内），串阻 22Ω 放在源端。
