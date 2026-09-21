# RevA 单 USB-C 5V 电源设计基线

日期：2026-09-16。技术设计选择，不涉及采购价格。只使用单 USB-C 的 5V；不引入 DC 插座、电池或 PD 高压。输入页、数字电源页可按本文件落图。新器件原厂PDF归档在 `docs/datasheets/power-reva/`；逐脚与候选值见[电源连接清单](../../hardware/asio-card-reva/power-pin-candidatevalues.json)。本文件替代旧电源树作为RevA设计输入；未闭合的上电/保护项不因落图而自动通过。

## 先冻结的产品边界

1. **Default USB current 不是 1.5A，更不是看到USB-C就有3A。** USB2未配置按100mA，配置后也只能依实际授权在≤500mA范围。本方案原型在Default档仅保留CC检测/低功耗电源指示，主音频和Hub都不启动；不谎报self-powered来取得电流。
2. **1.5A档只默认开放数字枚举、控制、USB回环；完整模拟音频要求3A。** 1.5A档默认关闭模拟正负轨、ADC/DAC模拟支路、耳放及幻象，无线禁用、背光低；只有另行验证的低功耗profile才能开放部分模拟功能。电流监测超过软件预算则先降载，不能让硬限流持续振荡充当功率管理。
3. 这是少芯片且能安全启动的边界：省去单独的USB低功耗管理MCU。代价是Default广告端口/普通A转C线不会启动音频。若以后要求在Default 500mA也提供USB状态/降级音频，必须追加真实的低功耗枚举与Hub功率预算设计，不将CH334 PWREN当作任意500mA授权。
4. 单USB-C可实现，并不等于所有主机端口可供应整机所需功率。当前电源器件和PCB仍是工程原型，未声称通过USB认证、纹波、热或上掉电测试。

## 拓扑与网名

```text
USB-C VBUS -> VBUS_RAW
  |-- 100Ω限故障电流 -> V5_AON_IN -> TPS7A2033PDBVR -> V3V3_AON
  |      仅TUSB320LAI、逻辑、欠压监控；不挂ESP32/Hub/屏幕
  |
  |-- TPS259470ARPWR（反向阻断、可调限流、可调OVLO、软充电） -> V5_SYS
         |-- SY8089AAAC 3.3V -> V3V3_D（ESP32、Hub、数字外围）
         |     |-- TPS7A2018PDBVR -> V1V8（XU全IO/OTP/Flash）
         |-- TPS7A2033PDBVR -> V3V3_USB（XU USB PHY）
         |-- SY8089AAAC 0.9V -> V0V9 -> 板级滤波 -> V0V9_PLL
         |                     V1V8 -> 板级滤波 -> V1V8_USB
         |-- TPS65131RGER -> V6P_RAW ≈+6.45V / V6N_RAW ≈−6.50V
         |     |-- TPS7A3901DSCR -> V5P_AFE / V5N_AFE ≈±5V（PGA、OPA）
         |     |-- TPA6120A2直接用V6P_RAW / V6N_RAW
         |     |-- GM1205ACPZ-R7 -> V4V5_ADC（独立4.5V参考模拟轨）
         |     |-- TPS61170DRVR + 原厂倍压整流 -> V48_RAW -> RC -> PH48
         |-- 低噪3.3V源 -> ADC/DAC各局部电源域，保持可分别时序控制
```

对接已画主控：原理图沿用 **V0V9、V1V8、V0V9_PLL、V1V8_USB、V3V3_USB**。本文件早期讨论中的V0V9_CORE/V1V8_IO只是这些网的功能别名，不新增平行电源网。

## 输入页：硬件自主检测与限制

### CC检测：TUSB320LAIRWBR，GPIO/UFP模式

来源：TI `tusb320lai.pdf` Rev.D，p3引脚、p6 RVBUS、p12表3、p28初始化。

