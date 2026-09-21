# XU316 C24 逐引脚/固件网络核对

日期：2026-09-16。已停止采购/查价。仅新增本说明及 `xu-pin-net-plan.json`，未改固件、未操作 EDA。JSON 覆盖 **60 个周边引脚 + 5 个底部焊盘，共 65 个编号**，其中 34 个 GPIO。方向均从 XU316 看；页码为本地 QF60A PDF 的物理页码。

依据：`docs/datasheets/XU316-1024-QF60A.pdf`（XM014034B）；当前自有应用的 `.xn`、`xua_conf.h`、`xua_conf_tasks.h`、UART/audiohw/XUD_HAL；仅定点读取 `lib_sw_pll/src/sw_pll_common.c`、`lib_xua` 的 main/audiohub/ep_buffer。JSON记录主要源文件SHA256。

## 可直接用于功能草稿的连接

| 功能 | XU物理脚 / 信号 | 固件端口 | 网络/方向 |
|---|---|---|---|
| QSPI CS# | 3 / X0D01 | tile0 1B | QSPI_CS_N_1V8，输出 |
| QSPI CLK | 5 / X0D10 | tile0 1C | QSPI_SCLK_1V8，输出 |
| QSPI IO0/1/2/3 | **59/1/60/2** | tile0 4B[0/1/2/3] | 四条1.8V双向线 |
| USB VBUS检测 | 6 / X0D00 | tile0 1A | VBUS_SENSE_1V8，输入 |
| 控制UART TX/RX | **41/43**，X0D35/36 | tile0 1L/1M | CTRL_TX_XU18 / CTRL_RX_XU18，经电平转换连ESP32 |
| I2S DAC数据 | 9 / X1D00 | tile1 1A | DAC_DIN_XU18，输出，经升电平送DAC |
| I2S LRCLK | 10 / X1D01 | tile1 1B | I2S_LRCLK_XU18，输出；ADC/DAC共用时钟源 |
| I2S BCLK | 13 / X1D10 | tile1 1C | I2S_BCLK_XU18，输出；ADC/DAC共用时钟源 |
| MCLK输出/内部读取 | **14 / X1D11** | tile1 1D + AppPLL硬件复用 | XU_MCLK_1V8 |
| USB MCLK回接输入 | **47 / X0D39** | tile0 1P | 同一XU_MCLK_1V8；该脚归VDDIOT |
| ADC数据 | 53 / X1D34 | tile1 1K | ADC_DOUT_XU18，输入，需3.3→1.8V转换 |
| 调试TX | 32 / X1D13 | tile1 1F | DEBUG_TX_XU18；CH343P-B的VIO=1.8V才可直连 |
| 调试RX预留 | 39 / X1D22 | tile1 1G | 仅XN命名，当前没有接收任务/CLI |
| 可选xSCOPE IN1/IN0/OUT0/OUT1 | **33/35/36/37** | tile1 XL0 / 4D复用 | 当前XN已声明XL0，暂保留 |

新增 `_XU18`/`_1V8` 网名只区分电平转换器两侧，保留旧CTRL、ADC_DOUT、DAC_DIN等功能；不得把不同电压域仅用同名网直接并起来。所有GPIO均为1.8V，USB D±为专用PHY例外，不是普通1.8V GPIO。

## MCLK：只有一条外部回接，不是额外三个时钟脚

手册 **p15–16 §7.2/Fig7、9** 明确：AppPLL输出到 **X1D11/物理14**，tile1同时可从自身PORT_1D内部读到这个时钟。**不需要额外tile1输入脚或把另一GPIO回接给tile1。** 当前`sw_pll_fixed_clock()`设置AppPLL及寄存器0x0E，启用此输出；寄存器依据见p64。

必须走板上连接 **14 → 47（tile0/1P）**，供USB异步反馈时钟。14再分支到ADC MCLK的合规升电平/扇出网络。当前名义MCLK为22.5792/24.576MHz；源码固定频率表的22.5792族实际注释为22.579186MHz，不能把名义值当零误差测量结果。

`PORT_MCLK_COUNT=tile0/16B`仅用于`set_port_clock`后读取`getts`时间戳，**没有另一个需要接MCLK的物理输入脚**。16B与1M、1P共享的外部焊盘不是冲突：p12说明启用的窄端口优先于宽端口，其余位仍保持宽端口资源。不要为计数端口把40/44/45/46/48/50/51/54/55/56/58等脚连上MCLK。

## 完整供电/底部焊盘

