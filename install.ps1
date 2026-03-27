[CmdletBinding()]
param(
    [switch]$Menu,
    [switch]$All,
    [switch]$SkipProfile,
    [switch]$SkipTerminal,
    [switch]$InstallFontOnly,
    [switch]$ShowFontStatusOnly,
    [string]$FontPackageId,
    [string]$FontFace
)

Set-StrictMode -Version Latest

$script:SwiftPoshFontRepoBaseUrl = 'https://raw.githubusercontent.com/krolchonok/swift-posh-fonts/main/downloads'

function Get-WindowsTerminalSettingsPath {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

function Get-WindowsTerminalSettings {
    $settingsPath = Get-WindowsTerminalSettingsPath
    if (-not $settingsPath) {
        return $null
    }

    @{
        Path     = $settingsPath
        Settings = (Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json -Depth 100)
    }
}

function Get-AvailableNerdFonts {
    @(
        [pscustomobject]@{
            Name         = 'JetBrainsMono Nerd Font'
            PackageId    = 'DEVCOM.JetBrainsMonoNerdFont'
            Version      = ''
            FontFace     = 'JetBrainsMono Nerd Font'
            ReleaseAsset = 'JetBrainsMono.zip'
            InstallName  = 'JetBrainsMono'
        }
        [pscustomobject]@{
            Name         = 'FiraCode Nerd Font'
            PackageId    = $null
            Version      = ''
            FontFace     = 'FiraCode Nerd Font Mono'
            ReleaseAsset = 'FiraCode.tar.xz'
            InstallName  = 'FiraCode'
        }
        [pscustomobject]@{
            Name         = 'Hack Nerd Font'
            PackageId    = $null
            Version      = ''
            FontFace     = 'Hack'
            ReleaseAsset = 'Hack.tar.xz'
            InstallName  = 'Hack'
        }
        [pscustomobject]@{
            Name         = 'MesloLGM Nerd Font'
            PackageId    = $null
            Version      = ''
            FontFace     = 'MesloLGM Nerd Font Mono'
            ReleaseAsset = 'Meslo.tar.xz'
            InstallName  = 'Meslo'
        }
        [pscustomobject]@{
            Name         = 'CaskaydiaCove Nerd Font'
            PackageId    = $null
            Version      = ''
            FontFace     = 'CaskaydiaMono Nerd Font'
            ReleaseAsset = 'CascadiaCode.tar.xz'
            InstallName  = 'CascadiaCode'
        }
        [pscustomobject]@{
            Name         = 'GohuFont uni 11'
            PackageId    = $null
            Version      = ''
            FontFace     = 'GohuFont uni11 Nerd Font Mono'
            ReleaseAsset = 'GohuFontuni11NerdFontMono-Regular.ttf'
            InstallName  = 'GohuFontuni11'
            SourceUrl    = 'https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/Gohu/uni-11/GohuFontuni11NerdFontMono-Regular.ttf'
        }
        [pscustomobject]@{
            Name         = 'GohuFont uni 14'
            PackageId    = $null
            Version      = ''
            FontFace     = 'GohuFont uni14 Nerd Font Mono'
            ReleaseAsset = 'GohuFontuni14NerdFontMono-Regular.ttf'
            InstallName  = 'GohuFontuni14'
            SourceUrl    = 'https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/Gohu/uni-14/GohuFontuni14NerdFontMono-Regular.ttf'
        }
    )
}

function Get-FontSearchRoots {
    @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'),
        (Join-Path $env:WINDIR 'Fonts')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
}

function Test-IsAdministrator {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-FontFamilyNameFromFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    Add-Type -AssemblyName System.Drawing
    $collection = New-Object System.Drawing.Text.PrivateFontCollection
    try {
        $collection.AddFontFile($Path)
        return @($collection.Families | Select-Object -ExpandProperty Name)
    } finally {
        $collection.Dispose()
    }
}

function Get-FontRegistryDisplayName {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $familyName = @(Get-FontFamilyNameFromFile -Path $Path | Select-Object -First 1)
    if (-not $familyName) {
        return "{0} (TrueType)" -f ([System.IO.Path]::GetFileNameWithoutExtension($Path))
    }

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $style = ''
    if ($baseName -match '-(?<style>[^-]+)$') {
        $style = $Matches['style']
    }

    $styleMap = @{
        'Regular'    = 'Regular'
        'Bold'       = 'Bold'
        'Italic'     = 'Italic'
        'BoldItalic' = 'Bold Italic'
        'SemiBold'   = 'SemiBold'
        'Medium'     = 'Medium'
        'Light'      = 'Light'
        'Thin'       = 'Thin'
        'ExtraLight' = 'ExtraLight'
        'ExtraBold'  = 'ExtraBold'
        'Retina'     = 'Retina'
    }

    $styleText = if ($styleMap.ContainsKey($style)) { $styleMap[$style] } elseif ($style) { $style } else { '' }
    if ($styleText) {
        return "{0} {1} (TrueType)" -f $familyName[0], $styleText
    }

    return "{0} (TrueType)" -f $familyName[0]
}

function Register-FontWithWindows {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class SwiftPoshFontNative {
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int AddFontResourceEx(string lpszFilename, uint fl, IntPtr pdv);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd,
        uint Msg,
        IntPtr wParam,
        string lParam,
        uint fuFlags,
        uint uTimeout,
        out IntPtr lpdwResult
    );
}
'@ -ErrorAction SilentlyContinue

    [void][SwiftPoshFontNative]::AddFontResourceEx($Path, 0, [IntPtr]::Zero)
    $result = [IntPtr]::Zero
    [void][SwiftPoshFontNative]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [IntPtr]::Zero, $null, 0x0002, 1000, [ref]$result)
}