| pin | 接法 |
|---|---|
| 1 CC1、2 CC2 | 分别到Type-C CC1/CC2；用芯片内部Rd，不再并接第二套5.1kΩ |
| 3 PORT | GND，固定UFP/sink，不悬空成DRP |
| 4 VBUS_DET | 经887kΩ/1%接VBUS_RAW（满足855–920kΩ要求） |
| 5 ADDR | NC，GPIO模式，不装I2C上拉/下拉 |
| 6 OUT3 | 不使用，标NC；它是音频附件标志，不是普通USB音频使能 |
| 7 OUT1、8 OUT2 | 各10kΩ上拉V3V3_AON；只接AON逻辑和高阻模式检测 |
| 9 ID | NC（本机不做DFP） |
| 10 GND、11 EN_N | GND；LA版本低有效，勿混HA版本 |
| 12 VDD | V3V3_AON，近端100nF；不得直接接可能超过5V的VBUS |

OUT1/OUT2：HH=未附着；HL=Default attached；LH=1.5A；LL=3A。SN74LVC2G04DBVR（p3：1=1A、6=1Y、3=2A、4=2Y、2GND、5VCC）由3.3AON供电，得到 `ALLOW_MAIN=!OUT1` 和 `MODE_HIGH=!OUT2`。Default时MODE_HIGH也可能高，但ALLOW_MAIN为低，故主开关仍关闭。

### AON与欠压安全态

- `R_AON=100Ω/1%/1W`，VBUS_RAW到V5_AON_IN。其后1µF/10V到地，TPS7A2033PDBVR（1IN/2GND/3EN/4NC/5OUT），EN接输入、OUT=3.3AON，输出2.2µF/10V且保证有效≥0.47µF。单个LDO/后端短路即使在5.5V输入也被100Ω限制到约55mA；电阻最坏约0.303W，1W留降额余量。**主电源不得经过这只电阻。**
- AON设计正常预算≤5mA；必须实际测量。USB直接侧只留AON输入1µF和主eFuse近端100nF，其他大电容全部在eFuse之后；还需最终核算完整USB入口浪涌。
- `TPS3808G01DBVR`：6VDD=3.3AON、2GND；5SENSE以90.9kΩ/0.1%从VBUS_RAW接入，10kΩ/0.1%到地，标称负向阈值0.405×10.09=**4.086V**。芯片G01阈值±2%、输入漏电和电阻误差必须计入，约4.00–4.18V范围，不能宣称精密4.086V硬点。
- 4CT接22nF/5%到地，公式 `CT(nF)=(tD(s)−0.0005)×175`，标称延迟约126ms；实际延迟容差按手册验证。3MR接10k到3.3AON，预留开漏`SYS_KILL_N`；1RESET为开漏，接主eFuse EN节点。
- `ALLOW_MAIN -> 47kΩ -> EFUSE_EN`，EFUSE_EN另100kΩ到GND，TPS3808 RESET直接下拉此节点。因此CC未允许、AON未起、欠压或MR低均保持主开关关闭。47k/100k还使AON<1.7V时可能出现的逻辑高被缩到<1.16V，低于eFuse最低1.183V开启门槛；AON有效后由RESET保证延迟。
- 该电源监控默认失效为关断，不依赖ESP32先启动。USB附着电流升降也不依赖固件轮询。

### 主开关：TPS259470ARPWR，必须是470A

TI `tps25947.pdf` Rev.C，p4比较表：**470A=可调OVLO+主动限流+AUXOFF/FLT**；474是断路器型，472是过压钳位型，不能混替。

| pin | 连接/候选值 |
|---|---|
| 1 EN/UVLO | EFUSE_EN，如上硬件门控 |
| 2 OVLO | VBUS_RAW→34.5kΩ/0.1%→OVLO→10kΩ/0.1%→GND；约5.34V typ关断，阈值分散约5.27–5.45V，含泄漏另核 |
| 3 AUXOFF | 10k上拉3.3AON，命名MAIN_PATH_ON；表示输入有效且充电完成，**不是带独立阈值的PG** |
| 4 FLT | 10k上拉3.3AON，送高阻FAULT监测；未上电ESP侧须避免反灌 |
| 5 IN | VBUS_RAW，近端100nF/10V |
| 6 OUT | V5_SYS，初始47µF/10V，其他大电容经分阶段开启 |
| 7 dVdt | 10nF/16V到GND，约0.2V/ms typ、5V约25ms；最终按实际CLOAD/SOA复算 |
| 8 GND | GND |
| 9 ILM | 2.74kΩ/0.1%到地；并联支路2.49kΩ/0.1%+受MODE_HIGH控制的N-MOS到地；ILM可经高阻RC送ADC |
| 10 ITIMER | NC，最快过流响应；不加允许长时间2×ILIM的延时电容 |

