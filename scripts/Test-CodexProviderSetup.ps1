$ErrorActionPreference = 'Continue'
$codexHome = Join-Path $env:USERPROFILE '.codex'
$configPath = Join-Path $codexHome 'config.toml'
$settingsPath = Join-Path $codexHome 'provider-switch.settings.json'
$switcherPath = Join-Path $codexHome 'Switch-CodexProvider.ps1'

$results = [ordered]@{}
$results.ConfigExists = Test-Path -LiteralPath $configPath
$results.SettingsExist = Test-Path -LiteralPath $settingsPath
$results.SwitcherExists = Test-Path -LiteralPath $switcherPath
if ($results.SettingsExist) {
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    $results.Provider = $settings.providerName
    $results.Model = $settings.model
    $provider = Get-Content -LiteralPath $configPath -Raw
    $results.ProviderBlockExists = $provider.Contains("[model_providers.$($settings.providerName)]")
    $results.SwitchBlockExists = $provider.Contains('# BEGIN CODEX PROVIDER SWITCH')
}
$results | Format-List

