# XMOS启动外围补充原厂资料

2026-09-16。四份PDF均从原厂公开链接取得并校验SHA256，路径/来源/使用页码和哈希记录在 `hardware/asio-card-reva/xmos-boot-plan.json` 的 `sources`。

| PDF | 本轮用途 |
|---|---|
| W25Q16FW_RevJ.pdf | W25Q16FWSNIQ技术候选、1.65–1.95V、QE、Quad命令及上电条件 |
| W25Q16JW_RevG.pdf | 对照JW替代条件；未批准无条件替换FW |
| FA-238_Q22FA23800065_en.pdf | 24MHz无源晶体具体规格、负载/ESR/驱动和封装脚号 |
| tps3897.pdf | 三路监督器的引脚、阈值、开漏输出和延时计算 |

以上是参数/电路依据，不代表完整ROM联合仿真或实板启动已经通过；边界见 `docs/schematic/reva-xmos-boot.md`。本轮不包含库存/查价。
