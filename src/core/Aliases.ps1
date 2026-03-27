Set-StrictMode -Version Latest

function global:Get-SwiftPoshHomeDirectory {
    $homeDir = Join-Path $HOME '.swift-posh'
    if (-not (Test-Path -LiteralPath $homeDir)) {
        New-Item -ItemType Directory -Path $homeDir -Force | Out-Null
    }

    return $homeDir
}

function global:Get-SwiftPoshAliasConfigPath {
    return (Join-Path (Get-SwiftPoshHomeDirectory) 'aliases.json')
}

function global:Read-SwiftPoshAliasConfig {
    $path = Get-SwiftPoshAliasConfigPath
    if (-not (Test-Path -LiteralPath $path)) {
        return @()
    }

    $raw = Get-Content -LiteralPath $path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @()
    }

    $parsed = ConvertFrom-Json -InputObject $raw -Depth 10
    if ($parsed -is [System.Collections.IEnumerable] -and -not ($parsed -is [string])) {
        return @($parsed)
    }

    return @($parsed)
}

function global:Save-SwiftPoshAliasConfig {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Aliases
    )

    $path = Get-SwiftPoshAliasConfigPath
    $json = if ($Aliases.Count -eq 0) {
        '[]'
    } else {
        $Aliases | Sort-Object Name | ConvertTo-Json -Depth 10
    }
    Set-Content -LiteralPath $path -Value $json
}

function global:Set-SwiftPoshAliasBinding {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$Value
    )

    $command = Get-Command $Value -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Command '$Value' was not found."
    }

    if (Test-Path -LiteralPath ("Alias:\{0}" -f $Name)) {
        Remove-Item -LiteralPath ("Alias:\{0}" -f $Name) -Force
    }

    Set-Alias -Name $Name -Value $Value -Scope Global -Option AllScope
}

function global:Import-SwiftPoshAliases {
    $aliases = @(Read-SwiftPoshAliasConfig)
    foreach ($entry in $aliases) {
        if (-not $entry.Name -or -not $entry.Value) {
            continue
        }

        try {
            Set-SwiftPoshAliasBinding -Name ([string]$entry.Name) -Value ([string]$entry.Value)
        } catch {
            Write-Warning ("swift-posh alias skipped: {0} -> {1}. {2}" -f $entry.Name, $entry.Value, $_.Exception.Message)
        }
    }
}
