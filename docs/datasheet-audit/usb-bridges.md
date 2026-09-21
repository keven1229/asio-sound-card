# USB Hub 与串口桥补充手册核验

> 日期：2026-09-06。本轮补齐 CH334U / CH343P 原厂手册，属于原36份PDF核验以外的2份补充；新增后本地目录为38份。本报告未修改旧设计或BOM，也不代表USB枚举、功耗和信号完整性已经实测。

## 1. 文件来源与完整性

优先访问了沁恒官方下载页面。主整理任务已报告中文下载接口返回“请刷新页面”；英文下载页正常公开但页面依赖JavaScript，旧下载路径未取得可用文件。未绕过验证码或鉴权，改用硬件厂商托管的**WCH原厂英文PDF镜像**。判断原厂内容的依据是PDF标题、逐页WCH/`wch-ic.com`页眉、原厂型号表/版本号/管脚图及电气表，不采用镜像网页的二次参数摘要。

| 本地文件 | 内容 | 下载来源 | 大小与校验 |
|---|---|---|---|
| [CH334DS1_WCH.pdf](../datasheets/CH334DS1_WCH.pdf) | WCH《CH334/335 Datasheet》V2.5，32物理页 | [Adafruit托管原厂PDF](https://cdn-learn.adafruit.com/assets/assets/000/131/435/original/CH334DS1.PDF)；[WCH官方发布页](https://www.wch-ic.com/downloads/CH334DS1_PDF.html) | 419,558 bytes；有效PDF已解析 |
| [CH343DS1_WCH.pdf](../datasheets/CH343DS1_WCH.pdf) | WCH《USB to High-Speed Serial Chip CH343》V2.0，13物理页 | [Waveshare托管原厂PDF](https://files.waveshare.com/wiki/ESP32-S3-LCD-1.3/CH343DS1_EN.pdf)；[WCH官方驱动及关联手册说明](https://www.wch-ic.com/downloads/CH343CDC_ZIP.html) | 277,847 bytes；有效PDF已解析 |

```text
SHA256 CH334DS1_WCH.pdf c078817182e320e7bc1c2f5d28b361a55246bac70d4a07b05cb0e997dedea586
SHA256 CH343DS1_WCH.pdf d1dba2658f17b842a14a1911e65ce1a19fa8d1fdb8f777183e4cde4febb34865
```

页码规则：下文`pN`一律为**物理PDF页码**。CH334的p1是无印刷页号封面，p2起印刷页号=N−1；CH343物理页号与印刷页号相同。CH343候选立创链接在本机下载返回403，没有保存错误页面。版本是本次取得的版本，未宣称它们必然是沁恒当前最新版。

## 2. CH334U：封装和12MHz方向正确，供电接法需补全

| 核验项 | 原厂结论 | 证据 |
|---|---|---|
| 功能与USB速度 | 四口USB2.0 Hub；上游支持HS/FS，下游HS480Mbps/FS12Mbps/LS1.5Mbps；MTT为每个口独立TT。不能把Hub理解成没有调度和协议开销的理想零延迟导线 | p1 Overview；p3 Table1-1；p8系统架构 |
| 精确封装 | **CH334U=QSOP-28，body宽3.9mm(150mil)，pitch0.635mm**；不是同族CH334S的SSOP，也不是QFN；U封装无EPAD。库符号必须读取型号列`4U` | p2 Fig1-1；p4 Table1-2；p24 §5.4 |
| 数据引脚 | 上游DMU15/DPU16；下游1 DM10/DP11，2 DM8/DP9，3 DM6/DP7，4 DM4/DP5 | p2管脚图；p4 Table1-3 |
| 电源引脚 | V5=20；**VDD33=21与13两脚**；GND=1、12、28；XI3/XO2；RESET#/CDP17；PSELF19；PWREN#25；OVCUR#26；NC18/27不连接 | p2、p4–7 Table1-3 |
| 5V供电模式 | V5额定4.5–5.25V，内部LDO建立VDD33，LDO输出范围3.2–3.5V；V5接至少1µF；主VDD33按手册去耦0.1µF+10µF或1µF，另VDD33脚局部去耦 | p5管脚表；p21 §4.2 |
| 外部3.3V模式 | **V5和所有VDD33均接外部3.3V**，额定3.2–3.4V；不能只接一个名为“VDD”的脚而悬空V5或第二VDD33。p28推荐工业设计用此模式减少LDO损耗 | p21 §4.2；p28–29 §6.1 |
| 绝对最大值 | V5−0.4…5.5V；VDD33−0.4…4V；标记5I的输入−0.4…5.3V；普通GPIO/USB−0.4…VDD33+0.4V。这些不是推荐电压 | p21 §4.1 |
| 真实电流条件 | 上游HS+4下游HS：**typ85mA**；上游HS+1下游HS：typ42mA；上游HS+4下游FS：typ25mA；HS+1FS：typ21mA；无下游设备：typ0.3mA。**ICC最大栏为空，85mA不是保证最大值**。本机“1HS+3FS”的具体电流没有独立给出，需留余量并实测 | p21 §4.2（已渲染表格） |
| 挂起/外部负载 | 深睡typ0.12/max0.4mA，不含1.5k上拉；内部LDO向其他器件供电的能力max20mA，不足以供ESP32等负载 | p21–22 |
| 时钟 | 外晶振**12MHz**，片内振荡器已有负载电容，内PLL产生480MHz。原厂参考图没有再并通用18/22pF负载；不能机械复制XMOS晶振外围。手册未给这版内置负载电容的精确pF值，应结合所购晶体/原厂要求选型 | p1 Features；p28 §6.1参考图 |
| 免晶振限制 | 可配置免外晶振，XO悬空、XI接地，但可能有参数偏离USB规范，原厂限非精密场景，且部分封装/批次并非默认开启。音频首版保留12MHz外晶振更合适 | p29 §6.2 |
| 电源模式与过流 | **CH334U仅支持GANG整体电源控制/过流检测**；PSELF默认内部上拉为self-powered，低为bus-powered。PWREN#和OVCUR#均低有效，必须对应真实电源拓扑与Hub描述信息，不能直接凭“全部内置设备”忽略 | p3 Table1-1；p5–6；p9 §3.1 |
| 复位/CDP复用 | RESET#/CDP上电时主动拉高可能开启CDP并取消低功耗挂起；不需要外复位时手册建议悬空；MCU控制须按图3-2-2只实现需要的拉低，不能默认10k强上拉或GPIO高电平 | p5；p13 Table3-2 |
| IO与EEPROM | 普通IO VIH≥2V、VIL≤0.8V；并非1.8V接口。EEPROM侧为Hub自身的I2C主口，时钟187.5kHz，SDA有片内上拉；可配置端口数、non-removable、VID/PID等，不能直接当作ESP32共享的从设备I2C | p16–18 §3.4/3.5；p22 |

对应旧稿 `docs/schematic/07-usb-c.md` §7.4、§7.8：QSOP28与12MHz结论可保留；“VDD=3.3V”必须展开成V5/VDD33实际接线和3.2–3.4V容差。总功率预算应按具体连接速度/模式与下游桥电流重算，不能把85mA当最大保证，或用“Hub零影响”代替音频压力测试。

## 3. CH343P：确有独立VIO，支持1.8V UART

| 核验项 | 原厂结论 | 证据 |
|---|---|---|
| 精确封装 | **CH343P=QFN16_3×3，pitch0.5mm**；EPAD标0#GND，原厂称可选但推荐接，其他GND必须接。型号G/C/K的引脚不能沿用到P | p2 Packages（已渲染） |
| 完整关键管脚 | **VIO1**、GND2、VDD5=3、TXD4、RXD5、V3=6、UD+7、UD−8、VBUS9、ACT#10、DCD11、DTR/TNOW12、RTS13、DSR14、CTS15、RI16 | p2图与p3–4 `343P`列（已渲染） |
| VIO能力 | 独立IO供电输入，额定**1.7–5.5V**，功能说明明确支持1.8/2.5/3.3/5V，与对端MCU的IO轨同源；CH343C才是VIO内部短到VDD5，不得把C型号限制或错误网页摘要套给P | p1 Features；p3 Pinouts；p5 §5.2；p9 §6.2 |
| USB/核心供电 | 5V模式：VDD5=4.0–5.5V，V3仅外接约0.1µF去耦，由内部LDO产生。3.3V模式：**VDD5与V3并接外部3.0–3.6V**，仍去耦。不能给整个芯片VDD5/V3只供1.8V | p3、p5；p9 |
| 电流 | USB/核心IVDD typ3/max15mA；另有取决于IO负载的IVIO。挂起IVDD在5V模式typ0.09/max0.16mA、3.3V模式typ0.085/max0.15mA；VIO空载挂起typ2/max50µA。内部V3 LDO可带外部负载max10mA | p9 §6.2 |
| 1.8V IO门槛 | VIO1.8V时VIH≥1.3V、VIL≤0.5V；VOH≥VIO−0.4=1.4V @2mA，VOL≤0.4V @3mA。3.3V时VIH≥1.9V，因此XU3161.8V高电平不能保证驱动VIO3.3V的CH343P | p9–10电气表 |
| 与XU316直接连接 | 将XU调试桥的VIO1接V1V8，在标称1.8V条件下门槛匹配：XU VIH≥0.65VDDIO≈1.17V/VIL≤0.35VDDIO≈0.63V；XU VOH≥1.35V/VOL≤0.24V @2mA。**可取消该一路1.8↔3.3转换器的需求**，仍须核电源容差、Schmitt配置、实际驱动/负载与串阻；ESP32↔XU控制UART仍需电平转换 | CH343 p9–10；XU316 PDF物理p32 §14.3 |
| 绝对最大值 | VDD5/VIO−0.5…6V；VBUS−0.5…6.5V；USB脚−0.5…V3+0.5V；UART等−0.5…VIO+0.5V。5.5V工作上限和6V绝对最大不可混淆 | p9 §6.1 |
| VBUS/掉电 | VBUS9是真实USB存在检测，工作高电平1.7–5.8V，内部下拉；不随VIO供电。USB电源消失会关USB并挂起。若V5D被DC备份保持，接V5D检测不到USB拔出，需按实际上游总线/下游端口电源语义设计检测连接 | p5、p10 |
| USB与串口能力 | USB端是**Full-Speed 12Mbps**，不是USB High-Speed；UART最高6Mbps，50bps起，支持5–8数据位、常见校验和CTS/RTS；内置12MHz时钟，无需外晶振。921600在支持波特率范围内 | p1、p6–8 |
| 驱动与配置 | 支持系统CDC或WCH VCP；CH343P内EEPROM可配VID/PID/最大电流和字符串，不代表任意枚举配置在所有Windows版本都自动免驱。实际驱动包/CDC描述应测试；双芯片分别枚举各自COM | p1；[WCH驱动说明](https://www.wch-ic.com/downloads/CH343CDC_ZIP.html) |
| 数据线/复位 | UD+/UD−原厂明确不加额外串联电阻；这里与UART源端串阻不是一回事。片内POR9–25ms（typ15ms）。P封装没有独立RST脚，不要按CH343C的RST脚画 | p3 Pinouts；p10 §6.3 |

对应旧稿 `docs/schematic/07-usb-c.md` §7.5、`docs/hardware-devices-design.md` §5.4/6.2：CH343P的VIO能力由“待核”变为确定；XU调试桥应优先VIO=V1V8，ESP32调试桥VIO=V3V3D，各自USB/核心供电仍按5V或3.3V模式。旧“UART脚TTL3.3V直连”不能继续应用在XU端。

## 4. 此次完成与仍待验证

已完成：两份真实原厂内容PDF保存；版本/页数/哈希记录；CH343P封装图与逐型号管脚表、CH334电流表视觉核对；供电、12MHz时钟、VIO、电流和复位注意项核验。

仍未完成：所购批次的默认CDP/免晶振/EEPROM配置确认、精确晶体CL选型、Bus/Self-powered描述与功率路径闭合、1HS+3FS混合负载功耗和音频压力测试、两颗桥的实机驱动枚举。由镜像取得的V2.5/V2.0不冒充已经与官网最新二进制逐字节比对。

覆盖文件：`.jspace/datasheet-audit/usb-bridges-coverage.json`（2项）；此前转换器等覆盖仍为原36份集合，不应重复计数。
