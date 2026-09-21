# 固件、主机工具与脚本审阅（2026-09-05）

本次以自有应用 `firmware/sw_usb_audio/app_usb_aud_asiocard`、`firmware/DESIGN.md`、`firmware/README.md`、`host/` 和 `scripts/` 为范围，只新增本报告，未修改固件或脚本。未审计 `firmware/lib_*` 的第三方实现。对架构事实使用本机 XTC 官方手册和已有 `.xe` 的符号表交叉核验。

**结论：已有可加载的 XMOS 固件原型和音频路由代码，但控制链存在确定的架构缺陷，不能把“编译/启动通过”写成“混音、VU、ESP32 联调通过”。ESP32 控制固件和真实硬件验收仍未完成。**

## 1. 当前实际实现

| 部分 | 源码中已存在 | 尚不能宣称完成 |
|---|---|---|
| XMOS 音频配置 | UAC2、USB 6 入/6 出、I2S 2 入/2 出、44.1–192 kHz；开发 VID/PID 为 0x20B1/0x0016 | Windows 枚举、ASIO 驱动匹配、实际采样率切换与音频质量 |
| 录音通道 | USB IN 1/2 为 Mic/Line 两路单声道；3/4 为立体声 Stream Mix；5/6 为 Main 播放干声回环 | 六路都是实体输入、独立语义设备名已实现 |
| 播放通道 | USB OUT 1/2 Main、3/4 Backing、5/6 Game；五个来源混为监听立体声送 DAC | 三组独立实体模拟输出 |
| DSP | `UserBufferManagement` 内有五源、双立体声总线混音、Main 干声回环、简单 4:1 波形压缩和峰值采集 | ESP32 可实际控制混音、可靠 dBFS 显示、前瞻限幅、EQ/动态压缩、平滑调参 |
| UART | 921600-8N1、CRC8、0x01/02/03/04 命令、0x11/12 应答/上报、3 组预设 | 跨 tile 参数/状态传递、异常帧恢复、0x13 事件、ESP32 端真实联调 |
| 调试 | tile1 上独立 UART TX，启动文字和每秒状态行 | 通用 xSCOPE printf 重定向、DEBUG_RX 命令行；RX 端口仅预留 |
| 时钟/板级钩子 | `AudioHwInit` 调用 `sw_pll_fixed_clock`；`AudioHwConfig` 记录采样率；XN 指定 QF60A 和 2 MB Flash | 完整板级初始化、codec 配置/就绪握手、换采样率时的静音与重配置联动 |
| ESP32 | 一份 Python UART 协议参考及自测 | 未找到 ESP-IDF、PlatformIO、Arduino 项目；屏幕、旋钮、ADC/DAC I2C、PGA2500 SPI、继电器/幻象电源控制均没有实际 ESP32 固件 |
| 主机侧 | 安装说明和 `device-check.ps1` 的 PnP/驱动提供者/音频设备枚举检查 | 自研 ASIO 驱动、录放音/延迟/掉音自动验收；检查脚本列出设备也不能代替 ASIO 出声测试 |

主要代码定位：`xua_conf.h:62–85,108–150`；`user_buffer_management.xc:88–152`；`usb_uart_ctrl.xc:145–235,307–371`；`audiohw.xc:26–48`；`audiostream.xc:6–13`。行号均相对上述自有应用目录。

默认构建配置是 `2AMi6o6xxxxxx`，使用自有 DSP（Track A，`MIXER=0`）。`_mix6` 仅为框架混音实验配置，`_usblb` 是六路 USB 原样回环调试配置，不能当作正常硬件录放音固件。

## 2. 必须先修的确定问题

### P1：跨 tile 全局变量实际上是两份，控制与音频没有连通

代码将 `usb_uart_ctrl` 放在 tile0，把音频处理和调试任务放在 tile1（`src/core/xua_conf_tasks.h:13–15`、`src/core/xua_conf.h:125–128`），通过 `unsafe volatile` 指针“共享”全局状态（`src/extensions/asiocard_shared.h:4–7,23–36`；`usb_uart_ctrl.xc:24–40`）。

