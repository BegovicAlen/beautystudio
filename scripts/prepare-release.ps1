param(
    [string]$ReleaseDate = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependencies failed.' }
    flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:5000
    if ($LASTEXITCODE -ne 0) { throw 'Android build failed.' }
    flutter build windows --release --dart-define=API_BASE_URL=http://localhost:5000
    if ($LASTEXITCODE -ne 0) { throw 'Windows build failed. Close the running BeautyStudio app.' }
    & $Python -X utf8 scripts/package_release.py --date $ReleaseDate
    if ($LASTEXITCODE -ne 0) { throw 'Packaging failed.' }
} finally { Pop-Location }