`ILIM_typ≈3334/RILM`：1.5A档=1.217A typ；3A档并联约1.3045kΩ=2.556A typ。按>1A区±10%及电阻容差估上沿分别约1.340A、2.814A；即使预留AON100mA故障级预算，总量仍约1.440A/2.914A，低于1.5A/3A。**这不是纳秒级绝不越限的保证**，eFuse有响应时间，正常运行还要用更低软件预算。

N-MOS的RDS(on)增加只会降低3A档限流；需低漏电、VGS=3.3V能开通、VDS≥12V，选定后核引脚。MOS默认100k栅极下拉。CC从3A变1.5A时硬件立即撤销并联支路；变Default时硬件直接关闭主开关。

## 数字电源页：现阶段可落图

| 支路 | 器件/参数 | 控制与边界 |
|---|---|---|
| V3V3_D | SY8089AAAC：上270k/下60.0k，均0.1%；VREF0.6V→3.3V；L2.2µH，输入10–22µF、输出有效建议>22µF | 只在MAIN_PATH_ON为高后启动。1EN/2GND/3LX/4IN/5FB；不是A1AAC，VIN≤5.5V。该型号已知NRND，作为本次技术兼容候选，非采购批准 |
| V1V8 | TPS7A2018PDBVR，从V3V3_D供电；CIN2.2µF、COUT4.7µF/10V | 1IN/2GND/3EN/4NC/5OUT。有效输出0.47–200µF、ESR≤100mΩ；将整条IO/Flash去耦计入。由3.3→1.8减少热耗 |
| V3V3_USB | TPS7A2033PDBVR，从V5_SYS供电；CIN2.2µF、COUT4.7µF/10V | XU USB PHY专用域；同封装脚位。与1.8V一起先建立 |
| V0V9 | SY8089AAAC：100k/200k 0.1%；L2.2µH；CIN10–22µF、COUT22–47µF候选 | CORE_ENABLE默认100k下拉；由[启动电路](reva-xmos-boot.md)的IO/USB监控开漏输出合成，不依赖MCU先运行。目标0.855–0.945V包括静态、纹波、动态、线损 |
| V0V9_PLL、V1V8_USB | 分别由V0V9、V1V8经主控已核滤波支路供电 | 不建立独立不相关稳压源；PLL磁珠/阻容与主控逐脚表衔接 |

3.3V上270k/下60.0k的静态计算正确，但仍有参考±2%和动态误差；Hub要求3.2–3.4V，建议Hub由独立TPS7A2033PDBVR（V5_SYS输入）供电，名称`V3V3_HUB`，不要将Buck最大动态容差直接当Hub已通过。Hub在Default档不启动。

## 模拟域：采用分轨，不采用共用±5.1V

TPS65131总输出精度3%、TPS7A39负输出精度3%，都不足以让同一对±5.1V同时保证TPA≥5V和PGA≤5.25V。以±3%举例，可选标称必须同时≥5/0.97=5.155V且≤5.25/1.03=5.097V，区间为空。

因此冻结拓扑为：**TPS65131约±6.5V给TPA；TPS7A3901再稳压±5V给PGA及OPA**。这增加一颗双LDO，但解决保证范围冲突并降低前端开关噪声。

### TPS65131RGER

