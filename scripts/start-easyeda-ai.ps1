[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'easyeda-agent\v1.3.0'),
    [switch]$Mcp,
    [string]$NodePath = $env:EASYEDA_NODE
)

$ErrorActionPreference = 'Stop'
$binary = Join-Path $InstallRoot 'easyeda_windows_amd64.exe'
$server = Join-Path $InstallRoot 'mcp\src\server.mjs'
$healthUrl = 'http://127.0.0.1:60832/health'
if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) {
    throw "Missing EasyEDA Agent v1.3.0 binary: $binary"
}

function Read-DaemonHealth {
    try { return Invoke-RestMethod -Uri $healthUrl -TimeoutSec 2 }
    catch { return $null }
}

# Multiple MCP clients may start together. Serialize only daemon startup.
$startupMutex = New-Object System.Threading.Mutex($false, 'Local\EasyedaAgentV130Start')
$mutexHeld = $false
try {
    try { $mutexHeld = $startupMutex.WaitOne(15000) }
    catch [System.Threading.AbandonedMutexException] { $mutexHeld = $true }
    if (-not $mutexHeld) { throw 'Timed out waiting for EasyEDA daemon startup.' }
    $health = Read-DaemonHealth
    if ($null -ne $health -and $health.service -ne 'easyeda-agent') {
        throw 'Port 60832 is occupied by a different HTTP service.'
    }
    if ($null -eq $health) {
        $logRoot = Join-Path $InstallRoot 'logs'
        New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
        $daemon = Start-Process -FilePath $binary `
            -ArgumentList @('daemon', 'start', '--auto-update-skill=false') `
            -WorkingDirectory $InstallRoot -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $logRoot 'daemon.stdout.log') `
            -RedirectStandardError (Join-Path $logRoot 'daemon.stderr.log')
        for ($attempt = 0; $attempt -lt 40; $attempt++) {
            Start-Sleep -Milliseconds 250
            $health = Read-DaemonHealth
            if ($null -ne $health) { break }
            if ($daemon.HasExited) { throw "EasyEDA daemon exited; inspect $logRoot" }
        }
        if ($null -eq $health) { throw "EasyEDA daemon did not become healthy; inspect $logRoot" }
        if ($health.service -ne 'easyeda-agent') { throw 'Unexpected daemon service identity.' }
    }
    if (($health.version -replace '^v', '') -ne '1.3.0') {
        throw "An EasyEDA daemon with version $($health.version) is running; expected v1.3.0."
    }
}
finally {
    if ($mutexHeld) { $startupMutex.ReleaseMutex() }
    $startupMutex.Dispose()
}

if ($Mcp) {
    if ([string]::IsNullOrWhiteSpace($NodePath)) {
        $nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
        if ($nodeCommand) { $NodePath = $nodeCommand.Source }
    }
    if ([string]::IsNullOrWhiteSpace($NodePath) -or -not (Test-Path -LiteralPath $NodePath)) {
        throw 'Node.js >=20.17 is required. Pass -NodePath or set EASYEDA_NODE.'
    }
    $env:EASYEDA_BIN = $binary
    & $NodePath $server
    exit $LASTEXITCODE
}

$health | ConvertTo-Json -Depth 12
