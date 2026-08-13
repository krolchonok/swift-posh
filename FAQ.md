# SWIFT-POSH CHEAT SHEET & FAQ (WINDOWS)

## 📁 Навигация и работа с папками
- `mkcd <path>` / `take <path>` — Создать папку и сразу перейти в нее.
- `gclone <url> [target-dir]` / `gclcd` — Клонировать Git-репозиторий и сразу перейти в созданную папку.

## 📦 Архивы и файлы
- `extract <file>` / `x <file>` — Автоматическая распаковка архивов (`.zip` через Expand-Archive, `.tar.gz`/`.tgz`/`.tar` через tar.exe, `.7z`/`.rar` через 7z.exe).

## 🚀 Управление swift-posh
- `Update-SwiftPosh` / `update-posh` — Обновить репозиторий swift-posh из Git и перезагрузить окружение.
- `Update-SwiftPosh -Force` — Принудительно обновить репозиторий и проверить обновления PowerShell.exe.
- `Reload-SwiftPosh` — Перезагрузить локальные модули и темы swift-posh в текущей сессии.
- `Menu` / `Open-SwiftPoshSetup` — Открыть интерактивное меню настройки swift-posh.
- `Get-SwiftPoshFAQ` / `posh-faq` — Показать эту справку в терминале.

## ⚡ Управление алиасами и фразами
- `Get-SwiftPoshAliases` — Показать список персональных алиасов.
- `Add-SwiftPoshAlias -Name <имя> -Value <команда>` — Добавить постоянный алиас.
- `Remove-SwiftPoshAlias -Name <имя>` — Удалить постоянный алиас.
- `Get-SwiftPoshPhrases` / `Remove-SwiftPoshPhrase` — Управление фразовыми командами.

## 🎨 Темы и шрифты
- `Install-SwiftPoshThemeLibrary` — Загрузить официальную библиотеку тем oh-my-posh.
- `Get-SwiftPoshThemeLibrary` — Просмотреть доступные темы.
