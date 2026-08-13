Set-StrictMode -Version Latest

function global:Open-SwiftPoshSetup {
    [CmdletBinding()]
    param()

    & "$PSScriptRoot\..\..\install.ps1" -Menu
}

function global:Menu {
    [CmdletBinding()]
    param()

    Open-SwiftPoshSetup
}

function global:Install-SwiftPoshFont {
    [CmdletBinding()]
    param()

    & "$PSScriptRoot\..\..\install.ps1" -InstallFontOnly
}

function global:Select-SwiftPoshFont {
    [CmdletBinding()]
    param()

    & "$PSScriptRoot\..\..\install.ps1" -InstallFontOnly
}

function global:Get-SwiftPoshFontStatus {
    [CmdletBinding()]
    param()

    & "$PSScriptRoot\..\..\install.ps1" -ShowFontStatusOnly
}

function global:Restart-SwiftPoshTerminal {
    [CmdletBinding()]
    param()

    $wt = Get-Command wt.exe -ErrorAction SilentlyContinue
    if (-not $wt) {
        $wt = Get-Command wt -ErrorAction SilentlyContinue
    }

    if (-not $wt) {
        throw 'Windows Terminal is not available.'
    }

    Start-Process -FilePath $wt.Source | Out-Null
    Get-Process -Name WindowsTerminal -ErrorAction SilentlyContinue | Stop-Process -Force
}

function global:Check-SwiftPoshUpdates {
    [CmdletBinding()]
    param()

    if (-not (Get-Variable -Name SwiftPoshConfig -Scope Script -ErrorAction SilentlyContinue)) {
        $script:SwiftPoshConfig = Get-SwiftPoshConfig -ConfigPath "$PSScriptRoot\..\config.psd1"
    }

    Invoke-SwiftPoshPowerShellUpdateCheck -Config $script:SwiftPoshConfig -Force
}

function global:Reload-SwiftPosh {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = "$PSScriptRoot\..\config.psd1"
    )

    . "$PSScriptRoot\..\swift-posh.ps1"
    Initialize-SwiftPosh -ConfigPath $ConfigPath
    Write-Host 'swift-posh reloaded'
}

function global:Update-SwiftPosh {
    [CmdletBinding()]
    [Alias('swift-posh-update', 'update-posh')]
    param(
        [switch]$ApplySetup,
        [switch]$Force,
        [string]$ConfigPath = "$PSScriptRoot\..\config.psd1"
    )

    $projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $gitDir = Join-Path $projectRoot '.git'

    if (Test-Path -LiteralPath $gitDir) {
        $git = Get-Command git -ErrorAction SilentlyContinue
        if (-not $git) {
            throw 'git is not available, cannot update swift-posh repository.'
        }

        Write-Host '[swift-posh] Fetching latest updates from Git...' -ForegroundColor Cyan
        & $git.Source -C $projectRoot pull --ff-only
    } else {
        Write-Host '[swift-posh] Repository is not a git clone. Reloading local files only.' -ForegroundColor Yellow
    }

    if ($Force) {
        $lastCheckPath = Join-Path (Get-SwiftPoshHomeDirectory) 'last_check'
        if (Test-Path -LiteralPath $lastCheckPath) {
            Remove-Item -LiteralPath $lastCheckPath -Force
        }
        if ($script:SwiftPoshConfig) {
            Invoke-SwiftPoshPowerShellUpdateCheck -Config $script:SwiftPoshConfig -Force
        }
    }

    if ($ApplySetup) {
        & "$projectRoot\install.ps1" -All
    }

    Reload-SwiftPosh -ConfigPath $ConfigPath
    Write-Host '[swift-posh] Environment updated and reloaded successfully!' -ForegroundColor Green
}

function global:Get-SwiftPoshAliases {
    [CmdletBinding()]
    param()

    @(Read-SwiftPoshAliasConfig) | Select-Object Name, Value
}

function global:Format-SwiftPoshAliases {
    [CmdletBinding()]
    param()

    $aliases = @(Get-SwiftPoshAliases)
    if (-not $aliases.Count) {
        return 'No aliases configured.'
    }

    return (($aliases | Sort-Object Name | ForEach-Object {
        "{0} -> {1}" -f $_.Name, $_.Value
    }) -join [Environment]::NewLine)
}

