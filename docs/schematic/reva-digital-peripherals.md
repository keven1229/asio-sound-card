# Rev A 数字外围设计输入

2026-09-16 最后同步：当前接口依据为[逐管脚计划 schema_version=2](../../hardware/asio-card-reva/digital-peripheral-plan.json)，并服从[单USB-C电源基线](reva-power-design.md)与[音频基线](reva-audio-design.md)。以下旧版详细说明已经归档；其共享codec电源和供电策略未定的描述不能作为新网表依据。

| 本轮已修订接口 | 当前连接/策略 |
|---|---|
| 数字主轨 | V3V3_D |
| Hub专用轨 | V3V3_HUB供CH334U的13/20/21脚及上游USB数据开关 |
| Hub供电声明 | PSELF19接GND，按总线供电；不保留外部DC自供电分支 |
| Type-C功率档 | Default仅AON；1.5A仅数字枚举/控制/回环，软件额度≤1.0A；3A为模拟功能目标，软件额度≤2.2A并按实际线压和负载准入 |
| ESS数字域 | V3V3_ADC_DIG与V3V3_DAC_DIG独立；分别提供前向翻译、CHIP_EN和I2C隔离分支，不并成V3V3_CODEC_IO |
| 耳机静音 | MCP23017 GPB3新增HP_UNMUTE→K4；默认掉线圈静音。IODIRB基线改0x70，初始化仍先写OLAT=0再改方向 |
| Flash | 1.8V需求已确定；准确型号及XMOS ROM Quad启动兼容证据仍TBD，未批准任意1.8V Flash替换 |

CH334/CH343/ESP固定USB/UART引脚及XU1.8V接口核对保留在JSON中。电源、器件型号、管脚和GPIO分配是设计输入，不代表固件已实现或原生原理图已落图。源码、BOM采购字段和库存/价格未在这次数字方案中改动。

仍需关闭：GANG保护与真实描述符、各轨电压窗口、隔离OE/EN的硬件条件、AON跨域检测及GPIO分配、上掉电/时钟时序与回灌验证、Flash选定。schema2最后修订后仅重新确认JSON可解析，完整电气校验未重跑；不得沿用旧校验结论宣布这些新增接口已通过。

<details>
<summary>旧版详细说明（供来源和历史追溯；冲突以顶部schema2接口为准）</summary>

# 原数字外围说明

日期：2026-09-16。正式机器可读计划：[digital-peripheral-plan.json](../../hardware/asio-card-reva/digital-peripheral-plan.json)。本次只写设计计划；不采购、不查价、不改固件、不操作EDA。JSON逐脚覆盖CH334U的28脚、两颗CH343P各16脚+地焊盘、ESP32模块41脚及新增MCP23017的28脚，并列出电平转换器接线。

**实施边界**：固定接口遵循现有设计；ESP32应用固件尚不存在，新增GPIO表是明确的技术方案，不是“现有固件已采用”。当前XMOS侧的921600-8N1、控制TX物理41/RX43、调试TX32/RX39保留；调试RX仍未实现。四条JTAG短名遵循原理图主任务的`hardware/asio-card-reva/net-aliases.json`，本任务不改这些网络。

## 1. Hub四个下游口保持原分配

| 端口 | CH334U DM / DP物理脚 | 目标DM / DP | 速度/用途 |
|---|---|---|---|
| 上游 | 15 / 16 | USB-C上游保护/隔离后的D−/D+ | HS上游 |
| 下游1 | **10 / 11** | XU316 **28 / 29** | HS音频 |
| 下游2 | **8 / 9** | ESP模块 **13 / 14**，GPIO19/20 | FS原生USB维护 |
| 下游3 | **6 / 7** | CH343P-A **8 / 7** | FS，ESP UART0 |
| 下游4 | **4 / 5** | CH343P-B **8 / 7** | FS，XU日志 |

四个端口都已有用途。若调试桥某版不装，相应Hub D±留空，不短接、不加模拟设备上拉；若希望减少宣告端口数，再配置Hub。内置器件的non-removable候选掩码为EEPROM偏移0x06写0x1E，端口数偏移0x07为4，但**这不是完整可烧写镜像**，还须checksum、签名和真实MaxPower。

CH334U为**QSOP28，3.9mm宽、0.635mm脚距，无EPAD**。选择外部3.3V供电的技术接法：**V5脚20、VDD33脚21和13全部接同一3.2～3.4V数字轨**；GND脚1/12/28全接。20脚局部≥1µF，21脚0.1µF+10µF或按原厂替代，13脚另有局部去耦。电源来源/USB取电额度仍由电源设计方案闭合，不能用Hub内部LDO去供ESP。

12MHz无源晶体接XI3/XO2，CH334带内部负载电容，**不默认加XMOS式18/22pF**；精确晶体CL/ESR留待技术型号核对。默认不采用免晶振模式。

