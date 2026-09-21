# ============================================================================
# 设备验收检查 (Windows / 板子上电后运行)
# 检查: 1) USB 枚举 (VID 0x20B1 / PID 0x0016)  2) XMOS 驱动状态
#       3) Windows 音频设备列表
# 用法: powershell -File host\device-check.ps1
# ============================================================================
$ErrorActionPreference = "Continue"
Write-Host "==== ASIO-CARD 设备验收检查 ====" -ForegroundColor Cyan

# 1) USB 设备枚举 (PnP)
$devs = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
    Where-Object { $_.InstanceId -match 'VID_20B1&PID_0016|VID_20B1&PID_D016' }
if ($devs) {
    foreach ($d in $devs) {
        $status = $d.Status
        $color = if ($status -eq 'OK') { 'Green' } else { 'Yellow' }
        Write-Host "[FOUND] $($d.FriendlyName) [$status]" -ForegroundColor $color
    }
    Write-Host "  PID 0x0016 = 正常运行固件; PID 0xD016 = DFU 模式 (可经控制面板升级)" -ForegroundColor DarkGray
} else {
    Write-Host "[NONE] 未检测到 VID_20B1 设备 — 检查: USB 线 (数据线)/Hub/上电/复位" -ForegroundColor Red
}

# 2) 驱动签名 (XMOS 驱动 = Thesycon 签名; 内置 = Microsoft)
$driverDevs = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
    Where-Object { $_.InstanceId -match 'VID_20B1' }
foreach ($d in $driverDevs) {
    $m = $d | Get-PnpDeviceProperty -KeyName 'DEVPKEY_Device_DriverProvider' -ErrorAction SilentlyContinue
    $provider = $m.Data
    if ($provider -match 'XMOS|Thesycon') {
        Write-Host "[DRV OK] $($d.FriendlyName): 驱动提供者 = $provider (XMOS/Thesycon, 含 ASIO)" -ForegroundColor Green
    } elseif ($provider -match 'Microsoft') {
        Write-Host "[DRV WARN] $($d.FriendlyName): 内置 UAC2 驱动 (能出声, 无 ASIO/控制面板)。请装 XMOS USB Audio 驱动 (host/README.md)" -ForegroundColor Yellow
    } else {
        Write-Host "[DRV ?] $($d.FriendlyName): 驱动提供者 = $provider" -ForegroundColor Yellow
    }
}

# 3) 音频端点概览
Write-Host "`n---- Windows 音频设备 (本机) ----" -ForegroundColor Cyan
Get-CimInstance Win32_SoundDevice -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'XMOS|ASIO-CARD' } |
    Select-Object Name, Status | Format-Table -AutoSize | Out-String

Write-Host "`n后续 (ASIO 实测): REAPER 中 Audio->Device 选 'XMOS USB Audio 2.0 ST 309x' 的 ASIO 驱动" -ForegroundColor DarkGray
Write-Host "==== 检查结束 ====" -ForegroundColor Cyan
