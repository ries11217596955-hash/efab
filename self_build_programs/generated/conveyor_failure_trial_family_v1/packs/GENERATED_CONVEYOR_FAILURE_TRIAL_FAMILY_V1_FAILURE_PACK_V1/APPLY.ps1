param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-JsonFile {
    param([string]$Path)
    return Get-Content $Path -Raw | ConvertFrom-Json
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )

    $Value | ConvertTo-Json -Depth 100 |
        Set-Content $Path -Encoding UTF8
}

function Get-SingleByProperty {
    param(
        [object[]]$Items,
        [string]$PropertyName,
        [string]$ExpectedValue,
        [string]$Label
    )

    $Matches = @($Items | Where-Object { $_.$PropertyName -eq $ExpectedValue })
    if ($Matches.Count -ne 1) {
        throw "$Label expected exactly one item where $PropertyName = $ExpectedValue, found $($Matches.Count)."
    }

    return $Matches[0]
}

if (-not $InvokedByOrchestrator) { throw "Generated failure trial pack must be invoked by orchestrator." }
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Get-Location).Path
}
$RepoRoot = (Resolve-Path $RepoRoot).Path
Set-Location $RepoRoot

$PackId = "GENERATED_CONVEYOR_FAILURE_TRIAL_FAMILY_V1_FAILURE_PACK_V1"
$TaskId = "TASK_GENERATED_CONVEYOR_FAILURE_TRIAL_FAMILY_V1_FAILURE_PACK_V1_001"
$CapabilityId = "generated_conveyor_failure_trial_family_v1_failure_pack_v1"
$GeneratedPhase = "GENERATED_CONVEYOR_FAILURE_TRIAL_FAMILY_V1_PHASE_1"
$SemanticRole = "CONVEYOR_FAILURE_RECOVERY_PROOF"
$ControlledErrorCode = "CONTROLLED_GENERATED_CONVEYOR_FAILURE_TRIAL"
$ProofPath = ".\proofs\GENERATED_CONVEYOR_FAILURE_TRIAL_FAMILY_V1_FAILURE_PACK_V1.json"
$ReportPath = ".\reports\generated_family_autonomous_conveyor\GENERATED_CONVEYOR_FAILURE_TRIAL_FAMILY_V1_FAILURE_PACK_V1_REPORT.json"
$Conclusion = "Generated conveyor failure trial pack intentionally failed after writing failure evidence and returning the queue to NONE."

$State = Read-JsonFile ".\GENESIS_STATE.json"
$Roadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
$Queue = Read-JsonFile ".\TASK_QUEUE.json"
$ActiveTaskBefore = [string]$Queue.active_task_id

if ($ActiveTaskBefore -ne $TaskId) {
    throw "Generated conveyor failure trial pack requires active_task_id=$TaskId before execution."
}

$Capability = Get-SingleByProperty -Items @($Roadmap.capabilities) -PropertyName "id" -ExpectedValue $CapabilityId -Label "Generated failure trial capability"
$Task = Get-SingleByProperty -Items @($Queue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "Generated failure trial task"
if ([string]$Capability.status -ne "ACTIVE") { throw "Generated failure trial capability must be ACTIVE before execution." }
if ([string]$Task.status -ne "ACTIVE") { throw "Generated failure trial task must be ACTIVE before execution." }

$Capability.status = "FAILED"
$Task.status = "FAILED"
$Queue.active_task_id = "NONE"
$State.current_phase = $GeneratedPhase
$State.current_capability = $CapabilityId
$State.last_run_status = "FAIL_EXPECTED"

Write-JsonFile -Path ".\CAPABILITY_ROADMAP.json" -Value $Roadmap
Write-JsonFile -Path ".\TASK_QUEUE.json" -Value $Queue
Write-JsonFile -Path ".\GENESIS_STATE.json" -Value $State

$ProofDir = Split-Path -Parent $ProofPath
$ReportDir = Split-Path -Parent $ReportPath
if (-not (Test-Path $ProofDir)) { New-Item -ItemType Directory -Force -Path $ProofDir | Out-Null }
if (-not (Test-Path $ReportDir)) { New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null }

$Proof = [ordered]@{
    proof_id = $PackId
    run_id = $RunId
    status = "FAIL_EXPECTED"
    task_id = $TaskId
    capability_id = $CapabilityId
    semantic_role = $SemanticRole
    executed_by = "generated_family_autonomous_conveyor"
    active_task_before = $ActiveTaskBefore
    active_task_after = "NONE"
    controlled_failure = $true
    error_code = $ControlledErrorCode
    conclusion = $Conclusion
}

$Report = [ordered]@{
    report_id = "GENERATED_CONVEYOR_FAILURE_TRIAL_FAMILY_V1_FAILURE_PACK_V1_REPORT"
    run_id = $RunId
    status = "FAIL_EXPECTED"
    task_id = $TaskId
    capability_id = $CapabilityId
    semantic_role = $SemanticRole
    executed_by = "generated_family_autonomous_conveyor"
    active_task_before = $ActiveTaskBefore
    active_task_after = "NONE"
    controlled_failure = $true
    error_code = $ControlledErrorCode
    conclusion = $Conclusion
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content $ProofPath -Encoding UTF8
$Report | ConvertTo-Json -Depth 100 |
    Set-Content $ReportPath -Encoding UTF8

Write-Host "GENERATED_CONVEYOR_FAILURE_TRIAL_PACK_STATUS=FAIL_EXPECTED"
throw $ControlledErrorCode
