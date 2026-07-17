$ErrorActionPreference = "Stop"

function Add-Failure([string]$Message) {
    $script:Failures += $Message
}

function Write-JsonFile {
    param([string]$Path, $Data)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $json = ($Data | ConvertTo-Json -Depth 40) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($Path, $json.TrimEnd() + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

$script:Failures = @()
$launcher = "operations/autonomous_inner_motor/start_agent_life_v1.ps1"
$proofPath = "tests/self_development/AGENT_LIFE_LAUNCHER_V1_PROOF.json"

if (-not (Test-Path $launcher)) { Add-Failure "missing_launcher" }
else {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $launcher), [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) { Add-Failure "launcher_parse_errors" }
    $paramBlock = $ast.ParamBlock
    if ($null -eq $paramBlock) { Add-Failure "missing_param_block" }
    else {
        $params = @($paramBlock.Parameters)
        if (@($params).Count -ne 1) { Add-Failure "launcher_must_have_exactly_one_parameter" }
        if (@($params).Count -eq 1 -and $params[0].Name.VariablePath.UserPath -ne "DurationMinutes") { Add-Failure "only_parameter_must_be_DurationMinutes" }
    }

    $text = Get-Content $launcher -Raw
    $required = @(
        "-Mode SandboxExploration",
        "-EnableDeepThinking",
        "-EnableMemoryLearning",
        "-MemoryIngestionMode QueueOnly",
        'Convert-JsonCompatible',
        "action_execution_allowed = `$false",
        "codex_allowed = `$false",
        "web_allowed = `$false",
        "git_mutation_allowed = `$false",
        "repair_execution_allowed = `$false"
    )
    foreach ($needle in $required) {
        if ($text -notlike "*$needle*") { Add-Failure "missing_required_canonical_setting: $needle" }
    }
    $forbiddenParams = @("Mode", "EnableDeepThinking", "EnableMemoryLearning", "MemoryIngestionMode", "AllowActionExecution", "AllowCodex", "AllowWeb")
    if ($paramBlock) {
        foreach ($p in @($paramBlock.Parameters)) {
            $name = $p.Name.VariablePath.UserPath
            if ($forbiddenParams -contains $name) { Add-Failure "forbidden_user_facing_parameter: $name" }
        }
    }
}

$proof = [ordered]@{
    schema = "agent_life_launcher_v1_validation"
    status = if (@($script:Failures).Count -eq 0) { "PASS_AGENT_LIFE_LAUNCHER_V1" } else { "FAIL_AGENT_LIFE_LAUNCHER_V1" }
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    launcher = $launcher
    user_required_parameter = "DurationMinutes"
    canonical_contract = [ordered]@{
        one_launch_way = $true
        user_mode_choice_allowed = $false
        mode = "SandboxExploration"
        enable_deep_thinking = $true
        enable_memory_learning = $true
        memory_ingestion_mode = "QueueOnly"
        action_execution_allowed = $false
        codex_allowed = $false
        web_allowed = $false
        git_mutation_allowed = $false
        repair_execution_allowed = $false
    }
    failures = $script:Failures
    boundary = [ordered]@{
        validator_did_not_start_agent_life = $true
        active_memory_mutated = $false
        live_process_touched = $false
        codex_launched = $false
        web_launched = $false
    }
}
Write-JsonFile -Path $proofPath -Data $proof
$proof.status
if ($proof.status -ne "PASS_AGENT_LIFE_LAUNCHER_V1") { exit 1 }
exit 0
