# Codex Desktop: OpenAI, Polza AI и OdiRouter

PowerShell-скрипты и инструкции для переключения Codex Desktop между OpenAI и совместимыми API-провайдерами на Windows.

> Неофициальный проект. Формат конфигурации Codex может измениться. Установщики сохраняют резервную копию `~/.codex/config.toml` перед изменением.

## Выберите сценарий

- **Только Polza AI:** отдельная настройка с Polza в качестве единственного активного провайдера. Аккаунт ChatGPT для настройки не требуется. См. [инструкцию Polza-only](POLZA-ONLY-WINDOWS-RU.md).
- **OpenAI, Polza AI и OdiRouter:** установщик OdiRouter добавляет третий профиль в общий переключатель и сохраняет активный профиль. См. [инструкцию для OdiRouter](ODIROUTER-WINDOWS-RU.md).
- **Другой OpenAI-совместимый API:** используйте универсальный установщик `Install-CodexProviderSwitcher.ps1` с параметрами своего провайдера.

## OdiRouter: краткий запуск

1. Установите Codex Desktop и запустите его хотя бы один раз.
2. Скачайте репозиторий через **Code → Download ZIP** и распакуйте архив.
3. Откройте PowerShell в распакованной папке и выполните:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\Install-OdiRouter.ps1
```

Установщик запросит API-ключ скрытым вводом, создаст каталог совместимых моделей и добавит ярлык **Codex - OdiRouter**. Ярлыки OpenAI, Polza AI и OdiRouter используют общий переключатель профилей; переключение закрывает и перезапускает Codex Desktop. Сохраните свою работу перед переключением.

Если ключ пока не готов, установите профиль без запроса ключа:

```powershell
.\scripts\Install-OdiRouter.ps1 -SkipApiKeyPrompt
```

При первом запуске ярлыка OdiRouter переключатель запросит ключ и проверит его перед перезапуском приложения. По умолчанию выбирается `gpt-5.6-sol`; доступные ID моделей берутся из каталога OdiRouter.

## Универсальный установщик

Для произвольного OpenAI-совместимого провайдера передайте параметры API и модели:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\Install-CodexProviderSwitcher.ps1 `
  -ProviderName myprovider `
  -ProviderDisplayName "My Provider" `
  -BaseUrl "https://example.com/v1/" `
  -EnvKey "MY_PROVIDER_API_KEY" `
  -Model "model-name"
```

Этот установщик создаёт ярлыки **Codex - OpenAI** и **Codex - My Provider**. Параметр `-CatalogPath` необязателен; при его использовании укажите путь к JSON-каталогу моделей. Ключ запрашивается скрытым вводом и сохраняется только в пользовательской переменной среды Windows.

## Документация

- [Пошаговая инструкция для начинающих](docs/MANUAL-INSTALL-RU.md)
- [Инструкция для Codex, Claude Code и других агентов](docs/AGENT-INSTRUCTIONS.md)
- [Формат каталога моделей](docs/MODEL-CATALOG.md)
- [Диагностика проблем](docs/TROUBLESHOOTING-RU.md)
- [Безопасность](docs/SECURITY-RU.md)

## Ограничение интерфейса

Codex Desktop использует один активный `model_provider`. Поэтому модели двух провайдеров нельзя надёжно объединить в одном стандартном списке выбора. Этот проект переключает активный провайдер и перезапускает приложение.

## Официальная документация

- [Codex configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference)
- [Codex configuration basics](https://learn.chatgpt.com/docs/config-file/config-basic)

