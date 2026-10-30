[CmdletBinding()]
param(
    [string]$Model,
    [string]$CodexHome = (Join-Path $env:USERPROFILE '.codex'),
    [switch]$SkipApiKeyPrompt
)

$ErrorActionPreference = 'Stop'
$apiBaseUrl = 'https://polza.ai/api/v1/'
$apiKeyName = 'POLZA_API_KEY'
$configPath = Join-Path $CodexHome 'config.toml'
$catalogPath = Join-Path $CodexHome 'polza-models.json'
$logPath = Join-Path $CodexHome 'polza-install.log'
$testScriptSource = Join-Path $PSScriptRoot 'Test-PolzaSetup.ps1'
$testScriptTarget = Join-Path $CodexHome 'Test-PolzaSetup.ps1'

New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null
if (-not (Test-Path -LiteralPath $configPath)) { New-Item -ItemType File -Path $configPath -Force | Out-Null }
$backupPath = Join-Path $CodexHome ("config.before-polza.{0}.toml" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
Copy-Item -LiteralPath $configPath -Destination $backupPath

$apiKey = [Environment]::GetEnvironmentVariable($apiKeyName, 'User')
if (-not $SkipApiKeyPrompt) {
    $secureKey = Read-Host 'Enter your Polza AI API key' -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
    try {
        $apiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        [Environment]::SetEnvironmentVariable($apiKeyName, $apiKey, 'User')
    } finally {
        if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
    }
}
if (-not $apiKey) { throw 'POLZA_API_KEY is not configured.' }

Write-Host 'Downloading the Polza AI model list...' -ForegroundColor Cyan
$response = Invoke-RestMethod -Uri ($apiBaseUrl + 'models') -Headers @{ Authorization = "Bearer $apiKey" } -Method Get
$availableModels = @($response.data)
if (-not $availableModels.Count) { throw 'Polza returned an empty model list.' }
$visionModels = @($availableModels | Where-Object { @($_.architecture.input_modalities) -contains 'image' })
if (-not $visionModels.Count) { throw 'No image-capable models were returned by Polza.' }

if (-not $Model) {
    Write-Host ''
    Write-Host 'Image-capable models (first 40):' -ForegroundColor Yellow
    $visionModels | Select-Object -First 40 | ForEach-Object { Write-Host ("  {0}  -  {1}" -f $_.id, $_.name) }
    Write-Host ''
    Write-Host "Polza returned $($visionModels.Count) image-capable models."
    $Model = Read-Host 'Enter the full model ID from the list or your Polza account'
}
if (-not ($availableModels.id -contains $Model)) { throw "Model '$Model' is not available for this Polza account." }

$priority = 10000
$catalogModels = foreach ($item in $visionModels) {
    $efforts = @($item.reasoning.supported_efforts | Where-Object { $_ -in @('minimal', 'low', 'medium', 'high', 'xhigh', 'max') })
    $reasoningLevels = foreach ($effort in $efforts) {
        [ordered]@{ effort = $effort; description = "Reasoning effort: $effort" }
    }
    $defaultEffort = [string]$item.reasoning.default_effort
    if ($defaultEffort -notin $efforts) { $defaultEffort = if ($efforts -contains 'medium') { 'medium' } elseif ($efforts) { $efforts[0] } else { 'medium' } }
    [ordered]@{
        slug = [string]$item.id
        display_name = if ($item.name) { [string]$item.name } else { [string]$item.id }
        description = [string]$item.short_description
        default_reasoning_level = $defaultEffort
        supported_reasoning_levels = @($reasoningLevels)
        shell_type = 'unified_exec'
        visibility = 'list'
        supported_in_api = $true
        priority = $priority--
        additional_speed_tiers = @()
        service_tiers = @()
        availability_nux = $null
        upgrade = $null
        model_messages = $null
        include_skills_usage_instructions = $false
        include_plugin_usage_instructions = $false
        include_apps_usage_instructions = $false
        default_reasoning_summary = 'none'
        support_verbosity = $true
        default_verbosity = 'low'
        apply_patch_tool_type = 'freeform'
        web_search_tool_type = 'text_and_image'
        truncation_policy = [ordered]@{ mode = 'tokens'; limit = 10000 }
        input_modalities = @('text', 'image')
        supports_image_detail_original = $true
        context_window = [int64]$item.context_length
        max_context_window = [int64]$item.context_length
        comp_hash = 'polza-generated-v1'
        effective_context_window_percent = 95
        experimental_supported_tools = @()
        supports_search_tool = $true
        supports_experimental_context = $false
        use_responses_lite = $true
        supports_reasoning_effort_updates = $true
        node_repl_auto_review_required = $true
        node_repl_disabled = $false
        tool_mode = 'code_mode_only'
        multi_agent_version = 'v2'
        multi_agent_reasoning_effort = 'xhigh'
        base_instructions = 'You are Codex, a coding agent. Follow the user instructions and complete the requested work carefully.'
    }
}
$catalogJson = @{ models = @($catalogModels) } | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText($catalogPath, $catalogJson, [Text.UTF8Encoding]::new($false))

$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
$firstSection = [regex]::Match($config, '(?m)^\[')
if ($firstSection.Success) {
    $root = $config.Substring(0, $firstSection.Index)
    $sections = $config.Substring($firstSection.Index)
} else {
    $root = $config
    $sections = ''
}
$root = [regex]::Replace($root, '(?m)^\s*(model_provider|model|model_reasoning_effort|model_catalog_json)\s*=.*(?:\r?\n|$)', '')
$escapedCatalog = $catalogPath.Replace('\', '\\')
$activeConfig = @(
    '# Polza AI is the only active model provider',
    'model_provider = "polza"',
    ('model = "{0}"' -f $Model),
    'model_reasoning_effort = "medium"',
    ('model_catalog_json = "{0}"' -f $escapedCatalog),
    ''
) -join [Environment]::NewLine

$providerHeader = '[model_providers.polza]'
$providerBlock = @(
    $providerHeader,
    'name = "Polza AI"',
    ('base_url = "{0}"' -f $apiBaseUrl),
    ('env_key = "{0}"' -f $apiKeyName),
    'wire_api = "responses"',
    'requires_openai_auth = false',
    ''
) -join [Environment]::NewLine
$providerPattern = '(?ms)^\[model_providers\.polza\].*?(?=^\[|\z)'
if ([regex]::IsMatch($sections, $providerPattern)) {
    $sections = [regex]::Replace($sections, $providerPattern, $providerBlock, 1)
} else {
    $sections = $sections.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $providerBlock
}

$newConfig = $activeConfig + $root.Trim() + [Environment]::NewLine + [Environment]::NewLine + $sections.TrimStart()
[IO.File]::WriteAllText($configPath, $newConfig, [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath $testScriptSource -Destination $testScriptTarget -Force
Add-Content -LiteralPath $logPath -Encoding UTF8 -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Model=$Model VisionModels=$($visionModels.Count) Backup=$backupPath"
$apiKey = $null

Write-Host ''
Write-Host 'Polza-only setup completed successfully.' -ForegroundColor Green
Write-Host "Selected model: $Model"
Write-Host "Image-capable models: $($visionModels.Count)"
Write-Host "Backup: $backupPath"
Write-Host 'Close PowerShell and restart Codex Desktop.' -ForegroundColor Yellow