但是 XMOS tile 具有独立内存和地址空间；只有同一个 tile 内的逻辑核共享内存。`unsafe` 放宽语言检查，不能让普通指针跨 tile 访问 RAM。本次使用 `xobjdump --syms` 检查基础配置已有镜像，得到以下实际符号地址：

| 符号 | tile0 | tile1 |
|---|---|---|
| `g_mix_levels` | `0x00089e98` | `0x000826d0` |
| `p_mix_levels` | `0x0008bbf8` | `0x00082818` |
| `g_vu` | `0x0008bd28` | `0x000828b8` |
| `g_cur_samfreq` | `0x0008bc18` | `0x00082838` |

**影响**：UART 更新的是 tile0 参数，音频任务读取 tile1 的初值；tile0 VU 上报读不到 tile1 的采样峰值；UART 状态包采样率可能一直保留 48000；tile1 调试日志的 USB 连接标志也不能随 tile0 检测更新。启动不崩溃不能发现这种问题。

修复方向：在 tile0/tile1 间建立明确的 channel/interface 消息协议；参数与计量状态由所属 tile 持有，跨 tile 发送快照。音频回调不能在每个采样帧里等待不定时 UART 消息。即使迁移到同 tile，也要处理多字段参数一致性和峰值读取/清零竞态。

依据：本机官方 XTC 15.3.1 手册 `C:/Program Files/XMOS/XTC/15.3.1/doc/html/tools-guide/tools-ref/cmd-line-tools/xgdb-manual/xgdb-manual.html:420–422`，章节 *Inferiors & threads*。

### P1：UART 收到 LEN > 16 后永久停止解析

`usb_uart_ctrl.xc:270–283` 接收任意一字节长度；进入 `S_PAYLOAD` 后，只有 `n < PAYLOAD_MAX` 才增加 `n`，但跳转条件是 `n >= len`。当 LEN=17 时，`n` 停在 16，后续帧头和有效命令都会被吞掉，且没有帧超时恢复。

本次把该计数逻辑逐字等价移植到内存中的 Python 检查，连续输入 500 字节后仍为 `S_PAYLOAD, n=16`。修复需在长度字段处拒绝越界长度、增加超时/重新同步规则，并测试损坏帧后的有效帧。Python 参考解码器允许 255 字节且采用扫描缓冲的重同步策略（`scripts/esp32_protocol_ref.py:62–86`），不能作为现有固件状态机已健壮的证据。

### P1：VU 的 dBFS 算法反向，满幅显示接近 -180 dBFS

`usb_uart_ctrl.xc:73–93` 的 `clz32()` 返回的是非零数的位宽，调用者却把它当作前导零个数；后续小数部分提取也应一并重写。以下是本次对现有整数算法的独立复现结果：

| Q31 正幅度 | 代码输出 | 正确理论值 |
|---|---:|---:|
| 1 | -5.99 dBFS | -186.64 dBFS |
| 65536 | -99.33 dBFS | -90.31 dBFS |
| 1073741824（半满幅） | -183.62 dBFS | -6.02 dBFS |
| 2147483647（接近满幅） | -180.64 dBFS | 约 0 dBFS |

另有边界问题：`user_buffer_management.xc:70–76` 将 `abs(INT32_MIN)=0x80000000` 转成有符号 `int` 比较，满负幅度可能不被计入峰值；`usb_uart_ctrl.xc:170–171,329–335` 的 UART 和调试输出都能清零峰值，后续正确通信时需重新确定读写所有权。

### P1：采样率变化尚未形成 ADC/DAC 配置闭环

`audiohw.xc:38–47` 只写采样率变量，没有通知或等待 ESP32 完成 codec 重配置。`audiostream.xc:6–13` 的流状态回调完全空置，`RESP_EVENT` 只定义、没有发送实现。不能认为当前协议已实现采样率切换静音、恢复或流开始/停止事件。

