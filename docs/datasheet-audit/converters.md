# ADC / DAC 原厂 PDF 参数复核

> 核验范围：本地 7 份转换器 PDF，覆盖现用 ES9822PRO、ES9039Q2M，以及 ES7210、ES8156、ES9018K2M、ES9038Q2M、CS4272 备选。每份均重新打开真实 PDF，按电源、IO、时钟、模拟接口、控制协议和封装查阅；图文冲突处另外渲染检查。本文不更改原设计、BOM 或固件，也不代表样机测试通过。
>
> 下文 **pN 是从 PDF 第一页开始计数的物理页码**，这 7 份文件的正文印刷页码恰与物理页码一致。`推荐`、`绝对最大值`、`典型性能`分别记录，不相互替代。地址均明确区分 7-bit 地址和线上包含 R/W 位的 8-bit 地址字节。

## 1. 最重要的区分：DVDD 不存在跨型号通用接法

| 芯片/本地版本 | 标准 DVDD / 数字电源接法 | 手册是否建立外供条件 | 本项目可以据此做什么 |
|---|---|---|---|
| ES7210 Rev9.1 | VDDD 是外部数字供电输入，1.6–3.6V；VDDP 是独立 IO 供电 | 未提供可旁路的内部核心 LDO 外供模式 | 按真实外部电源脚处理，不套用 ESS 的“DVDD 内部输出”概念 |
| ES8156 Rev3.0 | DVDD 是外部数字供电输入，1.6–3.6V；PVDD 为 IO 供电 | 同上 | DVDD=1.8V 在其推荐范围内，与 ES9822/9039 的同名节点含义不同 |
| ES9018K2M v3.7 | 默认 DVCC→内部约1.2V DVDD，去耦2.2µF | **明确允许并在指定高时钟/采样率条件要求外供1.3V±5%**；外供电压高于内部1.2V，使内部供电退出；见p7、28、31 | 不能写成“DVDD一律不能外供”；也不能把其外供1.3V做法平移给其他型号 |
| ES9038Q2M v1.4 | 内部约1.2V，推荐4.7µF去耦 | p4、11、50没有给出外供启动、停内部LDO或外供容差/时序方案 | 标准工程采用内部供电；**外供1.2V是否可用，现文件未建立条件**。这不等于证明任何外供方案都物理不可能 |
| ES9039Q2M v0.2.3 | DVDD(pin9)内部1.2V，p11要求1µF去耦 | 检查p11、50–51、95–100参考电路及全文DVDD出现处，未找到外供1.2V启用/关内部LDO的条件 | 禁止接旧稿V3V3D/1.8V，因为超过1.4V绝对最大值；若要另供1.2V，先取得该型号的原厂依据，不写成“一切外供都禁止” |
| ES9822PRO v0.5.2 | DVDD(pin29)内部1.2V；p129参考图为对地1µF | 检查p9、52、58、129图及全文DVDD出现处，未找到外供1.2V条件 | 同样只确认旧1.8/3.3V接法错误；外供1.2V没有被本手册认证为可直接实施 |
| CS4272 DS593F2 | VD是外部3.1–5.25V数字电源，VL是2.37–5.25V IO电源 | 没有供设计者按ESS方式外供的1.2V DVDD引脚；VCOM/FILT+是参考输出 | 不将VCOM/FILT+当供电轨，不给VD或VL接1.8V |

将“内部产生电压”“绝对最大允许电压”和“原厂保证可外接稳压器的工作模式”混为一谈，会同时造成误接与过度禁止。外供核心电压还涉及调节器并联争用、反灌、启动和停机，不能只看1.2V这个数。

## 2. ES7210.pdf — 四通道 ADC，备选

文件：`docs/datasheets/ES7210.pdf`，11页，Revision 9.1，January 2019。**判定：核心参数已核验；短版手册存在采样率和引脚表内部矛盾，尚不足以冻结完整驱动与符号。**

