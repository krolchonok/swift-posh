Set-StrictMode -Version Latest

function global:Import-SwiftPoshModules {
    [CmdletBinding()]
    param()

    . "$PSScriptRoot\core\State.ps1"
    . "$PSScriptRoot\core\Prompt.ps1"
    . "$PSScriptRoot\core\Updates.ps1"
    . "$PSScriptRoot\core\Aliases.ps1"
    . "$PSScriptRoot\core\Phrases.ps1"
    . "$PSScriptRoot\core\ThemeLibrary.ps1"
    . "$PSScriptRoot\core\Commands.ps1"
    . "$PSScriptRoot\core\Utilities.ps1"
    . "$PSScriptRoot\segments\Status.ps1"
    . "$PSScriptRoot\segments\Path.ps1"
    . "$PSScriptRoot\segments\Git.ps1"
    . "$PSScriptRoot\themes\Minimal.ps1"
}

Import-SwiftPoshModules

function global:Initialize-SwiftPosh {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = "$PSScriptRoot\config.psd1"
    )

    $script:SwiftPoshConfig = Get-SwiftPoshConfig -ConfigPath $ConfigPath
    $script:SwiftPoshTheme = Get-SwiftPoshTheme -Name $script:SwiftPoshConfig.Theme

    Set-Item -Path Function:\prompt -Value {
        New-SwiftPoshPrompt
    }

    Import-SwiftPoshAliases
    Import-SwiftPoshPhrases
    Invoke-SwiftPoshPowerShellUpdateCheck -Config $script:SwiftPoshConfig
    Invoke-SwiftPoshRepoAutoUpdate -ProjectRoot (Split-Path -Path $PSScriptRoot -Parent)
}
