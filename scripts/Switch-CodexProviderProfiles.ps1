param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('OpenAI', 'Polza', 'OdiRouter')]
    [string]$Provider,

    [switch]$NoRestart,

    [string]$CodexHome = (Join-Path $env:USERPROFILE '.codex')
)

$ErrorActionPreference = 'Stop'
$configPath = Join-Path $CodexHome 'config.toml'
$settingsPath = Join-Path $CodexHome 'provider-switch.settings.json'
$logPath = Join-Path $CodexHome 'provider-switch.log'
$beginMarker = '# BEGIN CODEX PROVIDER SWITCH'
$endMarker = '# END CODEX PROVIDER SWITCH'

if (-not (Test-Path -LiteralPath $settingsPath)) { throw "Missing settings: $settingsPath" }
if (-not (Test-Path -LiteralPath $configPath)) { throw "Missing Codex config: $configPath" }
$settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$profile = @($settings.profiles | Where-Object { $_.key -eq $Provider }) | Select-Object -First 1
if (-not $profile) { throw "Provider profile '$Provider' is not configured." }

$apiKeyName = [string]$profile.apiKeyName
if ($apiKeyName -and -not [Environment]::GetEnvironmentVariable($apiKeyName, 'User')) {
    $label = if ($profile.displayName) { $profile.displayName } else { $Provider }
    $secureKey = Read-Host "Enter $label API key" -AsSecureString
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

if ($Provider -eq 'OdiRouter') {
    $key = [Environment]::GetEnvironmentVariable($apiKeyName, 'User')
    try {
        Invoke-RestMethod -Uri 'https://api.odirouter.ai/v1/models/catalog?category=llm&page=1&page_size=1' `
            -Headers @{ Authorization = "Bearer $key" } -Method Get -TimeoutSec 30 | Out-Null
    } catch {
        throw "OdiRouter API key validation failed: $($_.Exception.Message)"
    }
}

$profileLines = @(
    $beginMarker,
    ('# Active profile: {0}' -f $profile.displayName),
    ('model_provider = "{0}"' -f $profile.modelProvider)
)
if ($profile.model) { $profileLines += ('model = "{0}"' -f $profile.model) }
if ($profile.reasoning) { $profileLines += ('model_reasoning_effort = "{0}"' -f $profile.reasoning) }
if ($profile.catalogPath) {
    $escapedCatalog = ([string]$profile.catalogPath).Replace('\', '\\')
    $profileLines += ('model_catalog_json = "{0}"' -f $escapedCatalog)
}
$profileLines += $endMarker

$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
$pattern = '(?ms)^' + [regex]::Escape($beginMarker) + '.*?^' + [regex]::Escape($endMarker)
if (-not [regex]::IsMatch($config, $pattern)) { throw 'Provider switch block was not found in config.toml.' }

$updatedConfig = [regex]::Replace($config, $pattern, ($profileLines -join [Environment]::NewLine), 1)
$temporaryPath = "$configPath.switching"
[IO.File]::WriteAllText($temporaryPath, $updatedConfig, [Text.UTF8Encoding]::new($false))
Move-Item -LiteralPath $temporaryPath -Destination $configPath -Force
Add-Content -LiteralPath $logPath -Encoding UTF8 -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Provider=$Provider ConfigUpdated=True Restart=$(-not $NoRestart)"

if (-not $NoRestart) {
    Get-Process -Name ChatGPT -ErrorAction SilentlyContinue | Stop-Process -Force
    $deadline = (Get-Date).AddSeconds(10)
    while ((Get-Process -Name ChatGPT -ErrorAction SilentlyContinue) -and ((Get-Date) -lt $deadline)) {
        Start-Sleep -Milliseconds 250
    }
    Start-Process explorer.exe 'shell:AppsFolder\OpenAI.Codex_2p2nqsd0c76g0!App'
}