function Resolve-InstalledFontFace {
    param(
        [Parameter(Mandatory)]
        [string]$InstallName,
        [Parameter(Mandatory)]
        [string]$FallbackFontFace
    )

    $candidates = foreach ($root in @(Get-FontSearchRoots)) {
        Get-ChildItem -Path $root -File -ErrorAction SilentlyContinue | Where-Object {
            $_.BaseName -like "$InstallName*"
        }
    }

    if (-not $candidates) {
        return $FallbackFontFace
    }

    $familyNames = foreach ($file in $candidates) {
        try {
            Get-FontFamilyNameFromFile -Path $file.FullName
        } catch {
            continue
        }
    }

    $uniqueNames = @($familyNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    if (-not $uniqueNames.Count) {
        return $FallbackFontFace
    }

    $preferred = $uniqueNames | Where-Object { $_ -eq $FallbackFontFace } | Select-Object -First 1
    if ($preferred) {
        return $preferred
    }

    $monoPreferred = $uniqueNames | Where-Object { $_ -match 'Mono' } | Select-Object -First 1
    if ($monoPreferred) {
        return $monoPreferred
    }

    return ($uniqueNames | Select-Object -First 1)
}

function Test-NerdFontInstalled {
    param(
        [Parameter(Mandatory)]
        [string]$InstallName,
        [Parameter(Mandatory)]
        [string]$ExpectedFontFace
    )

    $resolvedFace = Resolve-InstalledFontFace -InstallName $InstallName -FallbackFontFace $ExpectedFontFace
    if ([string]::IsNullOrWhiteSpace($resolvedFace)) {
        return $false
    }

    Add-Type -AssemblyName System.Drawing
    $fonts = New-Object System.Drawing.Text.InstalledFontCollection
    return @($fonts.Families | Select-Object -ExpandProperty Name) -contains $resolvedFace
}

function Install-FontFiles {
    param(
        [Parameter(Mandatory)]
        [string]$FontDirectory,
        [string]$PreferredFamily
    )

    $fonts = @(Get-ChildItem -Path $FontDirectory -Recurse -File | Where-Object { $_.Extension -in @('.ttf', '.otf') })
    if (-not $fonts) {
        throw "No font files found in $FontDirectory"
    }

    if ($PreferredFamily) {
        $matchingFonts = @(
            $fonts | Where-Object {
                try {
                    @(Get-FontFamilyNameFromFile -Path $_.FullName) -contains $PreferredFamily
                } catch {
                    $false
                }
            }
        )

        if ($matchingFonts.Count) {
            $fonts = $matchingFonts
        }
    }

    $isAdmin = Test-IsAdministrator
    $destinationDir = if ($isAdmin) { Join-Path $env:WINDIR 'Fonts' } else { Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts' }
    if (-not (Test-Path -LiteralPath $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }

    $fontRegistryPath = if ($isAdmin) {
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    } else {
        'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    }

    foreach ($fontFile in $fonts) {
        $destination = Join-Path $destinationDir $fontFile.Name
        if (-not (Test-Path -LiteralPath $destination)) {
            Copy-Item -LiteralPath $fontFile.FullName -Destination $destination -Force
        }

        $registryName = Get-FontRegistryDisplayName -Path $destination
        $registryValue = if ($isAdmin) { $fontFile.Name } else { $destination }
        Set-ItemProperty -Path $fontRegistryPath -Name $registryName -Value $registryValue -Type String
        Register-FontWithWindows -Path $destination
    }
}

function Install-NerdFontFromRelease {
    param(
        [Parameter(Mandatory)]
        [string]$ReleaseAsset,
        [Parameter(Mandatory)]
        [string]$SelectedFontFace,
        [string]$SourceUrl
    )

    $downloadRoot = Join-Path $env:TEMP 'swift-posh-fonts'
    if (-not (Test-Path -LiteralPath $downloadRoot)) {
        New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null
    }

    $archivePath = Join-Path $downloadRoot $ReleaseAsset
    $extractPath = Join-Path $downloadRoot ([System.IO.Path]::GetFileNameWithoutExtension($ReleaseAsset))
    if (Test-Path -LiteralPath $extractPath) {
        Remove-Item -LiteralPath $extractPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null

    $primaryUri = "{0}/{1}" -f $script:SwiftPoshFontRepoBaseUrl, $ReleaseAsset
    $fallbackUri = if ($SourceUrl) { $SourceUrl } else { "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$ReleaseAsset" }
    if (Test-Path -LiteralPath $archivePath) {
        Write-Host ("Using cached archive: {0}" -f $archivePath)
    } else {
        Write-Host ("Downloading archive: {0}" -f $ReleaseAsset)
        try {
            Invoke-WebRequest -Uri $primaryUri -OutFile $archivePath
        } catch {
            Write-Host ("Primary font repo download failed, falling back to upstream: {0}" -f $ReleaseAsset)
            Invoke-WebRequest -Uri $fallbackUri -OutFile $archivePath
        }
    }

    if ($ReleaseAsset.EndsWith('.ttf') -or $ReleaseAsset.EndsWith('.otf')) {
        Copy-Item -LiteralPath $archivePath -Destination (Join-Path $extractPath (Split-Path -Path $archivePath -Leaf)) -Force
    } elseif ($ReleaseAsset.EndsWith('.zip')) {
        Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath -Force
    } elseif ($ReleaseAsset.EndsWith('.tar.xz')) {
        $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
        if (-not $tar) {
            throw 'tar.exe is required to extract .tar.xz archives'
        }

        & $tar.Source -xJf $archivePath -C $extractPath
        if ($LASTEXITCODE -ne 0) {
            throw "tar extraction failed for $ReleaseAsset with exit code $LASTEXITCODE"
        }
    } else {
        throw "Unsupported archive format: $ReleaseAsset"
    }

    if (-not (Get-ChildItem -Path $extractPath -Recurse -File | Where-Object { $_.Extension -in @('.ttf', '.otf') } | Select-Object -First 1)) {
        throw "Archive extracted but no .ttf or .otf files were found in $extractPath"
    }

    Install-FontFiles -FontDirectory $extractPath -PreferredFamily $SelectedFontFace
    Write-Host ("Applied: {0} installation from Nerd Fonts release" -f $SelectedFontFace)
}

function Get-WindowsTerminalCurrentFontFace {
    $terminal = Get-WindowsTerminalSettings
    if (-not $terminal) {
        return $null
    }

    $settings = $terminal.Settings
    $defaultProfileGuid = [string]$settings.defaultProfile
    if ($defaultProfileGuid) {
        $defaultProfile = $settings.profiles.list | Where-Object { $_.guid -eq $defaultProfileGuid } | Select-Object -First 1
        if ($defaultProfile -and $defaultProfile.PSObject.Properties['font'] -and $defaultProfile.font.PSObject.Properties['face']) {
            return [string]$defaultProfile.font.face
        }
    }

    if ($settings.profiles.defaults.PSObject.Properties['font'] -and $settings.profiles.defaults.font.PSObject.Properties['face']) {
        return [string]$settings.profiles.defaults.font.face
    }

    return $null
}

function Set-TerminalKeybinding {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IList]$Bindings,
        [Parameter(Mandatory)]
        [string]$Id,
        [Parameter(Mandatory)]
        [string]$Keys
    )

    $existing = $Bindings | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    if ($existing) {
        $existing.keys = $Keys
        return
    }

    $Bindings.Add([pscustomobject]@{
        id   = $Id
        keys = $Keys
    }) | Out-Null
}

function Save-WindowsTerminalSettings {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [psobject]$Settings
    )

    $json = $Settings | ConvertTo-Json -Depth 100
    Set-Content -LiteralPath $Path -Value $json
}

function Restart-WindowsTerminalProcess {
    $wt = Get-Command wt.exe -ErrorAction SilentlyContinue
    if (-not $wt) {
        $wt = Get-Command wt -ErrorAction SilentlyContinue
    }

    if ($wt) {
        Start-Process -FilePath $wt.Source | Out-Null
    }

    Get-Process -Name WindowsTerminal -ErrorAction SilentlyContinue | Stop-Process -Force
}

function Confirm-WindowsTerminalRestart {
    if (-not (Test-IsConsoleInteractive)) {
        return
    }

    $answer = Read-Host 'Restart Windows Terminal now? [y/N]'
    if ($answer -match '^(y|yes|д|да)$') {
        Restart-WindowsTerminalProcess
    }
}

function Remove-TerminalKeybinding {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IList]$Bindings,
        [Parameter(Mandatory)]
        [string]$Id
    )

    for ($i = $Bindings.Count - 1; $i -ge 0; $i--) {
        if ($Bindings[$i].id -eq $Id) {
            $Bindings.RemoveAt($i)
        }
    }
}

