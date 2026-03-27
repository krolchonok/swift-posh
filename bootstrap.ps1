[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $HOME '.swift-posh\repo'),
    [string]$RepoOwner = 'krolchonok',
    [string]$RepoName = 'swift-posh',
    [string]$Branch = 'main',
    [switch]$Menu,
    [switch]$All
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$zipUrl = "https://github.com/$RepoOwner/$RepoName/archive/refs/heads/$Branch.zip"
$tempRoot = Join-Path $env:TEMP 'swift-posh-bootstrap'
$zipPath = Join-Path $tempRoot "$RepoName-$Branch.zip"
$extractPath = Join-Path $tempRoot "$RepoName-$Branch"

if (-not (Test-Path -LiteralPath $tempRoot)) {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
}

if (Test-Path -LiteralPath $extractPath) {
    Remove-Item -LiteralPath $extractPath -Recurse -Force
}

Write-Host ("Downloading {0}/{1} ({2})..." -f $RepoOwner, $RepoName, $Branch)
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath

Write-Host 'Extracting archive...'
Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

$sourceRoot = Join-Path $extractPath "$RepoName-$Branch"
if (-not (Test-Path -LiteralPath $sourceRoot)) {
    throw "Extracted repository root was not found: $sourceRoot"
}

$installParent = Split-Path -Path $InstallRoot -Parent
if (-not (Test-Path -LiteralPath $installParent)) {
    New-Item -ItemType Directory -Path $installParent -Force | Out-Null
}

if (Test-Path -LiteralPath $InstallRoot) {
    Remove-Item -LiteralPath $InstallRoot -Recurse -Force
}

Write-Host ("Installing to {0}" -f $InstallRoot)
Move-Item -LiteralPath $sourceRoot -Destination $InstallRoot

$installerPath = Join-Path $InstallRoot 'install.ps1'
if (-not (Test-Path -LiteralPath $installerPath)) {
    throw "Installer was not found: $installerPath"
}

if ($Menu) {
    & $installerPath -Menu
} elseif ($All) {
    & $installerPath -All
} else {
    & $installerPath -Menu
}
