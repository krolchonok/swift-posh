Set-StrictMode -Version Latest

if (-not (Get-Variable -Name SwiftPoshState -Scope Script -ErrorAction SilentlyContinue)) {
    $script:SwiftPoshState = @{
        RepoCache = @{}
        GitCache  = @{}
    }
}

function global:Get-SwiftPoshConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Swift Posh config not found: $ConfigPath"
    }

    Import-PowerShellDataFile -LiteralPath $ConfigPath
}

function global:Get-SwiftPoshTheme {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $theme = Get-Command -Name "Get-SwiftPoshTheme$Name" -CommandType Function -ErrorAction SilentlyContinue
    if (-not $theme) {
        throw "Swift Posh theme not found: $Name"
    }

    & $theme.Name
}

function global:Join-SwiftPoshPath {
    param(
        [string[]]$Parts
    )

    [System.IO.Path]::GetFullPath(([System.IO.Path]::Combine($Parts)))
}

function global:Find-SwiftPoshRepositoryRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StartPath,
        [int]$MaxDepth = 6
    )

    $normalized = [System.IO.Path]::GetFullPath($StartPath)
    if ($script:SwiftPoshState.RepoCache.ContainsKey($normalized)) {
        return $script:SwiftPoshState.RepoCache[$normalized]
    }

    $current = $normalized
    $depth = 0

    while ($null -ne $current -and $depth -le $MaxDepth) {
        if (Test-Path -LiteralPath (Join-Path $current '.git')) {
            $script:SwiftPoshState.RepoCache[$normalized] = $current
            return $current
        }

        $parent = Split-Path -Path $current -Parent
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) {
            break
        }

        $current = $parent
        $depth++
    }

    $script:SwiftPoshState.RepoCache[$normalized] = $null
    return $null
}

function global:Resolve-SwiftPoshGitDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot
    )

    $gitPath = Join-Path $RepositoryRoot '.git'

    if (Test-Path -LiteralPath $gitPath -PathType Container) {
        return $gitPath
    }

    if (Test-Path -LiteralPath $gitPath -PathType Leaf) {
        $content = Get-Content -LiteralPath $gitPath -TotalCount 1 -ErrorAction SilentlyContinue
        if ($content -match '^gitdir:\s*(.+)$') {
            $gitDir = $Matches[1].Trim()
            if ([System.IO.Path]::IsPathRooted($gitDir)) {
                return $gitDir
            }

            return Join-SwiftPoshPath -Parts @($RepositoryRoot, $gitDir)
        }
    }

    return $null
}

function global:Get-SwiftPoshAnsi {
    [CmdletBinding()]
    param(
        [string]$Foreground
    )

    if (-not $PSStyle) {
        return @{ Prefix = ''; Suffix = '' }
    }

    $color = $PSStyle.Foreground.$Foreground
    if (-not $color) {
        $color = ''
    }

    @{
        Prefix = $color
        Suffix = $PSStyle.Reset
    }
}
