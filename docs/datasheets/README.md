# Datasheet 索引（docs/datasheets/）

> 全部 PDF 已按"器件型号"命名。**画图前逐引脚核对**，尤其 XU316/ES9822/ES9039/PGA2500/TPA6120A2。

## 已收录（35 份）

### 主控与存储
| 文件 | 器件 | 来源 |
|---|---|---|
| XU316-1024-QF60A.pdf | 主控（2.8MB） | 立创 CDN |
| XU208-128-QF48.pdf | 主控备选 | 立创 CDN |
| W25Q16JV_Datasheet.pdf | QSPI Flash | Winbond 官网 |

### ADC / DAC
| 文件 | 器件 | 来源 |
|---|---|---|
| ES9038Q2M.pdf | DAC 备选（QFN-40） | 立创 CDN |
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
| SY6280.pdf / SY8089.pdf | 限流开关 / Buck | 立创 CDN |
| SGM2036.pdf | 3.3V LDO | 立创 CDN |
| TPS7A20_TI.pdf | 1.8V/低噪 LDO 系列 | TI |
| LM27762.pdf | ±5V 电荷泵 | TI |
| LT3045.pdf | 超低噪 LDO（ADI 文档） | 立创 CDN |
| XL6019.pdf | 48V Boost | 立创 CDN |

### 控制与外围
| 文件 | 器件 | 来源 |
|---|---|---|
| ESP32-S3-WROOM-1_ESPRESSIF.pdf | 管理 MCU 模组 | 乐鑫官网 |
| EC11.pdf | 旋转编码器 | 立创 CDN |
| TPD4E05U06.pdf | USB ESD | TI |
| CA-IS3720.pdf | 国产数字隔离（地环备选） | 川土微官网 |

## 暂缺（获取方式）

| 器件 | 原因 | 获取途径 |
|---|---|---|
| **ES9822PRO** | ESS 官网下载有 bot 防护 | ① 淘宝卖家发货附带（最实际）② ESS 官网人工下载：[ES9822PRO_DS_v0.5.1.pdf](https://www.esstech.com/wp-content/uploads/2025/04/ES9822PRO_DS_v0.5.1.pdf) |
| **ES9039Q2M** | 同上 | 同上（卖家版）；画图先用 ES9038Q2M.pdf（同族 QFN-40），**拿到后核对差异** |
| NZ2520SD | NDK 官网反爬 | NDK 官网人工下载；或直接问晶振卖家要 phase noise 参数 |
| HFD4 继电器 | 宏发官网无直链 | 立创商品页在线看，或淘宝卖家发 |
| ST7789V | 屏幕控制器 | 淘宝屏幕模块卖家附送；或搜 "ST7789V datasheet" 镜像 |

> ⚠️ ES9039Q2M 与 ES9038Q2M 的引脚差异、供电引脚名务必以卖家版 datasheet 复核后再发板。
