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
    if ($null -eq $Value) { return $null }
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
    'contracts/build_execution_result.schema.json',
    'contracts/build_task.schema.json',
    'contracts/task_queue.schema.json',
    'tasks/TASK_SELF_BUILD_EXECUTION_LOOP_001.json',
    'tasks/TASK_SELF_VALIDATION_RELEASE_GATES_001.json',
    'modules/load_build_task.ps1',
    'modules/execute_build_task.ps1',
    'modules/run_validators.ps1',
    'modules/update_genesis_state.ps1',
    'modules/update_task_queue.ps1',
    'modules/emit_run_report.ps1',
    'validators/validate_self_build_execution_loop.ps1'
)

foreach ($relativePath in $requiredPaths) {
    $fullPath = Join-Path $repoRoot $relativePath
    Add-CheckResult -Name "path::$relativePath" -Passed (Test-Path -LiteralPath $fullPath) -Detail "Expected present: $relativePath" -Category 'structure'
}

$jsonTargets = @(
    'CAPABILITY_ROADMAP.json',
    'GENESIS_STATE.json',
    'TASK_QUEUE.json',
    'contracts/build_execution_result.schema.json',
    'contracts/build_task.schema.json',
    'contracts/task_queue.schema.json',
    'tasks/TASK_SELF_BUILD_EXECUTION_LOOP_001.json',
    'tasks/TASK_SELF_VALIDATION_RELEASE_GATES_001.json'
)

foreach ($jsonRelPath in $jsonTargets) {
    try {
        $null = Read-JsonFile -Path (Join-Path $repoRoot $jsonRelPath)
        Add-CheckResult -Name "json::$jsonRelPath" -Passed $true -Detail 'Valid JSON parse.' -Category 'json'
    }
    catch {
        Add-CheckResult -Name "json::$jsonRelPath" -Passed $false -Detail "Invalid JSON parse: $($_.Exception.Message)" -Category 'json'
    }
}

. (Join-Path $repoRoot 'modules/load_build_task.ps1')
. (Join-Path $repoRoot 'modules/execute_build_task.ps1')
. (Join-Path $repoRoot 'modules/run_validators.ps1')
. (Join-Path $repoRoot 'modules/update_genesis_state.ps1')
. (Join-Path $repoRoot 'modules/update_task_queue.ps1')
. (Join-Path $repoRoot 'modules/emit_run_report.ps1')

$state = $null
$roadmap = $null
$queue = $null
$activeCapability = $null
$activeQueueTask = $null
$buildTask = $null
$executionResult = $null
$validationStack = $null

try {
    $state = Read-JsonFile -Path (Join-Path $repoRoot 'GENESIS_STATE.json')
    $roadmap = Read-JsonFile -Path (Join-Path $repoRoot 'CAPABILITY_ROADMAP.json')
    $queue = Read-JsonFile -Path (Join-Path $repoRoot 'TASK_QUEUE.json')
    Add-CheckResult -Name 'truth::load' -Passed $true -Detail 'Root truth files loaded.' -Category 'truth'
}
catch {
    Add-CheckResult -Name 'truth::load' -Passed $false -Detail $_.Exception.Message -Category 'truth'
}

if ($null -ne $state) {
    Add-CheckResult -Name 'truth::state.current_phase' -Passed ($state.current_phase -eq 'PHASE_2') -Detail "Expected PHASE_2; actual $($state.current_phase)" -Category 'truth'
    Add-CheckResult -Name 'truth::state.current_capability' -Passed ($state.current_capability -eq 'self_build_execution_loop') -Detail "Expected self_build_execution_loop; actual $($state.current_capability)" -Category 'truth'
}

if ($null -ne $roadmap) {
    $activeCapability = $roadmap.capabilities | Where-Object { $_.id -eq 'self_build_execution_loop' } | Select-Object -First 1
    $nextCapability = $roadmap.capabilities | Where-Object { $_.id -eq 'self_validation_release_gates' } | Select-Object -First 1
    Add-CheckResult -Name 'truth::roadmap.execution_loop.active' -Passed ($null -ne $activeCapability -and $activeCapability.status -eq 'ACTIVE') -Detail "Expected ACTIVE; actual $($activeCapability.status)" -Category 'truth'
    Add-CheckResult -Name 'truth::roadmap.release_gates.pending' -Passed ($null -ne $nextCapability -and $nextCapability.status -eq 'PENDING') -Detail "Expected PENDING; actual $($nextCapability.status)" -Category 'truth'
}