| 项目 | 真实 PDF 参数与边界 | 页码/定位 |
|---|---|---|
| 类型、封装 | 四通道ADC，24-bit；QFN-32，4×4mm，pitch0.4mm；EPAD在参考电路标PGND33 | p1 Features/Ordering；p2 Pin Out；p3 Typical Application；p10 Package（已渲染） |
| 关键管脚 | MCLK5；VDDP6；VDDD7/GNDD8；SCLK9/LRCK10；SDOUT1/TDMOUT11、SDOUT2/TDMIN12；VDDA22/GNDA21、VDDM23。MIC1 P/N=16/15、MIC2=19/20、MIC3=31/32、MIC4=28/27 | p2管脚图与表、p3参考图 |
| I2C管脚矛盾 | **p2图和p3原理图均为CDATA3、CCLK4；p2表第一行却按“CCLK,CDATA→3,4”写反顺序**。建立符号时优先保留一致图示映射并取得原厂修订确认，不把该表机械解析为最终引脚 | p2图/表已渲染对照；p3 |
| 推荐供电 | VDDD、VDDP、VDDM各1.6–3.6V，typ3.3V；VDDA同范围，但**VDDA<2V时PGA增益必须高于30dB** | p7 Recommended Operating Conditions及Note |
| 绝对最大值 | 模拟/数字供电−0.3…3.6V；模拟输入GNDA−0.3…VDDA+0.3V；数字输入GNDD−0.3…VDDP+0.3V；工作−40…85°C | p7 Absolute Maximum Ratings |
| IO | VIH≥0.7×VDDP；VIL≤0.5V；VOH/VOL表仅列典型VDDP/0，不能视为所有负载下的保证输出。VDDP=1.8V可建立与XMOS同电平接口，但ESP32 I2C上拉必须随低压域处理 | p8 DC Characteristics |
| 时钟/采样 | p1写8–100kHz；p3功能文字仅单速8–48k、双速64–96k；p7测试条件含192k、存在Quad Speed滤波表；p8接口极限MCLK≤51.2MHz、LRCK≤200kHz、SCLK≤26MHz、MCLK duty40–60%。**内部不一致，不能用LRCK200k证明192k采样模式已可用** | p1、3、7–8 |
| 时钟关系 | 256/384/512Fs等、12/24MHz USB时钟及部分25/26MHz非标准时钟；从模式LRCK/SCLK须与系统时钟同步；支持I2S/LJ/DSP/TDM，输出在SCLK下降沿更新 | p3 Clock Modes；p5–6 Digital Audio |
| 模拟输入 | 满幅表写`AVDD/3.3 Vrms`，但本芯片电源名是VDDA，属于命名不一致；3.3V条件为typ1Vrms。输入阻抗typ6kΩ。未给输入共模的保证数值；采用p3耦合/参考网络，不能推断0V直流直连成立 | p8 Analog Input；p3 |
| 噪声条件 | SNR A计权min95/typ102/max104dB；THD+N typ−85dB，表列min−88/max−75dB。条件VDDA/VDDD=3.3V、25°C、MCLK/LRCK=256；Fs写48/96/192k。未完整给出测量带宽、输入电平、各速率逐项限制 | p7 ADC Analog and Filter Characteristics |
| I2C | 7-bit=`0x40–0x43`（`10000 AD1 AD0`）；线上写字节`0x80/82/84/86`。最高400kHz；tLOW≥1.3µs、tHIGH≥0.4µs、数据setup≥100ns、rise/fall≤300ns；寄存器读使用先写寄存器地址再Repeated START读 | p3–4接口、p9 I2C Switching |
| 去耦/资料缺口 | p3显示各电源/参考1µF与0.1µF，建议贴近；该11页文件没有完整寄存器表、上电初始化序列、PGA各档满幅或启动时序保证。需要配套User Guide才能完成参数确认后的驱动落地 | p3、p5、p1–11范围检查 |

与旧方案：`docs/hardware-devices-design.md` §8.4 的“ES7210是ADC、MCLK≤51.2MHz”成立；“可替代”只能指降低指标的另一套方案。它既不能接100MHz，也不能仅凭页尾时序表纳入本机192k最高档。

## 3. ES8156.pdf — 立体声 DAC，备选

文件：`docs/datasheets/ES8156.pdf`，12页，Revision 3.0，July 2019。**判定：短版参数已核验；可作低功耗低指标路线，不能无修改替换主DAC。**

