#!/usr/bin/env bash
# ============================================================================
# WSL2 Ubuntu 22.04 编译通道（可选，非日常必需）
#
# 背景: XMOS 官方只支持 Ubuntu 20.04/22.04 x64。当前 WSL 默认发行版是 Arch，
#       不受支持，故本通道使用独立 Ubuntu-22.04 发行版。
#
# 从 Windows PowerShell 开始:
#   wsl --install -d Ubuntu-22.04
#   然后把本脚本拷进 Ubuntu 后执行: sudo bash setup-wsl-ubuntu.sh
#
# 注意（官方立场）:
#   - XMOS 不支持在 WSL2 内访问 xTAG/烧录（USB 需 usbipd-win 透传，插拔易断）；
#   - 本通道只用于【编译】，烧录/调试仍在 Windows 侧做；
#   - 日常开发推荐 Windows 原生 XTC（见 firmware/README.md §0）。
# ============================================================================
set -euo pipefail

echo "== 1/3 基础依赖 =="
sudo apt-get update
sudo apt-get install -y cmake ninja-build git build-essential

echo "== 2/3 XTC Tools 15.3.1（Linux 版）=="
echo "  需要你先在 Windows 浏览器登录 xmos.com 下载 Linux 版安装包(.run)"
echo "  放到 Windows 侧 tools\\ 目录，例如 tools/XTC-Tools-15.3.1-x86_64.run"
echo "  然后在 Ubuntu 里执行（路径按实际情况替换）:"
echo ""
echo "    WIN_TOOLS=/mnt/c/workdir/asio-sound-card/tools"
echo "    chmod +x \$WIN_TOOLS/XTC-Tools-15.3.1-x86_64.run"
echo "    sudo bash \$WIN_TOOLS/XTC-Tools-15.3.1-x86_64.run   # 向导内完成免费激活"
echo ""

echo "== 3/3 环境变量（追加到 ~/.bashrc）=="
cat <<'EOF'
# --- 追加到 ~/.bashrc（路径以安装器实际位置为准）---
export XMOS_TOOL_PATH=/opt/XMOS/XTC/15.3.1
export PATH="$XMOS_TOOL_PATH/bin:$PATH"
export XMOS_CMAKE_PATH="$XMOS_TOOL_PATH/lib/xcommon_cmake"
# ------------------------------------------------
EOF

echo ""
echo "构建（在 Ubuntu 里）:"
echo "  cd /mnt/c/workdir/asio-sound-card/firmware/sw_usb_audio/app_usb_aud_xk_316_mc"
echo "  cmake -G Ninja -B build && cmake --build build --target app_usb_aud_xk_316_mc_2AMi8o8xxxxxx -j"
echo ""
echo "注意: 建议构建目录放 WSL 文件系统内（/home/...），避免 /mnt/c 上的性能损耗;"
echo "      需要 -B /mnt/c/... 时也可用，但明显更慢。"