- 正输出R上432kΩ/R下100kΩ，0.1%，标称+6.453V；负输出R3=536kΩ接VNEG↔FBN、R4=100kΩ接FBN↔VREF，标称−6.502V。**负反馈下端是VREF，不是GND**。
- 按TI p11图8-1：正/负各4.7µH（建议Isat≥3A、Irms≥2A，具体DCR/温度选型后验证）；输入各有效≥4.7µF，输出各有效≥22µF；候选名义47µF/16V以便保容。CP10nF、CN4.7nF、VREF220nF，VIN由V5_SYS经100Ω+100nF滤波。
- FFP约6.8µs/432kΩ=15.7pF，FFN约7.5µs/536kΩ=14.0pF；先放16pF/15pF C0G，属于计算起点，负载阶跃和环路需验。
- 正整流D1：A=SWP、K=V6P_RAW；负整流D2：A=V6N_RAW、K=SWN；候选肖特基≥40V/2A，按实际温升/峰值复核。按图8-1保留由BSW驱动的正输入PMOS，以断开关断时VIN→L→D的直通路径。
- PSP/PSN先接GND禁用省电跳频；ENP/ENN接同一ANALOG_RAW_EN且100k下拉。只在数字控制启动并确认功率预算后使能。
- 设计能力目标改为正轨600mA、负轨250mA；并发稳态分配约正448mA、负190mA（见后表），两者不是同一含义。按最低V5_SYS=3.8V，TI p13式3/4的峰值估算为正约1.592A、负约1.059A，需与具体输入/温度下开关限流和实测波形核验；1.8A限流min的表内测试条件是VIN=3.6V，不能偷换成所有工况保证。4.7µH需按Lmin、1.25MHz频率min和负载计算。AFE静态正93mA/负95mA，不能沿用早期一颗OPA1612的预算。

### TPS7A3901DSCR

- 输入V6P_RAW/V6N_RAW；正反馈上32.4k/下10k，负反馈OUTN↔FBN为42.2k、FBN↔BUF为10k，均0.1%。TI p37式13/14与同页参考值支持；约+5.037V、−5.022V。
- 正输出全条件±1.5%、负输出±3%再计外阻后，再给反馈偏置电流留约4.2mV外部误差预算后，静态约+4.95…5.125V、负幅4.857…5.187V；给PGA4.75–5.25V留动态裕量。PGA VD−经10Ω支路，最大2mA时额外约20mV仍在静态范围内；上/掉电差分仍需验证。
- 输入和输出每轨有效≥10µF；CNR/SS=10nF，正负各10nF前馈按官方连接。EN≥2.2V，接3.3V控制，默认下拉。输出命名V5P_AFE/V5N_AFE。
- AFE每轨预算120mA，器件能力150mA/轨；两颗OPA1656+三颗OPA1612+PGA的93mA静态上界已占较大比例，信号驱动和外部负载另核。±6.5→±5在120mA/轨约0.36W损耗，仍需热布局。

### ADC 4.5V与DAC分区电源

ADC 4.5V从正6.45V经独立GM1205产生，RSET45.0kΩ/0.1%、CSET4.7µF、输入10µF/输出有效≥10µF，OUTS就近Kelvin，ILIM接GND使用内部限制，支路能力先按150mA评估，正常运行只分配60mA；两者不可同时当作并发预算。输出`V4V5_ADC`再按ADC原厂图分AVCC时钟/左/右局部去耦；不把此网接内部DVDD。

3.3V模拟源仍可采用独立GM1205，RSET33.0kΩ；DAC的 `V3V3_DAC_DIG/CLK/L/R` 必须保留逐域使能顺序，不能在电源页直接并网。局部开关及精确电源容差由主任务与音频页同步落实；这一项尚未冻结到开关器件逐脚。

## 48V：采用TI实际参考倍压电路

**TPS61170DRVR，直接复制其英文PDF p22 Figure20的Boost+倍压连接，输入接V6P_RAW。** 原图输入4.5–15V/输出48V 60mA，故本机6.45V输入落在参考范围；比从有压降的USB直接喂XL6019可靠。本机只分配一路幻象≤15mA，加泄放及控制余量总≤20mA，不承诺60mA整机额度。

- L=22µH；CIN4.7µF；飞跨C2=1µF；中间C3=4.7µF；C4=4.7µF。**C4按原图跨在V48_RAW与VMID之间，不是从V48到GND**。
- SW接L后端；D3 A=SW/K=VMID；C2接SW↔PUMP；D2 A=VMID/K=PUMP；D1 A=PUMP/K=V48_RAW；C3 VMID到GND；C4 V48_RAW到VMID。D1–D3原图B140，工程可按≥60V/1A低漏电肖特基规格先画，额外耐压不代表瞬态已验。
- 上反馈380kΩ/下10kΩ，0.1%，名义47.931V（1.229V基准）；COMP经10kΩ串10nF到地。FB pin1、COMP2、GND3、SW4、CTRL5、VIN6、EPAD GND。
- CTRL由PHANTOM_EN控制且100k下拉；必须先RAW正轨稳定。普通Boost使能关闭后输出并不天然隔离；K1应先断开，再关CTRL，并用100kΩ/≥0.125W泄放。PH48滤波先放47Ω/0.25W+10µF/63V起点，反馈留在V48_RAW；约14mA时电阻降0.66V，需纳入最终幻象电压验收。
- 48V功率0.96W@20mA，按该级效率75%的工程预算，需要正6.45V约198mA；这还会占TPS65131正轨负载与USB总预算。**只在3A档允许幻象**，上电/插拔及故障用真实波形验收。

