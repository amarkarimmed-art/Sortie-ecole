$ErrorActionPreference = "Stop"
Write-Host "1. Initialisation de la base de donnees..." -ForegroundColor Cyan
$result = docker exec sortie-app php artisan demo:seed

$tokenLine = $result | Select-String -Pattern "TOKEN="
if (-not $tokenLine) { Write-Host "Erreur: token non trouve." -ForegroundColor Red; exit 1 }
$token = $tokenLine.ToString().Replace("TOKEN=", "").Trim()

$schoolLine = $result | Select-String -Pattern "SCHOOL_ID="
$schoolId = if ($schoolLine) { $schoolLine.ToString().Replace("SCHOOL_ID=", "").Trim() } else { "11111111-1111-1111-1111-111111111111" }

Write-Host "2. Mise a jour du token dans Flutter (Token: $token, School: $schoolId)..." -ForegroundColor Cyan
$mainDart = "app_ecole\lib\main.dart"
$content = Get-Content $mainDart -Raw
$content = $content -replace "token:\s*'[^']*'", "token: '$token'"
$content = $content -replace "schoolId:\s*'[^']*'", "schoolId: '$schoolId'"
Set-Content $mainDart -Value $content -NoNewline

Write-Host "3. Lancement de l'application..." -ForegroundColor Cyan
cd app_ecole
$env:PATH = "C:\src\flutter\bin;" + $env:PATH
flutter run -d chrome
