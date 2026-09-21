# EDA恢复记录：2026-09-16

## 19:34更新（优先于下面17时的记录）

- U10现为(670,510)；去耦列为x=65/125/185/245，18颗电容地短桩已缩至5单位，保持非零导线。当前layout-lint/clusters/bridge-check均通过，101脚对账再次通过。
- 08/09/10 playbook已全部完成；移动产生的重复VDD标记已清除，五个IO电源脚改为清楚的共享母线，三条PHY/PLL电源引出已重新错开。
- 11 playbook在meta.doc切换处超时，未执行任何步骤；后续已通过明确doc的单独typed/CLI操作补齐两块分区框和两条说明。**不要直接重跑11，会重复说明。** 当前说明ID为`9f7f21da5291e2ce`、`51a1a7afe4b31e66`，布局以最新原生读回为准。
- 当前strict gate只剩`missing-titleblock`及原生DRC30条WARN。图签API对Name/Drawed等写值均报`Cannot set properties of undefined`；sheet不支持普通component.modify。这些尝试未写入图签文本。需原生UI填写，不再重试相同API。
- 网络端口名称不显示的原生修法已验证：typed select所有netport→属性Name行**右侧showValue复选框**统一关再开；左侧是属性名显示，不要混淆。整体移动重建端口后需要再执行一次，且应按方向表恢复IN/OUT/BI。
- 当前障碍已不是旧的GetCursorPos：桌面恢复后，本轮启动审计调用本地XTC模拟调试器触发`xgdbserver.exe` Windows防火墙提示。所有相关调试进程已退出；根未点击安全弹窗、未改防火墙，已请用户手动取消。后台MCP当前页读写仍可用；原生属性/DRC操作待弹窗关闭。不再为普通手册核对启动调试服务。
- 新的时钟/Flash/复位方案已写入`xmos-boot-plan.json`与`docs/schematic/reva-xmos-boot.md`；4份原厂PDF归档`docs/datasheets/xmos-boot-reva/`，SHA256已校验。Flash保持有条件候选。尚未新建/绘制启动页，PCB仍为空。

工程`ASIO_CARD_USB5V_REV_A`，原理图文档`4256e3ead5652257`，XMOS_CORE页`25705a7645bdb6d1`。环境固定v1.3.0 / EasyEDA Pro3.2.181，不单独升级任何组件。

## 当前保存点

U10在(730,510)，C101–C118在左侧4列。18颗电容已统一通过modify设置stored rotation=90，并按实际管脚坐标重连：pin2电源在上，pin1地在下。36个电容引脚与65个XU引脚重新独立对账通过；这不是完整启动电路。

`05-xmos-tidy.playbook.json`的journal停在`shift-core`：原因是同名module claim与group二义性，不是移动已失败。之后已单独用`sch group-move --group g1 --dx 150 --dy 0`完成移动并通过其网表对账；`06-xmos-reconnect-caps.playbook.json`39步全完成并保存。**不能直接resume 05，否则重复/错误移动。** 当前虚拟组为g1 XU316_CORE、g2 XU_DECOUPLING；命令用组ID避免同名冲突。

两次pin.disconnect曾报告残留；均先读回确认原网络仍连接，再按journal从该步重试，之后成功。不能将一次超时/partial报告当作未修改而全页重放。

## 实测工具兼容问题

1. `component.place(rotation:90)`最终stored rotation为270，而`component.modify(rotation:90)`得到90。第一颗C101先放0再modify，其余直接place90，因此最初上下不同。所有18颗已经按真实pin坐标修复。后续器件先读回pins/rotation，不能由传参推断。
2. 初次原生PNG里Netport-OUT/BI多处没有可见网名；IN的名字/符号朝向会挤进芯片体内。`components.list`和原生网表能读到正确网络名，保存重开不能修复渲染。需在原生属性面板检查文字显示与方向。
3. CLI `group-move`重建了单脚网络端点：本次core的端口形状变为BI、共享VDD/IO端点出现重复标记。逐pin网络保持，但图形语义和整洁度没有保持；不要仅凭其“刚体/对账绿”输出断言图形也保持。之后已按检查器准确ID清除11个重复VDD标记（07 playbook），保留一枚及全部导线；再次101脚对账通过。
4. `schematic.read(includeCheck:true)`中的check比CLI完整`sch gate --strict`覆盖少，前者findings=[]不能代表marker/分区/原生DRC全部通过。最终以保存的gate报告为准。
5. 原生符号取回后`manufacturer/supplier`空字符串修改会被SDK忽略。普通电容使用显式`UNSELECTED`后读回确认，采购BOM不得把该字符串当真实料号。

## 下一步

先health并读回现状，保留当前保存点。恢复Windows桌面后查看原生网名显示/端口属性和29条DRC WARN明细；修复核心重复电源标记与超宽标签，完成分区框、模块说明和图签，再跑逐pin对账及strict gate。尚未进行PCB导入/布局。

本次最后的Computer Use错误是`GetCursorPos failed: Access is denied. (0x80070005)`。已刷新窗口选择并恢复一次仍失败，停止鼠标键盘操作并向用户询问；未更改系统权限/安全设置。MCP连接仍正常，原生工程已显式保存。
