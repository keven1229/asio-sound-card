# ============================================================================
# XTC Tools 环境自检 / 安装指引
# 用法: powershell -File scripts\setup-xtc.ps1
# ============================================================================
$ErrorActionPreference = "Continue"

Write-Host "================ XMOS XTC Tools 环境自检 ================" -ForegroundColor Cyan

# 1) 核心环境变量
if ($env:XMOS_TOOL_PATH -and $env:XMOS_CMAKE_PATH) {
    Write-Host "[OK] XMOS_TOOL_PATH = $env:XMOS_TOOL_PATH" -ForegroundColor Green
    Write-Host "[OK] XMOS_CMAKE_PATH = $env:XMOS_CMAKE_PATH" -ForegroundColor Green
    Write-Host "[OK] XTC 工具链已配置（新开的 shell 自动生效）" -ForegroundColor Green
} else {
    Write-Host "[MISSING] 未检测到 XTC 工具链环境变量" -ForegroundColor Red
    Write-Host @"

请按以下步骤安装（需要免费 xmos.com 账号）:

  1. 登录 https://www.xmos.com/software-tools/
  2. 下载 "XTC Tools 15.3.1" 的 Windows x64 Installer (.exe)
  3. 以管理员运行安装向导，一路默认（向导内完成免费 license 激活）
  4. 安装完成后，从开始菜单打开 "XTC Tools 15.3.1 Command Prompt"，
     在该终端里重跑本脚本与 build.ps1

  官方安装文档:
  https://www.xmos.com/documentation/XM-014363-PC/html/installation/index.html

  （注意: 当前 PowerShell 会话是旧环境，变量不会自动出现;
    必须新开 XTC Command Prompt，或注销重登后使用。）
"@
}

# 2) 配套工具
Write-Host "---------------- 配套工具 ----------------" -ForegroundColor Cyan
foreach ($t in @("cmake", "ninja", "git", "code")) {
    $c = Get-Command $t -ErrorAction SilentlyContinue
    if ($c) { Write-Host ("[OK] {0,-8} {1}" -f $t, $c.Source) -ForegroundColor Green }
    else    { Write-Host "[MISSING] $t" -ForegroundColor Yellow }
}

# 3) VS Code XMOS 扩展
$ext = (& code --list-extensions 2>$null | Select-String "xmos.xtc-tools")
if ($ext) { Write-Host "[OK] VS Code 扩展 xmos.xtc-tools 已安装" -ForegroundColor Green }
else {
    Write-Host "[MISSING] VS Code 扩展 xmos.xtc-tools；安装: code --install-extension xmos.xtc-tools" -ForegroundColor Yellow
}

# 4) 调试器检查
Write-Host "---------------- 调试器 ----------------" -ForegroundColor Cyan
$xf = Get-Command xflash -ErrorAction SilentlyContinue
if ($xf) {
    Write-Host "检查已连接的 xTAG/目标（xflash -l）:"
    & xflash -l
} else {
    Write-Host "[SKIP] xflash 尚未可用（先装 XTC 工具）。" -ForegroundColor Yellow
    Write-Host "       硬件提醒: XU316 (xcore.ai) 必须使用 XTAG4，XTAG3 不支持。" -ForegroundColor Yellow
}

Write-Host "================ 自检结束 ================" -ForegroundColor Cyan