function Get-ProfileContent {
    $profileDir = Split-Path -Path $PROFILE -Parent
    if (-not (Test-Path -LiteralPath $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    if (Test-Path -LiteralPath $PROFILE) {
        return Get-Content -LiteralPath $PROFILE -Raw
    }

    return ''
}

function Save-ProfileContent {
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    Set-Content -LiteralPath $PROFILE -Value $Content
}

function Ensure-ProfileLine {
    param(
        [Parameter(Mandatory)]
        [string]$Line
    )

    $content = Get-ProfileContent
    if ($content -match "(?m)^\Q$Line\E\s*$") {
        return $false
    }

    if ($content -and -not $content.EndsWith("`n")) {
        $content += "`r`n"
    }

    $content += $Line + "`r`n"
    Save-ProfileContent -Content $content
    return $true
}

function Ensure-ProfileBlock {
    param(
        [Parameter(Mandatory)]
        [string]$Marker,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]]$Lines
    )

    $content = Get-ProfileContent
    $begin = "# >>> swift-posh:$Marker >>>"
    $end = "# <<< swift-posh:$Marker <<<"
    $block = @($begin) + $Lines + $end
    $blockText = ($block -join "`r`n")

    if ($content.Contains($begin)) {
        $pattern = "(?s)" + [regex]::Escape($begin) + ".*?" + [regex]::Escape($end)
        $existingBlock = [regex]::Match($content, $pattern).Value
        if ($existingBlock -eq $blockText) {
            return $false
        }

        $updatedContent = [regex]::Replace($content, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $blockText }, 1)
        Save-ProfileContent -Content $updatedContent
        return $true
    }

    if ($content -and -not $content.EndsWith("`n")) {
        $content += "`r`n"
    }

    if ($content) {
        $content += "`r`n"
    }

    $content += $blockText + "`r`n"
    Save-ProfileContent -Content $content
    return $true
}

