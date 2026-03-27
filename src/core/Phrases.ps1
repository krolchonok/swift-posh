Set-StrictMode -Version Latest

function global:Get-SwiftPoshPhraseConfigPath {
    return (Join-Path (Get-SwiftPoshHomeDirectory) 'phrases.json')
}

function global:Read-SwiftPoshPhraseConfig {
    $path = Get-SwiftPoshPhraseConfigPath
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

function global:Save-SwiftPoshPhraseConfig {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Phrases
    )

    $path = Get-SwiftPoshPhraseConfigPath
    $json = if ($Phrases.Count -eq 0) {
        '[]'
    } else {
        $Phrases | Sort-Object Name | ConvertTo-Json -Depth 10
    }

    Set-Content -LiteralPath $path -Value $json
}

function global:Invoke-SwiftPoshPhraseValue {
    param(
        [Parameter(Mandatory)]
        [string]$Value,
        [string[]]$RemainingArguments
    )

    $escapedArguments = @($RemainingArguments | ForEach-Object {
        "'" + ($_ -replace "'", "''") + "'"
    })

    $commandLine = if ($escapedArguments.Count -gt 0) {
        "{0} {1}" -f $Value, ($escapedArguments -join ' ')
    } else {
        $Value
    }

    Invoke-Expression $commandLine
}

function global:Register-SwiftPoshPhraseDispatcher {
    param(
        [Parameter(Mandatory)]
        [string]$Head
    )

    if (-not (Get-Variable -Name SwiftPoshPhraseFallbacks -Scope Global -ErrorAction SilentlyContinue)) {
        $global:SwiftPoshPhraseFallbacks = @{}
    }

    if (-not (Get-Variable -Name SwiftPoshPhraseDispatch -Scope Global -ErrorAction SilentlyContinue)) {
        $global:SwiftPoshPhraseDispatch = @{}
    }

    if (-not $global:SwiftPoshPhraseFallbacks.ContainsKey($Head)) {
        $fallback = Get-Command $Head -ErrorAction SilentlyContinue | Where-Object {
            $_.CommandType -ne 'Function' -or $_.Name -ne $Head
        } | Select-Object -First 1

        $global:SwiftPoshPhraseFallbacks[$Head] = $fallback
    }

    Set-Item -Path ("Function:\global:{0}" -f $Head) -Value {
        param([Parameter(ValueFromRemainingArguments = $true)][object[]]$Arguments)

        $head = $MyInvocation.MyCommand.Name
        $entries = @($global:SwiftPoshPhraseDispatch[$head] | Sort-Object {
            -(@($_.Tokens).Count)
        })
        $argumentStrings = @($Arguments | ForEach-Object { [string]$_ })
        $inputPhrase = if ($argumentStrings.Count -gt 0) {
            "{0} {1}" -f $head, ($argumentStrings -join ' ')
        } else {
            $head
        }

        foreach ($entry in $entries) {
            $tailTokens = if (@($entry.Tokens).Count -gt 1) {
                @($entry.Tokens[1..(@($entry.Tokens).Count - 1)])
            } else {
                @()
            }
            if (@($argumentStrings).Count -lt @($tailTokens).Count) {
                continue
            }

            $phraseName = [string]$entry.Name
            if ($inputPhrase -ne $phraseName -and -not $inputPhrase.StartsWith("$phraseName ")) {
                continue
            }

            $remaining = if (@($argumentStrings).Count -gt @($tailTokens).Count) {
                @($argumentStrings[@($tailTokens).Count..(@($argumentStrings).Count - 1)])
            } else {
                @()
            }

            Invoke-SwiftPoshPhraseValue -Value ([string]$entry.Value) -RemainingArguments ([string[]]@($remaining))
            return
        }

        $fallback = $global:SwiftPoshPhraseFallbacks[$head]
        if ($fallback) {
            & $fallback @Arguments
            return
        }

        throw ("Unknown command phrase: {0} {1}" -f $head, ($Arguments -join ' '))
    }
}

function global:Import-SwiftPoshPhrases {
    $phrases = @(Read-SwiftPoshPhraseConfig)
    $grouped = @{}

    foreach ($entry in $phrases) {
        if (-not $entry.Name -or -not $entry.Value) {
            continue
        }

        $tokens = @(([string]$entry.Name).Trim().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries))
        if ($tokens.Count -lt 2) {
            continue
        }

        $head = $tokens[0]
        if (-not $grouped.ContainsKey($head)) {
            $grouped[$head] = @()
        }

        $grouped[$head] += [pscustomobject]@{
            Name   = [string]$entry.Name
            Value  = [string]$entry.Value
            Tokens = $tokens
        }
    }

    $global:SwiftPoshPhraseDispatch = $grouped
    foreach ($head in $grouped.Keys) {
        Register-SwiftPoshPhraseDispatcher -Head $head
    }
}

function global:Add-SwiftPoshPhrase {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$Value
    )

    $Name = $Name.Trim()
    $Value = $Value.Trim()

    if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Value)) {
        throw 'Phrase name and value cannot be empty.'
    }

    $tokens = @($Name.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries))
    if ($tokens.Count -lt 2) {
        throw 'Phrase command must contain a space, for example: ip a'
    }

    $phrases = @(Read-SwiftPoshPhraseConfig | Where-Object { $_.Name -ne $Name })
    $phrases += [pscustomobject]@{
        Name  = $Name
        Value = $Value
    }

    Save-SwiftPoshPhraseConfig -Phrases $phrases
    Import-SwiftPoshPhrases
    Write-Host ("Phrase saved: {0} -> {1}" -f $Name, $Value)
    Write-Host ("Config: {0}" -f (Get-SwiftPoshPhraseConfigPath))
}
