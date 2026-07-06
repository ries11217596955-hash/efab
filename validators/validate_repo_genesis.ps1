[CmdletBinding()]
param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-RunId {
    return (Get-Date -Format 'yyyyMMdd_HHmmss')
}

function Add-CheckResult {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Detail,
        [string]$Category = 'validation'
    )

    $script:Checks.Add([ordered]@{
        name     = $Name
        category = $Category
        status   = if ($Passed) { 'PASS' } else { 'FAIL' }
        detail   = $Detail
    }) | Out-Null

    if (-not $Passed) {
        $script:FailReasons.Add("$Name :: $Detail") | Out-Null
    }
}

function Test-PathCheck {
    param(
        [string]$Path,
        [string]$Label
    )

    if (Test-Path -LiteralPath $Path) {
        Add-CheckResult -Name "path::$Label" -Passed $true -Detail "Found: $Path" -Category 'structure'
        return $true
    }

    Add-CheckResult -Name "path::$Label" -Passed $false -Detail "Missing: $Path" -Category 'structure'
    return $false
}

function Read-JsonFile {
    param([string]$Path)

    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

$script:Checks = [System.Collections.ArrayList]::new()
$script:FailReasons = [System.Collections.ArrayList]::new()

$resolvedRunId = if ([string]::IsNullOrWhiteSpace($RunId)) { New-RunId } else { $RunId }

$scriptPath = Split-Path -Parent $PSCommandPath
$repoRoot = (Resolve-Path (Join-Path $scriptPath '..')).Path
Set-Location -LiteralPath $repoRoot

$runDir = Join-Path $repoRoot "runs/$resolvedRunId"
New-Item -ItemType Directory -Path $runDir -Force | Out-Null

$rootFiles = @(
    'README.md',
    'AGENTS.md',
    'AGENT_MISSION.md',
    'GENESIS_MASTER_PLAN.md',
    'CAPABILITY_ROADMAP.json',
    'GENESIS_STATE.json',
    'TASK_QUEUE.json'
)

$contractFiles = @(
    'contracts/build_task.schema.json',
    'contracts/task_queue.schema.json',
    'contracts/external_agent_spec.schema.json',
    'contracts/run_report.schema.json',
    'contracts/capability_roadmap.schema.json',
    'contracts/validation_report.schema.json',
    'contracts/genesis_state.schema.json'
)

$orchestratorFiles = @('orchestrator/run.ps1')

$moduleFiles = @(
    'modules/read_genesis_plan.ps1',
    'modules/read_genesis_state.ps1',
    'modules/select_next_task.ps1',
    'modules/execute_build_task.ps1',
    'modules/run_validators.ps1',
    'modules/emit_run_report.ps1',
    'modules/update_genesis_state.ps1',
    'modules/update_task_queue.ps1'
)

$validatorFiles = @(
    'validators/validate_repo_genesis.ps1',
    'validators/validate_state_alignment.ps1',
    'validators/validate_task_queue_alignment.ps1',
    'validators/validate_run_report_contract.ps1',
    'validators/validate_external_agent_spec.ps1'
)

$externalSpecTemplateFiles = @(
    'specs/external_agent_spec_template/MISSION.md',
    'specs/external_agent_spec_template/INPUT_CONTRACT.json',
    'specs/external_agent_spec_template/OUTPUT_CONTRACT.json',
    'specs/external_agent_spec_template/CAPABILITY_REQUIREMENTS.json',
    'specs/external_agent_spec_template/VALIDATION_REQUIREMENTS.md',
    'specs/external_agent_spec_template/FORBIDDEN_SCOPE.md'
)

$placeholderFiles = @(
    'runs/.gitkeep',
    'generated_agents/.gitkeep'
)

$allRequiredPaths = @($rootFiles + $contractFiles + $orchestratorFiles + $moduleFiles + $validatorFiles + $externalSpecTemplateFiles + $placeholderFiles)
foreach ($requiredPath in $allRequiredPaths) {
    [void](Test-PathCheck -Path (Join-Path $repoRoot $requiredPath) -Label $requiredPath)
}

$jsonTargets = @(
    'CAPABILITY_ROADMAP.json',
    'GENESIS_STATE.json',
    'TASK_QUEUE.json'
)

foreach ($jsonRelPath in $jsonTargets) {
    $jsonFullPath = Join-Path $repoRoot $jsonRelPath
    if (Test-Path -LiteralPath $jsonFullPath) {
        try {
            $null = Read-JsonFile -Path $jsonFullPath
            Add-CheckResult -Name "json::$jsonRelPath" -Passed $true -Detail 'Valid JSON parse.' -Category 'json'
        }
        catch {
            Add-CheckResult -Name "json::$jsonRelPath" -Passed $false -Detail "Invalid JSON parse: $($_.Exception.Message)" -Category 'json'
        }
    }
}

Get-ChildItem -LiteralPath (Join-Path $repoRoot 'contracts') -Filter '*.json' -File | ForEach-Object {
    try {
        $null = Read-JsonFile -Path $_.FullName
        Add-CheckResult -Name "json::contracts/$($_.Name)" -Passed $true -Detail 'Valid JSON parse.' -Category 'json'
    }
    catch {
        Add-CheckResult -Name "json::contracts/$($_.Name)" -Passed $false -Detail "Invalid JSON parse: $($_.Exception.Message)" -Category 'json'
    }
}

Get-ChildItem -LiteralPath (Join-Path $repoRoot 'specs/external_agent_spec_template') -Filter '*.json' -File | ForEach-Object {
    try {
        $null = Read-JsonFile -Path $_.FullName
        Add-CheckResult -Name "json::specs/external_agent_spec_template/$($_.Name)" -Passed $true -Detail 'Valid JSON parse.' -Category 'json'
    }
    catch {
        Add-CheckResult -Name "json::specs/external_agent_spec_template/$($_.Name)" -Passed $false -Detail "Invalid JSON parse: $($_.Exception.Message)" -Category 'json'
    }
}

$capabilityRoadmap = $null
$genesisState = $null
$taskQueue = $null

try {
    $capabilityRoadmap = Read-JsonFile -Path (Join-Path $repoRoot 'CAPABILITY_ROADMAP.json')
    $genesisState = Read-JsonFile -Path (Join-Path $repoRoot 'GENESIS_STATE.json')
    $taskQueue = Read-JsonFile -Path (Join-Path $repoRoot 'TASK_QUEUE.json')
}
catch {
    Add-CheckResult -Name 'truth::load' -Passed $false -Detail "Unable to load truth files: $($_.Exception.Message)" -Category 'truth'
}

if ($null -ne $genesisState) {
    Add-CheckResult -Name 'truth::state.current_phase' -Passed ($genesisState.current_phase -eq 'PHASE_0') -Detail "Expected PHASE_0; actual $($genesisState.current_phase)" -Category 'truth'
    Add-CheckResult -Name 'truth::state.current_capability' -Passed ($genesisState.current_capability -eq 'repo_genesis') -Detail "Expected repo_genesis; actual $($genesisState.current_capability)" -Category 'truth'
    Add-CheckResult -Name 'truth::state.self_build_ready' -Passed ($genesisState.self_build_ready -eq $false) -Detail "Expected false; actual $($genesisState.self_build_ready)" -Category 'truth'
    Add-CheckResult -Name 'truth::state.external_agent_build_ready' -Passed ($genesisState.external_agent_build_ready -eq $false) -Detail "Expected false; actual $($genesisState.external_agent_build_ready)" -Category 'truth'
}

if ($null -ne $capabilityRoadmap) {
    $repoGenesisCap = $capabilityRoadmap.capabilities | Where-Object { $_.id -eq 'repo_genesis' } | Select-Object -First 1
    $selfBuildCoreCap = $capabilityRoadmap.capabilities | Where-Object { $_.id -eq 'self_build_control_core' } | Select-Object -First 1

    Add-CheckResult -Name 'truth::roadmap.repo_genesis.status' -Passed ($null -ne $repoGenesisCap -and $repoGenesisCap.status -eq 'ACTIVE') -Detail "Expected ACTIVE; actual $($repoGenesisCap.status)" -Category 'truth'
    Add-CheckResult -Name 'truth::roadmap.self_build_control_core.status' -Passed ($null -ne $selfBuildCoreCap -and $selfBuildCoreCap.status -eq 'PENDING') -Detail "Expected PENDING; actual $($selfBuildCoreCap.status)" -Category 'truth'
}

if ($null -ne $taskQueue) {
    Add-CheckResult -Name 'truth::queue.active_task_id' -Passed ($taskQueue.active_task_id -eq 'TASK_REPO_GENESIS_001') -Detail "Expected TASK_REPO_GENESIS_001; actual $($taskQueue.active_task_id)" -Category 'truth'
    $genesisTask = $taskQueue.tasks | Where-Object { $_.task_id -eq 'TASK_REPO_GENESIS_001' } | Select-Object -First 1
    Add-CheckResult -Name 'truth::queue.task.capability_id' -Passed ($null -ne $genesisTask -and $genesisTask.capability_id -eq 'repo_genesis') -Detail "Expected repo_genesis; actual $($genesisTask.capability_id)" -Category 'truth'
    Add-CheckResult -Name 'truth::queue.task.status' -Passed ($null -ne $genesisTask -and $genesisTask.status -eq 'ACTIVE') -Detail "Expected ACTIVE; actual $($genesisTask.status)" -Category 'truth'
    Add-CheckResult -Name 'truth::queue.task.expected_gate' -Passed ($null -ne $genesisTask -and $genesisTask.expected_gate -eq 'REPO_GENESIS_READY') -Detail "Expected REPO_GENESIS_READY; actual $($genesisTask.expected_gate)" -Category 'truth'
}

$overallPass = ($script:FailReasons.Count -eq 0)
$status = if ($overallPass) { 'PASS' } else { 'FAIL' }
$stopReason = if ($overallPass) { $null } else { ($script:FailReasons -join ' | ') }

$beforeState = $genesisState | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$beforeQueue = $taskQueue | ConvertTo-Json -Depth 20 | ConvertFrom-Json

$stateDelta = [ordered]@{
    applied = $false
    before  = $beforeState
    after   = $beforeState
}

$taskDelta = [ordered]@{
    applied = $false
    before  = [ordered]@{
        active_task_id = $beforeQueue.active_task_id
        repo_genesis_task = ($beforeQueue.tasks | Where-Object { $_.task_id -eq 'TASK_REPO_GENESIS_001' } | Select-Object -First 1)
    }
    after   = [ordered]@{
        active_task_id = $beforeQueue.active_task_id
        repo_genesis_task = ($beforeQueue.tasks | Where-Object { $_.task_id -eq 'TASK_REPO_GENESIS_001' } | Select-Object -First 1)
        next_task = $null
    }
}

$nextTask = $null

if ($FinalizePhase -and $overallPass) {
    $repoGenesisCap = $capabilityRoadmap.capabilities | Where-Object { $_.id -eq 'repo_genesis' } | Select-Object -First 1
    $selfBuildCoreCap = $capabilityRoadmap.capabilities | Where-Object { $_.id -eq 'self_build_control_core' } | Select-Object -First 1
    $repoGenesisTask = $taskQueue.tasks | Where-Object { $_.task_id -eq 'TASK_REPO_GENESIS_001' } | Select-Object -First 1

    $repoGenesisCap.status = 'COMPLETED'
    $selfBuildCoreCap.status = 'ACTIVE'

    $genesisState.current_phase = 'PHASE_1'
    $genesisState.current_capability = 'self_build_control_core'
    if (-not ($genesisState.completed_capabilities -contains 'repo_genesis')) {
        $genesisState.completed_capabilities += 'repo_genesis'
    }
    $genesisState.last_run_status = 'PASS'

    $repoGenesisTask.status = 'COMPLETED'
    $taskQueue.active_task_id = 'TASK_SELF_BUILD_CONTROL_CORE_001'

    $newTask = [ordered]@{
        task_id = 'TASK_SELF_BUILD_CONTROL_CORE_001'
        capability_id = 'self_build_control_core'
        status = 'ACTIVE'
        objective = 'Implement the self-build control core: read plan/state/queue, select the next approved task, and emit a decision object.'
        expected_gate = 'SELF_BUILD_CONTROL_CORE_READY'
    }

    $exists = $taskQueue.tasks | Where-Object { $_.task_id -eq 'TASK_SELF_BUILD_CONTROL_CORE_001' } | Select-Object -First 1
    if ($null -eq $exists) {
        $taskQueue.tasks += $newTask
    }

    $nextTask = 'TASK_SELF_BUILD_CONTROL_CORE_001'

    ($capabilityRoadmap | ConvertTo-Json -Depth 50) | Set-Content -LiteralPath (Join-Path $repoRoot 'CAPABILITY_ROADMAP.json') -Encoding UTF8
    ($genesisState | ConvertTo-Json -Depth 50) | Set-Content -LiteralPath (Join-Path $repoRoot 'GENESIS_STATE.json') -Encoding UTF8
    ($taskQueue | ConvertTo-Json -Depth 50) | Set-Content -LiteralPath (Join-Path $repoRoot 'TASK_QUEUE.json') -Encoding UTF8

    $stateDelta = [ordered]@{
        applied = $true
        before  = $beforeState
        after   = $genesisState
    }

    $taskDelta = [ordered]@{
        applied = $true
        before  = [ordered]@{
            active_task_id = $beforeQueue.active_task_id
            repo_genesis_task = ($beforeQueue.tasks | Where-Object { $_.task_id -eq 'TASK_REPO_GENESIS_001' } | Select-Object -First 1)
        }
        after   = [ordered]@{
            active_task_id = $taskQueue.active_task_id
            repo_genesis_task = ($taskQueue.tasks | Where-Object { $_.task_id -eq 'TASK_REPO_GENESIS_001' } | Select-Object -First 1)
            next_task = ($taskQueue.tasks | Where-Object { $_.task_id -eq 'TASK_SELF_BUILD_CONTROL_CORE_001' } | Select-Object -First 1)
        }
    }
}

$validationReport = [ordered]@{
    validation_run_id = $resolvedRunId
    status = $status
    checks = $script:Checks
}

$runReport = [ordered]@{
    run_id = $resolvedRunId
    mode = 'PHASE_0_CLOSEOUT'
    status = $status
    task_executed = 'TASK_REPO_GENESIS_001'
    validators = @('validators/validate_repo_genesis.ps1')
    next_task = $nextTask
    stop_reason = $stopReason
}

$artifactMap = [ordered]@{
    run_id = $resolvedRunId
    artifacts = @(
        'VALIDATION_REPORT.json',
        'RUN_REPORT.json',
        'STATE_DELTA.json',
        'TASK_DELTA.json',
        'ARTIFACT_MAP.json'
    ) | ForEach-Object { Join-Path "runs/$resolvedRunId" $_ }
}

($validationReport | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $runDir 'VALIDATION_REPORT.json') -Encoding UTF8
($runReport | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $runDir 'RUN_REPORT.json') -Encoding UTF8
($stateDelta | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $runDir 'STATE_DELTA.json') -Encoding UTF8
($taskDelta | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $runDir 'TASK_DELTA.json') -Encoding UTF8
($artifactMap | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $runDir 'ARTIFACT_MAP.json') -Encoding UTF8

if ($overallPass) {
    Write-Host "PASS :: repo_genesis checks passed. run_id=$resolvedRunId"
}
else {
    Write-Host "FAIL :: repo_genesis checks failed. run_id=$resolvedRunId"
    Write-Host "STOP_REASON :: $stopReason"
}

if ($overallPass) {
    exit 0
}
else {
    exit 1
}

