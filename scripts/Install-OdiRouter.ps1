[CmdletBinding()]
param(
    [string]$Model = 'gpt-5.6-sol',
    [ValidateSet('low', 'medium', 'high', 'xhigh')][string]$Reasoning = 'low',
    [string]$CodexHome = (Join-Path $env:USERPROFILE '.codex'),
    [switch]$SkipApiKeyPrompt
)

$ErrorActionPreference = 'Stop'
$apiBaseUrl = 'https://api.odirouter.ai/v1'
$apiKeyName = 'ODIROUTER_API_KEY'
$providerName = 'odirouter'
$providerDisplayName = 'OdiRouter'
$configPath = Join-Path $CodexHome 'config.toml'
$catalogPath = Join-Path $CodexHome 'odirouter-models.json'
$settingsPath = Join-Path $CodexHome 'provider-switch.settings.json'
$switcherSource = Join-Path $PSScriptRoot 'Switch-CodexProviderProfiles.ps1'
$switcherTarget = Join-Path $CodexHome 'switch-codex-provider.ps1'
$catalogUpdater = Join-Path $PSScriptRoot 'Update-OdiRouterModelCatalog.ps1'
$testScriptSource = Join-Path $PSScriptRoot 'Test-OdiRouterSetup.ps1'
$testScriptTarget = Join-Path $CodexHome 'Test-OdiRouterSetup.ps1'
$beginMarker = '# BEGIN CODEX PROVIDER SWITCH'
$endMarker = '# END CODEX PROVIDER SWITCH'

New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null
if (-not (Test-Path -LiteralPath $configPath)) { New-Item -ItemType File -Path $configPath -Force | Out-Null }
$backupPath = Join-Path $CodexHome ("config.before-odirouter.{0}.toml" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
Copy-Item -LiteralPath $configPath -Destination $backupPath

if (-not $SkipApiKeyPrompt -and -not [Environment]::GetEnvironmentVariable($apiKeyName, 'User')) {
    $secureKey = Read-Host 'Enter your OdiRouter API key' -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
    try {
        $plainKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        if ([string]::IsNullOrWhiteSpace($plainKey)) { throw 'The API key cannot be empty.' }
        [Environment]::SetEnvironmentVariable($apiKeyName, $plainKey, 'User')
        $envValue = [Environment]::GetEnvironmentVariable($apiKeyName, 'User')
        [Environment]::SetEnvironmentVariable($apiKeyName, $envValue, 'Process')
    } finally {
        if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::FreeBSTR($pointer) }
        $plainKey = $null
    }
}

& $catalogUpdater -CodexHome $CodexHome -CatalogPath $catalogPath -ApiBaseUrl $apiBaseUrl
$catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not (@($catalog.models.slug) -contains $Model)) {
    throw "Model '$Model' is not in the generated OdiRouter catalog. Run -Model with one of the listed IDs."
}

$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
$providerHeader = "[model_providers.$providerName]"
$providerBlock = @(
    $providerHeader,
    ('name = "{0}"' -f $providerDisplayName),
    ('base_url = "{0}"' -f $apiBaseUrl),
    ('env_key = "{0}"' -f $apiKeyName),
    'wire_api = "responses"',
    'requires_openai_auth = false',
    ''
) -join [Environment]::NewLine
$providerPattern = '(?ms)^' + [regex]::Escape($providerHeader) + '.*?(?=^\[|\z)'
if ([regex]::IsMatch($config, $providerPattern)) {
    $config = [regex]::Replace($config, $providerPattern, $providerBlock, 1)
} else {
    $config = $config.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $providerBlock
}

# Preserve the active Polza model when that profile already exists.
$existingPolzaModel = 'gpt-5.6-sol'
$activePolzaMatch = [regex]::Match($config, '(?ms)^# BEGIN CODEX PROVIDER SWITCH\s+# Active profile: Polza AI.*?^model = "([^"]+)"')
if ($activePolzaMatch.Success) { $existingPolzaModel = $activePolzaMatch.Groups[1].Value }

if (-not [regex]::IsMatch($config, '(?ms)^' + [regex]::Escape($beginMarker) + '.*?^' + [regex]::Escape($endMarker))) {
    $initialBlock = @(
        $beginMarker,
        '# Active profile: OdiRouter',
        ('model_provider = "{0}"' -f $providerName),
        ('model = "{0}"' -f $Model),
        ('model_reasoning_effort = "{0}"' -f $Reasoning),
        ('model_catalog_json = "{0}"' -f $catalogPath.Replace('\', '\\')),
        $endMarker
    ) -join [Environment]::NewLine
    $config = $initialBlock + [Environment]::NewLine + [Environment]::NewLine + $config.TrimStart()
}
[IO.File]::WriteAllText($configPath, $config, [Text.UTF8Encoding]::new($false))

$profiles = @(
    [ordered]@{ key='OpenAI'; displayName='OpenAI'; modelProvider='openai'; reasoning='medium' },
    [ordered]@{ key='Polza'; displayName='Polza AI'; modelProvider='polza'; model=$existingPolzaModel; reasoning='low'; catalogPath=(Join-Path $CodexHome 'polza-models.json'); apiKeyName='POLZA_API_KEY' },
    [ordered]@{ key='OdiRouter'; displayName='OdiRouter'; modelProvider=$providerName; model=$Model; reasoning=$Reasoning; catalogPath=$catalogPath; apiKeyName=$apiKeyName }
)
[ordered]@{ profiles = @($profiles) } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
Copy-Item -LiteralPath $switcherSource -Destination $switcherTarget -Force
Copy-Item -LiteralPath $testScriptSource -Destination $testScriptTarget -Force

$desktop = [Environment]::GetFolderPath('Desktop')
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut((Join-Path $desktop 'Codex - OdiRouter.lnk'))
$shortcut.TargetPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File `"$switcherTarget`" -Provider OdiRouter"
$shortcut.WorkingDirectory = $CodexHome
$openAiShortcutPath = Join-Path $desktop 'Codex - OpenAI.lnk'
if (Test-Path -LiteralPath $openAiShortcutPath) {
    $openAiShortcut = $shell.CreateShortcut($openAiShortcutPath)
    if (-not [string]::IsNullOrWhiteSpace($openAiShortcut.IconLocation)) {
        $shortcut.IconLocation = $openAiShortcut.IconLocation
    }
}
if ([string]::IsNullOrWhiteSpace($shortcut.IconLocation)) {
    $codexApp = Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.InstallLocation 'app\ChatGPT.exe') } |
        Select-Object -First 1
    if ($codexApp) { $shortcut.IconLocation = Join-Path $codexApp.InstallLocation 'app\ChatGPT.exe' }
}
$shortcut.Description = 'Switch Codex Desktop to OdiRouter and restart it'
$shortcut.Save()

Add-Content -LiteralPath (Join-Path $CodexHome 'odirouter-install.log') -Encoding UTF8 -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Model=$Model Models=$(@($catalog.models).Count) Backup=$backupPath"
Write-Host ''
Write-Host 'OdiRouter profile installed successfully.' -ForegroundColor Green
Write-Host "Default model: $Model"
Write-Host "Catalog models: $(@($catalog.models).Count)"
Write-Host "Backup: $backupPath"
Write-Host 'The current active Codex profile was left unchanged.'
if (-not [Environment]::GetEnvironmentVariable($apiKeyName, 'User')) {
    Write-Host 'The OdiRouter API key is not configured yet. The first OdiRouter shortcut launch will ask for it securely.' -ForegroundColor Yellow
}