| 电源 | 全部物理脚 | 正常工作电压 |
|---|---|---|
| VDD → V0V9 | **4/12/19/27/34/42/49/57/61/62/63/64** | 0.855～0.945V，标称0.900V |
| PLL_AVDD → V0V9_PLL | **22** | 同0.9V范围，低噪声滤波支路 |
| VDDIOL → V1V8 | **8** | 1.62～1.98V |
| VDDIOB18 → V1V8 | **17、26** | 1.62～1.98V；不能漏26 |
| VDDIOR → V1V8 | **38** | 1.62～1.98V |
| VDDIOT → V1V8 | **52** | 1.62～1.98V |
| USB_VDD18 → V1V8_USB | **31** | 1.62～1.98V |
| USB_VDD33 → V3V3_USB | **30** | 3.0～3.6V |
| VSS → GND | **65中央大焊盘** | 地；**61～64绝不能接地** |

p27要求核心至少8颗就近100nF，VDD/VDDIO各保留≥10µF bulk，IO各电源脚局部去耦；PLL示例为1µF与600Ω@100MHz、DCR<1Ω磁珠，须计直流压降。全部电源单调爬升，IOL/R/T有效且Flash就绪后才释放RST_N；单一1.8V IO轨可简化POR条件。此表仅定义负载电源要求，不替代仍未冻结的上游电源树。

## 1.8V Flash：8脚功能占位，不选型号

采用常见8脚串行Flash**功能占位**：1=CS#→XU3；2=IO1→XU1；3=IO2/WP#→XU60；4=GND；5=IO0→XU59；6=CLK→XU5；7=IO3/HOLD#/RESET#→XU2；8=1.8V供电，并局部去耦。**具体Flash的脚序、7脚功能、封装/QE位/启动时间未选定，不能声称任意1.8V Flash均兼容。** 当前XN的2MB、256B页、4KB扇区只是目标几何。

QSPI ROM脚位固定，不能仅改XN搬引脚；p18–19要求启动采样`X0D06/X0D05/X0D04=000`。这对应物理**60/1/59**，内部默认弱下拉。因此不能照通用SPI模板给IO2/WP#或IO0/IO1盲目上拉；CS#应上拉到1.8V保持复位时Flash未选中。选定Flash后还须确认WP#/QE与写保护的具体关系。

ROM使用0xEB、3个0地址字节、1个dummy字节、mode0/0；Flash应在300µs内就绪，否则外部保持复位。QE/Quad状态及暖重启恢复必须核对，不能让Flash残留QPI状态。旧3V W25Q16JV不能直接沿用。

## 未用脚和XTAG

- **真正NC只有25**，不得接任何网络/测试点/地。
- 当前可不接的GPIO为7、11、40、44、45、46、48、50、51、54、55、56、58；39为未实现调试RX预留。7是**tile0/1D**，旧1-bit预算漏了它，它不是AppPLL输出。
- 未用GPIO可留空/测试点；复位有弱下拉，但16B输入计数资源启用后应核对剩余焊盘拉电阻状态，不把复位默认状态当运行期保证。不要把未用GPIO直接硬接电源/地以“填满图纸”。
- 当前`.xn`启用XL0且编译带`-fxscope`，33/35/36/37先保留；复用这些脚需同步改固件。调试UART不等同于xSCOPE链路。
- **推荐首版明确的2×5、1.27mm xSYS2 JTAG口，XTAG4/1.8V**：1=VDDIOB18/VREF，2=TMS，3=GND，4=TCK，5=GND，6=TDO，7=GND，8=TDI，9=GND，10=RST_N。依据p77，JSON已列对应XU脚号。
- 完整2×10可选：11=VREF_LINK/VDDIOR，12/14=XL0 IN1/IN0，16/18=XL0 OUT0/OUT1（输出端近XU串43Ω）。**本地p78正文把X1D16～19写成X0D16～19，而且说pin13接VDDIO，和Fig52的pin13=GND矛盾。** JSON明确保留疑点；未进一步核XTAG4原厂定义前，采用2×5避免把电源/地接错。20=DEBUG_N不应虚构连接到QF60A不存在的专用脚。

## 必须回写但本轮未修改的问题

1. `XUD_HAL.xc`注释仍写V5D经100k/100k，需改成真实USB VBUS与1.8V兼容分压（当前候选220k/100k），并检查掉电反灌。
2. `xua_conf.h`仍写ES9039“100MHz/无需MCLK”，与已核ESS手册冲突；本表只确定XU→ADC/USB的时钟，不批准DAC最终时钟方案。
3. 跨tile共享全局缺陷仍存在；UART引脚正确不代表DSP控制已通。通道/interface传输应在固件后续修复。
4. QF60A附录G将QSPI数据脚称为“output only”与主引脚表及Quad Read行为冲突；四线必须按双向QSPI处理，不能依该复制错误禁用读数据。

校验边界：逐编号覆盖65/65、GPIO34/34、声明端口均有引脚或明确“内部计数资源”解释；未运行硬件、未重新编译、未做EDA ERC/DRC。root负责将这个功能计划落实到已指定原生工程，并完成最终器件引脚/电平/网表核对。