function global:Add-SwiftPoshAlias {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$Value
    )

    $Name = $Name.Trim()
    $Value = $Value.Trim()

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw 'Alias name cannot be empty.'
    }

    if ($Name -match '\s') {
        throw 'Alias name cannot contain spaces.'
    }

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw 'Command cannot be empty.'
    }

    Set-SwiftPoshAliasBinding -Name $Name -Value $Value

    $aliases = @(Read-SwiftPoshAliasConfig | Where-Object { $_.Name -ne $Name })
    $aliases += [pscustomobject]@{
        Name  = $Name
        Value = $Value
    }

    Save-SwiftPoshAliasConfig -Aliases $aliases
    Write-Host ("Alias saved: {0} -> {1}" -f $Name, $Value)
    Write-Host ("Config: {0}" -f (Get-SwiftPoshAliasConfigPath))
}

function global:New-SwiftPoshAlias {
    [CmdletBinding()]
    param()

    $name = Read-Host 'Alias name'
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw 'Alias name cannot be empty.'
    }

    $value = Read-Host 'Command'
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw 'Command cannot be empty.'
    }

    Add-SwiftPoshAlias -Name $name.Trim() -Value $value.Trim()
}

function global:Remove-SwiftPoshAlias {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $aliases = @(Read-SwiftPoshAliasConfig)
    $remaining = @($aliases | Where-Object { $_.Name -ne $Name })
    if ($remaining.Count -eq $aliases.Count) {
        throw "Alias '$Name' was not found."
    }

    Save-SwiftPoshAliasConfig -Aliases $remaining

    if (Test-Path -LiteralPath ("Alias:\{0}" -f $Name)) {
        Remove-Item -LiteralPath ("Alias:\{0}" -f $Name) -Force
    }

    Write-Host ("Alias removed: {0}" -f $Name)
    Write-Host ("Config: {0}" -f (Get-SwiftPoshAliasConfigPath))
}

function global:Get-SwiftPoshPhrases {
    [CmdletBinding()]
    param()

    @(Read-SwiftPoshPhraseConfig) | Select-Object Name, Value
}

function global:Format-SwiftPoshPhrases {
    [CmdletBinding()]
    param()

    $phrases = @(Get-SwiftPoshPhrases)
    if (-not $phrases.Count) {
        return 'No phrase commands configured.'
    }

    return (($phrases | Sort-Object Name | ForEach-Object {
        "{0} -> {1}" -f $_.Name, $_.Value
    }) -join [Environment]::NewLine)
}

function global:Remove-SwiftPoshPhrase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $phrases = @(Read-SwiftPoshPhraseConfig)
    $remaining = @($phrases | Where-Object { $_.Name -ne $Name })
    if ($remaining.Count -eq $phrases.Count) {
        throw "Phrase '$Name' was not found."
    }

    Save-SwiftPoshPhraseConfig -Phrases $remaining
    Import-SwiftPoshPhrases
    Write-Host ("Phrase removed: {0}" -f $Name)
    Write-Host ("Config: {0}" -f (Get-SwiftPoshPhraseConfigPath))
}

function global:Get-SwiftPoshCommands {
    [CmdletBinding()]
    param()

    $items = @()
    $items += @(Get-SwiftPoshAliases | ForEach-Object {
        [pscustomobject]@{
            Type  = 'alias'
            Name  = $_.Name
            Value = $_.Value
        }
    })
    $items += @(Get-SwiftPoshPhrases | ForEach-Object {
        [pscustomobject]@{
            Type  = 'phrase'
            Name  = $_.Name
            Value = $_.Value
        }
    })

    @($items | Sort-Object Name)
}

function global:Format-SwiftPoshCommands {
    [CmdletBinding()]
    param()

    $items = @(Get-SwiftPoshCommands)
    if (-not $items.Count) {
        return 'No commands configured.'
    }

    return (($items | ForEach-Object {
        "[{0}] {1} -> {2}" -f $_.Type, $_.Name, $_.Value
    }) -join [Environment]::NewLine)
}

function global:Get-SwiftPoshThemeLibrary {
    [CmdletBinding()]
    param()

    Get-SwiftPoshInstalledThemeLibrary
}

function global:Add-SwiftPoshCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$Value
    )

    if ($Name -match '\s') {
        Add-SwiftPoshPhrase -Name $Name -Value $Value
    } else {
        Add-SwiftPoshAlias -Name $Name -Value $Value
    }
}

function global:New-SwiftPoshCommand {
    [CmdletBinding()]
    param()

    $name = Read-Host 'Command name'
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw 'Command name cannot be empty.'
    }

    $value = Read-Host 'Command'
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw 'Command cannot be empty.'
    }

    Add-SwiftPoshCommand -Name $name.Trim() -Value $value.Trim()
}

function global:Remove-SwiftPoshCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($Name -match '\s') {
        Remove-SwiftPoshPhrase -Name $Name
    } else {
        Remove-SwiftPoshAlias -Name $Name
    }
}
