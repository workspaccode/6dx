#!/usr/bin/env pwsh
<#
.SYNOPSIS
Runs, stops and inspects the 6DX backend.

.DESCRIPTION
`run` keeps `go run ./cmd/api` in the foreground, exactly like typing it by
hand. `start` builds a small binary into .run/ and launches it detached, so the
server survives closing the terminal; it then waits for /health before
reporting success. `stop` finds the server either through .run/api.pid or by
looking at the port from .env, which also covers a `go run` started manually.

.EXAMPLE
./serve.ps1 start
./serve.ps1 status
./serve.ps1 stop
#>
[CmdletBinding()]
param(
    [ValidateSet('run', 'start', 'stop', 'restart', 'status', 'logs')]
    [string]$Action = 'run'
)

$ErrorActionPreference = 'Stop'

$backendDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$runDir = Join-Path $backendDir '.run'
$exePath = Join-Path $runDir '6dx-api.exe'
$pidPath = Join-Path $runDir 'api.pid'
$outLog = Join-Path $runDir 'api.log'
$errLog = Join-Path $runDir 'api.err.log'

# The listen address comes from the environment first (so a test can pick a
# spare port) and from .env otherwise.
function Get-Port {
    $addr = $env:ADDR
    $envFile = Join-Path $backendDir '.env'
    if (-not $addr -and (Test-Path -LiteralPath $envFile)) {
        foreach ($line in Get-Content -LiteralPath $envFile) {
            if ($line -match '^\s*ADDR\s*=\s*(.+?)\s*$') {
                $addr = $Matches[1]
                break
            }
        }
    }
    if ($addr -and $addr -match ':?(\d+)\s*$') { return [int]$Matches[1] }
    return 8080
}

function Get-HealthUri {
    "http://127.0.0.1:$(Get-Port)/health"
}

function Get-RecordedPid {
    if (-not (Test-Path -LiteralPath $pidPath)) { return $null }
    $raw = (Get-Content -LiteralPath $pidPath -Raw).Trim()
    if (-not $raw) { return $null }
    $process = Get-Process -Id ([int]$raw) -ErrorAction SilentlyContinue
    if ($process) { return $process.Id }
    return $null
}

function Get-PortOwner {
    $connection = Get-NetTCPConnection -LocalPort (Get-Port) -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $connection) { return $null }
    return Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue
}

function Wait-ForHealth {
    param([int]$TimeoutSeconds = 20)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -Uri (Get-HealthUri) -TimeoutSec 2 -UseBasicParsing
            if ($response.StatusCode -eq 200) { return $true }
        } catch {
            Start-Sleep -Milliseconds 300
        }
    }
    return $false
}

function Start-Server {
    $recorded = Get-RecordedPid
    if ($recorded) {
        Write-Host "already running (PID $recorded) on port $(Get-Port)"
        return
    }

    $owner = Get-PortOwner
    if ($owner) {
        $message = "port $(Get-Port) is already used by $($owner.ProcessName) " +
            "(PID $($owner.Id)) - run ./serve.ps1 stop, or close that process first."
        throw $message
    }

    New-Item -ItemType Directory -Path $runDir -Force | Out-Null

    Push-Location -LiteralPath $backendDir
    try {
        Write-Host 'building...'
        & go build -o $exePath ./cmd/api
        if ($LASTEXITCODE -ne 0) { throw 'go build failed' }
    } finally {
        Pop-Location
    }

    $process = Start-Process -FilePath $exePath -WorkingDirectory $backendDir -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $outLog -RedirectStandardError $errLog
    Set-Content -LiteralPath $pidPath -Value $process.Id -NoNewline

    if (-not (Wait-ForHealth)) {
        Write-Warning "the server did not answer /health - see $errLog"
        return
    }

    Write-Host "running (PID $($process.Id)) on http://localhost:$(Get-Port)"
    Write-Host "log: $outLog"
}

function Stop-Server {
    $stopped = $false

    $recorded = Get-RecordedPid
    if ($recorded) {
        Stop-Process -Id $recorded -Force -ErrorAction SilentlyContinue
        Write-Host "stopped (PID $recorded)"
        $stopped = $true
    }
    Remove-Item -LiteralPath $pidPath -ErrorAction SilentlyContinue

    # A server started by hand (`go run ./cmd/api`) has no pid file: find it
    # through the port instead, and take its `go run` parent down as well.
    $owner = Get-PortOwner
    if ($owner) {
        if ($owner.ProcessName -in @('go', 'api', '6dx-api')) {
            $parentId = Get-CimInstance Win32_Process -Filter "ProcessId = $($owner.Id)" |
                Select-Object -ExpandProperty ParentProcessId
            Stop-Process -Id $owner.Id -Force -ErrorAction SilentlyContinue
            if ($parentId) { Stop-Process -Id $parentId -Force -ErrorAction SilentlyContinue }
            Write-Host "stopped $($owner.ProcessName) (PID $($owner.Id)) holding port $(Get-Port)"
            $stopped = $true
        } else {
            Write-Warning "port $(Get-Port) is held by $($owner.ProcessName) (PID $($owner.Id)); leaving it alone"
        }
    }

    if (-not $stopped) { Write-Host 'not running' }
}

function Show-Status {
    $port = Get-Port
    $owner = Get-PortOwner
    if (-not $owner) {
        Write-Host "stopped (port $port is free)"
        return
    }

    $healthy = Wait-ForHealth -TimeoutSeconds 3
    $state = if ($healthy) { 'healthy' } else { 'not answering /health' }
    Write-Host "$($owner.ProcessName) (PID $($owner.Id)) on port $port - $state"
}

function Invoke-Foreground {
    Push-Location -LiteralPath $backendDir
    try {
        & go run ./cmd/api
    } finally {
        Pop-Location
    }
}

switch ($Action) {
    'run' { Invoke-Foreground }
    'start' { Start-Server }
    'stop' { Stop-Server }
    'restart' { Stop-Server; Start-Server }
    'status' { Show-Status }
    'logs' {
        if (-not (Test-Path -LiteralPath $outLog)) { throw "no log yet - start the server once" }
        Get-Content -LiteralPath $outLog -Wait
    }
}
