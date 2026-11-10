<#
.SYNOPSIS
  Builds the release APK and packs it into a .zip for GitHub Releases.

.DESCRIPTION
  1. Reads the version from pubspec.yaml (e.g. 2.0.0+2 -> tag v2.0.0)
  2. flutter build apk --release
  3. Creates dist\transfeer-v<version>.zip containing app-release.apk
  4. With -Publish: creates the GitHub release (tag = v<version>) and uploads
     the zip. Needs a token in $env:GITHUB_TOKEN (scope: repo / contents:write).

  The app's in-app updater reads the latest release, downloads the .zip,
  extracts the .apk and opens the Android installer.

.EXAMPLE
  .\scripts\release.ps1
  .\scripts\release.ps1 -Publish -Notes "Sửa lỗi và cải thiện hiệu năng"
#>
param(
  [switch]$Publish,
  [string]$Notes = "",
  [string]$Repo = "phunlh2001/transfeer",
  [string]$Flutter = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# --- version -----------------------------------------------------------------
$line = Select-String -Path "pubspec.yaml" -Pattern '^version:\s*(\S+)' | Select-Object -First 1
if (-not $line) { throw "No 'version:' found in pubspec.yaml" }
$full = $line.Matches[0].Groups[1].Value          # 2.0.0+2
$version = $full.Split('+')[0]                    # 2.0.0
$tag = "v$version"
Write-Host "Version $full  ->  tag $tag" -ForegroundColor Cyan

# --- build -------------------------------------------------------------------
if (-not $Flutter) {
  $cmd = Get-Command flutter -ErrorAction SilentlyContinue
  if ($cmd) { $Flutter = $cmd.Source }
  else { $Flutter = Join-Path $env:USERPROFILE "develop\flutter\bin\flutter.bat" }
}
if (-not (Test-Path "android\key.properties")) {
  Write-Warning "android\key.properties not found: the APK will be DEBUG-signed and in-app updates will fail for users on the release key."
}
& $Flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw "flutter build failed" }

# --- zip ---------------------------------------------------------------------
$apk = "build\app\outputs\flutter-apk\app-release.apk"
$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force $dist | Out-Null
$zipName = "transfeer-$tag.zip"
$zip = Join-Path $dist $zipName
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $apk -DestinationPath $zip -CompressionLevel Optimal
$sizeMb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host "Created $zip ($sizeMb MB)" -ForegroundColor Green

if (-not $Publish) {
  Write-Host ""
  Write-Host "Next: create a GitHub release with tag '$tag' and attach '$zipName'." -ForegroundColor Yellow
  Write-Host "      https://github.com/$Repo/releases/new?tag=$tag"
  Write-Host "      (or re-run with -Publish and `$env:GITHUB_TOKEN set)"
  exit 0
}

# --- publish -----------------------------------------------------------------
if (-not $env:GITHUB_TOKEN) { throw "Set `$env:GITHUB_TOKEN to publish." }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$headers = @{
  Authorization          = "Bearer $env:GITHUB_TOKEN"
  Accept                 = "application/vnd.github+json"
  "X-GitHub-Api-Version" = "2022-11-28"
}
if (-not $Notes) { $Notes = "Phiên bản $version" }
$body = @{ tag_name = $tag; name = "Transfeer $tag"; body = $Notes; draft = $false; prerelease = $false } | ConvertTo-Json
$bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
$release = Invoke-RestMethod -Method Post -Uri "https://api.github.com/repos/$Repo/releases" `
  -Headers $headers -Body $bytes -ContentType "application/json; charset=utf-8"
Write-Host "Release created: $($release.html_url)" -ForegroundColor Green

$uploadUrl = "https://uploads.github.com/repos/$Repo/releases/$($release.id)/assets?name=$zipName"
Invoke-RestMethod -Method Post -Uri $uploadUrl -Headers $headers -InFile $zip -ContentType "application/zip" | Out-Null
Write-Host "Uploaded $zipName. Installed apps will offer the update on next launch." -ForegroundColor Green