| 项目 | 真实 PDF 参数与边界 | 页码/定位 |
|---|---|---|
| 类型、封装/引脚 | 双通道24-bit DAC，含耳机驱动/虚地；QFN-20、3×3mm、pitch0.4mm、EPAD参考图PGND21。CDATA1/CCLK2/MCLK3、DVDD4/PVDD5/DGND6、SCLK7/SDIN8/LRCK9、HPCOM10、R+=11/R−=12、AGND13、L−=14/L+=15、AVDD16、VRP17/VMID18/CE19/SDOUT20 | p1、p3、p4、p12 Package（已渲染） |
| 推荐 vs 绝对最大 | 推荐DVDD/PVDD1.6–3.6V、AVDD1.7–3.6V；typ3.3V。绝对供电−0.3…3.6V，数字输入−0.3…PVDD+0.3V，模拟脚AGND−0.3…AVDD+0.3V；工作−40…85°C | p9 Electrical Characteristics |
| 电源/IO含义 | DVDD为外部数字供电输入，PVDD是IO供电，AVDD模拟供电；VIH≥0.7PVDD、VIL≤0.5V；VOH/VOL仅typPVDD/0。PVDD=1.8V可选，但不能把ESP32的3.3V上拉直接带入该域 | p3、p10 Digital Voltage Level |
| 功能采样范围 | p1为8–96kHz，p6软件模式分8–48k/64–96k。默认硬件模式，寄存器0x02 bit2使能软件模式；HW表仅8–50kHz与指定MCLK/LRCK比值，不应把所有SW模式套到HW | p1、p6 Hardware Mode / Clock Modes |
| 电气时钟上限 | MCLK≤49.2MHz，LRCK≤200kHz，SCLK≤26MHz；MCLK/LRCK duty40–60%；输入setup/hold各≥10ns。**LRCK200k是接口时序额定，不足以推翻功能章节96k限制** | p11 Serial Audio Switching |
| 幅度/耳机 | 满幅typ AVDD/3.3 Vrms，即3.3V时1Vrms；短表未清楚界定所有差分/单端/耳机负载的幅度保证。HPCOM是无隔直耳机的虚地，仅SW可用；p4 capless与p5隔直22µF+33Ω是不同接法。HPCOM不能当GND短接，也不能据“集成耳放”就保证32Ω下主方案指标 | p3、p4–5应用电路、p9 Analog Output |
| 噪声/功耗条件 | SNR A计权typ110dB、min100dB；THD+N typ−80dB、max−78dB。条件AVDD/DVDD3.3V、25°C、48k、MCLK/LRCK256；未明示完整带宽/测试负载。典型19mW是在DVDD/PVDD1.8V、AVDD3.3V条件，不能与其他供电下指标混算 | p9–10 |
| I2C | 7-bit `0x08/0x09`（`000100 CE`），写字节`0x10/0x12`；100/400kHz。Fast tLOW≥1.3µs/tHIGH≥0.6µs/setup≥100ns，rise/fall≤300ns；单寄存器读写格式见p7 | p6–7、p10 I2C Switching |
| 配置资料缺口 | 本短版没有完整EQ、DRC、音量、时钟初始化寄存器说明或完整耳机负载性能表；VMID/VRP是参考滤波节点，不能外灌数字电源 | p2–12；p4参考图 |

与旧方案：§8.4所列低成本DAC路线可保留；1Vrms条件与49.2MHz上限有原文依据，**不能声称兼容100MHz或192k全功能**，也不能直接承诺在所有输出模式下“增加6dB就得到2Vrms”。

## 4. ES9018K2M.pdf — 旧代双通道 DAC，备选

文件：`docs/datasheets/ES9018K2M.pdf`，41页，v3.7，2021-04-22。**判定：关键参数和外供DVDD例外已核验；与现用DAC的封装、时钟和供电规则不同。**

| 项目 | 真实 PDF 参数与边界 | 页码/定位 |
|---|---|---|
| 封装/关键脚 | 28-QFN 5×5mm，pitch0.5mm，EPAD→DGND；SCL3/SDA4/ADDR5、XO6/XI7、AVCC_L15/AVCC_R16、VCCA17、DVCC18、DVDD21、DATA2=25/DATA1=26/DATA_CLK27、RESETB28 | p1、p3–4 Pin Layout/Descriptions；p36机械图（已渲染） |
| 推荐供电 | VCCA、AVCC_L/R=3.3V±5%；DVCC为1.8V±5%或3.3V±5%；DVDD默认内部1.2V typ，**外供模式1.3V±5%**；工作−20…70°C | p28 Recommended Operating Conditions |
| 绝对最大 | DVCC/VCCA/AVCC最大4.7V；DVDD最大1.8V；数字输入−0.3…DVCC+0.3V，DAC输出应在GND和AVCC之间。**DVDD的1.8V绝对最大不是可用的1.8V核心电压** | p28 Absolute Maximum |
| 内部/外部核心供电 | 默认内部DVDD去耦建议2.2µF，要求在1.2V与温度范围有效容量至少1µF。p7列PCM `MCLK>50MHz 或 FSR>192kHz`、DSD `MCLK>50MHz 或 FSR>11.2MHz`需外供；外供1.3V要高于内部1.2V以使内部供电退出。p31 Note2明确内部MCLK最大50MHz(DVCC1.8V)，外供1.3V且DVCC3.3V可到100MHz。不要只截取p7中交叉页号有误的句子扩大内部100MHz适用范围 | p7 DVDD Supply；p28 Notes；p31 Note2 |
| IO | VIH≥DVCC/2+0.4V，VIL≤0.4V；VOH≥DVCC−0.2V、VOL≤0.2V @100µA。DVCC1.8V时门槛1.3V，可考虑与XMOS同域；DVCC3.3V时门槛2.05V，需要电平处理 | p29 DC Electrical |
| 时钟/数据 | 普通PCM≤384k；异步MCLK>192×FSR，同步允许128×FSR；OSF旁路MCLK>24×FSR、原始输入≤1.536MHz；SPDIF MCLK>386×FSR，FSR≤200k；主模式仅32-bit。MCLK/数据时钟周期≥10ns，高/低≥4.5ns，data setup≥4.1ns/hold≥2ns | p5、p7、p30–31 |
| 模拟输出 | 每腿电压摆幅0.924×AVCC Vpp、共模AVCC/2；等效源阻806Ω±11%。3.3V时每腿3.05Vpp，理想无负载差分约2.16Vrms；负载/外加电阻会改变电平。允许电流或电压取出，**不代表具备低阻抗线路驱动** | p31 Analog Performance与Note1 |
| 性能条件 | DNR typ127dBA（−60dBFS，差分电流模式）；THD+N typ−120dB（0dBFS，同模式）。25°C、AVCC/VCCA/DVCC3.3V、内部DVDD+2.2µF、44.1k、MCLK27MHz、32bit；DNR20Hz–20kHz A计权、THD+N同带宽不计权 | p31 |
| I2C | ADDR0/1在线写字节0x90/0x92，即7-bit0x48/0x49；100/400kHz，Fast tLOW≥1.3µs/tHIGH≥0.6µs、SDA保持≥0.3µs、setup≥100ns、bus≤400pF | p10 Serial Control Interface |
| 上电/待机 | AVCC不早于VCCA；外DVDD不早于DVCC；全部电源和外MCLK稳定后至少1ms再释放RESETB，后续reset≥10ns。待机先将输出ramp到地，再RESETB低；外MCLK停低、外DVDD关闭；恢复后重新初始化 | p7 Standby；p27 Power-Up |