## 状态机与功率档位

| 状态 | 硬件权限 | 软件策略 |
|---|---|---|
| 未附着/CC异常 | OUT1高，eFuse关闭；AON静态运行 | 所有电源EN下拉，继电器断开 |
| Default，未配置 | 仅AON，目标≤5mA，主系统不启动 | 不超过USB2未配置100mA，不装外部第二组Rd |
| Default，即使主机能力写500mA | 首版仍仅AON，不利用未建立的配置授权 | 明确显示/说明端口不支持此原型完整音频 |
| Rp=1.5A | eFuse约1.217A typ | 主输入软件上界≤1.0A；仅数字枚举/控制/USB回环。模拟默认关闭，RF禁用、背光低；不承诺基础全双工模拟音频 |
| Rp=3A | eFuse约2.556A typ | 软件电流上界≤2.2A（已计IMON/ADC误差）；可依预算开放幻象/耳机目标档，低线压先关幻象；不是无限制耳放输出 |
| 3A降1.5A | 硬件先撤销ILM并联支路 | 立即关幻象、降低耳机/背光，重新审预算 |
| 降Default/拔线/欠压 | 硬件关eFuse | 继电器硬件失电断开；输入信号和各轨放电必须满足模拟芯片边界 |
| USB Suspend | 维持CC状态检测，进入低功耗策略 | 关幻象、AFE、ADC/DAC、XU音频/背光/无线；保留能响应resume的Hub/ESP低功耗链路，验证USB电流规范；不能关掉整个Hub后假称还能靠USB resume唤醒 |

以最低V5_SYS=3.8V作功率预算：1.5A档按1.0A软件门最多约3.8W，3A档按2.2A门约8.36W。数字/音频实际分配还要扣各级损耗；旧表930mA@5V≈4.65W已经高于1.5A档的保守软件额度，因此不能承诺1.5A在所有采样率/输入/耳机负载下全功能。3A档才是首版整机目标电源条件。


### 完整并发预算（设计额度，不是典型值冒充保证值）

以下取V5_SYS=4.25V；TPS65131和48V级效率各按75%作保守工程预算，数字Buck按85%。这些效率均须实测。电流额度是本机功率管理目标，不是芯片datasheet最大耗流。

| 项目 | 正常并发额度 | 折算V5_SYS输入功率 |
|---|---|---|
| AFE全部器件 | ±5V各120mA；含PGA及新增两颗ADC驱动OPA1612 | 与下列三项合计经双极变换器约5.505W |
| TPA双声道 | RAW每轨平均70mA额度；1Vrms/32Ω点约58mA平均、瞬时约118mA/轨，需储能及响应余量 | 不能以2×31mW耳机输出代替功耗 |
| ADC4.5V支路 | 正常60mA；150mA是支路能力目标 | RAW取电60mA |
| 48V幻象 | 输出总20mA；含一路麦克风/滤波/泄放余量 | RAW正轨约198mA，已计75%效率 |
| 0.9V核 | 0.8A分配额度、85%效率 | 0.847W |
| 3.3V数字 | 总300mA（含ESP、低背光及1.8V LDO输入）、85%效率 | 1.165W |
| ESS3.3V域 | 总120mA额度、LDO从4.25V输入 | 0.510W |
| Hub | 60mA额度、3.3V LDO从4.25V输入 | 0.255W |
| XU3.3V USB PHY | 30mA额度 | 0.128W |
| AON / 其他裕量 | 25mW / 200mW | 0.225W |
| **已列项目小计，未含继电器线圈** | RAW正约448mA、负约190mA | **约8.634W，即约2.032A@4.25V** |
| 继电器线圈（独立待定） | K1/K2/K3/K4的精确线圈与并发状态未选；若沿用旧5V/30mA占位且3–4只同时吸合 | **另加约0.45–0.60W，驱动和转换损耗另计**；不能包含在200mW杂项内 |

