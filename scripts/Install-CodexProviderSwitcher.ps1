[CmdletBinding()]
param(
    [string]$ProviderName = 'polza',
    [string]$ProviderDisplayName = 'Polza AI',
    [string]$BaseUrl = 'https://polza.ai/api/v1/',
    [string]$EnvKey = 'POLZA_API_KEY',
    [Parameter(Mandatory = $true)][string]$Model,
    [string]$CatalogPath,
    [ValidateSet('responses', 'chat')][string]$WireApi = 'responses',
    [ValidateSet('minimal', 'low', 'medium', 'high', 'xhigh')][string]$OpenAIReasoning = 'medium',
    [ValidateSet('minimal', 'low', 'medium', 'high', 'xhigh')][string]$OtherReasoning = 'low',
    [string]$CodexHome = (Join-Path $env:USERPROFILE '.codex'),
    [switch]$SkipShortcuts,
    [switch]$SkipApiKeyPrompt
)

$ErrorActionPreference = 'Stop'
$configPath = Join-Path $CodexHome 'config.toml'
$switcherSource = Join-Path $PSScriptRoot 'Switch-CodexProvider.ps1'
$switcherTarget = Join-Path $CodexHome 'Switch-CodexProvider.ps1'
$settingsPath = Join-Path $CodexHome 'provider-switch.settings.json'
$beginMarker = '# BEGIN CODEX PROVIDER SWITCH'
$endMarker = '# END CODEX PROVIDER SWITCH'

New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null
if (-not (Test-Path -LiteralPath $configPath)) { New-Item -ItemType File -Path $configPath -Force | Out-Null }
$backup = Join-Path $CodexHome ("config.backup.{0}.toml" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
Copy-Item -LiteralPath $configPath -Destination $backup

if ($CatalogPath) {
    $CatalogPath = (Resolve-Path -LiteralPath $CatalogPath).Path
    Get-Content -LiteralPath $CatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null
}
if (-not $SkipApiKeyPrompt -and -not [Environment]::GetEnvironmentVariable($EnvKey, 'User')) {
    $secureKey = Read-Host "Enter API key for $ProviderDisplayName" -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
    try {
        $plainKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        [Environment]::SetEnvironmentVariable($EnvKey, $plainKey, 'User')
    } finally {
        if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
        $plainKey = $null
    }
}
Copy-Item -LiteralPath $switcherSource -Destination $switcherTarget -Force

$settings = [ordered]@{
    providerName = $ProviderName
    providerDisplayName = $ProviderDisplayName
    model = $Model
    catalogPath = $CatalogPath
    openaiReasoning = $OpenAIReasoning
    otherReasoning = $OtherReasoning
}
$settings | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding UTF8

$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
$providerHeader = "[model_providers.$ProviderName]"
$providerBlock = @(
    $providerHeader,
    ('name = "{0}"' -f $ProviderDisplayName),
    ('base_url = "{0}"' -f $BaseUrl),
    ('env_key = "{0}"' -f $EnvKey),
    ('wire_api = "{0}"' -f $WireApi),
    ''
) -join [Environment]::NewLine

$providerPattern = '(?ms)^' + [regex]::Escape($providerHeader) + '.*?(?=^\[|\z)'
if ([regex]::IsMatch($config, $providerPattern)) {
    $config = [regex]::Replace($config, $providerPattern, $providerBlock, 1)
} else {
    $config = $config.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $providerBlock
}

$initialBlock = @(
    $beginMarker,
    '# Active profile: OpenAI',
    'model_provider = "openai"',
    ('model_reasoning_effort = "{0}"' -f $OpenAIReasoning),
    $endMarker
) -join [Environment]::NewLine
$switchPattern = '(?ms)^' + [regex]::Escape($beginMarker) + '.*?^' + [regex]::Escape($endMarker)
if ([regex]::IsMatch($config, $switchPattern)) {
    $config = [regex]::Replace($config, $switchPattern, $initialBlock, 1)
} else {
    $config = $initialBlock + [Environment]::NewLine + [Environment]::NewLine + $config.TrimStart()
}
[IO.File]::WriteAllText($configPath, $config, [Text.UTF8Encoding]::new($false))

if (-not $SkipShortcuts) {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $shell = New-Object -ComObject WScript.Shell
    foreach ($item in @(@{Name='Codex - OpenAI';Value='OpenAI'}, @{Name="Codex - $ProviderDisplayName";Value='Other'})) {
        $shortcut = $shell.CreateShortcut((Join-Path $desktop ($item.Name + '.lnk')))
        $shortcut.TargetPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
        $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$switcherTarget`" -Provider $($item.Value)"
        $shortcut.WorkingDirectory = $CodexHome
        $shortcut.Save()
    }
}

Write-Host "Installed successfully. Backup: $backup" -ForegroundColor Green
Write-Host "Close all PowerShell windows so the new user environment variable becomes available."
Write-Host "Then use the new desktop shortcuts."

