Set-StrictMode -Version Latest

function global:Convert-SwiftPoshUtcDateTime {
    param(
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [datetime]) {
        return $Value.ToUniversalTime()
    }

    $text = [string]$Value
    $styles = [System.Globalization.DateTimeStyles]::RoundtripKind
    $culture = [System.Globalization.CultureInfo]::InvariantCulture

    $parsed = [datetime]::MinValue
    if ([datetime]::TryParse($text, $culture, $styles, [ref]$parsed)) {
        return $parsed.ToUniversalTime()
    }

    if ([datetime]::TryParse($text, [System.Globalization.CultureInfo]::CurrentCulture, [System.Globalization.DateTimeStyles]::AssumeLocal, [ref]$parsed)) {
        return $parsed.ToUniversalTime()
    }

    return $null
}

function global:Test-SwiftPoshInteractiveSession {
    try {
        [void]$Host.UI.RawUI.WindowTitle
        return [Environment]::UserInteractive
    } catch {
        return $false
    }
}

function global:Get-SwiftPoshUpdateCachePath {
    $cacheRoot = Join-Path $env:LOCALAPPDATA 'swift-posh\cache'
    if (-not (Test-Path -LiteralPath $cacheRoot)) {
        New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null
    }

    Join-Path $cacheRoot 'powershell-release.json'
}

function global:Read-SwiftPoshUpdateCache {
    $cachePath = Get-SwiftPoshUpdateCachePath
    if (-not (Test-Path -LiteralPath $cachePath)) {
        return $null
    }

    try {
        Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json -Depth 10
    } catch {
        return $null
    }
}

function global:Write-SwiftPoshUpdateCache {
    param(
        [Parameter(Mandatory)]
        [psobject]$Cache
    )

    $cachePath = Get-SwiftPoshUpdateCachePath
    $Cache | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $cachePath
}

function global:Get-SwiftPoshLatestPowerShellRelease {
    param(
        [Parameter(Mandatory)]
        [hashtable]$UpdateConfig
    )

    $cache = Read-SwiftPoshUpdateCache
    if ($cache) {
        $checkedAtUtc = Convert-SwiftPoshUtcDateTime -Value $cache.CheckedAtUtc
        if ($checkedAtUtc -and $checkedAtUtc.AddHours($UpdateConfig.CacheHours) -gt [datetime]::UtcNow) {
            return $cache
        }
    }

    $progressPreference = $global:ProgressPreference
    $global:ProgressPreference = 'SilentlyContinue'
    try {
        $response = Invoke-RestMethod `
            -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' `
            -Headers @{ 'User-Agent' = 'swift-posh' } `
            -TimeoutSec $UpdateConfig.TimeoutSeconds

        $latestVersion = ([string]$response.tag_name).TrimStart('v')
        if (-not $latestVersion) {
            return $cache
        }

        $newCache = [pscustomobject]@{
            CheckedAtUtc      = [datetime]::UtcNow.ToString('o')
            LatestVersion     = $latestVersion
            ReleaseUrl        = [string]$response.html_url
            LastPromptedAtUtc = if ($cache) { $cache.LastPromptedAtUtc } else { $null }
            PromptedVersion   = if ($cache) { $cache.PromptedVersion } else { $null }
        }

        Write-SwiftPoshUpdateCache -Cache $newCache
        return $newCache
    } catch {
        return $cache
    } finally {
        $global:ProgressPreference = $progressPreference
    }
}

function global:Test-SwiftPoshShouldPromptUpgrade {
    param(
        [Parameter(Mandatory)]
        [psobject]$Cache
    )

    if (-not $Cache.LastPromptedAtUtc -or -not $Cache.PromptedVersion) {
        return $true
    }

    if ($Cache.PromptedVersion -ne $Cache.LatestVersion) {
        return $true
    }

    $lastPromptedAtUtc = Convert-SwiftPoshUtcDateTime -Value $Cache.LastPromptedAtUtc
    if (-not $lastPromptedAtUtc) {
        return $true
    }

    return $lastPromptedAtUtc.AddHours(24) -le [datetime]::UtcNow
}

function global:Save-SwiftPoshPromptedUpgrade {
    param(
        [Parameter(Mandatory)]
        [psobject]$Cache
    )

    $Cache | Add-Member -NotePropertyName LastPromptedAtUtc -NotePropertyValue ([datetime]::UtcNow.ToString('o')) -Force
    $Cache | Add-Member -NotePropertyName PromptedVersion -NotePropertyValue $Cache.LatestVersion -Force
    Write-SwiftPoshUpdateCache -Cache $Cache
}

function global:Invoke-SwiftPoshPowerShellUpdateCheck {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        [switch]$Force
    )

    if (-not $Config.UpdateCheck.Enabled) {
        return
    }

    $cache = Get-SwiftPoshLatestPowerShellRelease -UpdateConfig $Config.UpdateCheck
    if (-not $cache -or -not $cache.LatestVersion) {
        return
    }

    $currentVersion = [version]$PSVersionTable.PSVersion.ToString()
    $latestVersion = [version]$cache.LatestVersion
    if ($latestVersion -le $currentVersion) {
        return
    }

    if (-not $Force -and -not (Test-SwiftPoshShouldPromptUpgrade -Cache $cache)) {
        return
    }

    Write-Host ''
    Write-Host ("PowerShell {0} detected. A newer stable release is available: {1}" -f $currentVersion, $latestVersion) -ForegroundColor Yellow
    Write-Host ("Release page: {0}" -f $(if ($cache.ReleaseUrl) { $cache.ReleaseUrl } else { 'https://aka.ms/PowerShell-Release' })) -ForegroundColor DarkYellow

    Save-SwiftPoshPromptedUpgrade -Cache $cache

    if (-not $Config.UpdateCheck.PromptForUpgrade -or -not (Test-SwiftPoshInteractiveSession)) {
        return
    }

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Host 'winget not found. Update PowerShell manually.' -ForegroundColor DarkYellow
        return
    }

    $answer = Read-Host 'Run winget upgrade --id Microsoft.PowerShell now? [y/N]'
    if ($answer -notin @('y', 'Y', 'yes', 'YES', 'Yes')) {
        return
    }

    & $winget.Source upgrade --id Microsoft.PowerShell --accept-source-agreements --accept-package-agreements
}

function global:Invoke-SwiftPoshRepoAutoUpdate {
    [CmdletBinding()]
    param(
        [string]$ProjectRoot
    )

    if (-not $ProjectRoot) {
        return
    }

    $gitDir = Join-Path $ProjectRoot '.git'
    if (-not (Test-Path -LiteralPath $gitDir)) {
        return
    }

    $lastCheckPath = Join-Path (Get-SwiftPoshHomeDirectory) 'last_check'
    if (Test-Path -LiteralPath $lastCheckPath) {
        try {
            $lastCheck = (Get-Content -LiteralPath $lastCheckPath -Raw).Trim()
            $parsedDate = [datetime]::MinValue
            if ([datetime]::TryParse($lastCheck, [ref]$parsedDate)) {
                if ($parsedDate.AddHours(6) -gt [datetime]::UtcNow) {
                    return
                }
            }
        } catch {}
    }

    Set-Content -LiteralPath $lastCheckPath -Value ([datetime]::UtcNow.ToString('o'))

    Start-Job -ScriptBlock {
        param($repoPath)
        git -C $repoPath fetch origin main 2>&1 | Out-Null
        git -C $repoPath reset --hard origin/main 2>&1 | Out-Null
    } -ArgumentList $ProjectRoot | Out-Null
}
