# ASIO_CARD_USB5V_REV_A

2026-09-16。本目录是正式声卡的 **EasyEDA 专业版原生草稿**，不是已验收的生产工程。打开 `ASIO_CARD_USB5V_REV_A.eprj2`，不要打开 ai-smoke 测试工程来继续声卡设计。

用户已确定单 USB-C 供电；元件采购、库存与价格检查暂停。普通阻容按 Spec_ID、电气规格和暂用封装落图。库器件只用于提供真实符号/封装，不代表已采购选定：18颗电容的厂家、型号、供应商和供应商编号都显式记为 `UNSELECTED`。

## 已落图与计划的区别

| 项目 | 当前状态 |
|---|---|
| 原生工程 | 已创建并保存；12张A4功能页；PCB1仍为空 |
| XMOS_CORE | U10 XU316及C101–C118共19件已放置；65个XU管脚与原厂/固件表核对；18颗去耦已连接 |
| 已连接内容 | 0.9V核心/底部61–64、1.8V IO、USB PHY与PLL电源端点、GND65、QSPI/JTAG/时钟/I2S/UART网络端点；未用GPIO及真正NC25有非连接标记 |
| 启动电路计划 | 已补`xmos-boot-plan.json`及`reva-xmos-boot.md`，包含24MHz晶体/阻容和三路监控复位；W25Q16FWSNIQ为有条件候选，尚未落图或通过真实ROM/实板启动验证 |
| 仍缺的原生启动外围 | Flash、晶体、复位监控、电源源头、PLL/PHY滤波与调试连接器；已有网名不能代替另一端电路 |
| 其余11页 | 已建功能框架，尚未完成电气放置和布线；音频/电源/外围JSON是绘图计划，不是原生网表 |
| PCB | 未导入、未布局、未布线，不导出制造文件 |

页面顺序：SYSTEM、USB_INPUT、USB_HUB、DIGITAL_POWER、XMOS_CORE、CONTROL、MIC_PREAMP、LINE_INPUT、ADC、DAC、OUTPUT、ANALOG_POWER。

## 单 USB-C 边界

供电计划采用USB-C 5V电流能力检测及硬件限流。Default档仅保留低功耗检测；1.5A档先允许数字枚举、控制和USB回环，模拟域默认关闭；3A档作为完整功能目标，低线压仍优先限制幻象。只有实测预算通过后才能开放1.5A模拟降级模式。普通USB-A转C线/只广告Default的电脑口不能保证启动音频。不假设电脑支持高压PD，也不将500mA描述符视为1.5A/3A授权。

新技术基线分别见 `../../docs/schematic/reva-power-design.md`、`../../docs/schematic/reva-audio-design.md`。新加器件仍须逐PDF记录，旧38份手册的覆盖统计不自动包含后续新增电源器件。

## 检查边界

- `xmos-pin-verification.json` 是独立逐pin对账结果；检查XU65脚及18颗电容36脚，并检查普通电容未携带借用库件的采购身份。
- 原理图结构检查和网表身份核对不等于完整最小系统。尚未通过整机原生ERC/DRC、时序、模拟稳定性、热、功耗或实板验证。
- 已修正18颗电容的旋转方向并重新连接；原生网表重新对账101/101，结构检查无浮空错误/跨线/过脚错误，bridge-check为0。
- **19:34最新检查**：layout-lint、clusters、bridge-check通过；0重叠、0出界、0过近、0跨网短接。两块功能框及说明已落图；101个引脚再次独立对账通过。严格阶段检查仍因图签未填写及原生DRC聚合30条WARN失败，不能进入PCB阶段。
- 网络名不可见已在原生UI定位到Name行右侧showValue未勾，并验证可批量开启。随后整体移动会重建端口并再次隐藏名称，因此最终显示与端口方向仍需在原生属性面板恢复。
- 本轮桌面已恢复；之后启动审计中的XMOS本地模拟调试工具触发了`xgdbserver.exe`防火墙提示，需用户手动取消。相关调试进程均已退出，未放行网络或改防火墙。后台MCP仍可编辑当前页，但原生界面/页面切换待提示关闭。图签API另返回`Cannot set properties of undefined`，需原生UI处理。

## 文件与重放

- `s0-design.json`：首个器件放置前的方案/分页基线，已通过spec严格校验。
- `xu-pin-net-plan.json`、`xu-pin-notes.md`：原厂引脚与当前XN端口对应关系；`net-aliases.json`记录短JTAG标签映射。
- `xmos-connect.json`：当前连接意图；`xmos-capacitors.json`：去耦角色/规格，初始坐标仅供历史重放，实际坐标以原生工程读取为准。
- 编号playbook及journal：本次操作记录，含真实实例ID。**不要对现有工程从头重跑**；这会重复建页/放件。恢复时先health、指定工程/页面、读取现状与journal。
- `../../scripts/verify-xmos-draft.py`：从原生语义快照和元件快照重新对照独立引脚表。

采购信息以用户填表为准，不用历史BOM价格或库件C编号覆盖用户选择。最终位号/数量以完成后的原生原理图生成。