function Install-SwiftPoshProfileEntry {
    $lines = @(
        ('$swiftPoshRoot = ''{0}\src''' -f $PSScriptRoot)
        ". `"$PSScriptRoot\src\swift-posh.ps1`""
        'Initialize-SwiftPosh'
    )

    $changed = Ensure-ProfileBlock -Marker 'core' -Lines $lines
    if ($changed) {
        Write-Host 'Applied: swift-posh profile entry'
    } else {
        Write-Host 'Skipped: swift-posh profile entry already present'
    }
}

function Install-PSReadLineBindings {
    $lines = @(
        'Set-PSReadLineOption -AddToHistoryHandler {'
        '    param($line)'
        ''
        '    if (($line ?? '''').Trim() -eq ''exit'') {'
        '        return [Microsoft.PowerShell.AddToHistoryOption]::SkipAdding'
        '    }'
        ''
        '    return [Microsoft.PowerShell.PSConsoleReadLine]::GetDefaultAddToHistoryOption($line)'
        '}'
        ''
        'Set-PSReadLineKeyHandler -Chord Ctrl+d -ScriptBlock {'
        '    param($key, $arg)'
        ''
        '    $line = $null'
        '    $cursor = 0'
        '    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)'
        ''
        '    if ([string]::IsNullOrEmpty($line)) {'
        '        [Microsoft.PowerShell.PSConsoleReadLine]::Insert(''exit'')'
        '        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()'
        '        return'
        '    }'
        ''
        '    [Microsoft.PowerShell.PSConsoleReadLine]::DeleteChar($key, $arg)'
        '}'
        ''
        'Set-PSReadLineKeyHandler -Chord Ctrl+в -ScriptBlock {'
        '    param($key, $arg)'
        ''
        '    $line = $null'
        '    $cursor = 0'
        '    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)'
        ''
        '    if ([string]::IsNullOrEmpty($line)) {'
        '        [Microsoft.PowerShell.PSConsoleReadLine]::Insert(''exit'')'
        '        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()'
        '        return'
        '    }'
        ''
        '    [Microsoft.PowerShell.PSConsoleReadLine]::DeleteChar($key, $arg)'
        '}'
        ''
        'Set-PSReadLineKeyHandler -Chord Ctrl+c -Function CopyOrCancelLine'
        'Set-PSReadLineKeyHandler -Chord Ctrl+с -Function CopyOrCancelLine'
    )

    $changed = Ensure-ProfileBlock -Marker 'psreadline' -Lines $lines
    if ($changed) {
        Write-Host 'Applied: PSReadLine Ctrl+C bindings'
    } else {
        Write-Host 'Skipped: PSReadLine Ctrl+C bindings already present'
    }
}

function Install-CurlAliasPatch {
    $lines = @(
        'if (Test-Path Alias:\curl) {'
        '    Remove-Item Alias:\curl -Force'
        '}'
        'Set-Alias -Name curl -Value curl.exe'
    )

    $changed = Ensure-ProfileBlock -Marker 'curl' -Lines $lines
    if ($changed) {
        Write-Host 'Applied: curl alias patch'
    } else {
        Write-Host 'Skipped: curl alias patch already present'
    }
}

function Install-WindowsTerminalShortcuts {
    $terminal = Get-WindowsTerminalSettings
    if (-not $terminal) {
        Write-Host 'Skipped: Windows Terminal settings.json not found'
        return
    }

    $settings = $terminal.Settings

    if ($null -eq $settings.keybindings) {
        $settings | Add-Member -NotePropertyName keybindings -NotePropertyValue @()
    }
    if ($null -eq $settings.actions) {
        $settings | Add-Member -NotePropertyName actions -NotePropertyValue @()
    }

    $bindings = [System.Collections.ArrayList]@($settings.keybindings)
    Remove-TerminalKeybinding -Bindings $bindings -Id 'Terminal.DuplicatePaneAuto'
    Remove-TerminalKeybinding -Bindings $bindings -Id 'Terminal.DuplicatePaneDown'
    Remove-TerminalKeybinding -Bindings $bindings -Id 'Terminal.DuplicatePaneRight'
    Remove-TerminalKeybinding -Bindings $bindings -Id 'Terminal.SplitPaneHorizontal'
    Remove-TerminalKeybinding -Bindings $bindings -Id 'Terminal.SplitPaneVertical'
    Remove-TerminalKeybinding -Bindings $bindings -Id 'Terminal.SplitPaneDown'
    Remove-TerminalKeybinding -Bindings $bindings -Id 'Terminal.SplitPaneRight'
    Set-TerminalKeybinding -Bindings $bindings -Id 'Terminal.DuplicatePaneDown' -Keys 'alt+shift+s'
    Set-TerminalKeybinding -Bindings $bindings -Id 'Terminal.DuplicatePaneRight' -Keys 'alt+shift+d'
    Set-TerminalKeybinding -Bindings $bindings -Id 'Terminal.CopyToClipboard' -Keys 'ctrl+shift+c'
    Set-TerminalKeybinding -Bindings $bindings -Id 'Terminal.PasteFromClipboard' -Keys 'ctrl+shift+v'
    $settings.keybindings = $bindings

    $existingActions = @(
        $settings.actions | Where-Object {
            $command = $_.command
            $keysProperty = $_.PSObject.Properties['keys']
            $keysValue = if ($keysProperty) { [string]$keysProperty.Value } else { '' }
            if ($null -eq $command) {
                return $true
            }

            if ($keysValue -in @('alt+shift+s', 'shift+alt+s', 'alt+shift+d', 'shift+alt+d')) {
                return $false
            }

            if ($command -is [string]) {
                return $command -ne 'splitPane'
            }

            return $command.action -ne 'splitPane'
        }
    )

    $settings.actions = @($existingActions)

    Save-WindowsTerminalSettings -Path $terminal.Path -Settings $settings
    Write-Host 'Applied: Windows Terminal shortcuts'
    Write-Host 'Restart Windows Terminal to pick up the new bindings.'
}

function Install-WindowsTerminalCurrentDirectoryTitle {
    $terminal = Get-WindowsTerminalSettings
    if (-not $terminal) {
        Write-Host 'Skipped: Windows Terminal settings.json not found'
        return
    }

    $settings = $terminal.Settings
    if ($null -eq $settings.profiles -or $null -eq $settings.profiles.defaults) {
        Write-Host 'Skipped: Windows Terminal profiles.defaults not found'
        return
    }

    $defaults = $settings.profiles.defaults
    if ($defaults.PSObject.Properties['suppressApplicationTitle']) {
        $defaults.suppressApplicationTitle = $false
    } else {
        $defaults | Add-Member -NotePropertyName suppressApplicationTitle -NotePropertyValue $false
    }

    $defaultProfileGuid = [string]$settings.defaultProfile
    if ($defaultProfileGuid) {
        $defaultProfile = $settings.profiles.list | Where-Object { $_.guid -eq $defaultProfileGuid } | Select-Object -First 1
        if ($defaultProfile) {
            if ($defaultProfile.PSObject.Properties['suppressApplicationTitle']) {
                $defaultProfile.suppressApplicationTitle = $false
            } else {
                $defaultProfile | Add-Member -NotePropertyName suppressApplicationTitle -NotePropertyValue $false
            }

            if ($defaultProfile.PSObject.Properties['tabTitle']) {
                $defaultProfile.PSObject.Properties.Remove('tabTitle')
            }
        }
    }

    Save-WindowsTerminalSettings -Path $terminal.Path -Settings $settings

    $lines = @(
        '$global:SwiftPoshUseCurrentDirectoryTitle = $true'
    )

    $changed = Ensure-ProfileBlock -Marker 'tab-title' -Lines $lines
    if ($changed) {
        Write-Host 'Applied: current directory tab title profile patch'
    } else {
        Write-Host 'Skipped: current directory tab title profile patch already present'
    }

    Write-Host 'Applied: Windows Terminal current directory tab title'
    Write-Host 'Restart Windows Terminal to pick up the new title behavior.'
}

function Install-NerdFont {
    param(
        [string]$PackageId = 'DEVCOM.JetBrainsMonoNerdFont',
        [string]$SelectedFontFace = 'JetBrainsMono Nerd Font',
        [string]$ReleaseAsset = 'JetBrainsMono.zip',
        [string]$InstallName = 'JetBrainsMono',
        [string]$SourceUrl
    )

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget -and $PackageId) {
        Write-Host ("Starting Nerd Font installation for {0}..." -f $SelectedFontFace)
        & $winget.Source install `
            --id $PackageId `
            --source winget `
            --accept-source-agreements `
            --accept-package-agreements `
            --disable-interactivity

        $wingetExitCode = $LASTEXITCODE
        if ($wingetExitCode -eq 0 -or $wingetExitCode -eq -1978335189) {
            Write-Host ("Applied: {0} installation" -f $SelectedFontFace)
            return
        }

        Write-Host ("winget installation for {0} finished with exit code {1}, trying direct download..." -f $SelectedFontFace, $wingetExitCode)
    }

    if ($InstallName) {
        try {
            Write-Host ("Trying official Nerd Fonts PowerShell installer for {0}..." -f $SelectedFontFace)
            $scriptContent = (Invoke-WebRequest -Uri 'https://to.loredo.me/Install-NerdFont.ps1').Content
            & ([scriptblock]::Create($scriptContent)) -Name $InstallName
            Write-Host ("Applied: {0} installation via official Nerd Fonts installer" -f $SelectedFontFace)
            return
        } catch {
            Write-Host ("Official Nerd Fonts installer failed for {0}, trying release archive..." -f $SelectedFontFace)
        }
    }

    Install-NerdFontFromRelease -ReleaseAsset $ReleaseAsset -SelectedFontFace $SelectedFontFace -SourceUrl $SourceUrl
}