与旧方案：§8.4的“高MCLK需外供1.3V”方向正确，但条件还包括采样率。76mW是DVCC3.3V条件，手册同时给DVCC1.8V时52mW（p28），不能只写一个通用功耗。与ES9039既不同封装也不同寄存器，不能作为直接替换料。

## 5. ES9038Q2M.pdf — 双通道 DAC，备选

文件：`docs/datasheets/ES9038Q2M.pdf`，65页，v1.4，2021-01-20。**判定：标准内部DVDD方案已核验；不能依据ES9018或ES9039推定外供核心、封装或MCLK条件。**

| 项目 | 真实 PDF 参数与边界 | 页码/定位 |
|---|---|---|
| 封装/关键脚 | 30-QFN，**5×3mm、pitch0.4mm**，EPAD→DGND；AVCC_R1/AVCC_L10、VCCA12与27、DVCC13、DVDD15、DATA2=18/DATA1=19/DATA_CLK20、RESETB21、RT1=22必须DGND、SCL23/SDA24/ADDR25、XOUT28/XI29 | p3–5；p60机械图（已渲染）；p64订购 |
| 推荐供电 | VCCA、AVCC_L/R=3.3V±5%；DVCC=1.8V±5%或3.3V±5%；内部DVDD1.2V typ；工作−20…70°C | p50 Recommended Operating |
| 绝对最大 | VCCA/AVCC/DVCC最大4.7V，DVDD最大1.8V；非5V容忍数字脚−0.3…DVCC+0.3V；符合条件的5V容忍脚−0.3…5.3V | p50 Absolute Maximum |
| 5V容忍有条件 | **仅DVCC=3.3V时**，p5列RESETB、SDA/SCL、GPIO1/2、ADDR、DATA1/2、DATA_CLK、RT1为5V容忍；不能推广到DVCC1.8V或任意脚 | p5 5V Tolerant Pins |
| DVDD/IO | p11内部DVDD建议4.7µF±20% X5R6.3V0402，1.2V/温度范围有效值≥1µF；未给外供模式条件。IO VIH≥DVCC/2+0.4、VIL≤0.4、VOH≥DVCC−0.2、VOL≤0.2V @100µA | p11 DVDD Supply；p50 DC Electrical |
| XI≠内部MCLK | XI输入最高100MHz；内部音频MCLK=`XI / 2^clk_gear`。正常PCM异步MCLK≥192FSR、同步128FSR；Custom FIR需256FSR；OSF旁路异步24FSR/同步16FSR；DSD异步3FSR/同步2FSR；SPDIF386FSR。I2C时钟约束跟内部MCLK，不能只看XI | p6、p52 Analog Performance |
| 速率/时序 | 普通PCM异步FSR≤384k、同步≤768k；旁路≤1.536MHz；DSD异步≤11.3MHz/同步≤22.6MHz；SPDIF≤192k。XI/数据时钟周期≥10ns、高低≥4.5ns；数据setup4.1ns、hold2ns | p51–52 |
| 模拟与噪声 | 每腿源阻774Ω±11%，摆幅0.906AVCC Vpp，共模AVCC/2；3.3V时理想无负载差分约2.11Vrms。DNR **128dBA**（−60dBFS、差分电流模式），THD+N−120dB（0dBFS）。条件25°C、3.3V全部外供、内部DVDD4.7µF、44.1k、内部MCLK27MHz、32-bit；DNR20Hz–20kHz A计权，THD不计权 | p52 |
| I2C | 7-bit0x48/0x49（写字节0x90/0x92）；≤400kHz且`fSCL<MCLK/20`，tLOW/tHIGH还须>10/MCLK；NACK读保持≥2/MCLK。**禁止multi-byte reads**，否则解码器可能无响应直到reset；不应套用通用连续读取驱动 | p14 Serial Control及Timing |
| 上电/待机 | AVCC与VCCA同时或稍后；DVCC可先/后但保持RESETB低。全部外电源及XI稳定≥1ms后放开RESETB；后续reset≥10ns。待机停XI于低、恢复重新初始化 | p49、p11 |

