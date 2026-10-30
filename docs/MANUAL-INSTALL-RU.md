# Ручная установка для начинающих

## Что понадобится

- Windows 10 или 11;
- установленный Codex Desktop;
- адрес OpenAI-совместимого API;
- API-ключ провайдера;
- название модели;
- при необходимости JSON-каталог моделей.

## Установка скриптом

1. Скачайте ZIP репозитория и распакуйте его.
2. В Проводнике откройте распакованную папку.
3. Щёлкните правой кнопкой по пустому месту и выберите **Открыть в терминале**.
4. Скопируйте команду из README, замените модель, путь к каталогу и API-ключ.
5. Нажмите Enter. Надпись `Installed successfully` означает успешную установку.
6. Полностью закройте терминал. Это важно: новые окна получат переменную с API-ключом.
7. На рабочем столе используйте ярлык нужного провайдера.

## Если провайдер не Polza AI

Передайте свои значения параметров:

```powershell
.\scripts\Install-CodexProviderSwitcher.ps1 `
  -ProviderName myprovider `
  -ProviderDisplayName "My Provider" `
  -BaseUrl "https://example.com/v1/" `
  -EnvKey "MY_PROVIDER_API_KEY" `
  -Model "model-name"
```

Установщик запросит ключ скрытым вводом. Не добавляйте ключ прямо в команду: такая команда сохраняется в истории PowerShell.

Провайдер должен поддерживать API, совместимый с OpenAI Responses API. Если он поддерживает только Chat Completions, попробуйте `-WireApi chat`, но функции Codex могут работать не полностью.

## Удаление

1. Восстановите последний файл `~/.codex/config.backup.*.toml` как `~/.codex/config.toml`.
2. Удалите ярлыки, `~/.codex/Switch-CodexProvider.ps1`, `~/.codex/provider-switch.settings.json`.
3. Удалите ключ из пользовательских переменных среды:

```powershell
[Environment]::SetEnvironmentVariable('POLZA_API_KEY', $null, 'User')
```

