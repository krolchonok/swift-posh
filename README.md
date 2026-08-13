# swift-posh

Minimal fast prompt framework for PowerShell, built as a lightweight alternative to `oh-my-posh`.

## MVP goals

- No external process calls for the basic prompt path.
- Git branch detection by reading `.git/HEAD` directly.
- Small set of segments with simple theming.
- Easy profile integration.

## Structure

- `src/swift-posh.ps1` entry point.
- `src/config.psd1` default config.
- `src/core/` state, config and prompt renderer.
- `src/segments/` prompt segments.
- `src/themes/` theme definitions.
- `examples/profile.sample.ps1` profile integration example.

## Segments in MVP

- `Status`: previous command result.
- `Path`: current location with home shortening.
- `Git`: current branch without invoking `git`.

## Quick start

```powershell
. 'C:\Users\krol\swift-posh\src\swift-posh.ps1'
Initialize-SwiftPosh
```

To make it permanent, copy the example from `examples/profile.sample.ps1` into your PowerShell profile.

After loading `swift-posh`, open the setup menu from the console with:

```powershell
Menu
Open-SwiftPoshSetup
```

On startup, `swift-posh` can also check whether a newer stable PowerShell release is available and offer to upgrade via `winget`.

Useful shell commands after loading:

```powershell
Reload-SwiftPosh
Update-SwiftPosh
Update-SwiftPosh -ApplySetup
Install-SwiftPoshThemeLibrary
Get-SwiftPoshThemeLibrary
Get-SwiftPoshAliases
Add-SwiftPoshAlias -Name k -Value kubectl
New-SwiftPoshAlias
Remove-SwiftPoshAlias -Name k
```

`Reload-SwiftPosh` reloads local files into the current session.
`Update-SwiftPosh` runs `git pull --ff-only` when the project is a git repo, otherwise it reloads local files only.

Persistent aliases are stored in:

```powershell
~/.swift-posh/aliases.json
```

They are loaded automatically during `Initialize-SwiftPosh`.

Official external `oh-my-posh` themes can be downloaded into:

```powershell
~/.swift-posh/themes/oh-my-posh
```


## Utility Functions & Aliases

-  /  — Create directory and set location into it immediately.
-  /  — Clone git repository and set location into the cloned directory.
-  /  — Auto-extract archives (, , , , , , ).


## Utility Functions & Aliases

- `mkcd <path>` / `take <path>` — Create directory and set location into it immediately.
- `gclone <url> [target-dir]` / `gclcd` — Clone git repository and set location into the cloned directory.
- `extract <file>` / `x <file>` — Auto-extract archives (`.zip`, `.tar.gz`, `.tgz`, `.tar`, `.gz`, `.7z`, `.rar`).

## Install on another device

Use the bundled installer:

```powershell
& 'C:\Users\krol\swift-posh\install.ps1' -Menu
```

Menu actions:

- install `swift-posh` into `$PROFILE`
- install `Ctrl+C` / `Ctrl+с` PSReadLine fix
- open `Commands` for aliases, phrases and `curl.exe for curl`
- install Windows Terminal shortcuts
- set a `Nerd Font`
- install official `oh-my-posh` theme library
- apply all patches

Non-interactive full install:

```powershell
& 'C:\Users\krol\swift-posh\install.ps1' -All
```

It applies:

- PowerShell profile wiring for `swift-posh`
- `Ctrl+C` / `Ctrl+с` PSReadLine bindings
- command environment patches including `curl -> curl.exe`
- Windows Terminal copy and paste bindings:
  `Ctrl+Shift+C` and `Ctrl+Shift+V`

Notes:

- Windows Terminal settings are separate from PowerShell itself.
- After changing terminal settings, restart Windows Terminal.
- If another terminal is used, only the PowerShell profile changes will apply automatically.

## Bootstrap from GitHub

After publishing this repo, install on another Windows device with:

```powershell
irm https://raw.githubusercontent.com/krolchonok/swift-posh/main/bootstrap.ps1 | iex
```

Or run the full non-interactive install:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/krolchonok/swift-posh/main/bootstrap.ps1))) -All
```
