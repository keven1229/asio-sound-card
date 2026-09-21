# ============================================================================
# ASIO-CARD 固件构建脚本（Windows / XTC Tools 15.3.1）
# 用法:
#   powershell -File scripts\build.ps1                          # asiocard 2AMi6o6xxxxxx
#   powershell -File scripts\build.ps1 -App app_usb_aud_xk_316_mc -Config 2AMi8o8xxxxxx   # 官方参考
#   powershell -File scripts\build.ps1 -ListTargets             # 列出可用构建目标
# 说明: 脚本自动探测 XTC 安装目录并通过 SetEnv.bat 设置工具链环境,
#       因此普通 PowerShell 即可运行, 无需 XTC Command Prompt。
# ============================================================================
param(
    [string]$Config = "2AMi6o6xxxxxx",
    [string]$App    = "app_usb_aud_asiocard",
    [string]$Repo   = "C:\workdir\asio-sound-card\firmware\sw_usb_audio",
    [int]   $Jobs   = 8,
    [switch]$ListTargets
)

$ErrorActionPreference = "Stop"
$AppDir = Join-Path $Repo $App
if (-not (Test-Path (Join-Path $AppDir "CMakeLists.txt"))) {
    Write-Error "找不到应用目录: $AppDir"
}

# 1) 探测 XTC 安装
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
if (-not $XtcRoot) {
    Write-Error "未找到 XTC Tools 安装。请从 https://www.xmos.com/software-tools/ 下载安装 XTC Tools 15.3.1。"
}
$SetEnv = Join-Path $XtcRoot "SetEnv.bat"
if (-not (Test-Path $SetEnv)) { Write-Error "XTC 目录缺少 SetEnv.bat: $XtcRoot" }

# 2) cmake/ninja 兜底探测 (当前会话 PATH 可能是旧环境)
$cmakeExe = (Get-Command cmake -ErrorAction SilentlyContinue).Source
if (-not $cmakeExe) {
    $c = 'C:\Program Files\CMake\bin\cmake.exe'
    if (Test-Path $c) { $cmakeExe = $c } else { Write-Error "cmake 未找到 (winget install Kitware.CMake)" }
}
$ninjaExe = (Get-Command ninja -ErrorAction SilentlyContinue).Source
if (-not $ninjaExe) {
    $n = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\ninja.exe'
    $n2 = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ninja.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    if (Test-Path $n) { $ninjaExe = $n } elseif ($n2) { $ninjaExe = $n2 } else { Write-Error "ninja 未找到 (winget install Ninja-build.Ninja)" }
}

Write-Host "== 工具链 ==" -ForegroundColor Cyan
Write-Host "  XTC      : $XtcRoot"
Write-Host "  cmake    : $cmakeExe"
Write-Host "  ninja    : $ninjaExe"
Write-Host "  目标     : ${App}_${Config} (-j $Jobs)"

# 3) 构建 (经 SetEnv.bat 设置环境; 首次 configure 会联网拉取 lib_xua 等依赖)
$Target = "${App}_${Config}"
$BuildCmds = @(
    "call `"$SetEnv`"",
    "cd /d `"$AppDir`"",
    "`"$cmakeExe`" -G Ninja -DCMAKE_MAKE_PROGRAM=`"$ninjaExe`" -B build"
)
if ($ListTargets) {
    $BuildCmds += "`"$cmakeExe`" --build build --target help"
} else {
    $BuildCmds += "`"$cmakeExe`" --build build --target $Target -j $Jobs"
}
$CmdLine = $BuildCmds -join " && "

Push-Location $AppDir
try {
    & cmd /c $CmdLine
    if ($LASTEXITCODE -ne 0) { throw "构建失败 (exit $LASTEXITCODE)" }
}
finally {
    Pop-Location
}

# 4) 产物汇总 (XCommon CMake 输出到 bin\<config>\app_<name>_<config>.xe)
Write-Host "== 产物 ==" -ForegroundColor Cyan
Get-ChildItem "bin" -Recurse -Filter *.xe -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 5 FullName, Length, LastWriteTime | Format-Table -AutoSize
Write-Host "烧录 (XTAG4 接好 xSYS):" -ForegroundColor Green
Write-Host "  xflash --factory bin\$Config\${Target}.xe"