function Resolve-NerdFontFace {
    param(
        [Parameter(Mandatory)]
        [string]$InstallName,
        [Parameter(Mandatory)]
        [string]$SelectedFontFace
    )

    if ($InstallName -eq 'Hack') {
        return 'Hack'
    }

    $resolvedFace = Resolve-InstalledFontFace -InstallName $InstallName -FallbackFontFace $SelectedFontFace
    if ($resolvedFace -ne $SelectedFontFace) {
        Write-Host ("Resolved Windows Terminal font face: {0}" -f $resolvedFace)
    }

    return $resolvedFace
}

function Get-FontSourceUrl {
    param(
        [Parameter(Mandatory)]
        [psobject]$Font
    )

    if ($Font.PSObject.Properties['SourceUrl']) {
        return [string]$Font.SourceUrl
    }

    return $null
}

function Install-WindowsTerminalNerdFont {
    param(
        [string]$SelectedFontFace = 'JetBrainsMono Nerd Font'
    )

    $terminal = Get-WindowsTerminalSettings
    if (-not $terminal) {
        Write-Host 'Skipped: Windows Terminal settings.json not found'
        return
    }

    $settings = $terminal.Settings
    if ($null -eq $settings.profiles -or $null -eq $settings.profiles.defaults) {
        Write-Host 'Skipped: Windows Terminal profiles.defaults not found'
        return
    }

    $defaults = $settings.profiles.defaults
    $fontProperty = $defaults.PSObject.Properties['font']
    if (-not $fontProperty) {
        $defaults | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{})
    }

    $font = $defaults.font
    if ($font.PSObject.Properties['face']) {
        $font.face = $SelectedFontFace
    } else {
        $font | Add-Member -NotePropertyName face -NotePropertyValue $SelectedFontFace
    }

    $defaultProfileGuid = [string]$settings.defaultProfile
    if ($defaultProfileGuid) {
        $defaultProfile = $settings.profiles.list | Where-Object { $_.guid -eq $defaultProfileGuid } | Select-Object -First 1
        if ($defaultProfile) {
            $profileFontProperty = $defaultProfile.PSObject.Properties['font']
            if (-not $profileFontProperty) {
                $defaultProfile | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{})
            }

            $profileFont = $defaultProfile.font
            if ($profileFont.PSObject.Properties['face']) {
                $profileFont.face = $SelectedFontFace
            } else {
                $profileFont | Add-Member -NotePropertyName face -NotePropertyValue $SelectedFontFace
            }
        }
    }

    Save-WindowsTerminalSettings -Path $terminal.Path -Settings $settings
    Write-Host ("Applied: Windows Terminal font face -> {0}" -f $SelectedFontFace)
    Write-Host 'Restart Windows Terminal to pick up the new font.'
    Confirm-WindowsTerminalRestart
}