与旧方案：可用电压模式，但旧稿“Q2M内置输出级，所以不需I/V，且可直接继承器件DNR”的推论不成立；上表高指标测试在差分电流模式。旧§8.2借用9038的供电命名、4.7µF或100MHz来定义9039必须撤回。

## 6. ES9039Q2M_ESS.pdf — 现用双通道 DAC

文件：`docs/datasheets/ES9039Q2M_ESS.pdf`，109页，v0.2.3。**判定：主选参数已核验，旧设计至少需重画电源/符号/时钟；不再使用9038同族推测。**

| 项目 | 真实 PDF 参数与边界 | 页码/定位 |
|---|---|---|
| 封装/关键脚 | **32-QFN 5×5mm、pitch0.5mm，EPAD33接GND**。AVCC_DAC1=1、DAC1B/1=2/3、AGND1/2=4/5、DAC2B/2=6/7、AVCC_DAC2=8、DVDD9、AVDD10、GND11、BCLK12、DATA1/2=13/14、SCL15/SDA16、RT1=17接GND、CHIP_EN18、ADDR1=19/ADDR0=20、MODE29、GND30、VCCA31、MCLK32 | p10–12 Table1；p104–105（p104已渲染） |
| 推荐供电 | AVDD、VCCA=3.3V±5%；AVCC_DAC1/2表列3.3V±15%，脚注解释该变化用于ES9312Q校准模式，不能无条件当作普通供电容差预算；DVDD内部1.2V；−20…85°C | p51 Table26及Note1 |
| 绝对最大 | AVCC_DAC1/2−0.3…3.8V；AVDD/VCCA−0.3…3.7V；DVDD−0.3…1.4V；数字输入−0.3…AVDD(nom)+0.3V | p50 Table24 |
| 内部节点/电容 | DVDD9是内部1.2V，p11要求外接1µF钽到地；**AVCC_DAC2 pin8也明确要求1µF钽**。AVCC_DAC1 pin1及AVDD10各要求1µF但对应行未指定介质，AVDD10才是3.3V数字调节器供电。p96–97图中DVDD为对地电容，**不存在外供1.8/3.3V连接**。外供1.2V条件未在当前文档中建立，参见§1 | p11、p96–97 Fig31/32，已渲染参考图 |
| IO | VIH≥AVDD/2+0.4=约2.05V，VIL≤0.4V；VOH≥AVDD−0.2、VOL≤0.2V（该表未注明驱动电流条件）。因此XU3161.8V的高电平不保证满足；不能通过把内部DVDD改1.8V改变IO门槛 | p50 Table25 |
| MCLK/采样 | **MCLK最高50MHz**。HW同步模式依表7至49.152MHz；异步模式表8要求MCLK至少130FS，自动gearing通常>130FS。192k异步因此需至少约24.96MHz，**24.576MHz不是192k异步模式的合规替换**；49.152MHz具有频率余量，仍须配置。64FS模式可在49.152MHz实现768k PCM，属于特定高采样模式 | p16–17 Tables7/8及脚注；p54 Table29；p60 Reg0[6] |
| 音频时序 | DATA_CLK周期≥20ns，高/低≥9ns，duty45–55%；DATA1/2在上升沿采样，setup≥4.1ns、hold≥2ns。需把电平转换器延迟计入 | p57 Table31 |
| 模拟接口/指标 | 每腿源阻390Ω±15%，摆幅0.889AVCC Vpp，静态共模AVCC/2；3.3V理想无负载差分约2.07Vrms。DNR typ130dBA（双通道单路差分）、133dBA（两路相加mono），−60dBFS；48k/0dBFS/20Hz–20kHz差分THD+N−120dB、THD−126dB。96/192/384k的THD+N和测试频宽分别变化，不能统一宣称−120dB | p54 Table29 |
| 测试条件边界 | 25°C、3.3V外电源、DVDD1.2V、HW I2S主模式；p54注明性能取自EVB v1.0，“10Vrms=0dBFS input”是原表系统测量注记，**不能当DAC裸脚10Vrms输出指标**。输出运放方案见p98–99，电源校准见p100；旧2.2k差放须重算DAC源阻、负载与噪声 | p54、p98–100 |
| I2C与寄存器 | MODE直接GND为I2C，直接AVDD为SPI；47k上/下拉属于HW模式选择，不可混淆。7-bit0x48–0x4B，对应写字节0x90/92/94/96；≤400k且fSCL<CLK/20、tLOW/tHIGH>10/CLK，NACK读保持≥2/CLK。寄存器访问必须有系统时钟；多字节数值按LSB→MSB，写MSB锁存/读LSB锁存 | p13 Tables2/3；p14；p55 Table30；p57 |
| 音量/时序 | 音量0…−127.5dB、0.5dB步进，内置ramp，Reg74/75，DAC mute Reg86；上电AVDD先于VCCA约200µs，再AVCC_DAC1/2，最后CHIP_EN；关机先CHIP_EN低，再AVCC、VCCA、AVDD | p19 Volume Control；p51 Fig22/23 |