if ($null -ne $queue) {
    $activeQueueTask = $queue.tasks | Where-Object { $_.task_id -eq $queue.active_task_id } | Select-Object -First 1
    Add-CheckResult -Name 'truth::queue.active_task_id' -Passed ($queue.active_task_id -eq 'TASK_SELF_BUILD_EXECUTION_LOOP_001') -Detail "Expected TASK_SELF_BUILD_EXECUTION_LOOP_001; actual $($queue.active_task_id)" -Category 'truth'
    Add-CheckResult -Name 'truth::queue.active_task.status' -Passed ($null -ne $activeQueueTask -and $activeQueueTask.status -eq 'ACTIVE') -Detail "Expected ACTIVE; actual $($activeQueueTask.status)" -Category 'truth'
    Add-CheckResult -Name 'truth::queue.active_task.path' -Passed ($activeQueueTask.build_task_path -eq 'tasks/TASK_SELF_BUILD_EXECUTION_LOOP_001.json') -Detail "Expected tasks/TASK_SELF_BUILD_EXECUTION_LOOP_001.json; actual $($activeQueueTask.build_task_path)" -Category 'truth'
}

try {
    $buildTask = Read-BuildTask -RepoRoot $repoRoot -QueueTask $activeQueueTask
    Add-CheckResult -Name 'module::load_build_task' -Passed ($buildTask.content.task_id -eq 'TASK_SELF_BUILD_EXECUTION_LOOP_001') -Detail "Loaded build task $($buildTask.content.task_id)." -Category 'module'
}
catch {
    Add-CheckResult -Name 'module::load_build_task' -Passed $false -Detail $_.Exception.Message -Category 'module'
}

if ($null -ne $buildTask) {
    ($buildTask.content | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $runDir 'BUILD_TASK.json') -Encoding UTF8
}

try {
    $executionResult = Invoke-BuildTaskExecution -BuildTask $buildTask -RunDir $runDir -RunId $resolvedRunId
    Add-CheckResult -Name 'module::execute_build_task' -Passed ($executionResult.status -eq 'PASS') -Detail $executionResult.message -Category 'module'
}
catch {
    Add-CheckResult -Name 'module::execute_build_task' -Passed $false -Detail $_.Exception.Message -Category 'module'
}

if ($null -ne $executionResult) {
    ($executionResult | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $runDir 'EXECUTION_RESULT.json') -Encoding UTF8
}

try {
    $validationStack = Invoke-BuildValidationStack -BuildTask $buildTask -ExecutionResult $executionResult -RepoRoot $repoRoot
    Add-CheckResult -Name 'module::run_validators' -Passed ($validationStack.status -eq 'PASS') -Detail "Validation stack status=$($validationStack.status)" -Category 'module'
}
catch {
    Add-CheckResult -Name 'module::run_validators' -Passed $false -Detail $_.Exception.Message -Category 'module'
}

if ($null -ne $validationStack) {
    ($validationStack | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $runDir 'VALIDATION_STACK.json') -Encoding UTF8
}

$overallPass = ($script:FailReasons.Count -eq 0)
$status = if ($overallPass) { 'PASS' } else { 'FAIL' }
$stopReason = if ($overallPass) { $null } else { ($script:FailReasons -join ' | ') }

$beforeState = Copy-JsonObject -Value $state
$beforeRoadmap = Copy-JsonObject -Value $roadmap
$beforeQueue = Copy-JsonObject -Value $queue

$stateDelta = [ordered]@{
    applied = $false
    before = $beforeState
    after = $beforeState
}