因此3A档有工程上的可实现空间，但**全并发预算尚未因这张表而闭合**。仅加上述占位线圈就约9.08–9.23W@4.25V（转换损耗另计），约2.14–2.17A，已经接近2.2A软件上界。线圈必须使用独立受控供电，不可挂到已分配120mA的AFE±5V轨；其真实吸合电压、温度降额、保持电流与供电实现仍需冻结。1.5A不够同时开放以上额度。在V5_SYS约3.8V时须先禁止幻象/降载，不能继续保证全功能。Firmware应使用经增益和ADC误差修正后的`I_UPPER`决定能否开放下一模块，而不是用裸ADC读数2.2A作阈值；IMON最坏误差和电阻模式变化要同时计入。

以上没有把各芯片保护电流相加当作日常耗流。实际样机若比额度高，应缩减功能或重新设计，不能提高USB请求之外的限流值。

## 物理验收后才可关闭的项目

- CC翻转/插拔/广告降级、AON先起及eFuse EN上电波形、Default正常电流与入口浪涌。
- eFuse的ILIM、输入反灌、OVLO/UVLO范围和实际总CLOAD下软启动/SOA；限流是保护，不是日常稳态工作点。
- **XU CORE_ENABLE/RESET拓扑已补入[启动方案](reva-xmos-boot.md)**：三颗TPS3897A监控器、开漏联锁及1.8V复位上拉可用于草图；原理图实现、最低线末电压下的负载瞬态、IO/core爬升间隔和实测复位波形仍未验收。不能把静态阈值计算当成完整动态窗口验证。
- TPS65131输入/两轨峰值电流、二极管/电感温升、真实补偿与跳频；±5AFE极限和VD−动态差。
- **尚未闭合：DAC DIG→CLK→L/R逐轨时序开关的具体器件/逐脚连接**，不能提前把局部网短成一条3.3V。
- **尚未闭合：PGA幻象浪涌经保护二极管注入AFE轨时的能量吸收/钳位**。TPS7A39不是任意电流吸收器；仅加反向保护二极管不等于把AFE轨限制在±5.25V以内，关闭此项前PHANTOM_EN须禁用。
- **尚未闭合：TPA掉电时输入峰值<600mV的硬件输入静音/隔离**；仅断开耳机输出继电器不足以满足，不能在未关闭此项时宣称可安全任意开关耳放电源。
- **尚未闭合：继电器线圈独立电源与真实并发功耗**，不能把暂用5V/30mA当已选规格，也不能占用前端LDO的剩余容量。
- 倍压SW/PUMP/VMID电压、48V最大/最小值、纹波、20mA负载、幻象插拔与泄放时间。
- USB Hub bus/self-powered描述、固定内部端口以及Type-C高电流下的实际配置，必须由USB页落实；不虚报self-powered。

主要原厂来源：TI [TUSB320LAI](https://www.ti.com/lit/ds/symlink/tusb320lai.pdf)、[SN74LVC2G04](https://www.ti.com/lit/ds/symlink/sn74lvc2g04.pdf)、[TPS3808](https://www.ti.com/lit/ds/symlink/tps3808.pdf)、[TPS25947](https://www.ti.com/lit/ds/symlink/tps25947.pdf)、[TPS65131](https://www.ti.com/lit/ds/symlink/tps65131.pdf)、[TPS7A39](https://www.ti.com/lit/ds/symlink/tps7a39.pdf)、[TPS61170 Figure20](https://www.ti.com/lit/ds/symlink/tps61170.pdf)；既有芯片具体参数见本项目 `docs/datasheet-audit/power.md`。[USB-IF互操作测试电流要求](https://www.usb.org/sites/default/files/3.2%20Interoperability%20Testing%20v0.99%20w%20USB%20Type-C.pdf)给出HS及以下未配置100mA/配置500mA，Type-C电流广告另按对应规范执行。
