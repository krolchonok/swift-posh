@{
    Theme = 'Minimal'
    PromptSymbol = '>'
    Segments = @(
        'Status'
        'Path'
        'Git'
    )
    Git = @{
        Enabled = $true
        MaxDepth = 6
    }
    UpdateCheck = @{
        Enabled = $true
        CacheHours = 24
        TimeoutSeconds = 2
        PromptForUpgrade = $true
    }
}
