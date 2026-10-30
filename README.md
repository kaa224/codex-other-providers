# Codex Desktop: OpenAI + other providers

Набор инструкций и PowerShell-скриптов для Windows, который добавляет в Codex Desktop переключение между прямым OpenAI и OpenAI-совместимым провайдером (например, Polza AI).

> Это не официальный проект OpenAI. Формат конфигурации Codex может измениться. Перед установкой создаётся резервная копия `~/.codex/config.toml`.

## Что получится

- два ярлыка на рабочем столе: **Codex - OpenAI** и **Codex - Other Provider**;
- API-ключ хранится в пользовательской переменной среды, а не в репозитории или `config.toml`;
- отдельный JSON-каталог моделей для стороннего провайдера;
- журнал переключений `~/.codex/provider-switch.log`;
- автоматический перезапуск Codex Desktop после выбора провайдера.

## Самый простой способ

1. Установите и хотя бы один раз запустите Codex Desktop.
2. Скачайте этот репозиторий: **Code → Download ZIP**, распакуйте архив.
3. Откройте PowerShell в папке репозитория.
4. Выполните:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\Install-CodexProviderSwitcher.ps1 `
  -ProviderName polza `
  -ProviderDisplayName "Polza AI" `
  -BaseUrl "https://polza.ai/api/v1/" `
  -EnvKey "POLZA_API_KEY" `
  -Model "УКАЖИТЕ_МОДЕЛЬ" `
  -CatalogPath "C:\путь\к\models.json"
```

Если каталога моделей нет, уберите параметр `-CatalogPath`. Установщик безопасно запросит API-ключ без отображения символов и не сохранит его в истории команд. После установки закройте это окно PowerShell и запускайте нужный ярлык на рабочем столе.

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

