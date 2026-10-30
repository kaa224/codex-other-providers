# Codex Desktop на Windows через OdiRouter

Этот вариант добавляет OdiRouter третьим провайдером рядом с OpenAI и Polza AI. Текущий активный профиль при установке не меняется.

## Что создаётся

- профиль `odirouter` в `%USERPROFILE%\.codex\config.toml`;
- каталог `%USERPROFILE%\.codex\odirouter-models.json`;
- общий переключатель для OpenAI, Polza AI и OdiRouter;
- ярлык **Codex - OdiRouter** на рабочем столе;
- резервная копия конфигурации и журналы установки.

В каталог попадают только LLM-модели OdiRouter, которые принимают текст и изображения, возвращают текст и поддерживают Responses API.

## Установка

Откройте PowerShell в папке репозитория и выполните:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\Install-OdiRouter.ps1
```

Установщик скрыто запросит `ODIROUTER_API_KEY` и сохранит его только в пользовательской переменной Windows. По умолчанию используется модель `gpt-5.6-sol`:

```powershell
.\scripts\Install-OdiRouter.ps1 -Model "gpt-5.6-sol" -Reasoning "medium"
```

Если ключа пока нет, установка завершится без него:

```powershell
.\scripts\Install-OdiRouter.ps1 -SkipApiKeyPrompt
```

В этом случае при первом запуске ярлыка **Codex - OdiRouter** переключатель запросит ключ и проверит его до перезапуска Codex.

## Использование

Используйте ярлыки на рабочем столе:

- **Codex - OpenAI**;
- **Codex - Polza AI**;
- **Codex - OdiRouter**.

Перед переключением сохраните несохранённую работу: Codex Desktop будет закрыт и запущен заново.

## Проверка

Проверить конфигурацию без перезапуска приложения:

```powershell
& "$env:USERPROFILE\.codex\switch-codex-provider.ps1" -Provider OdiRouter -NoRestart
codex debug models
```

Вернуть Polza AI после проверки:

```powershell
& "$env:USERPROFILE\.codex\switch-codex-provider.ps1" -Provider Polza -NoRestart
```

Диагностические файлы:

- `%USERPROFILE%\.codex\odirouter-install.log`;
- `%USERPROFILE%\.codex\provider-switch.log`;
- `%USERPROFILE%\.codex\config.before-odirouter.*.toml`.

Проверка установки:

```powershell
& "$env:USERPROFILE\.codex\Test-OdiRouterSetup.ps1"
```

## Официальная документация

- [Codex CLI и OdiRouter](https://odirouter.ai/docs/integrations/coding-agents/codex-cli)
- [Каталог моделей](https://odirouter.ai/docs/api-reference/models/model-list)
- [Цены](https://odirouter.ai/pricing)

