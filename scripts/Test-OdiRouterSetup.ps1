[CmdletBinding()]
param(
    [string]$CodexHome = (Join-Path $env:USERPROFILE '.codex')
)

$configPath = Join-Path $CodexHome 'config.toml'
$catalogPath = Join-Path $CodexHome 'odirouter-models.json'
$settingsPath = Join-Path $CodexHome 'provider-switch.settings.json'
$switcherPath = Join-Path $CodexHome 'switch-codex-provider.ps1'
$config = if (Test-Path -LiteralPath $configPath) { Get-Content -LiteralPath $configPath -Raw } else { '' }
$catalog = if (Test-Path -LiteralPath $catalogPath) { Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json } else { $null }
$profiles = @()
if (Test-Path -LiteralPath $settingsPath) {
    $profiles = @((Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json).profiles)
}

[ordered]@{
    ConfigExists = Test-Path -LiteralPath $configPath
    OdiRouterIsActive = $config -match '(?m)^model_provider\s*=\s*"odirouter"'
    ProviderBlockCount = ([regex]::Matches($config, '(?m)^\[model_providers\.odirouter\]')).Count
    CatalogExists = Test-Path -LiteralPath $catalogPath
    CatalogModelCount = @($catalog.models).Count
    DefaultModelAvailable = -not $catalog -or (@($catalog.models.slug) -contains 'gpt-5.6-sol')
    ProfileCount = $profiles.Count
    SwitcherExists = Test-Path -LiteralPath $switcherPath
    ApiKeyConfigured = -not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('ODIROUTER_API_KEY', 'User'))
} | Format-List

