# Диагностика

## Ярлык ничего не делает

Запустите переключатель без скрытого окна:

```powershell
& "$env:USERPROFILE\.codex\Switch-CodexProvider.ps1" -Provider OpenAI -NoRestart
```

Проверьте `~/.codex/provider-switch.log`. Скрипты проекта используют только ASCII-текст, чтобы Windows PowerShell 5 не ломал UTF-8 без BOM.

## После переключения остался старый провайдер

Старый чат продолжает работать с провайдером, выбранным при его запуске. Полностью перезапустите Codex и создайте новый чат.

## Ошибка авторизации

```powershell
[Environment]::GetEnvironmentVariable('POLZA_API_KEY', 'User')
```

Команда должна вернуть непустое значение. Не публикуйте результат. После изменения переменной закройте все окна Codex и PowerShell.

## Нет моделей в списке

- проверьте существование `model_catalog_json`;
- проверьте JSON через `ConvertFrom-Json`;
- убедитесь, что `model` совпадает со `slug`;
- запустите `codex debug models`;
- проверьте, что каталог соответствует установленной версии Codex.

## Диагностический скрипт

```powershell
.\scripts\Test-CodexProviderSetup.ps1
```