审阅时的旧稿冲突（部分已于2026-09-06回写，以下为审阅快照）：`docs/schematic/04-dac-outputs.md:20,33,34`仍保留被否定的QFN-40、3.3V→DVDD、100MHz草案；BOM已标出部分勘误，但完整工程尚未闭合。上一轮摘要若将“旧DVDD外供接法均已否定”理解为“连经原厂确认的外供1.2V也一律不行”，应按§1收窄措辞。

## 7. ES9822PRO_ESS.pdf — 现用双通道 ADC

文件：`docs/datasheets/ES9822PRO_ESS.pdf`，144页，v0.5.2。**判定：主选参数已核验；供电/共模/I2C启动路径必须修正，手册若干时钟文字也需按保守交集处理。**

| 项目 | 真实 PDF 参数与边界 | 页码/定位 |
|---|---|---|
| 封装/关键脚 | 40-QFN 5×5mm、pitch0.4mm，EPAD41接DGND；MODE3、ACLK4、AVCC5、XOUT7/XIN8、VREF_L9/AVCC_L10、IN_P1/N1=12/13、IN_N2/P2=18/19、AVCC_R21/VREF_R22、CHIP_EN23、SDA25/SCL26、ADDR1=27/ADDR2=28、DVDD29、AVDD30、DGND31、RT1=40必须接DGND；NC14–17 | p8–10 Table1；p133–134（p133已渲染） |
| 推荐供电 | **AVCC/AVCC_L/AVCC_R=4.5V，AVDD=3.3V，DVDD=内部1.2V**；VREF_L/R内部产生；−20…85°C。Table31未列4.5V/3.3V的推荐min/max容差，不自行补写±5% | p58 Table31 |
| 绝对最大 | AVCC/AVCC_L/R最大4.75V，AVDD最大3.7V，DVDD最大1.4V；前三类负限−0.3V。数字输入−0.3…AVDD(nom)+0.3V；模拟IN_P/M为−0.4…+6V。不能用±5V钳位就宣称保护了其负向模拟输入 | p52 Table23 |
| 内部节点/去耦 | DVDD29在pin表为Internally Supplied，p129参考图C6=1µF对地；AVDD30=3.3V IO Supply，AVCC另4.5V。VREF_L/R参考图为4.7µF对地；采用ES9311等特定调节器时图注会改变去耦方案，须按对应参考设计处理，不机械加“每脚磁珠+10µF” | p9；p129 Fig28（已渲染） |
| IO门槛 | VIH≥AVDD/2+0.4=约2.05V，VIL≤0.4V；VOH≥AVDD−0.2，VOL≤0.2V，表注明IOH=(AVDD/2)+1.4mA、IOL=(AVDD/2)+1.7mA。ADC输出约3.3V不能直入XMOS1.8V | p52 Table24 |
| MCLK内部文字差异 | p44写最小22.579MHz，p58写22MHz，p53开关表却列20–50MHz；模拟ADC时钟p44–45写22.5792…24.576MHz，p53脚注写20–25MHz。按现有明确配置优先选**22.5792/24.576/45.1584/49.152MHz**并正确分频，不能拿20MHz表项覆盖功能正文 | p44–45 Clock Distribution；p53 Table25；p58 |
| 当前192k路线 | 24.576MHz可按p47–48表得到192k；双通道32bit BCLK为12.288MHz。49.152MHz通过内部模拟分频也可用于192k，不能只改晶振不改SELECT_ADC_NUM/相关时钟寄存器。p44特别建议22/24MHz时数据走GPIO4–6并启用TDM_GPIO456/相关映射 | p44–48 Fig21/Table18/19 |
| 时钟相位 | 从模式有**MCLK下降沿与BCK边沿的相位窗口要求**。p55区分45/49MHz与22/24MHz两组图表，不能只验证BCLK频率。p54 BCLK周期≥20ns、高低≥9ns；SDOUT延迟13.8ns是typ而非max | p54 Table26；p55 Fig23/24与Table27/28 |
| 满幅/共模/负载 | 0dBFS typ3.2Vrms，输入DC共模为AVCC_L/R÷2（典型2.25V）；输入阻抗430Ω±14%，Cin约10pF。p130有带VREF的驱动级，输出要有负载/满幅余量；旧0V共模PGA直接耦合不能据此成立。3.2Vrms折算约+12.3dBu仅是由手册典型值计算，未含前置衰减 | p61 Table33；p129–130参考电路 |
| 噪声/失真条件 | 25°C、AVCC系列4.5V、AVDD3.3V、MCLK49.152MHz、48k I2S。双通道DNR min122/typ125dBA（−60dBFS），mono min125/typ128dBA；48k/−1dBFS/20Hz–20kHz双通道THD+N typ−117/max−114dB。96k typ−115、192k typ−113dB，均在20Hz–20kHz带宽；不能把48k指标当全速率保证 | p61 Table33 |
| 普通与同步I2C地址 | MODE低为I2C。普通7-bit`0x20–0x23`，写地址字节`0x40/42/44/46`；**无系统时钟可写的同步接口**7-bit`0x24–0x27`，写字节`0x48/4A/4C/4E`。这两个地址窗口均与DAC7-bit0x48系列不同，不能把8-bit地址当7-bit导致假冲突 | p11 Table2及地址位串 |
| 启动顺序 | 普通寄存器窗口需要系统时钟；先通过同步窗口的write-only Reg192–194（0xC0–C2）选择/使能时钟，再访问普通窗口。Reg193[2:1]选XTAL/MCLK/ACLK、[0]EN_ANA_CLKIN；Reg194选择模拟时钟除数。全部供电与MCLK稳定后再assert CHIP_EN。不能把通用“先读ID”作为无条件首步 | p59 Fig27；p62 Register Overview；p124–125 |
| I2C时序/多字节 | ≤400k且fSCL<CLK/20；Fast低≥1.3µs/高≥0.6µs，另>10/CLK；NACK读保持≥2/CLK；bus≤400pF。多字节数值LSB→MSB，写MSB锁存，读LSB锁存；同步窗口只有写，不应做读回测试 | p56 Table29；p62 |

