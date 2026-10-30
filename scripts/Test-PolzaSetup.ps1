$ErrorActionPreference = 'Continue'
$codexHome = Join-Path $env:USERPROFILE '.codex'
$configPath = Join-Path $codexHome 'config.toml'
$catalogPath = Join-Path $codexHome 'polza-models.json'
$config = if (Test-Path -LiteralPath $configPath) { Get-Content -LiteralPath $configPath -Raw } else { '' }
$catalog = if (Test-Path -LiteralPath $catalogPath) { Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json } else { $null }

[ordered]@{
    ConfigExists = Test-Path -LiteralPath $configPath
    PolzaIsActive = $config -match '(?m)^model_provider\s*=\s*"polza"'
    ProviderBlockExists = $config.Contains('[model_providers.polza]')
    CatalogExists = Test-Path -LiteralPath $catalogPath
    CatalogModelCount = @($catalog.models).Count
    ApiKeyConfigured = -not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('POLZA_API_KEY', 'User'))
} | Format-List

