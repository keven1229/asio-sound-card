# Rev A：XU316 启动、24MHz 晶体与复位

日期：2026-09-16。范围限于 XU316-1024-QF60A-C24 的启动外围；未改固件、BOM 或 EDA，未查价采购。逐脚及阻容见 [xmos-boot-plan.json](../../hardware/asio-card-reva/xmos-boot-plan.json)。既有 65 脚表继续有效。

**可先画：晶体网络与下述三路监控复位电路。Flash 使用精确技术候选 W25Q16FWSNIQ 的 8 脚图，保留启动验收门槛，不能标“已验证兼容”。** 当前没有实板 Flash 读写、冷启动、暖复位证据。本文件中的上电释放设计也不等于整条电源动态窗口已经通过。

## 1. Flash：为什么保留 FW IQ，而不直接批准 JW 替换

已从 Winbond 官网取得完整手册：

- [W25Q16FW Rev.J，2017-05-18](https://www.winbond.com/resource-files/w25q16fw%20revj%2005182017%20sfdp.pdf)，91 页；本次技术候选 **W25Q16FWSNIQ**，SOIC-8 150mil。PDF p89 明列此型号，p16 明确 IQ 出厂 QE=1；它是可写的非易失位，不能说成永久固定。
- [W25Q16JW Rev.G，2021-06-30](https://www.winbond.com/resource-files/W25Q16JW%20RevG%2006302021%20Plus.pdf)，74 页；`W25Q16JWSNIQ` 的 QE 固定1、相同电压/封装；但 p22/p32 要求 mode byte 为 `Fx`。不能仅凭 p71 的 FW 向后兼容字样抹掉该条件。

FW 的工作电源为 **1.65–1.95V**，不是任意“1.8V IO正常范围”。接已有 `V1V8`，须同时满足 Flash 和 XU 的范围；不能把 XU 的 1.62–1.98V 整段照搬给 Flash。

还要核逻辑门槛：FW p76 的VIH为0.7×VCC；若把供电放宽到1.95V，其1.365V门槛已经高于XU表中指定2mA条件的1.35V最低VOH。实际1.8V稳压轨须连同误差/瞬态闭合该裕量，不能单凭两芯片电源范围相交就批准直连。

| 项目 | 已取得的一手证据 | 结论/限制 |
|---|---|---|
| ROM命令 | XU本地PDF p19 §9.1：0xEB、3字节0地址、一个dummy byte、CPOL/CPHA=0/0，最先收低半字节 | “一个dummy byte”不是足以独立确定逐时钟行为的波形图 |
| FW协议 | FW p39 Fig24a：8个命令周期、6个四线地址周期、2个mode周期、4个dummy周期，之后四线数据 | 0xEB、3字节地址及模式0对应；mode `00` 使 M5:M4≠10，不进入连续读取 |
| 出厂QE | FW p16 §7.1.10：IQ出厂1，IG/IE出厂0 | 必须保留 **IQ** 后缀；烧录/升级不得清QE |
| 上电准备 | FW p75 §9.3：VCC达到有效范围后读访问等待至少10µs，写/擦/状态写等待至少5ms；这些参数为characterized | 不把5ms写等待误报成读启动等待；下述复位延时为它留余量 |
| 暖复位 | XU p19假定Flash仍处于可QSPI读取状态；FW支持QPI、连续读、wrap、deep-power-down等状态 | 禁止应用留下这些状态；写擦忙期间不能直接复位后假定ROM读一定成功 |
| 工具 | XTC15.3.1 `QuadSpecEnum.h` 没有FW/JW具名枚举；`quadflash.h` 支持SFDP发现/自定义描述 | 缺少具名枚举不等于不支持；也不能用3V JV枚举冒充此器件已验证 |

本机 XTC15.3.1 的官方模拟器 ROM 可读：`xs3a_rom.h` 指定 QSPI helper 在 `0xfff0091e`。只读反汇编确认命令字 `0x01101011`、后续零输出及定时输入代码，保存在 `.jspace/board-design-20260916/boot-evidence/rom-disassembly.txt` 与 `rom-remote-log.txt`。**尝试运行 helper 的模拟捕获停在等待状态，未得到完整有效 boot 波形；这不构成通过的 ROM/Flash 联合仿真。** 因此最后的 mode/dummy 精确兼容仍列为待验，而不是凭静态片段作保证。

必须在发板前或样机启动门槛关闭：确认真实 ROM 输出符合 FW p39；用本项目 XN、XTC15.3.1 实际读取 JEDEC/SFDP、烧录后校验、冷启动和暖复位。FW 的 `9Fh` ID 应按原厂 p22/p60 的器件ID表核对为 `EF 60 15`；不要接受 JV 的 `EF 40 15`。XN 仍有旧 JV 注释，本轮没有改它。镜像半字节顺序必须由 XMOS 工具处理，不能将普通SPI读出的二进制不经核对直接当ROM镜像。

### Flash逐脚与小件

| Flash脚 | 功能/网络 | XU物理脚 |
|---|---|---|
| 1 | CS# → `QSPI_CS_N_1V8`，4.7k上拉V1V8 | 3 |
| 2 | IO1 → `QSPI_IO1_1V8` | 1 |
| 3 | IO2/WP# → `QSPI_IO2_1V8` | 60 |
| 4 | GND | 公共GND |
| 5 | IO0 → `QSPI_IO0_1V8` | 59 |
| 6 | CLK → `QSPI_SCLK_FLASH18`，经0Ω串联调试位接`QSPI_SCLK_1V8` | 5 |
| 7 | IO3/HOLD# → `QSPI_IO3_1V8` | 2 |
| 8 | VCC → V1V8，近端100nF+1µF到GND | 同XU IO轨 |

IO0/1/2各100k下拉到GND，明确保证启动strap `X0D06/05/04=000`，不装传统WP#上拉。IQ的QE=1时WP#/HOLD#功能关闭；**pin7不是独立复位脚，禁止接XU_RST_N**。IO3不强加上拉。串联位默认0Ω；后续按波形可调，不能未经信号完整性验证统一加22/33Ω。100nF/1µF用X7R，分别按C01≥25V/C02≥16V，电容有效值及封装按现有小件规范。该候选没有采购编号或库存结论。

## 2. 24MHz：确定的技术型号与完整接法

技术型号 **Epson FA-238 / Q22FA2380006517**。原厂[具体规格PDF](https://download.epsondevice.com/td/pdf/td_xtal_mhz/FA-238_Q22FA23800065_en.pdf) p1：24MHz基频、CL=12pF、ESR≤60Ω、驱动10–200µW、25°C初始±50ppm、−20～70°C温漂±30ppm、首年老化±5ppm；尾码17只是包装。它符合XU p16–17示例晶体的电气类别，**不是断言它与示例旧订货名已完成料号等同认证**。

- 晶体pin1接 `XU_XIN`（XU16），pin3接 `XU_XTAL_OUT`；pin2/4为盖壳，接GND。3.2×2.5mm四焊盘，禁止把壳脚当晶体端。
- XU15 `XU_XOUT` → **680Ω/1%** → `XU_XTAL_OUT`；**1MΩ/1%反馈电阻直接跨XU_XOUT与XU_XIN**，不跨到680Ω后的节点。
- `XU_XTAL_OUT`、`XU_XIN`各 **22pF、C0G、5%、≥50V** 到GND。对应XU p16 Fig10/p17 Fig11；CL约为两电容串联合成11pF再加寄生，故22pF是原厂示例起点，不是无条件最终负载值。
- 晶体与阻容紧邻XU，短线、连续地，远离开关节点，不接测试点长支线。仍须验证负阻起振裕量、驱动功率与全温/低压启动。
- 原厂允许外部1.8V时钟替代，XOUT留空，但本版采用无源晶体，不并装振荡器。现有XN的24MHz保持。

## 3. 复位与CORE_ENABLE：三颗相同监控器的可绘图方案

技术型号 **TPS3897ADRYR**，USON-6 1.45×1.00mm；选A版本，使电压和ENABLE条件均参与延时。原厂[SBVS172B](https://www.ti.com/lit/ds/symlink/tps3897.pdf) p3–7、14–15：高有效ENABLE，**SENSE_OUT是“电源正常为高/开漏释放”**；不能因名称含active-high就画成故障时输出高，也不要换TPS3898反极性版本。

三颗VCC全部接已确定的 **V3V3_AON**，每颗100nF去耦；总静态电流最大按36µA额外计入AON。这样监控器在主数字轨爬升前已工作，主关闭时仍能保持正确的低输出。它们属于原电源方案允许的AON监控负载。上电前提是原电源页先建立AON、后允许V5_SYS，不能绕过该电源链。

| 监控器 | pin1 ENABLE | pin2 | pin3 SENSE（上/下分压） | pin4 SENSE_OUT | pin5 CT | pin6 |
|---|---|---|---|---|---|---|
| U_XU_IO_MON | V3V3_AON | GND | V1V8→24.0k→SENSE→10.0k→GND | CORE_ENABLE | 1nF到GND | V3V3_AON |
| U_XU_USB_MON | V3V3_AON | GND | V3V3_USB→52.3k→SENSE→10.0k→GND | CORE_ENABLE | 1nF到GND | V3V3_AON |
| U_XU_CORE_MON | XU_RESET_ENABLE | GND | V0V9→7.37k→SENSE→10.0k→GND | XU_RST_N_1V8 | 4.7nF到GND | V3V3_AON |

分压电阻均0.1%、≤25ppm/°C；CT用低漏电C0G/5%、≥16V。上表SENSE节点均是不同网络，不能相连；先不加可拖慢检测的大滤波电容，可留DNP小电容位。

两个前级开漏输出并在 **CORE_ENABLE**，加10k上拉V3V3_D，保留电源页已有的100k下拉（**不重复画第二只**）。直接送已有SY8089核心Buck pin1。该信号不再依赖尚不存在的ESP程序发出；原电源页的“MCU sequencing”文字应由主任务后续同步。

CORE_ENABLE经10k到 `XU_RESET_ENABLE`，送核心监控器pin1；可加常开手动RESET按钮将此节点拉地，按钮仅重置XU、不切断核心电源。核心监控器pin4与XTAG4复位输出接同一 `XU_RST_N_1V8`（XU21）；**47k只上拉V1V8，不上拉3.3V**。不在该复位网上放大RC，以保留XTAG控制。XTAG和任何后续控制只允许合规开漏下拉；外部RST低脉冲须≥5µs。

### 阈值、延时与不能夸大的边界

按TI p6的上升门限0.495–0.505V、SENSE漏电±15nA和两只0.1%电阻，算得：

| 被监测轨 | 标称释放阈值 | 电阻/参考/漏电端点范围 |
|---|---|---|
| V1V8 | 1.7000V | 1.68027–1.71979V |
| V3V3_USB | 3.1150V | 3.07789–3.15222V |
| V0V9 | 0.8685V | 0.85898–0.87804V |

这是**上升释放门限**，不是电源额定窗口，也不是含板上噪声/温漂失配/动态跌落的验收结果。静态上，核心门限低于当前0.1%分压Buck约0.8814V的低端，且高于XU最低0.855V；实际PCB必须Kelvin取样到XU的供电区域。Flash工作电压上限仍必须由V1V8稳压误差与瞬态另验，监督器不提供过压钳位。

CT公式 `t≈4×C(µF)+40µs`：前两级约4.04ms，核心级约18.84ms。按C±5%、CT门限1.18–1.299V、充电260–360nA，单独电容充电部分约3.11–5.25ms、14.64–24.66ms；不把这些计算当所有内部传播延时的保证上限。Flash在V1V8建立后，经历IO监控、核心爬升和核心监控延时，读/写准备时间有充分设计余量。仍须测量真实复位释放、24MHz起振和完整上电波形。

XU p27要求各电源单调爬升，并**建议**VDDIO和VDD的爬升间隔不超过50ms；不是“手册硬性规定IO必须先于core”。本版按现有电源方案实现IO/USB先建立再开core，前级约4ms延迟给50ms建议留余量，但核心Buck的软启动/负载仍须量测。

**未关闭的运行期问题**：TPS3897的5mV迟滞及16µs下降传播是典型值，不能据此保证在任何跌落中都先于0.855V触发复位；普通复位监督也不阻止电源越压或任意快速瞬变。全电源窗口/故障保护仍由电源页验收，不能因增加这三颗监控器就标全部通过。

## 4. 保存与验收边界

JSON已检查候选Flash8脚、晶体4脚、三颗监控器各6脚唯一覆盖及网名衔接；源PDF的SHA256记录在JSON。未修改现有固件，不将临时最小测试程序的编译成功称为项目固件/Flash验收。没有运行真实器件、原生ERC或DRC。

关闭顺序：①原生图逐脚/封装与电源页CORE_ENABLE所有权对账；②真实ROM/Flash协议与XFLASH读写启动；③晶体起振/驱动和上掉电/暖复位；④电源动态与故障窗口。Flash候选状态在②前保持有条件。