复位/配置必须保留以下区别：

- RESET#/CDP17默认不外驱；上电强拉高可能开启CDP并关闭低功耗挂起。需要外部复位时只加合规开漏拉低，不套“10k强上拉+推挽MCU”。
- PSELF19默认高=自供电，低=总线供电。电源策略尚未定，图上做互斥strap而不是无条件接高。
- CH334U仅支持GANG。PWREN#25低有效，OVCUR#26低代表故障；实际负载开关、FAULT返回和Hub描述必须一致。不能把OVCUR接地当“未用”，也不能把PWREN误接到Hub自身供电形成断电循环。
- LED3/SCL14、LED4/SDA22是**Hub自己的EEPROM主总线**（187.5kHz），不能接ESP的ESS控制I2C。初版EEPROM/Hub状态LED可DNP，23/24脚LED1/2不强加功能。
- NC18/27必须悬空。原文依据：本地CH334 PDF p2、4–7、9、13、16–18、21–22、28–29。

## 2. 两颗CH343P：相同核心供电，不同VIO

每颗**QFN16 3×3mm**：VIO1，GND2与底部0号地焊盘，VDD5=3，TXD4，RXD5，V3=6，UD+7，UD−8，VBUS9，ACT#10，DCD11，DTR/TNOW12，RTS13，DSR14，CTS15，RI16。EDA封装可能把底部焊盘编号为17，必须做0↔EPAD的明确映射。

- 本计划选外部3.3V模式：**VDD5脚3与V3脚6并接V3V3D**，各按布局去耦；不能把核心只供1.8V。
- A桥VIO1=ESP的3.3V；TXD4→ESP RXD0模块36/GPIO44，RXD5←ESP TXD0模块37/GPIO43。
- B桥VIO1=XU的1.8V；RXD5←XU DEBUG_TX物理32，TXD4→预留DEBUG_RX物理39。标称电平兼容可直连，但不宣称RX功能已写好。
- 两桥内置时钟、无外晶振，**P封装没有独立RESET脚**。USB D±不额外串普通UART阻尼电阻。
- DTR12上电若检测到下拉会改成TNOW；本计划保留DTR/RTS，不直接绑ESP EN/GPIO0。自动下载需另用核过的网络，首版手动BOOT/RESET与原生USB均可维护。
- VBUS9由真实USB在位信号驱动，不能接可能被DC保持的V5D。手册允许该检测输入高于1.7V，因此可使用3.3V在位缓冲输出。
- CH343只明确说明**VIO不会反灌掉电的VDD5/V3**；不能反推“USB核心有电、VIO掉电时也一定无回灌”。B桥核心和XU数字电源须使用协调的上下电/故障策略。

依据本地CH343 PDF p2–5、9–10。未使用的调制解调器输入保留内部偏置并关闭软件硬件流控；未用输出悬空，不能随意短地。

## 3. ESP32-S3-WROOM-1-N8R8建议GPIO分配

固定的原生USB19/20、UART0 43/44保持；N8R8的GPIO35/36/37不可外用。新增分配如下，模块全部物理脚在JSON中。

| 功能 | GPIO（模块物理脚） | 说明 |
|---|---|---|
| XU控制UART TX/RX | **17/18（10/11）** | 原生U1TXD/U1RXD，921600-8N1，经双向分组翻译 |
| 控制I2C SDA/SCL | **8/9（12/17）** | MCP23017在本地控制侧，ESS经隔离支路 |
| LCD/PGA共享MOSI/SCLK | **11/12（19/20）** | 两个独立CS；事务间换速，PGA初始1MHz且≤6.25MHz |
| LCD CS/DC/RST/BL | **10/13/14/21（18/21/22/23）** | BL为驱动/PWM，不直接承诺GPIO可带模块背光 |
| PGA CS/MISO | **47/48（24/25）** | 经TXU0304；MISO原PGA侧约5V，不能直回ESP |
| 编码器1 A/B/SW | **4/5/6（4/5/6）** | A/B直接中断；按已核接点电流配上拉 |
| 编码器2 A/B/SW | **7/15/16（7/8/9）** | 同上 |
| ADC/DAC CHIP_EN | **38/39（31/32）** | 经跨电源域隔离，器件侧默认下拉 |
| 可选PGA OVR | **40（33）** | 经5→3.3V缓冲；不装时可作备用 |
| 继电器总允许 | **41（34）** | RELAY_ARM，外部100k下拉，硬件再与PGOOD联锁 |
| 备用 | **42（35）** | 不自动增加其他功能 |
| 扩展器中断 | **2（38）** | INTA，3.3V上拉；可不启用中断而轮询 |
| USB在位 | **1（39）** | 只接缓冲后的3.3V逻辑，不接5V |

