# FlightPath — one-command Android emulator runner (Windows / PowerShell)
#
# Usage:
#   .\tool\run-emulator.ps1            # debug build (default)
#   .\tool\run-emulator.ps1 -Profile   # profile build
#   .\tool\run-emulator.ps1 -Release   # release build (uses debug signing)
#   .\tool\run-emulator.ps1 -Emulator "Pixel_7_API_34"   # pick a specific AVD
#   .\tool\run-emulator.ps1 -NoLaunchEmulator            # don't auto-start an AVD
#
# What it does:
#   1. Verifies `flutter` is on PATH.
#   2. Sources tool/.env.local (KEY=VALUE per line) if it exists.
#   3. If no device is currently connected, launches the first available
#      Android emulator (or the one you passed via -Emulator).
#   4. Runs `flutter run` targeting the Android emulator with all required
#      --dart-define flags wired in.

[CmdletBinding()]
param(
    [switch]$Profile,
    [switch]$Release,
    [string]$Emulator,
    [switch]$NoLaunchEmulator
)

$ErrorActionPreference = "Stop"

# Resolve repo root = parent of this script's directory (tool/..)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = Split-Path -Parent $scriptDir
Set-Location $repoRoot

function Write-Info  ($msg) { Write-Host "[run-emulator] $msg" -ForegroundColor Cyan }
function Write-Warn2 ($msg) { Write-Host "[run-emulator] $msg" -ForegroundColor Yellow }
function Write-Err   ($msg) { Write-Host "[run-emulator] $msg" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# 1. flutter on PATH?
# ---------------------------------------------------------------------------
$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    Write-Err "`flutter` is not on PATH."
    Write-Err "Install the Flutter SDK and add it to PATH, then re-run."
    Write-Err "  https://docs.flutter.dev/get-started/install/windows"
    exit 1
}
Write-Info "flutter: $($flutter.Source)"

# ---------------------------------------------------------------------------
# 2. Source tool/.env.local (optional)
# ---------------------------------------------------------------------------
$envFile = Join-Path $scriptDir ".env.local"
if (Test-Path $envFile) {
    Write-Info "Loading env from tool/.env.local"
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$') {
            $k = $matches[1]
            $v = $matches[2].Trim('"').Trim("'")
            Set-Item -Path "Env:$k" -Value $v
        }
    }
} else {
    Write-Warn2 "tool/.env.local not found — using placeholder dart-defines."
    Write-Warn2 "Copy tool/.env.local.example to tool/.env.local when you have real keys."
}

# Defaults so the debug StateError guard in subscription_service.dart doesn't
# fire. Real keys live in tool/.env.local and override these.
if (-not $env:REVENUECAT_ANDROID_KEY) { $env:REVENUECAT_ANDROID_KEY = "goog_dev_placeholder" }
if (-not $env:REVENUECAT_IOS_KEY)     { $env:REVENUECAT_IOS_KEY     = "appl_dev_placeholder" }

# ---------------------------------------------------------------------------
# 3. Ensure an Android emulator/device is running
# ---------------------------------------------------------------------------
function Get-AndroidDeviceId {
    $devices = & flutter devices --machine 2>$null | Out-String
    if (-not $devices) { return $null }
    try {
        $parsed = $devices | ConvertFrom-Json
        foreach ($d in $parsed) {
            if ($d.targetPlatform -like "android*" -or $d.id -like "emulator-*") {
                return $d.id
            }
        }
    } catch {
        # Fallback: parse plain text `flutter devices` output
        $txt = & flutter devices 2>$null
        foreach ($line in $txt) {
            if ($line -match "emulator-\d+") { return $matches[0] }
        }
    }
    return $null
}

$deviceId = Get-AndroidDeviceId

if (-not $deviceId) {
    if ($NoLaunchEmulator) {
        Write-Err "No Android device/emulator connected and -NoLaunchEmulator set."
        exit 1
    }

    Write-Info "No Android device connected — looking for an AVD to launch."
    $avdList = & flutter emulators 2>$null
    $avdIds  = @()
    foreach ($line in $avdList) {
        if ($line -match "^([^\s]+)\s+\u2022") { $avdIds += $matches[1] }
        elseif ($line -match "^([A-Za-z0-9_\-]+)\s+\|") { $avdIds += $matches[1] }
    }

    if ($avdIds.Count -eq 0) {
        Write-Err "No Android AVDs found. Create one via:"
        Write-Err "  Android Studio -> More Actions -> Virtual Device Manager -> Create Device"
        Write-Err "Or from the CLI: `flutter emulators --create --name flightpath_avd`"
        exit 1
    }

    $target = if ($Emulator) { $Emulator } else { $avdIds[0] }
    Write-Info "Launching emulator: $target"
    & flutter emulators --launch $target | Out-Null

    # Poll up to 90s for the device to come online
    $deadline = (Get-Date).AddSeconds(90)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        $deviceId = Get-AndroidDeviceId
        if ($deviceId) { break }
    }

    if (-not $deviceId) {
        Write-Err "Emulator did not come online within 90 seconds."
        Write-Err "Check Android Studio's AVD Manager and try launching it manually."
        exit 1
    }
}

Write-Info "Target device: $deviceId"

# ---------------------------------------------------------------------------
# 4. Build the flutter run command
# ---------------------------------------------------------------------------
$buildMode = "--debug"
if ($Profile) { $buildMode = "--profile" }
if ($Release) { $buildMode = "--release" }

$dartDefines = @(
    "--dart-define=REVENUECAT_ANDROID_KEY=$($env:REVENUECAT_ANDROID_KEY)",
    "--dart-define=REVENUECAT_IOS_KEY=$($env:REVENUECAT_IOS_KEY)"
)

Write-Info "flutter run $buildMode -d $deviceId $($dartDefines -join ' ')"
Write-Host ""

& flutter run $buildMode -d $deviceId @dartDefines
exit $LASTEXITCODE