在完成 ESP32 固件后，需要定义启动时“codec 就绪”、采样率变更、静音、寄存器写入、I2S 恢复之间的状态机；各采样率对应的寄存器值须依据实际芯片手册确认。

## 3. 次级问题与文档冲突

| 优先级 | 问题 | 证据与影响 |
|---|---|---|
| P2 | 混音先饱和，再“限幅” | `user_buffer_management.xc:59–65,121–136` 先把累加值硬钳位到 Q31，再做 4:1 压缩。多源叠加产生的截顶信息已丢失；该函数没有包络/前瞻，也不是具有平滑拐点的音频限幅器。默认 -3 dB 阈值不是输出上限。 |
| P2 | 参数切换没有平滑与整组快照 | `usb_uart_ctrl.xc:205–208,218–231` 逐字更新参数；`user_buffer_management.xc:102–110` 逐字读取。修复跨 tile 后仍应避免读到半更新预设，并增加增益平滑以减少突变。 |
| P2 | 固件资源预算陈旧 | `DESIGN.md:153–156` 写 5–6/16 核，`:192` 写 tile0 7/8。基础 `.xe` 的 `xobjdump --resources` 实测上界为 tile0 **8/8 核、10/10 定时器**，tile1 **3/8 核、3/10 定时器**。不能按文档余量继续直接往 tile0 加任务。 |
| P2 | DFU 输出类型标注可疑，需要更正后验证 | `scripts/flash.ps1:51–54` 同时传 `--factory` 和 `--upgrade`，产出包含工厂及升级镜像的 Flash 布局，却在 `:79–81` 描述为直接交给 DFU 的升级镜像。官方 xflash 手册 `--upgrade` 说明不指定 factory 时可输出单独升级文件；应拆分“完整烧录镜像”和“DFU 升级镜像”，再做离线结构和设备验证。 |
| P2 | 老 Makefile 不是 CMake 的等价入口 | `Makefile:8` 未列 `lib_uart`；`:11` 的 mix6 未开启 `MIXER=1`，而头文件默认关闭。主线应明确为 CMake，并删除或修复“兼容入口”承诺。 |
| P2 | 自有应用随上游目录整体被根仓库忽略 | 根 `.gitignore:2` 忽略 `firmware/sw_usb_audio/`，自有应用保存在一个独立 Git 仓库中；本次该仓库 HEAD 为 `fc7085b`，自有文件有跟踪且工作区干净，但根仓库没有对应 submodule/版本绑定。只克隆根仓库不能重现固件。 |
| P3 | 开发状态互相矛盾 | `DESIGN.md:3` 写“未编译，待 XTC”，`:166` 又写三配置编译/仿真通过；`firmware/README.md:142` 仍称未编译脚手架。应统一为“已有编译产物/启动冒烟，功能尚未验收”。 |
| P3 | UART 实现描述陈旧 | `DESIGN.md:99,127,154` 写 GPIO glue/combinable；实际 `usb_uart_ctrl.xc:364–370` 为 streaming RX/TX/control 三任务，调试另占两个任务。 |
| P3 | README 指向旧混音路线 | `firmware/README.md:125–126` 仍要求框架 `MIXER=1` 和 `lib_dsp`；实际默认 Track A、未接入 lib_dsp。 |
| P3 | 构建说明路径和默认目标不一致 | `firmware/README.md:72,79,91–94` 的 `build/bin` 路径与本机 `app/bin/<config>/...xe` 不同；示例只传 8×8 Config，未传官方 App，会与脚本默认自有 App 冲突。`build.ps1:85` 返回原目录后从相对 `bin` 汇总，可能显示不到刚产出的文件。 |
| P3 | 自检能力写得过满 | `check-consistency.ps1` 的共享变量“唯一定义”仅检查一个预定文件；主要依赖正则与名字对应，未检查跨 tile 内存、实际 QFN 引脚、算法、协议错误恢复、资源预算或音频质量。 |

