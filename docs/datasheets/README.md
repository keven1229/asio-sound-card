# Datasheet 索引（docs/datasheets/）

> 2026-09-06已完成原有36份+补充2份的逐文件核验，共38份；此前“35/37份”为计数错误。参数、条件、页码和未确认项见[全量核验表](../datasheet-audit/README.md)，逐文件哈希见[覆盖记录](../datasheet-audit/coverage.json)。

2026-09-16：现共收录 **49份PDF**。新增7份电源资料在`power-reva/`，新增4份启动外围资料在[xmos-boot-reva](xmos-boot-reva/README.md)。对应核对与未关闭项见[RevA电源设计](../schematic/reva-power-design.md)和[XMOS启动设计](../schematic/reva-xmos-boot.md)。原`coverage.json`仍只覆盖下列38份基线，不能用于宣称新增方案或实板已经验收。

## 2026-09-06基线（38份）

### 主控与存储
| 文件 | 器件 | 来源 |
|---|---|---|
| XU316-1024-QF60A.pdf | 主控（2.8MB） | 立创 CDN |
| XU208-128-QF48.pdf | 主控备选 | 立创 CDN |
| W25Q16JV_Datasheet.pdf | QSPI Flash | Winbond 官网 |

### ADC / DAC
| 文件 | 器件 | 来源 |
|---|---|---|
| [ES9822PRO_ESS.pdf](ES9822PRO_ESS.pdf) | 当前ADC：v0.5.2，144页；2026-09-05补齐 | [ESS官方原文](https://www.esstech.com/wp-content/uploads/2025/04/ES9822PRO_DS_v0.5.2.pdf) |
| [ES9039Q2M_ESS.pdf](ES9039Q2M_ESS.pdf) | 当前DAC：v0.2.3，109页；QFN-32，MCLK最高50MHz；2026-09-05补齐 | [ESS官方原文](https://www.esstech.com/wp-content/uploads/2026/05/ES9039Q2M_Datasheet_v0.2.3.pdf) |
| ES9038Q2M.pdf | DAC 备选（30-QFN 5×3mm；不能沿用9039封装） | 立创 CDN |
| ES9018K2M.pdf | DAC 再降档备选 | 立创 CDN |
| CS4272_Cirrus.pdf | 全集成 codec（送人版路线） | Cirrus 官网 |
| ES8156.pdf | 顺芯 DAC（国产备选） | 立创 CDN |
| ES7210.pdf | 顺芯 ADC（国产备选） | 立创 CDN |

### 模拟前端 / 输出
| 文件 | 器件 | 来源 |
|---|---|---|
| PGA2500.pdf | 数控话筒前置 | TI 官网 |
| THAT1510-1512.pdf | 前置备选 | THAT 官网 |
| THAT1570.pdf / THAT5173.pdf / THAT5171.pdf / THAT1580.pdf / THAT626x.pdf | 升级候选套片 | THAT 官网 |
| OPA1656.pdf | 输入缓冲 | TI |
| OPA1611_OPA1612.pdf | 差分转单端 | TI |
| TPA6120A2.pdf | 耳机放大 | TI |
| NE5532_TI.pdf | 次级运放 | TI |

### 电源
| 文件 | 器件 | 来源 |
|---|---|---|
| AP7361C.pdf | 3.3V_D LDO 1A（美台 DIODES） | 立创 CDN |
| SY6280.pdf / SY8089.pdf | 限流开关 / Buck | 立创 CDN |
| SGM2036.pdf | 3.3V LDO | 立创 CDN |
| TPS7A20_TI.pdf | 1.8V/低噪 LDO 系列 | TI |
| LM27762.pdf | ±5V 电荷泵 | TI |
| GM1205.pdf | 3.3V_A 超低噪 LDO（国产主选） | 立创 CDN |
| LT3045.pdf | 超低噪 LDO（ADI 文档，pin-to-pin 发烧备选） | 立创 CDN |
| XL6019.pdf | 48V Boost | 立创 CDN |

### 控制与外围
| 文件 | 器件 | 来源 |
|---|---|---|
| [CH334DS1_WCH.pdf](CH334DS1_WCH.pdf) | CH334/CH335，英文v2.5；CH334U QSOP28/12MHz | WCH原厂内容，Adafruit镜像；来源与哈希见[USB桥核验](../datasheet-audit/usb-bridges.md) |
| [CH343DS1_WCH.pdf](CH343DS1_WCH.pdf) | CH343，英文v2.0；CH343P独立VIO支持1.8V | WCH原厂内容，Waveshare镜像；同上 |
| ESP32-S3-WROOM-1_ESPRESSIF.pdf | 管理 MCU 模组 | 乐鑫官网 |
| EC11.pdf | 旋转编码器 | 立创 CDN |
| PRTR5V0U2X.pdf | USB D± 双通道 ESD（友台 UMW 国产版） | 立创 CDN |
| TPD4E05U06.pdf | USB ESD（4 通道，已弃用备选） | TI |
| CA-IS3720.pdf | 国产数字隔离（地环备选） | 川土微官网 |

## 暂缺（获取方式）

| 器件 | 原因 | 获取途径 |
|---|---|---|
| NZ2520SD | NDK 官网反爬 | NDK 官网人工下载；或直接问晶振卖家要 phase noise 参数 |
| HFD4 继电器 | 宏发官网无直链 | 立创商品页在线看，或淘宝卖家发 |
| ST7789V | 屏幕控制器 | 淘宝屏幕模块卖家附送；或搜 "ST7789V datasheet" 镜像 |

> **不要以ES9038手册替代ES9039Q2M。** 两颗当前ESS器件的完整原厂手册已在本地；供电、内部DVDD、输入共模、时钟和封装的修订结论见[整体设计整理](../design-review-2026-09-05.md)。其他旧手册属于候选资料，收录不代表该型号仍适用于当前设计。
