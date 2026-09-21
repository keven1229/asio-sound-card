# ============================================================================
# ASIO-CARD 固件一致性静态检查（无需 XTC 工具链，可持续回归）
# 检查项:
#   1. 代码中引用的 PORT_* (XN 命名端口) 都已在 asiocard.xn 中定义;
#   2. asiocard_shared.h 中声明的共享全局在 .xc 中恰好定义一次;
#   3. 无对官方 316-MC 板级支持 (xk_audio_316_mc_ab / BOARD_SUPPORT_BOARD) 的代码引用;
#   4. CMakeLists 构建配置名与注释约定一致 (2AMi6o6xxxxxx 系列)。
# 用法: powershell -File scripts\check-consistency.ps1
# ============================================================================
$ErrorActionPreference = "Stop"
$App = "C:\workdir\asio-sound-card\firmware\sw_usb_audio\app_usb_aud_asiocard"
$Xn  = Join-Path $App "src\core\asiocard.xn"
$pass = 0; $fail = 0

function Ok($msg)   { $script:pass++; Write-Host "[PASS] $msg" -ForegroundColor Green }
function Bad($msg)  { $script:fail++; Write-Host "[FAIL] $msg" -ForegroundColor Red }

Write-Host "==== 1) XN 端口定义 vs 代码引用 ====" -ForegroundColor Cyan

[xml]$xn = Get-Content -Raw -Encoding UTF8 $Xn
$xnPorts = @{}
foreach ($tile in $xn.Network.Packages.Package.Nodes.Node.Tile) {
    foreach ($p in $tile.Port) { $xnPorts[$p.Name] = $p.Location }
}

$codeFiles = Get-ChildItem $App -Recurse -Include *.xc,*.h -File |
    Where-Object { $_.FullName -notmatch 'hid_report_descriptor' }
$codePorts = @{}
foreach ($f in $codeFiles) {
    $text = Get-Content -Raw $f.FullName
    # 剥离注释后再匹配 (避免注释中的解释性文字误报)
    $text = $text -replace '(?s)/\*.*?\*/', '' -replace '//[^\r\n]*', ''
    foreach ($m in [regex]::Matches($text, '\bPORT_[A-Z0-9_]+\b')) {
        $codePorts[$m.Value] = $f.Name
    }
}
$missing = $codePorts.Keys | Where-Object { -not $xnPorts.ContainsKey($_) } | Sort-Object
if ($missing) { Bad ("代码引用但 XN 未定义: " + ($missing -join ', ')) }
else { Ok "所有代码引用的 PORT_* 均已在 asiocard.xn 定义 ($($codePorts.Count) 个)" }

$unused = $xnPorts.Keys | Where-Object { -not $codePorts.ContainsKey($_) } | Sort-Object
if ($unused) { Write-Host "  (信息) XN 定义但代码未直接引用(可能由框架使用): $($unused -join ', ')" -ForegroundColor DarkGray }

Write-Host "==== 2) 共享状态定义与指针绑定 ====" -ForegroundColor Cyan
$header = Get-Content -Raw (Join-Path $App "src\extensions\asiocard_shared.h")
$ptrs = [regex]::Matches($header, 'extern\s+\w+\s+volatile\s*\*\s*unsafe\s+(p_\w+)') | ForEach-Object { $_.Groups[1].Value }
$defFile = Join-Path $App "src\extensions\usb_uart_ctrl.xc"
$defText = Get-Content -Raw $defFile
foreach ($p in $ptrs) {
    $bind = [regex]::Match($defText, "\b$p\s*=\s*(&?g_\w+)")
    if ($bind.Success) { Ok "$p 绑定到 $($bind.Groups[1].Value)" }
    else { Bad "$p 未找到绑定定义" }
}
# 底层全局唯一性
foreach ($p in $ptrs) {
    $bind = [regex]::Match($defText, "\b$p\s*=\s*(&?g_\w+)")
    if ($bind.Success) {
        $g = $bind.Groups[1].Value.TrimStart('&')
        $defs = [regex]::Matches($defText, "^\s*(unsigned|int)\s+$g\s*[\[=]", 'Multiline')
        if ($defs.Count -eq 1) { Ok "$g 定义唯一" }
        else { Bad "$g 定义数=$($defs.Count)" }
    }
}

Write-Host "==== 3) 官方板级支持残留检查 ====" -ForegroundColor Cyan
$residue = Get-ChildItem $App -Recurse -Include *.xc,*.h,*.cmake,Makefile -File |
    Where-Object { $_.FullName -notmatch '\\build\\|\\.build_' } |
    Select-String -Pattern 'xk_audio_316_mc_ab|BOARD_SUPPORT_BOARD|lib_board_support' |
    Where-Object { $_.Line -notmatch '^\s*(//|\*|#)\s*' }
if ($residue) { Bad ("代码级残留: " + (($residue | ForEach-Object { "$($_.Filename):$($_.LineNumber)" }) -join ', ')) }
else { Ok "无官方板级支持代码残留 (注释除外)" }

Write-Host "==== 4) 构建配置名约定 ====" -ForegroundColor Cyan
$cm = Get-Content -Raw (Join-Path $App "CMakeLists.txt")
$configs = [regex]::Matches($cm, 'APP_COMPILER_FLAGS_(2AMi6o6\w+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
foreach ($c in $configs) { Ok "配置 $c" }
if (-not ($configs -contains '2AMi6o6xxxxxx')) { Bad "缺少基础配置 2AMi6o6xxxxxx" }

Write-Host ""
Write-Host "======== 结果: PASS=$pass FAIL=$fail ========" -ForegroundColor Cyan
if ($fail -gt 0) { exit 1 }
