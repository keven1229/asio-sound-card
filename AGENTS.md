# ASIO-CARD 项目协作约定

- 先读根目录 README.md 与 docs/datasheet-audit/README.md；器件参数/条件以该逐PDF核验和所引原文为依据。再读整体/固件审阅和 docs/easyeda-ai-environment.md。
- docs/schematic/*.md、旧 SVG、hardware-devices-design.md 与 BOM.csv 都含未完成的历史方案。发生冲突时回到准确型号的原厂数据手册；审阅报告是问题索引，不能替代逐引脚核对。
- 不把 USB 6进6出写成6路物理ADC/DAC，不把芯片典型性能、成功编译或静态检查写成整机实测。
- 目前未冻结：电源树、ESS供电/共模/时钟、1.8V Flash、电平转换、USB供电策略与跨tile协议。生成有关原理图前先解决并回写对应文档和BOM，不凭旧稿补引脚。
- 使用立创EDA专业版原生工程和已配置的 easyeda-agent typed actions。先 health、指定工程/图页、读取现状，再变更；保留保存点，检查网表和原生ERC/DRC。SVG只能作为说明图。
- 核实用户已有未提交改动，保留不属于当前任务的文件。firmware/lib_* 与 firmware/sw_usb_audio 是上游参考/依赖，避免无关遍历和改动。
- 本机AI环境使用锁定的 v1.3.0；启动/自检见 scripts/start-easyeda-ai.ps1 和 scripts/check-easyeda-ai.ps1。不要只升级CLI而遗漏连接器和skill。
- 用户接受阻容感先按通用电气规格落原理图、后补品牌/MPN/立创C编号。以 docs/passive-parts-spec.md 和 docs/passives-spec.csv 的 Spec_ID 管理用途/额定值；不要把缺采购料号当作普通阻容草稿绘制的阻碍，也不要虚构库UUID或将占位料号列为已选。实际位号/数量由原理图生成；PCB前落实封装/脚距/高度，待计算的拓扑/额定值继续明确标TBD。
