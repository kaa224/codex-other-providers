[CmdletBinding()]
param(
    [string]$CodexHome = (Join-Path $env:USERPROFILE '.codex'),
    [string]$CatalogPath,
    [string]$ApiBaseUrl = 'https://api.odirouter.ai/v1'
)

$ErrorActionPreference = 'Stop'

if (-not $CatalogPath) {
    $CatalogPath = Join-Path $CodexHome 'odirouter-models.json'
}
New-Item -ItemType Directory -Path (Split-Path -Parent $CatalogPath) -Force | Out-Null

$websiteBaseUrl = ([uri]$ApiBaseUrl).GetLeftPart([UriPartial]::Authority)
$pricingUrl = "$websiteBaseUrl/api/pricing?p=1&page_size=1000"
Write-Host 'Downloading the public OdiRouter model catalog...' -ForegroundColor Cyan
$response = Invoke-RestMethod -Uri $pricingUrl -Method Get -TimeoutSec 60
$availableModels = @($response.data)

# Codex screenshots, tool calling and the Responses API need image-capable LLM entries.
$compatibleModels = @($availableModels | Where-Object {
    $_.model_family -eq 'llm' -and
    @($_.input_modalities) -contains 'Text' -and
    @($_.input_modalities) -contains 'Image' -and
    @($_.output_modalities) -contains 'Text' -and
    @($_.supported_endpoint_types) -contains 'openai-response'
})
if (-not $compatibleModels.Count) {
    throw 'OdiRouter returned no image-capable LLM models compatible with the Responses API.'
}

$priority = 10000
$catalogModels = foreach ($item in $compatibleModels) {
    $contextLength = [int64]$item.context_length
    if ($contextLength -le 0) { $contextLength = 128000 }
    [ordered]@{
        slug = [string]$item.model_name
        display_name = if ($item.display_name) { [string]$item.display_name } else { [string]$item.model_name }
        description = if ($item.description) { [string]$item.description } else { 'OdiRouter language model.' }
        default_reasoning_level = 'low'
        supported_reasoning_levels = @(
            [ordered]@{ effort = 'low'; description = 'Fast responses with lighter reasoning' },
            [ordered]@{ effort = 'medium'; description = 'Balances speed and reasoning depth' },
            [ordered]@{ effort = 'high'; description = 'Greater reasoning depth for complex tasks' }
        )
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
        context_window = $contextLength
        max_context_window = $contextLength
        comp_hash = 'odirouter-generated-v1'
        effective_context_window_percent = 95
        experimental_supported_tools = @()
        supports_search_tool = $false
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

$catalog = [ordered]@{ models = @($catalogModels) }
$catalogJson = $catalog | ConvertTo-Json -Depth 12
[IO.File]::WriteAllText($CatalogPath, $catalogJson, [Text.UTF8Encoding]::new($false))

Write-Host "Created $CatalogPath with $($catalogModels.Count) screenshot-capable models." -ForegroundColor Green
$catalogModels | ForEach-Object { $_.slug } | Sort-Object

