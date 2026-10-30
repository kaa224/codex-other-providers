param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('OpenAI', 'Other')]
    [string]$Provider,
    [switch]$NoRestart
)

$ErrorActionPreference = 'Stop'
$codexHome = Join-Path $env:USERPROFILE '.codex'
$configPath = Join-Path $codexHome 'config.toml'
$settingsPath = Join-Path $codexHome 'provider-switch.settings.json'
$logPath = Join-Path $codexHome 'provider-switch.log'
$beginMarker = '# BEGIN CODEX PROVIDER SWITCH'
$endMarker = '# END CODEX PROVIDER SWITCH'

if (-not (Test-Path -LiteralPath $settingsPath)) { throw "Missing settings: $settingsPath" }
if (-not (Test-Path -LiteralPath $configPath)) { throw "Missing Codex config: $configPath" }
$settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json

if ($Provider -eq 'OpenAI') {
    $profileLines = @(
        $beginMarker,
        '# Active profile: OpenAI',
        'model_provider = "openai"',
        ('model_reasoning_effort = "{0}"' -f $settings.openaiReasoning),
        $endMarker
    )
} else {
    $profileLines = @(
        $beginMarker,
        ('# Active profile: {0}' -f $settings.providerDisplayName),
        ('model_provider = "{0}"' -f $settings.providerName),
        ('model = "{0}"' -f $settings.model),
        ('model_reasoning_effort = "{0}"' -f $settings.otherReasoning)
    )
    if ($settings.catalogPath) {
        $escapedCatalog = $settings.catalogPath.Replace('\', '\\')
        $profileLines += ('model_catalog_json = "{0}"' -f $escapedCatalog)
    }
    $profileLines += $endMarker
}

$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
$pattern = '(?ms)^' + [regex]::Escape($beginMarker) + '.*?^' + [regex]::Escape($endMarker)
if (-not [regex]::IsMatch($config, $pattern)) { throw 'Provider switch block was not found in config.toml.' }
$updated = [regex]::Replace($config, $pattern, ($profileLines -join [Environment]::NewLine), 1)
$temporaryPath = "$configPath.switching"
[IO.File]::WriteAllText($temporaryPath, $updated, [Text.UTF8Encoding]::new($false))
Move-Item -LiteralPath $temporaryPath -Destination $configPath -Force
Add-Content -LiteralPath $logPath -Encoding UTF8 -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Provider=$Provider Restart=$(-not $NoRestart)"

if (-not $NoRestart) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show("Provider switched to $Provider. Codex will restart now.", 'Codex provider switch') | Out-Null
    Get-Process -Name ChatGPT -ErrorAction SilentlyContinue | Stop-Process -Force
    $deadline = (Get-Date).AddSeconds(10)
    while ((Get-Process -Name ChatGPT -ErrorAction SilentlyContinue) -and ((Get-Date) -lt $deadline)) { Start-Sleep -Milliseconds 250 }
    Start-Process explorer.exe 'shell:AppsFolder\OpenAI.Codex_2p2nqsd0c76g0!App'
}