审阅时的旧稿冲突（部分已于2026-09-06回写，以下为审阅快照）：`docs/schematic/03-adc-frontend.md:56,73,74,78,104`存在未解决的直耦/共模、笼统“内部PGA”、±5V钳位、1.8/3.3V外灌DVDD、+8dBu满幅假设。数字增益不能替代低噪模拟前置增益；本手册不支持把未确认的“内部PGA”作为Hi-Z电平不足的已落实解决方案。

## 8. CS4272_Cirrus.pdf — 双通道 ADC + DAC CODEC，备选

文件：`docs/datasheets/CS4272_Cirrus.pdf`，54页，DS593F2，OCT2021。**判定：参数足以建立低成本备选路线，但5V模拟供电、IO、I2C与时钟须独立适配。**

| 项目 | 真实 PDF 参数与边界 | 页码/定位 |
|---|---|---|
| 类型/封装 | 双通道ADC+双通道DAC、24-bit、192k级CODEC；28-TSSOP，body9.7×4.4mm、lead span6.4mm、pitch0.65mm。没有ESS式EPAD。SDOUT(M/S)等脚在standalone与software模式含义不同 | p1；p5–8 Pin Descriptions；p46 Package |
| 关键脚 | XTO1/XTI2/MCLK3、LRCK4/SCLK5、SDOUT6/SDIN7、DGND8/VD9/VL10、SCL11/SDA12/AD0-CS13/RST14、VCOM15、AINA−/+16/17、AINB+/−18/19、VA20/AGND21/FILT+22、AMUTEC23、AOUTA−/+24/25、AOUTB+/−26/27、BMUTEC28 | p5–6 |
| 推荐供电 | VA4.75–5.25V、VD3.1–5.25V、VL2.37–5.25V；nom5V/3.3V/3.3V。商业级−10…70°C，汽车级−40…85°C；尾缀等级不能混用 | p9 Specified Operating Conditions |
| 绝对最大 | VA/VL/VD均−0.3…6V；模拟输入GND−0.3…VA+0.3V；数字输入−0.3…VL+0.3V；非供电脚输入电流±10mA。**6V不是推荐供电，1.8V也不在VL范围** | p9 Absolute Maximum |
| IO/参考输出 | VIH≥0.7VL，VIL≤0.3VL；VOH≥VL−1V、VOL≤0.4V @2mA。VCOM typ0.48VA，输出阻25kΩ、最大源/灌电流表项1µA；FILT+约VA。MUTEC是0/VA输出、驱动约3mA，接MCU需按5V评估；不是继电器线圈直接驱动口 | p17 DC/Digital Characteristics |
| 去耦/共模 | VCOM电容在典型图明确**不超过1µF**；FILT+有47µF+0.1µF；VCOM应仅用于高阻共模参考/缓冲，不能挂大负载。ADC推荐带交流耦合及VCOM驱动网络，输入每腿以约VA/2为中心 | p23 Fig8；p32 Fig12/13 |
| 采样/外MCLK | 单速4–50k、双速50–100k、四速100–200k；standalone MCLK1.024–25.6MHz，control-port最高51.2MHz。外MCLK从pin3输入，XTI接地/XTO不接；从模式LRCK/BCLK必须与MCLK同步。192k/32-bit slot可选MCLK24.576MHz(128Fs)、BCLK12.288MHz(64Fs)，**有效音频数据最多24bit** | p18；p24；p27–29 Tables8/9 |
| 晶振模式 | XTI/XTO的晶振为20pF基频并联谐振，晶体频率16.384–25.6MHz；单/双/四速分别512/256/128Fs，典型外电容40pF×2。内部振荡器稳定后MCLK脚变输出，不能同时被外部驱动 | p18；p23–24；p27–28 |
| 模拟满幅/负载 | ADC差分满幅min1.07/typ1.13/max1.19×VA Vpp，5V时typ5.65Vpp≈2.00Vrms；差分输入阻抗min37kΩ。DAC差分满幅typ0.96VA Vpp≈4.8Vpp/1.70Vrms，源阻typ100Ω，负载≥3kΩ、容性≤100pF；这些不是耳机直驱条件 | p10/14；p32–33 |
| 噪声条件 | 商业级DAC/ADC A计权DNR min108/typ114dB；不计权typ111dB。DAC THD+N typ−100/max−94dB @0dBFS；ADC同值@−1dBFS。DAC用997Hz、RL3kΩ/CL10pF、10Hz–20kHz、一半LSB三角抖动；ADC1kHz，48/96/192k分表，20kHz/40kHz带宽不能混比。汽车级部分min/max较宽 | p9–11、p14–15；p45参数定义 |
| I2C | 7-bit0x10/0x11，写字节0x20/0x22；**SCL最高100kHz**，不是400k。RST上升至Start≥500ns；tLOW≥4.7µs、tHIGH≥4µs、setup≥250ns；可用MAP.INCR做顺序读写 | p21；p36 §6.2 |
| 上电/模式 | 外MCLK下先电源/MCLK/LRCK稳定、RST保持低；放RST后在10ms内向reg07h写03h(CPEN+PDN)，保持PDN配置，再清PDN。用内部振荡器时放RST后需先等1ms再写。SPI是write-only、最高6MHz；不能要求SPI模式读ID | p22；p27 §5.2.1；p35–36 |
| 手册需澄清处 | p35–36称AD0可接VA，但p9通用数字脚上限为VL+0.3V，VL<VA时存在冲突。该项目可先选择AD0接GND(7-bit0x10)避免这一问题；高地址配置应以原厂澄清/确认电平为准，不能照文字把5V送入3.3V域 | p9、p35–36 |

