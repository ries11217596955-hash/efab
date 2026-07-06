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
        name = $Name
        category = $Category
        status = if ($Passed) { 'PASS' } else { 'FAIL' }
        detail = $Detail
    }) | Out-Null

    if (-not $Passed) {
        $script:FailReasons.Add("$Name :: $Detail") | Out-Null
    }
}

function Read-JsonFile {
    param([string]$Path)

    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Copy-JsonObject {
    param([object]$Value)

    if ($null -eq $Value) {
        return $null
    }

    return ($Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json)
}

$script:Checks = [System.Collections.ArrayList]::new()
$script:FailReasons = [System.Collections.ArrayList]::new()

$resolvedRunId = if ([string]::IsNullOrWhiteSpace($RunId)) { New-RunId } else { $RunId }

$scriptPath = Split-Path -Parent $PSCommandPath
$repoRoot = (Resolve-Path (Join-Path $scriptPath '..')).Path
Set-Location -LiteralPath $repoRoot

$runDir = Join-Path $repoRoot "runs/$resolvedRunId"
New-Item -ItemType Directory -Path $runDir -Force | Out-Null

$requiredPaths = @(
    'GENESIS_MASTER_PLAN.md',
    'CAPABILITY_ROADMAP.json',
    'GENESIS_STATE.json',
    'TASK_QUEUE.json',
    'contracts/build_decision.schema.json',
    'modules/read_genesis_plan.ps1',
    'modules/read_genesis_state.ps1',
    'modules/read_capability_roadmap.ps1',
    'modules/read_task_queue.ps1',
    'modules/select_next_capability.ps1',
    'modules/select_next_task.ps1',
    'modules/emit_build_decision.ps1',
    'validators/validate_self_build_control_core.ps1'
)

foreach ($relativePath in $requiredPaths) {
    $fullPath = Join-Path $repoRoot $relativePath
    Add-CheckResult -Name "path::$relativePath" -Passed (Test-Path -LiteralPath $fullPath) -Detail "Expected present: $relativePath" -Category 'structure'
}

$jsonTargets = @(
    'CAPABILITY_ROADMAP.json',
    'GENESIS_STATE.json',
    'TASK_QUEUE.json',
    'contracts/build_decision.schema.json'
)

foreach ($jsonRelPath in $jsonTargets) {
    $jsonFullPath = Join-Path $repoRoot $jsonRelPath
    try {
        $null = Read-JsonFile -Path $jsonFullPath
        Add-CheckResult -Name "json::$jsonRelPath" -Passed $true -Detail 'Valid JSON parse.' -Category 'json'
    }
    catch {
        Add-CheckResult -Name "json::$jsonRelPath" -Passed $false -Detail "Invalid JSON parse: $($_.Exception.Message)" -Category 'json'
    }
}

. (Join-Path $repoRoot 'modules/read_genesis_plan.ps1')
. (Join-Path $repoRoot 'modules/read_genesis_state.ps1')
. (Join-Path $repoRoot 'modules/read_capability_roadmap.ps1')
. (Join-Path $repoRoot 'modules/read_task_queue.ps1')
. (Join-Path $repoRoot 'modules/select_next_capability.ps1')
. (Join-Path $repoRoot 'modules/select_next_task.ps1')
. (Join-Path $repoRoot 'modules/emit_build_decision.ps1')

$plan = $null
$genesisState = $null
$roadmap = $null
$taskQueue = $null
$selectedCapability = $null
$selectedTask = $null
$buildDecision = $null

try {
    $plan = Read-GenesisPlan -RepoRoot $repoRoot
    Add-CheckResult -Name 'module::read_genesis_plan' -Passed ($plan.contains_phase_1 -and $plan.contains_gate) -Detail 'Genesis plan exposes PHASE 1 and its gate.' -Category 'module'
}
catch {
    Add-CheckResult -Name 'module::read_genesis_plan' -Passed $false -Detail $_.Exception.Message -Category 'module'
}

try {
    $genesisState = Read-GenesisState -RepoRoot $repoRoot
    Add-CheckResult -Name 'module::read_genesis_state' -Passed ($genesisState.current_phase -eq 'PHASE_1' -and $genesisState.current_capability -eq 'self_build_control_core') -Detail "Phase=$($genesisState.current_phase); capability=$($genesisState.current_capability)" -Category 'module'
}
catch {
    Add-CheckResult -Name 'module::read_genesis_state' -Passed $false -Detail $_.Exception.Message -Category 'module'
}

try {
    $roadmap = Read-CapabilityRoadmap -RepoRoot $repoRoot
    Add-CheckResult -Name 'module::read_capability_roadmap' -Passed ($null -ne $roadmap.capabilities) -Detail 'Capability roadmap loaded.' -Category 'module'
}
catch {
    Add-CheckResult -Name 'module::read_capability_roadmap' -Passed $false -Detail $_.Exception.Message -Category 'module'
}

try {
    $taskQueue = Read-TaskQueue -RepoRoot $repoRoot
    Add-CheckResult -Name 'module::read_task_queue' -Passed ($null -ne $taskQueue.tasks) -Detail 'Task queue loaded.' -Category 'module'
}
catch {
    Add-CheckResult -Name 'module::read_task_queue' -Passed $false -Detail $_.Exception.Message -Category 'module'
}

try {
    $selectedCapability = Select-NextCapability -Roadmap $roadmap -GenesisState $genesisState
    Add-CheckResult -Name 'module::select_next_capability' -Passed ($selectedCapability.id -eq 'self_build_control_core') -Detail "Selected capability=$($selectedCapability.id)" -Category 'module'
}
catch {
    Add-CheckResult -Name 'module::select_next_capability' -Passed $false -Detail $_.Exception.Message -Category 'module'
}

try {
    $selectedTask = Select-NextTask -TaskQueue $taskQueue -SelectedCapability $selectedCapability
    Add-CheckResult -Name 'module::select_next_task' -Passed ($selectedTask.task_id -eq 'TASK_SELF_BUILD_CONTROL_CORE_001') -Detail "Selected task=$($selectedTask.task_id)" -Category 'module'
}
catch {
    Add-CheckResult -Name 'module::select_next_task' -Passed $false -Detail $_.Exception.Message -Category 'module'
}

try {
    $buildDecision = New-BuildDecision -Plan $plan -GenesisState $genesisState -SelectedCapability $selectedCapability -SelectedTask $selectedTask -DecisionId "BUILD_DECISION_$resolvedRunId"
    Add-CheckResult -Name 'module::emit_build_decision' -Passed ($buildDecision.status -eq 'READY' -and $buildDecision.selected_task.task_id -eq 'TASK_SELF_BUILD_CONTROL_CORE_001') -Detail 'Build decision emitted and aligned.' -Category 'module'
}
catch {
    Add-CheckResult -Name 'module::emit_build_decision' -Passed $false -Detail $_.Exception.Message -Category 'module'
}

$overallPass = ($script:FailReasons.Count -eq 0)
$status = if ($overallPass) { 'PASS' } else { 'FAIL' }
$stopReason = if ($overallPass) { $null } else { ($script:FailReasons -join ' | ') }

$beforeState = Copy-JsonObject -Value $genesisState
$beforeQueue = Copy-JsonObject -Value $taskQueue

$stateDelta = [ordered]@{
    applied = $false
    before = $beforeState
    after = $beforeState
}

$taskDelta = [ordered]@{
    applied = $false
    before = [ordered]@{
        active_task_id = if ($null -ne $beforeQueue) { $beforeQueue.active_task_id } else { $null }
        self_build_control_core_task = if ($null -ne $beforeQueue) { ($beforeQueue.tasks | Where-Object { $_.task_id -eq 'TASK_SELF_BUILD_CONTROL_CORE_001' } | Select-Object -First 1) } else { $null }
    }
    after = [ordered]@{
        active_task_id = if ($null -ne $beforeQueue) { $beforeQueue.active_task_id } else { $null }
        self_build_control_core_task = if ($null -ne $beforeQueue) { ($beforeQueue.tasks | Where-Object { $_.task_id -eq 'TASK_SELF_BUILD_CONTROL_CORE_001' } | Select-Object -First 1) } else { $null }
        next_task = $null
    }
}

$nextTask = $null

if ($FinalizePhase -and $overallPass) {
    $currentCap = $roadmap.capabilities | Where-Object { $_.id -eq 'self_build_control_core' } | Select-Object -First 1
    $nextCap = $roadmap.capabilities | Where-Object { $_.id -eq 'self_build_execution_loop' } | Select-Object -First 1
    $currentTask = $taskQueue.tasks | Where-Object { $_.task_id -eq 'TASK_SELF_BUILD_CONTROL_CORE_001' } | Select-Object -First 1

    $currentCap.status = 'COMPLETED'
    $nextCap.status = 'ACTIVE'

    $genesisState.current_phase = 'PHASE_2'
    $genesisState.current_capability = 'self_build_execution_loop'
    if (-not ($genesisState.completed_capabilities -contains 'self_build_control_core')) {
        $genesisState.completed_capabilities += 'self_build_control_core'
    }
    $genesisState.last_run_status = 'PASS'

    $currentTask.status = 'COMPLETED'
    $taskQueue.active_task_id = 'TASK_SELF_BUILD_EXECUTION_LOOP_001'

    $newTask = [ordered]@{
        task_id = 'TASK_SELF_BUILD_EXECUTION_LOOP_001'
        capability_id = 'self_build_execution_loop'
        status = 'ACTIVE'
        objective = 'Implement the self-build execution loop: execute an approved build task, run validators, emit run artifacts, update state and queue, and continue only when gates remain valid.'
        expected_gate = 'SELF_BUILD_EXECUTION_LOOP_READY'
    }

    $existingNextTask = $taskQueue.tasks | Where-Object { $_.task_id -eq 'TASK_SELF_BUILD_EXECUTION_LOOP_001' } | Select-Object -First 1
    if ($null -eq $existingNextTask) {
        $taskQueue.tasks += $newTask
    }

    $nextTask = 'TASK_SELF_BUILD_EXECUTION_LOOP_001'

    ($roadmap | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $repoRoot 'CAPABILITY_ROADMAP.json') -Encoding UTF8
    ($genesisState | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $repoRoot 'GENESIS_STATE.json') -Encoding UTF8
    ($taskQueue | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $repoRoot 'TASK_QUEUE.json') -Encoding UTF8

    $stateDelta = [ordered]@{
        applied = $true
        before = $beforeState
        after = $genesisState
    }

    $taskDelta = [ordered]@{
        applied = $true
        before = [ordered]@{
            active_task_id = $beforeQueue.active_task_id
            self_build_control_core_task = ($beforeQueue.tasks | Where-Object { $_.task_id -eq 'TASK_SELF_BUILD_CONTROL_CORE_001' } | Select-Object -First 1)
        }
        after = [ordered]@{
            active_task_id = $taskQueue.active_task_id
            self_build_control_core_task = ($taskQueue.tasks | Where-Object { $_.task_id -eq 'TASK_SELF_BUILD_CONTROL_CORE_001' } | Select-Object -First 1)
            next_task = ($taskQueue.tasks | Where-Object { $_.task_id -eq 'TASK_SELF_BUILD_EXECUTION_LOOP_001' } | Select-Object -First 1)
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
    mode = 'PHASE_1_CLOSEOUT'
    status = $status
    task_executed = 'TASK_SELF_BUILD_CONTROL_CORE_001'
    validators = @('validators/validate_self_build_control_core.ps1')
    next_task = $nextTask
    stop_reason = $stopReason
}

$artifactMap = [ordered]@{
    run_id = $resolvedRunId
    artifacts = @(
        'BUILD_DECISION.json',
        'VALIDATION_REPORT.json',
        'RUN_REPORT.json',
        'STATE_DELTA.json',
        'TASK_DELTA.json',
        'ARTIFACT_MAP.json'
    ) | ForEach-Object { Join-Path "runs/$resolvedRunId" $_ }
}

($buildDecision | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $runDir 'BUILD_DECISION.json') -Encoding UTF8
($validationReport | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $runDir 'VALIDATION_REPORT.json') -Encoding UTF8
($runReport | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $runDir 'RUN_REPORT.json') -Encoding UTF8
($stateDelta | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $runDir 'STATE_DELTA.json') -Encoding UTF8
($taskDelta | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $runDir 'TASK_DELTA.json') -Encoding UTF8
($artifactMap | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $runDir 'ARTIFACT_MAP.json') -Encoding UTF8

if ($overallPass) {
    Write-Host "PASS :: self_build_control_core checks passed. run_id=$resolvedRunId"
}
else {
    Write-Host "FAIL :: self_build_control_core checks failed. run_id=$resolvedRunId"
    Write-Host "STOP_REASON :: $stopReason"
}

if ($overallPass) {
    exit 0
}
else {
    exit 1
}

