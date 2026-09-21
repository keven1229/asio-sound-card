# ============================================================================
# 烧录/DFU 脚本（XU316 / QSPI Flash / XTAG4 / XTC 15.3.1）
# 用法 (普通 PowerShell 即可, 自动经 SetEnv.bat 设置工具链环境):
#   powershell -File scripts\flash.ps1 -List                          # 列出调试器/目标
#   powershell -File scripts\flash.ps1 -Factory -Xe <path.xe>         # 工厂镜像烧录 (需 XTAG4)
#   powershell -File scripts\flash.ps1 -Upgrade 1 -Xe <path.xe>       # 升级镜像烧录 (需 XTAG4)
#   powershell -File scripts\flash.ps1 -MakeUpgradeImage              # 离线生成 DFU 升级 .bin (无需硬件)
#   powershell -File scripts\flash.ps1 -Analyze <path.bin>            # 分析镜像内容 (分区表)
# ============================================================================
param(
    [switch]$List,
    [switch]$Factory,
    [int]$Upgrade = 0,            # 0=不使用; 1=升级镜像(image number)
    [string]$Xe = "",
    [switch]$MakeUpgradeImage,
    [string]$Analyze = "",
    [string]$FactoryVersion = "15.3"
)

$ErrorActionPreference = "Stop"

# 1) 探测 XTC (与 build.ps1 同款逻辑)
$XtcRoot = $null
if ($env:XMOS_TOOL_PATH -and (Test-Path $env:XMOS_TOOL_PATH)) {
    $XtcRoot = $env:XMOS_TOOL_PATH
} else {
    foreach ($base in @('C:\Program Files\XMOS\XTC','C:\XMOS')) {
        $ver = Get-ChildItem $base -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending | Select-Object -First 1
        if ($ver) { $XtcRoot = $ver.FullName; break }
    }
}
if (-not $XtcRoot) { Write-Error "未找到 XTC Tools 安装" }
$SetEnv = Join-Path $XtcRoot "SetEnv.bat"
$xflash = Join-Path $XtcRoot "bin\xflash.exe"

# 2) 未指定 .xe 时取最近构建产物
if (-not $Xe -and ($Factory -or $Upgrade -ge 1 -or $MakeUpgradeImage)) {
    $candidate = Get-ChildItem "C:\workdir\asio-sound-card\firmware\sw_usb_audio\app_usb_aud_asiocard\bin" -Recurse -Filter "*.xe" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch 'mix6|usblb' } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($candidate) { $Xe = $candidate.FullName } else { Write-Error "未找到 .xe，请用 -Xe 指定" }
}
if ($Xe -and -not (Test-Path $Xe)) { Write-Error "文件不存在: $Xe" }

# 3) 组装命令
$cmds = @()
if ($List) {
    $cmds += "`"$xflash`" -l"
}
elseif ($MakeUpgradeImage) {
    # DFU 升级镜像 (XTC 15.3.1 语法: 工厂+升级 合成一个 .bin; 经控制面板上传)
    $out = [System.IO.Path]::ChangeExtension($Xe, ".upgrade.bin")
    $cmds += "`"$xflash`" --factory `"$Xe`" --upgrade 1 `"$Xe`" --factory-version $FactoryVersion -o `"$out`""
}
elseif ($Analyze) {
    $cmds += "`"$xflash`" --analyze `"$Analyze`""
}
elseif ($Factory) {
    Write-Host "工厂镜像烧录: xflash --factory $Xe (需 XTAG4 连接 xSYS)" -ForegroundColor Cyan
    $cmds += "`"$xflash`" --factory `"$Xe`""
}
elseif ($Upgrade -ge 1) {
    Write-Host "升级镜像烧录: xflash --upgrade $Upgrade $Xe (需 XTAG4; 需固件带 DFU)" -ForegroundColor Cyan
    $cmds += "`"$xflash`" --upgrade $Upgrade `"$Xe`""
}
else {
    Write-Host "未指定操作, 仅列出目标:" -ForegroundColor Yellow
    $cmds += "`"$xflash`" -l"
}

$cmdline = "call `"$SetEnv`" && " + ($cmds -join " && ")
& cmd /c $cmdline
if ($LASTEXITCODE -ne 0) { throw "xflash 失败 (exit $LASTEXITCODE)" }

if ($MakeUpgradeImage) {
    $out = [System.IO.Path]::ChangeExtension($Xe, ".upgrade.bin")
    Write-Host ""
    Write-Host "DFU 升级镜像已生成:" -ForegroundColor Green
    Write-Host "  $out ($((Get-Item $out).Length) bytes)"
    Write-Host "升级方式: USB Audio 控制面板 -> Firmware Upgrade, 或 xmosdfu 工具 (设备进 DFU 模式时)"
}

Write-Host @"

烧录后验证:
  1. 复位/重新上电, USB 接 Windows
  2. 设备管理器出现 "XMOS USB Audio 2.0 ST 309x" (装 XMOS 驱动后)
  3. 控制面板选采样率, REAPER 确认 ASIO 设备

W25Q16JVSNIQ: 已在 xflash QuadSpecEnum (WINBOND_W25Q16JV=12) 支持列表;
自板 XN SQIFlash 段为 256B page / 4KB sector / 8192 pages (2MB)。
"@