与旧方案：§8.4中5V VA、VCOM≤1µF、需输出缓冲方向正确；**MUTEC只能控制外部静音电路，不能仅因为存在该引脚就省掉保护功能**。它虽可降低双转换器的复杂度，仍不是只改一颗芯片的同封装替换。

## 9. 跨器件检查结果与尚需原厂补充的边界

| 检查 | 结论 |
|---|---|
| 主选ADC/DAC的I2C“地址冲突” | 正确换算7-bit后，ES9822普通0x20–23/同步0x24–27与ES9039的0x48–4B不冲突；旧稿“务必错开”应落实成这张具体表，而不是凭8-bit标签猜测 |
| 1.8V直连XMOS | 现用ES9822/9039 IO门槛由3.3V AVDD决定，必须处理电平。ES9018/9038、ES7210/8156可选择低IO供电，但所有控制线和复位也要一并处理；CS4272 VL不能设1.8V |
| 100MHz晶振替换 | 9039≤50MHz；9822≤50MHz且有模拟时钟分频/相位条件；ES7210≤51.2、ES8156≤49.2、CS4272≤51.2(control)；9038可100MHz XI，9018须满足外DVDD条件。不能为全系列使用同一个“100MHz音频晶振”模板 |
| DNR与输出类型 | 旧ESS9018/9038高DNR明确在差分电流模式测量；可输出电压不等于“内置线路驱动并保证同指标”。主DAC源阻390Ω和主ADC430Ω输入都应进入阻抗/噪声/满幅预算 |
| 手册缺页/缺表 | 7个PDF均可解析且文件页数正常；ES7210/8156短版缺完整寄存器/配置指南和一些模拟负载条件，属于资料内容不足，不能用“文件已存在”代替这些参数已确认 |
| 本轮没有确认的外供模式 | ES9038/9039/9822外供1.2V核心的原厂模式条件；未给出不能写成绝对物理禁止，也不能默认允许。若继续走内部供电标准方案，无需为此阻断该标准方案；若改用外供则必须补证据 |
| 本轮没有宣称完成的工作 | 全部寄存器逐值审核、实际器件真伪、动态功耗、固件驱动联调、模拟电路稳定性、ERC/DRC及样机测量。本文是选型与外围连接所需关键参数审核 |

机器覆盖记录见 `.jspace/datasheet-audit/converters-coverage.json`。该记录包含7项；它只是全仓库36份PDF审核中的转换器子集，不应将数量相加误计为37份。