$taskDelta = [ordered]@{
    applied = $false
    before = [ordered]@{
        active_task_id = if ($null -ne $beforeQueue) { $beforeQueue.active_task_id } else { $null }
        execution_loop_task = if ($null -ne $beforeQueue) { ($beforeQueue.tasks | Where-Object { $_.task_id -eq 'TASK_SELF_BUILD_EXECUTION_LOOP_001' } | Select-Object -First 1) } else { $null }
    }
    after = [ordered]@{
        active_task_id = if ($null -ne $beforeQueue) { $beforeQueue.active_task_id } else { $null }
        execution_loop_task = if ($null -ne $beforeQueue) { ($beforeQueue.tasks | Where-Object { $_.task_id -eq 'TASK_SELF_BUILD_EXECUTION_LOOP_001' } | Select-Object -First 1) } else { $null }
        next_task = $null
    }
}

$nextTask = $null

if ($FinalizePhase -and $overallPass) {
    $currentCap = $roadmap.capabilities | Where-Object { $_.id -eq 'self_build_execution_loop' } | Select-Object -First 1
    $nextCap = $roadmap.capabilities | Where-Object { $_.id -eq 'self_validation_release_gates' } | Select-Object -First 1

    $currentCap.status = 'COMPLETED'
    $nextCap.status = 'ACTIVE'

    $state = New-UpdatedGenesisStateForNextCapability -GenesisState $state -CompletedCapability 'self_build_execution_loop' -NextPhase 'PHASE_3' -NextCapability 'self_validation_release_gates'

    $nextQueueTask = [ordered]@{
        task_id = 'TASK_SELF_VALIDATION_RELEASE_GATES_001'
        capability_id = 'self_validation_release_gates'
        status = 'ACTIVE'
        objective = 'Implement self-validation and release gates: verify truth alignment, validator evidence, artifact alignment, and fail-run diagnostics.'
        expected_gate = 'SELF_BUILD_READY'
        build_task_path = 'tasks/TASK_SELF_VALIDATION_RELEASE_GATES_001.json'
    }

    $queue = New-UpdatedTaskQueueForNextTask -TaskQueue $queue -CurrentTaskId 'TASK_SELF_BUILD_EXECUTION_LOOP_001' -NextTask $nextQueueTask
    $nextTask = 'TASK_SELF_VALIDATION_RELEASE_GATES_001'

    ($roadmap | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $repoRoot 'CAPABILITY_ROADMAP.json') -Encoding UTF8
    ($state | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $repoRoot 'GENESIS_STATE.json') -Encoding UTF8
    ($queue | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath (Join-Path $repoRoot 'TASK_QUEUE.json') -Encoding UTF8

    $stateDelta = [ordered]@{
        applied = $true
        before = $beforeState
        after = $state
    }

    $taskDelta = [ordered]@{
        applied = $true
        before = [ordered]@{
            active_task_id = $beforeQueue.active_task_id
            execution_loop_task = ($beforeQueue.tasks | Where-Object { $_.task_id -eq 'TASK_SELF_BUILD_EXECUTION_LOOP_001' } | Select-Object -First 1)
        }
        after = [ordered]@{
            active_task_id = $queue.active_task_id
            execution_loop_task = ($queue.tasks | Where-Object { $_.task_id -eq 'TASK_SELF_BUILD_EXECUTION_LOOP_001' } | Select-Object -First 1)
            next_task = ($queue.tasks | Where-Object { $_.task_id -eq 'TASK_SELF_VALIDATION_RELEASE_GATES_001' } | Select-Object -First 1)
        }
    }
}

$validationReport = [ordered]@{
    validation_run_id = $resolvedRunId
    status = $status
    checks = $script:Checks
}

$runReport = New-ExecutionRunReport -RunId $resolvedRunId -Status $status -TaskExecuted 'TASK_SELF_BUILD_EXECUTION_LOOP_001' -NextTask $nextTask -StopReason $stopReason

$artifactMap = [ordered]@{
    run_id = $resolvedRunId
    artifacts = @(
        'BUILD_TASK.json',
        'EXECUTION_PROOF_MARKER.json',
        'EXECUTION_RESULT.json',
        'VALIDATION_STACK.json',
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
    Write-Host "PASS :: self_build_execution_loop checks passed. run_id=$resolvedRunId"
}
else {
    Write-Host "FAIL :: self_build_execution_loop checks failed. run_id=$resolvedRunId"
    Write-Host "STOP_REASON :: $stopReason"
}

if ($overallPass) {
    exit 0
}
else {
    exit 1
}
