Set-StrictMode -Version Latest

function global:New-SwiftPoshPrompt {
    [CmdletBinding()]
    param()

    $nativeExitCodeVariable = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
    $nativeExitCode = if ($nativeExitCodeVariable) { $nativeExitCodeVariable.Value } else { $null }

    $promptContext = @{
        Success        = $?
        NativeExitCode = $nativeExitCode
        Location       = (Get-Location).Path
        Config         = $script:SwiftPoshConfig
    }

    $segments = foreach ($segmentName in $script:SwiftPoshConfig.Segments) {
        $command = Get-Command -Name "Get-SwiftPoshSegment$segmentName" -CommandType Function -ErrorAction SilentlyContinue
        if (-not $command) {
            continue
        }

        & $command.Name -Context $promptContext
    }

    $renderedSegments = $segments | Where-Object { $_ } | ForEach-Object {
        Format-SwiftPoshSegment -Segment $_
    }

    $terminalPrefix = ''
    $currentLocation = $promptContext.Location
    if ($currentLocation) {
        $terminalPrefix += "`e]9;9;`"$currentLocation`"$([char]07)"
    }

    if ((Get-Variable -Name SwiftPoshUseCurrentDirectoryTitle -Scope Global -ErrorAction SilentlyContinue) -and $global:SwiftPoshUseCurrentDirectoryTitle) {
        $leaf = Split-Path -Path $currentLocation -Leaf
        if ([string]::IsNullOrWhiteSpace($leaf)) {
            $leaf = $currentLocation
        }

        try {
            $Host.UI.RawUI.WindowTitle = $leaf
        } catch {
        }

        $terminalPrefix += "`e]0;{0}{1}" -f $leaf, [char]7
    }

    $body = $script:SwiftPoshTheme.Render.Invoke($renderedSegments, $promptContext, $script:SwiftPoshConfig)
    return $terminalPrefix + $body
}

function global:Format-SwiftPoshSegment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Segment
    )

    $ansi = Get-SwiftPoshAnsi -Foreground $Segment.Foreground
    "$($ansi.Prefix)$($Segment.Text)$($ansi.Suffix)"
}
