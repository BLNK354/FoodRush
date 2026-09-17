# FoodRush - run the web app with real Firebase config
# Reads the six FIREBASE_* values from .env.firebase.local and passes them
# as --dart-define arguments to flutter run.
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env.firebase.local'

if (-not (Test-Path $envFile)) {
  Write-Error "Missing $envFile"
}

$defines = @()
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim()
  if ($line -eq '' -or $line.StartsWith('#')) { return }
  $parts = $line -split '=', 2
  $k = $parts[0].Trim()
  $v = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }
  if ($k -and $v) {
    $defines += ('--dart-define={0}={1}' -f $k, $v)
  }
}

Set-Location $root
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 @defines
