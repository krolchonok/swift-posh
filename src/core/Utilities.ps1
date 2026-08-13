Set-StrictMode -Version Latest

# Create directory and immediately set location into it
function global:New-DirectoryAndSetLocation {
    [CmdletBinding()]
    [Alias('take', 'mkcd')]
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-Error 'Path cannot be empty.'
        return
    }

    $newItem = New-Item -ItemType Directory -Path $Path -Force
    if ($newItem) {
        Set-Location -Path $newItem.FullName
    }
}

# Git clone and immediately set location into cloned repository
function global:Invoke-GitCloneAndSetLocation {
    [CmdletBinding()]
    [Alias('gclone', 'gclcd')]
    param(
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Arguments
    )

    if (-not $Arguments -or $Arguments.Count -eq 0) {
        Write-Host 'Usage: gclone <repo-url> [target-dir] [git-options...]' -ForegroundColor Yellow
        return
    }

    $url = $null
    foreach ($arg in $Arguments) {
        if ($arg -match '^(https?://|git@|ssh://|git://)') {
            $url = $arg
            break
        }
    }

    if (-not $url) {
        git clone @Arguments
        return
    }

    $lastArg = $Arguments[-1]
    $targetDir = $null
    if ($lastArg -ne $url -and -not $lastArg.StartsWith('-')) {
        $targetDir = $lastArg
    } else {
        $leaf = ($url -replace '\.git$', '').Split('/:\')[-1]
        $targetDir = $leaf
    }

    git clone @Arguments
    if ($LASTEXITCODE -eq 0 -and $targetDir -and (Test-Path -LiteralPath $targetDir)) {
        Set-Location -Path $targetDir
    }
}

# Extract archives (.zip, .tar.gz, .tgz, .tar, .gz, .7z, .rar) automatically
function global:Expand-ArchiveAuto {
    [CmdletBinding()]
    [Alias('extract', 'x')]
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$Path,
        [Parameter(Position=1)]
        [string]$DestinationPath
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Error "File not found: $Path"
        return
    }

    $item = Get-Item -LiteralPath $Path
    $ext = $item.Extension.ToLower()
    $name = $item.Name.ToLower()

    if (-not $DestinationPath) {
        $DestinationPath = (Get-Location).Path
    }

    if ($ext -eq '.zip') {
        Expand-Archive -LiteralPath $item.FullName -DestinationPath $DestinationPath -Force
    } elseif ($name.EndsWith('.tar.gz') -or $name.EndsWith('.tgz') -or $ext -eq '.tar' -or $ext -eq '.gz' -or $name.EndsWith('.tar.bz2')) {
        if (Get-Command tar.exe -ErrorAction SilentlyContinue) {
            tar.exe -xvf $item.FullName -C $DestinationPath
        } else {
            Write-Error "tar.exe not found on system to extract $Path"
        }
    } elseif ($ext -eq '.7z' -or $ext -eq '.rar') {
        if (Get-Command 7z.exe -ErrorAction SilentlyContinue) {
            & 7z.exe x $item.FullName "-o$DestinationPath" -y
        } else {
            Write-Error "7z.exe not found on system to extract $Path"
        }
    } else {
        Write-Error "Unsupported archive format: $Path"
    }
}