function Select-NerdFont {
    $fonts = @(Get-AvailableNerdFonts)
    if (-not $fonts.Count) {
        Write-Host 'No Nerd Font packages found through winget.'
        return $null
    }

    return Select-InteractiveItem `
        -Title 'Available Nerd Fonts' `
        -Items $fonts `
        -LabelSelector {
            param($font)
            $isInstalled = Test-NerdFontInstalled -InstallName $font.InstallName -ExpectedFontFace $font.FontFace
            $status = if ($isInstalled) { '[installed]' } else { '[download]' }
            if ($font.PackageId) {
                "{0} {1} [{2}]" -f $font.Name, $status, $font.PackageId
            } else {
                "{0} {1}" -f $font.Name, $status
            }
        }
}

function Install-SelectedNerdFont {
    $selectedFont = Select-NerdFont
    if (-not $selectedFont) {
        return
    }

    if (Test-NerdFontInstalled -InstallName $selectedFont.InstallName -ExpectedFontFace $selectedFont.FontFace) {
        Write-Host ("Skipped: {0} is already installed" -f $selectedFont.Name)
        return
    }

    Install-NerdFont -PackageId $selectedFont.PackageId -SelectedFontFace $selectedFont.FontFace -ReleaseAsset $selectedFont.ReleaseAsset -InstallName $selectedFont.InstallName -SourceUrl (Get-FontSourceUrl -Font $selectedFont)
}

function Install-SelectedWindowsTerminalNerdFont {
    $selectedFont = Select-NerdFont
    if (-not $selectedFont) {
        return
    }

    $resolvedFace = Resolve-NerdFontFace -InstallName $selectedFont.InstallName -SelectedFontFace $selectedFont.FontFace
    Install-WindowsTerminalNerdFont -SelectedFontFace $resolvedFace
}

function Install-SelectedNerdFontAndApply {
    $selectedFont = Select-NerdFont
    if (-not $selectedFont) {
        return
    }

    if (-not (Test-NerdFontInstalled -InstallName $selectedFont.InstallName -ExpectedFontFace $selectedFont.FontFace)) {
        Install-NerdFont -PackageId $selectedFont.PackageId -SelectedFontFace $selectedFont.FontFace -ReleaseAsset $selectedFont.ReleaseAsset -InstallName $selectedFont.InstallName -SourceUrl (Get-FontSourceUrl -Font $selectedFont)
    } else {
        Write-Host ("Skipped download: {0} is already installed" -f $selectedFont.Name)
    }

    $resolvedFace = Resolve-NerdFontFace -InstallName $selectedFont.InstallName -SelectedFontFace $selectedFont.FontFace
    Install-WindowsTerminalNerdFont -SelectedFontFace $resolvedFace
}

function Show-NerdFontStatus {
    $currentFont = Get-WindowsTerminalCurrentFontFace
    if ($currentFont) {
        Write-Host ("Current Windows Terminal font: {0}" -f $currentFont)
    } else {
        Write-Host 'Current Windows Terminal font: not set'
    }

    $fonts = @(Get-AvailableNerdFonts)
    if (-not $fonts.Count) {
        Write-Host 'Available Nerd Fonts from winget: none found'
        return
    }

    Write-Host 'Available Nerd Fonts from winget:'
    foreach ($font in $fonts) {
        $isInstalled = Test-NerdFontInstalled -InstallName $font.InstallName -ExpectedFontFace $font.FontFace
        $status = if ($isInstalled) { 'installed' } else { 'not installed' }
        Write-Host ("- {0} [{1}] - {2}" -f $font.Name, $font.PackageId, $status)
    }
}

function Get-SwiftPoshStyle {
    param(
        [string]$Name
    )

    if (Get-Variable -Name PSStyle -Scope Global -ErrorAction SilentlyContinue) {
        return $global:PSStyle.$Name
    }

    return ''
}

function Show-MenuStatus {
    param(
        [string]$Message
    )

    if ([string]::IsNullOrWhiteSpace($Message)) {
        return
    }

    Write-Host ''
    Write-Host $Message
    Write-Host 'Press any key to continue...'
    [void][System.Console]::ReadKey($true)
}

function Select-InteractiveItem {
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [object[]]$Items,
        [Parameter(Mandatory)]
        [scriptblock]$LabelSelector
    )

    if (-not $Items.Count) {
        return $null
    }

    if (-not (Test-IsConsoleInteractive)) {
        return $Items[0]
    }

    $selectedIndex = 0
    $labels = @($Items | ForEach-Object { & $LabelSelector $_ })
    $accent = Get-SwiftPoshStyle -Name 'Foreground'
    $reset = if (Get-Variable -Name PSStyle -Scope Global -ErrorAction SilentlyContinue) { $global:PSStyle.Reset } else { '' }
    $selectionPrefix = if ($accent) { $accent.BrightCyan } else { '' }
    $selectionBody = if ($accent) { $global:PSStyle.Background.BrightBlack + $global:PSStyle.Foreground.BrightWhite } else { '' }

    $previousCursorVisible = $true
    try {
        $previousCursorVisible = [System.Console]::CursorVisible
        [System.Console]::CursorVisible = $false

        while ($true) {
            Clear-Host
            Write-Host $Title
            Write-Host 'Use Up/Down arrows and Enter. Esc cancels.'
            Write-Host ''

            for ($i = 0; $i -lt $Items.Count; $i++) {
                $label = $labels[$i]
                if ($i -eq $selectedIndex) {
                    Write-Host ("{0}> {1}{2}" -f $selectionPrefix, $selectionBody, $label) -NoNewline
                    Write-Host $reset
                } else {
                    Write-Host "  $label"
                }
            }

            $key = [System.Console]::ReadKey($true)
            switch ($key.Key) {
                'UpArrow' {
                    if ($selectedIndex -gt 0) {
                        $selectedIndex--
                    } else {
                        $selectedIndex = $Items.Count - 1
                    }
                }
                'DownArrow' {
                    if ($selectedIndex -lt ($Items.Count - 1)) {
                        $selectedIndex++
                    } else {
                        $selectedIndex = 0
                    }
                }
                'Enter' {
                    Clear-Host
                    return $Items[$selectedIndex]
                }
                'Escape' {
                    Clear-Host
                    return $null
                }
            }
        }
    } finally {
        try {
            [System.Console]::CursorVisible = $previousCursorVisible
        } catch {
        }
    }
}

function Invoke-MenuAction {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Action
    )

    & $Action 6>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.InformationRecord]) {
            $_.MessageData
        } else {
            "$_"
        }
    }
}

function Remove-SelectedSwiftPoshCommand {
    $commands = @(Get-SwiftPoshCommands)
    if (-not $commands.Count) {
        Write-Host 'No commands configured.'
        return
    }

    $selectedCommand = Select-InteractiveItem `
        -Title 'Remove command' `
        -Items $commands `
        -LabelSelector {
            param($command)
            "[{0}] {1} -> {2}" -f $command.Type, $command.Name, $command.Value
        }

    if (-not $selectedCommand) {
        return
    }

    Remove-SwiftPoshCommand -Name $selectedCommand.Name
}

