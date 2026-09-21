[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'easyeda-agent\v1.3.0'),
    [switch]$RequireConnector,
    [switch]$McpSmokeTest,
    [string]$NodePath = $env:EASYEDA_NODE
)

$ErrorActionPreference = 'Stop'
$binary = Join-Path $InstallRoot 'easyeda_windows_amd64.exe'
$checksums = Get-Content -LiteralPath (Join-Path $InstallRoot 'checksums.txt')
$verified = @()
foreach ($name in @('easyeda_windows_amd64.exe', 'easyeda-agent-connector.eext')) {
    $entry = @($checksums | Where-Object { ($_ -split '\s+')[1] -eq $name })
    if ($entry.Count -ne 1) { throw "Missing unique release checksum for $name" }
    $actual = (Get-FileHash -LiteralPath (Join-Path $InstallRoot $name) -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne ($entry[0] -split '\s+')[0]) { throw "Release SHA256 mismatch: $name" }
    $verified += $name
}
$version = (& $binary version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -ne 'easyeda-agent v1.3.0') {
    throw "Unexpected CLI version: $version"
}

$health = $null
try { $health = Invoke-RestMethod -Uri 'http://127.0.0.1:60832/health' -TimeoutSec 3 }
catch { Write-Warning 'Daemon is offline. Run scripts/start-easyeda-ai.ps1 first.' }
if ($health -and $health.service -ne 'easyeda-agent') { throw 'Unexpected service on port 60832.' }
if ($health -and ($health.version -replace '^v', '') -ne '1.3.0') { throw 'Daemon version does not match v1.3.0.' }
$windows = @()
if ($health -and $health.windows) { $windows = @($health.windows) }
if ($RequireConnector -and $windows.Count -eq 0) {
    throw 'No EasyEDA connector is connected. Import/enable EDA Agent Connector and allow external interaction.'
}
if ($RequireConnector) {
    # Windows PowerShell 5.1 turns native stderr (including success notices) into
    # NativeCommandError records. Ignore that stream here and trust the native
    # exit code; restore terminating errors before parsing/checking the result.
    $savedErrorPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $cliHealthText = @(& $binary daemon health 2>$null)
        $cliHealthExitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $savedErrorPreference }
    if ($cliHealthExitCode -ne 0) { throw "CLI daemon health failed (exit $cliHealthExitCode)." }
    $cliHealth = ($cliHealthText | Out-String) | ConvertFrom-Json
    if ($cliHealth.versionGate -and $cliHealth.versionGate.verdict -ne 'ok') {
        throw 'CLI/daemon/connector version check failed. Run easyeda daemon health for details.'
    }
    foreach ($window in $windows) {
        if ($window.PSObject.Properties.Name -contains 'connectorVersionOk' -and $window.connectorVersionOk -eq $false) {
            throw 'A connected EasyEDA extension has a stale connector version.'
        }
    }
}

if ($McpSmokeTest) {
    if ([string]::IsNullOrWhiteSpace($NodePath)) {
        $nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
        if ($nodeCommand) { $NodePath = $nodeCommand.Source }
    }
    if ([string]::IsNullOrWhiteSpace($NodePath)) { throw 'Node.js not found. Pass -NodePath.' }
    & $NodePath (Join-Path $InstallRoot 'mcp\check-mcp.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'MCP protocol smoke test failed.' }
}

[pscustomobject]@{
    checkedAt = (Get-Date).ToString('o')
    installRoot = $InstallRoot
    releaseAssetsVerified = $verified
    cliVersion = $version
    daemonOnline = ($null -ne $health)
    connectedWindows = $windows.Count
    connectorReady = ($windows.Count -gt 0)
    extensionFile = (Join-Path $InstallRoot 'easyeda-agent-connector.eext')
    health = $health
} | ConvertTo-Json -Depth 15