硬件接口方面：XN 的端口选择已可生成镜像，但文档仍没有完成实际 QF60A 引脚号/网络逐一签核；双 tile 的 MCLK 输入接线必须与板级方案一起确认。`PORT_DEBUG_RX` 已命名但未用，不能按文档宣传可接收 CLI。ADC/DAC 两组时钟在固件只有一套 I2S BCLK/LRCLK 端口，应在原理图上明确为同源网络分支。有关芯片引脚和电源设计的详细结论以硬件审阅为准。

## 4. 本次实际验证与证据边界

| 检查 | 本次结果 | 能证明什么 |
|---|---|---|
| `scripts/check-consistency.ps1` | **PASS=19、FAIL=0** | 命名端口、预定共享变量绑定、部分依赖残留和三种配置名的静态一致性 |
| `python scripts/esp32_protocol_ref.py` | 5 条 PASS；CRC 标准向量 0xF4、帧往返、坏 CRC、VU/状态解码通过 | Python 参考实现的这些案例通过；未调用真实固件解析器或 DSP |
| 工具链版本 | 经 `SetEnv.bat` 后 `xcc --version`：**XTC 15.3.1**，Build 29-89e0f73 | 本机工具链可启动；不能直接在未配置环境时调用 xcc |
| 已有镜像 | 基础 3,642,112 B；mix6 3,796,524 B；usblb 3,370,224 B，时间均为 2026-08-19 05:59–06:00 | 三个现有 `.xe` 可被 xobjdump 读取；本轮未重新编译，也未作二进制与源码的可重现性证明 |
| 基础镜像符号与资源 | 发现两 tile 各自的全局状态副本；资源上界见上文 | 控制架构问题及已有镜像的静态资源占用 |
| 本次 xsim 启动冒烟 | `xsim --max-cycles 2000000 <基础.xe>` 运行后以 **C51188: maximum cycles reached (2000000)** 退出，进程码 1；另有 XLink0 未连接警告 | 达到仿真周期上限，未见其他致命报错；不是测试断言全部通过，也没有模拟真实 USB/ADC/ESP32 |
| 算法独立复现 | LEN=17 卡死状态、上述 dBFS 错值可复现 | 依据源代码逻辑证明缺陷，不是目标硬件测量 |

基础镜像位置：`firmware/sw_usb_audio/app_usb_aud_asiocard/bin/2AMi6o6xxxxxx/app_usb_aud_asiocard_2AMi6o6xxxxxx.xe`。

本轮没有执行烧录、驱动安装、USB 设备验收、真实录放音、延迟/THD+N 测量、通道命名验证、DFU 升级或 ESP32 联调。旧文档的实测声明只有在附带可复现命令、结果和硬件条件时，才应提升为当前验收依据。

## 5. 建议修复与验证顺序

1. 固定唯一主线：保留默认 Track A 为产品实现；将 mix6/usblb 标为实验/诊断。记录独立固件仓库版本和依赖版本，建立根仓库可复现的获取方式。
2. 先改跨 tile 通信和状态所有权，明确参数快照、VU 上报、USB 状态、采样率变更各自的消息方向；以 XTC 资源报告重新分配任务。
3. 修复 UART 长度/超时/重同步，以及 dBFS 和满负幅度处理；用真实解析器与 DSP 的边界测试替代仅 Python 编解码自测。
4. 定义并实现 ESP32 固件，包括 ADC/DAC 初始化、采样率切换握手、静音时序、继电器/幻象电源控制和屏幕；硬件引脚与 XN 同步定稿。
5. 修正混音 headroom、限幅算法和参数平滑，再用已知输入检验每一路输出、监听/直播隔离及回环方向。
6. 重新编译三个配置、保留编译和资源报告；仿真需至少覆盖有效/异常 UART 帧、跨 tile 参数实际生效和已知音频输入输出，而不只检测启动。
7. 板卡与调试器到位后执行 Flash/USB/UAC2/ASIO/全部采样率/断连恢复/长时间稳定性实测；最后验证单独 DFU 镜像及升级恢复流程。