function Show-CommandMenu {
    $items = @(
        @{
            Label  = 'Use curl.exe for curl'
            Action = { Invoke-MenuAction { Install-CurlAliasPatch } }
        }
        @{
            Label  = 'List commands'
            Action = { Invoke-MenuAction { Format-SwiftPoshCommands } }
        }
        @{
            Label  = 'Create command'
            Action = { Invoke-MenuAction { New-SwiftPoshCommand } }
        }
        @{
            Label  = 'Remove command'
            Action = {
                Remove-SelectedSwiftPoshCommand
                'Command menu finished'
            }
        }
        @{
            Label  = 'Back'
            Action = { return '__quit__' }
        }
    )

    $selectedIndex = 0
    $statusMessage = ''
    $accent = Get-SwiftPoshStyle -Name 'Foreground'
    $reset = if (Get-Variable -Name PSStyle -Scope Global -ErrorAction SilentlyContinue) { $global:PSStyle.Reset } else { '' }
    $selectionPrefix = if ($accent) { $accent.BrightCyan } else { '' }
    $selectionBody = if ($accent) { $global:PSStyle.Background.BrightBlack + $global:PSStyle.Foreground.BrightWhite } else { '' }

    while ($true) {
        Clear-Host
        Write-Host 'swift-posh commands'
        Write-Host 'Use Up/Down arrows and Enter. Esc goes back.'
        Write-Host ''

        for ($i = 0; $i -lt $items.Count; $i++) {
            $label = $items[$i].Label
            if ($i -eq $selectedIndex) {
                Write-Host ("{0}> {1}{2}" -f $selectionPrefix, $selectionBody, $label) -NoNewline
                Write-Host $reset
            } else {
                Write-Host "  $label"
            }
        }

        if ($statusMessage) {
            Show-MenuStatus -Message $statusMessage
            $statusMessage = ''
            continue
        }

        $key = [System.Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' {
                if ($selectedIndex -gt 0) { $selectedIndex-- } else { $selectedIndex = $items.Count - 1 }
            }
            'DownArrow' {
                if ($selectedIndex -lt ($items.Count - 1)) { $selectedIndex++ } else { $selectedIndex = 0 }
            }
            'Enter' {
                $result = & $items[$selectedIndex].Action
                if ($result -is [System.Array]) {
                    $result = ($result -join [Environment]::NewLine).Trim()
                }

                if ($result -eq '__quit__') {
                    Clear-Host
                    return
                }

                $statusMessage = [string]$result
            }
            'Escape' {
                Clear-Host
                return
            }
        }
    }
}

function Show-SetupMenu {
    $items = @(
        @{
            Label  = 'Install swift-posh into PowerShell profile'
            Action = { Invoke-MenuAction { Install-SwiftPoshProfileEntry } }
        }
        @{
            Label  = 'Install Ctrl+C / Ctrl+с PSReadLine fix'
            Action = { Invoke-MenuAction { Install-PSReadLineBindings } }
        }
        @{
            Label  = 'Install Windows Terminal shortcuts'
            Action = { Invoke-MenuAction { Install-WindowsTerminalShortcuts } }
        }
        @{
            Label  = 'Use current folder as tab title'
            Action = { Invoke-MenuAction { Install-WindowsTerminalCurrentDirectoryTitle } }
        }
        @{
            Label  = 'Commands'
            Action = {
                Show-CommandMenu
                'Returned from command menu'
            }
        }
        @{
            Label  = 'Set font'
            Action = {
                Install-SelectedNerdFontAndApply
                'Font setup finished'
            }
        }
        @{
            Label  = 'Apply all patches'
            Action = {
                $messages = @()
                $messages += Invoke-MenuAction { Install-SwiftPoshProfileEntry }
                $messages += Invoke-MenuAction { Install-PSReadLineBindings }
                $messages += Invoke-MenuAction { Install-WindowsTerminalShortcuts }
                $messages += Invoke-MenuAction { Install-WindowsTerminalCurrentDirectoryTitle }
                $messages += Invoke-MenuAction { Install-CurlAliasPatch }
                Install-SelectedNerdFontAndApply
                $messages += 'Font setup finished'
                $messages
            }
        }
        @{
            Label  = 'Quit'
            Action = { return '__quit__' }
        }
    )

    $selectedIndex = 0
    $statusMessage = ''
    $accent = Get-SwiftPoshStyle -Name 'Foreground'
    $reset = if (Get-Variable -Name PSStyle -Scope Global -ErrorAction SilentlyContinue) { $global:PSStyle.Reset } else { '' }
    $selectionPrefix = if ($accent) { $accent.BrightCyan } else { '' }
    $selectionBody = if ($accent) { $global:PSStyle.Background.BrightBlack + $global:PSStyle.Foreground.BrightWhite } else { '' }

    while ($true) {
        Clear-Host
        Write-Host 'swift-posh setup'
        Write-Host 'Use Up/Down arrows and Enter. Esc exits.'
        Write-Host ''

        for ($i = 0; $i -lt $items.Count; $i++) {
            $label = $items[$i].Label
            if ($i -eq $selectedIndex) {
                Write-Host ("{0}> {1}{2}" -f $selectionPrefix, $selectionBody, $label) -NoNewline
                Write-Host $reset
            } else {
                Write-Host "  $label"
            }
        }

        if ($statusMessage) {
            Show-MenuStatus -Message $statusMessage
            $statusMessage = ''
            continue
        }

        $key = [System.Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' {
                if ($selectedIndex -gt 0) {
                    $selectedIndex--
                } else {
                    $selectedIndex = $items.Count - 1
                }
            }
            'DownArrow' {
                if ($selectedIndex -lt ($items.Count - 1)) {
                    $selectedIndex++
                } else {
                    $selectedIndex = 0
                }
            }
            'Enter' {
                $result = & $items[$selectedIndex].Action
                if ($result -is [System.Array]) {
                    $result = ($result -join [Environment]::NewLine).Trim()
                }

                if ($result -eq '__quit__') {
                    Clear-Host
                    return
                }

                $statusMessage = if ([string]::IsNullOrWhiteSpace($result)) { 'Done.' } else { $result }
            }
            'Escape' {
                Clear-Host
                return
            }
        }
    }
}

