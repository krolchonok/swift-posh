Set-StrictMode -Version Latest

$script:SwiftPoshOhMyPoshThemesApi = 'https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/contents/themes?ref=main'

function global:Get-SwiftPoshThemeLibraryRoot {
    $root = Join-Path (Get-SwiftPoshHomeDirectory) 'themes'
    if (-not (Test-Path -LiteralPath $root)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }

    return $root
}

function global:Get-SwiftPoshOhMyPoshThemeDirectory {
    $dir = Join-Path (Get-SwiftPoshThemeLibraryRoot) 'oh-my-posh'
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    return $dir
}

function global:Get-SwiftPoshOhMyPoshThemeIndex {
    $headers = @{ 'User-Agent' = 'swift-posh' }
    $items = Invoke-RestMethod -Uri $script:SwiftPoshOhMyPoshThemesApi -Headers $headers

    @($items | Where-Object {
        $_.type -eq 'file' -and $_.name -match '\.omp\.(json|ya?ml)$'
    } | Sort-Object name | ForEach-Object {
        [pscustomobject]@{
            Name        = [string]$_.name
            DownloadUrl = [string](@($_.download_url) | Select-Object -First 1)
            HtmlUrl     = [string](@($_.html_url) | Select-Object -First 1)
        }
    })
}

function global:Get-SwiftPoshInstalledThemeLibrary {
    $dir = Get-SwiftPoshOhMyPoshThemeDirectory
    @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object Name, FullName, Length)
}

function global:Install-SwiftPoshThemeLibrary {
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    $dir = Get-SwiftPoshOhMyPoshThemeDirectory
    $themes = @(Get-SwiftPoshOhMyPoshThemeIndex)
    $downloaded = 0
    $skipped = 0

    foreach ($theme in $themes) {
        $target = Join-Path $dir $theme.Name
        if ((-not $Force) -and (Test-Path -LiteralPath $target)) {
            $skipped++
            continue
        }

        if ([string]::IsNullOrWhiteSpace($theme.DownloadUrl)) {
            throw ("Theme '{0}' does not have a downloadable URL." -f $theme.Name)
        }

        Invoke-WebRequest -Uri $theme.DownloadUrl -OutFile $target
        $downloaded++
    }

    Write-Host ("Installed official Oh My Posh theme library to {0}" -f $dir)
    Write-Host ("Downloaded: {0}" -f $downloaded)
    Write-Host ("Skipped: {0}" -f $skipped)
}

function global:Format-SwiftPoshThemeLibrary {
    [CmdletBinding()]
    param()

    $items = @(Get-SwiftPoshInstalledThemeLibrary)
    if (-not $items.Count) {
        return 'No external themes installed.'
    }

    return (($items | ForEach-Object { $_.Name }) -join [Environment]::NewLine)
}
