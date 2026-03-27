Set-StrictMode -Version Latest

function global:Get-SwiftPoshSegmentGit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Context
    )

    if (-not $Context.Config.Git.Enabled) {
        return $null
    }

    $repoRoot = Find-SwiftPoshRepositoryRoot -StartPath $Context.Location -MaxDepth $Context.Config.Git.MaxDepth
    if (-not $repoRoot) {
        return $null
    }

    $gitDir = Resolve-SwiftPoshGitDirectory -RepositoryRoot $repoRoot
    if (-not $gitDir) {
        return $null
    }

    $headPath = Join-Path $gitDir 'HEAD'
    if (-not (Test-Path -LiteralPath $headPath)) {
        return $null
    }

    $headInfo = Get-Item -LiteralPath $headPath
    $cacheKey = $repoRoot
    $cached = $script:SwiftPoshState.GitCache[$cacheKey]

    if ($cached -and $cached.LastWriteTimeUtc -eq $headInfo.LastWriteTimeUtc) {
        return $cached.Segment
    }

    $head = Get-Content -LiteralPath $headPath -TotalCount 1 -ErrorAction SilentlyContinue
    if (-not $head) {
        return $null
    }

    $branch = if ($head -match '^ref:\s+refs/heads/(.+)$') {
        $Matches[1]
    } else {
        $head.Substring(0, [Math]::Min(7, $head.Length))
    }

    $segment = @{
        Text       = "git:$branch"
        Foreground = 'BrightYellow'
    }

    $script:SwiftPoshState.GitCache[$cacheKey] = @{
        LastWriteTimeUtc = $headInfo.LastWriteTimeUtc
        Segment          = $segment
    }

    return $segment
}