function Test-IsConsoleInteractive {
    try {
        [void][System.Console]::CursorTop
        return $true
    } catch {
        return $false
    }
}

function Show-BasicSetupMenu {
    while ($true) {
        Write-Host ''
        Write-Host 'swift-posh setup'
        Write-Host '1. Install swift-posh into PowerShell profile'
        Write-Host '2. Install Ctrl+C / Ctrl+с PSReadLine fix'
        Write-Host '3. Install Windows Terminal shortcuts'
        Write-Host '4. Use current folder as tab title'
        Write-Host '5. Commands'
        Write-Host '6. Set font'
        Write-Host '7. Apply all patches'
        Write-Host 'Q. Quit'
        Write-Host ''

        $choice = Read-Host 'Select action'
        switch ($choice.ToLowerInvariant()) {
            '1' { Show-MenuStatus -Message (Invoke-MenuAction { Install-SwiftPoshProfileEntry }) }
            '2' { Show-MenuStatus -Message (Invoke-MenuAction { Install-PSReadLineBindings }) }
            '3' { Show-MenuStatus -Message (Invoke-MenuAction { Install-WindowsTerminalShortcuts }) }
            '4' { Show-MenuStatus -Message (Invoke-MenuAction { Install-WindowsTerminalCurrentDirectoryTitle }) }
            '5' { Show-CommandMenu }
            '6' {
                Install-SelectedNerdFontAndApply
                Show-MenuStatus -Message 'Font setup finished'
            }
            '7' {
                $messages = @()
                $messages += Invoke-MenuAction { Install-SwiftPoshProfileEntry }
                $messages += Invoke-MenuAction { Install-PSReadLineBindings }
                $messages += Invoke-MenuAction { Install-WindowsTerminalShortcuts }
                $messages += Invoke-MenuAction { Install-WindowsTerminalCurrentDirectoryTitle }
                $messages += Invoke-MenuAction { Install-CurlAliasPatch }
                Install-SelectedNerdFontAndApply
                $messages += 'Font setup finished'
                Show-MenuStatus -Message (($messages | Where-Object { $_ }) -join [Environment]::NewLine)
            }
            'q' { return }
            default { Show-MenuStatus -Message 'Unknown option' }
        }
    }
}

function Install-DefaultSet {
    if (-not $SkipProfile) {
        Install-SwiftPoshProfileEntry
        Install-PSReadLineBindings
        Install-CurlAliasPatch
    }

    if (-not $SkipTerminal) {
        Install-WindowsTerminalShortcuts
        Install-WindowsTerminalCurrentDirectoryTitle
        Install-WindowsTerminalNerdFont
    }
}

$isInteractiveHost = $Host.Name -notmatch 'ServerRemoteHost'

if ($ShowFontStatusOnly) {
    Show-NerdFontStatus
    return
}

if ($InstallFontOnly) {
    if ($FontPackageId -and $FontFace) {
        $selectedFont = Get-AvailableNerdFonts | Where-Object { $_.PackageId -eq $FontPackageId -or $_.FontFace -eq $FontFace } | Select-Object -First 1
        $releaseAsset = if ($selectedFont) { $selectedFont.ReleaseAsset } else { 'JetBrainsMono.zip' }
        $installName = if ($selectedFont) { $selectedFont.InstallName } else { 'JetBrainsMono' }
        $sourceUrl = if ($selectedFont) { Get-FontSourceUrl -Font $selectedFont } else { $null }
        Install-NerdFont -PackageId $FontPackageId -SelectedFontFace $FontFace -ReleaseAsset $releaseAsset -InstallName $installName -SourceUrl $sourceUrl
        $resolvedFace = Resolve-NerdFontFace -InstallName $installName -SelectedFontFace $FontFace
        Install-WindowsTerminalNerdFont -SelectedFontFace $resolvedFace
    } else {
        Install-SelectedNerdFontAndApply
    }
    return
}

if ($Menu -or (-not $All -and -not $SkipProfile -and -not $SkipTerminal -and $isInteractiveHost)) {
    if (Test-IsConsoleInteractive) {
        Show-SetupMenu
    } else {
        Show-BasicSetupMenu
    }
    return
}

Install-DefaultSet