GPIO0为BOOT，上拉并接手动下载按钮；GPIO45/46保持低strap，下载时GPIO0=0且GPIO46=0。**GPIO3外部拉高**：默认eFuse状态本来走USB JTAG；若启用strap选择，高选择USB JTAG、低选择外部JTAG。因此不把旧“GPIO3随便下拉”当成唯一正确方案。保留GPIO39–42作本计划控制用途意味着不使用外部pad JTAG。

EN模块3脚用10k/1µF候选并加复位按钮；EN不得悬空，遵守供电稳定后至少50µs、复位低至少50µs和strap保持3ms。模块1/40/41接地，2脚3.3V。原文依据模块PDF p11–16、41。

**功能来源**：两个编码器、LCD及phantom/Hi-Z/mute来自现有`05-control.md`框图。旧稿另外列的独立四按键、四LED、K4备用幻象没有新的明确用户确认，本计划不默认装配；可用LCD/编码器菜单完成控制，扩展余脚留空。LCD模块实际针序/背光电路必须按确定模块核对，不能凭ST7789控制器名虚构连接器脚序。

## 4. GPIO扩展采用MCP23017-I/SO，而非长期功能占位

技术型号：**MCP23017-I/SO，28脚宽SOIC、3.3V**。采用原厂当前[DS20001952E（2026）](https://ww1.microchip.com/downloads/aemDocuments/documents/APID/ProductDocuments/DataSheets/MCP23017-MCP23S17-16-Bit-IO-Expander-with-Serial-Interface-DS20001952.pdf)，不是旧RevC。

- GPB0/1/2（1/2/3脚）分别控制K1幻象、K2 Hi-Z、K3 **UNMUTE**。经晶体管驱动，不能直接接继电器线圈。
- 9=3.3V、10=GND、12=SCL、13=SDA、18=RESET_N接CTRL_RESET_N；11/14为NC。15/16/17地址脚全高，7-bit地址**0x27**。20=INTA到ESP GPIO2，19=INTB不并接。
- **GPA7（28脚）与GPB7（8脚）在MCP23017只能作输出**；已避开按键输入。其余未用脚在JSON明确留作备用，不自动落四LED/四按钮。
- 先保持RELAY_ARM=0，写OLATA/B=0，再配置方向。建议基线IODIRA=0x7F、IODIRB=0x78；位7设输出低，GPB0–2输出低，其余留输入并按需要设偏置。需要中断时设MIRROR=1、ODR=1，只用INTA，不把复位默认推挽INTA/B硬并。
- 硬件必须满足：K1线圈关→常开触点断开48V馈电；K3线圈关→物理静音/断开音频。**低GPIO不自动等于安全触点接法**。每路MOS栅极/驱动有默认下拉；共同线圈供电或驱动允许由RELAY_ARM与电源正常信号联锁。
- ESP内部软件/看门狗复位不一定拉低EN，也就不一定复位MCP；因此保留独立RELAY_ARM安全路径，固件启动时先清使能。若要求处理MCU卡死且ARM保持高的故障，再加独立超时联锁，不能把普通GPIO称为完整硬件看门狗。

I2C暂用100kHz，3.3V条件最高按400kHz设计。地址分配建议：ES9822普通**0x20**、同步**0x24**，ES9039 **0x48**，扩展器**0x27**；ES9822不能再改成普通0x23/同步0x27而不同时调整扩展器地址。此为明确的待实施地址分配，无既有ESP驱动会被悄悄改动。

## 5. 固定方向电平转换分组

选择技术型号与封装，不涉及价格或采购。每颗VCCA/VCCB各局部100nF，OE默认下拉；OE由两域有效条件产生，不能只在软件里延时后猜供电正常。

| 分组 / 型号 | 方向与信号 |
|---|---|
| 音频前向 **TXU0104PWR，TSSOP14** | A=1.8V，B=ESS IO3.3V；MCLK、BCLK、LRCLK、DAC_DIN四路A→B |
| ADC回传 **TXU0202DCUR，VSSOP8** | A=1.8V，B=ESS IO3.3V；B2→A2Y传ADC_DOUT，另一前向输入接地、输出NC |
| ESP↔XU控制 **TXU0202DCUR** | A=1.8V，B=ESP3.3V；A1→B1Y为XU TX→ESP RX，B2→A2Y为ESP TX→XU RX |
| Codec使能 **TXU0104PWR** | 两边均3.3V、但供电域不同；ADC/DAC CHIP_EN两路前向，器件侧下拉，余输入接地/输出NC |
| PGA SPI **TXU0304PWR，TSSOP14** | A=ESP3.3V，B=+5VA；MOSI/SCLK/CS三前向，SDO一路反向；PGA侧CS上拉到自身5V，失能时保持未选中 |
| 可选PGA OVR **TXU0202DCUR** | A=3.3V，B=5V，OVR用反向通道；不用则不装 |

**TXU0202总共两通道：一正一反，不能误认为各两路。** TXU0104是四正向，TXU0304是三正一反；不要换成TXUN0104，其OE极性不同。实际I2S建立/保持、MCLK占空/抖动和ADC往返延迟仍要计算与实测，200Mbps首页字样不等于本电路时序已通过。

MCLK保持已确定的**XU14→XU47原始1.8V回接**，仅ADC分支经过翻译；不能把3.3V缓冲输出反接XU47。SPI共享要在两个CS均高时切换模式/速率，LCD不驱动PGA MISO。

ESS I2C跨上下电域采用 **TCA9517ADGKR（VSSOP8）** 的具体方案：1=VCCA控制3.3V，2/3=控制SCL/SDA，4=GND，5=EN默认低，6/7=codec SDA/SCL，8=VCCB codec3.3V。两侧各自上拉到本域。其关电总线高阻；B侧有约0.5V偏移（最大LOW0.6V），必须核codec VOL/VILc，不能再串另一个B侧偏移缓冲。EN仅在总线空闲时切换。若最终让两域始终同电源且无独立关机，可在审查后简化，不可未经分析短接两个域。

原厂依据：[TXU0104](https://www.ti.com/lit/ds/symlink/txu0104.pdf) p4，[TXU0202](https://www.ti.com/lit/ds/symlink/txu0202.pdf) p4，[TXU0304](https://www.ti.com/lit/ds/symlink/txu0304.pdf) p4，[TCA9517A](https://www.ti.com/lit/ds/symlink/tca9517a.pdf) p1、4、7。JSON已逐脚展开。

## 6. 主电源关闭与USB回灌：画出隔离，不能靠串阻

建议图纸区分两个状态：**DIGITAL_OFF**（Hub/ESP/XU等数字电源均关）与 **AUDIO_OFF**（数字维护保留，PGA/ESS/继电器关闭）。不能用一个含糊的“关机”覆盖所有供电组合。

1. **上游USB数据断电保护技术方案：TS3USB221ARSER**。10脚UQFN，VCC10跟数字3.3V、GND5；USB-C保护后D+/D−进公共8/7，Hub D+/D−接支路1的1/2，S9接地选支路1；OE6高=断开，默认上拉，只有数字电源有效且真实VBUS存在才拉低。未用支路2不走长stub。该型号p5给出VCC=0时I(OFF)≤2µA（输入0～5.25V），是有条件的有限漏电保护，不是绝对零漏电/隔离耐压。
2. **VBUS检测：SN74LVC1G17DBVR**。SOT23-5，A2接保护后的真实VBUS检测线，GND3、Y4为USB_PRESENT_3V3、VCC5=数字3.3V、NC1留空；Y加下拉。其输入支持至5.5V且有Ioff，避免ESP裸输入钳位给掉电3.3V轨充电。输出同时给ESP GPIO1与两桥VBUS9；不得接可能被DC保持的V5D来冒充USB在位。
3. **数字开、模拟关**：所有PGA/ESS翻译OE低、I2C隔离EN低、CHIP_EN器件侧低、RELAY_ARM低。不能让ESP高电平经SPI/I2C/复位脚给掉电模拟芯片反灌。
4. **若要求Hub继续工作但单独关闭ESP**，上述“所有数字同组关机”已不成立：必须在Hub端口2另放USB数据隔离，且CH343P-A与ESP同组掉电或隔离其TXD/DTR/RTS；不能只拉EN低、串22Ω或断3.3V就宣称无回灌。
5. **主电源/外部DC/USB VBUS的电源导通与反向阻断仍需电源设计方案落实**。上述数据开关不隔离VBUS电源。PSELF、PWREN、OVCUR和MaxPower必须跟最后选择一致，不将它们自动冻结成错误的总线供电配置。

原厂依据：[TS3USB221A](https://www.ti.com/lit/ds/symlink/ts3usb221a.pdf) p3/5/13、[SN74LVC1G17](https://www.ti.com/lit/ds/symlink/sn74lvc1g17.pdf) p1/3。两者均是技术方案，未做商城选型。若USB高频/PCB验证要求不同，可替换为具有等效明确关断与掉电额定的方案后重新核脚，不能只凭“USB switch”名称替换。

## 校验结果与交接

脚号唯一覆盖：CH334U 28/28，CH343P各17/17（含0号焊盘），ESP模块41/41，MCP23017 28/28；GPIO35–37未外用，固定UART0/USB及XMOS网络方向保持。尚未运行实板、ERC/DRC或ESP固件测试。

设计落实前需最终确认：电源域开关语义与GANG保护、IO_READY硬件条件、LCD实际模块脚序、继电器掉线圈的真实静音触点、原生库符号与封装。电气方案具体型号已经列出；MPN采购信息、库存/价格没有查询或修改。

</details>
