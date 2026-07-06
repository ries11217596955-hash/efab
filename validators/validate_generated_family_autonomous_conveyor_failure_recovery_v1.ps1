param(
    [switch]$FinalizePhase,
    [string]$RunId,
    [string]$RepoRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-RequiredPath {
    param(
        [string]$Path,
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "$Label path must not be empty."
    }
    if (-not (Test-Path $Path)) {
        throw "$Label missing: $Path"
    }
}

function Assert-PathMissing {
    param(
        [string]$Path,
        [string]$Label
    )

    if (Test-Path $Path) {
        throw "$Label must not exist before PHASE66 runtime: $Path"
    }
}

function Assert-JsonParse {
    param([string]$Path)
    $null = Get-Content $Path -Raw | ConvertFrom-Json
}

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

function Add-CompletedCapability {
    param(
        [object]$State,
        [string]$CompletedCapabilityId
    )

    if (@($State.completed_capabilities) -notcontains $CompletedCapabilityId) {
        $State.completed_capabilities += $CompletedCapabilityId
    }
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

if (-not $FinalizePhase) {
    throw "PHASE66 failure recovery validator requires -FinalizePhase."
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Get-Location).Path
}
$RepoRoot = (Resolve-Path $RepoRoot).Path
Set-Location $RepoRoot

$ParentCapabilityId = "generated_family_autonomous_conveyor_failure_recovery_v1"
$ParentTaskId = "TASK_GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_FAILURE_RECOVERY_V1_001"
$GeneratedFamilyId = "conveyor_failure_trial_family_v1"
$GeneratedCapabilityId = "generated_conveyor_failure_trial_family_v1_failure_pack_v1"
$GeneratedTaskId = "TASK_GENERATED_CONVEYOR_FAILURE_TRIAL_FAMILY_V1_FAILURE_PACK_V1_001"
$GeneratedPackId = "GENERATED_CONVEYOR_FAILURE_TRIAL_FAMILY_V1_FAILURE_PACK_V1"
$GeneratedPhase = "GENERATED_CONVEYOR_FAILURE_TRIAL_FAMILY_V1_PHASE_1"
$ControlledErrorCode = "CONTROLLED_GENERATED_CONVEYOR_FAILURE_TRIAL"
$Phase65ProofPath = ".\proofs\GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_LIVE_TRIAL_V1.json"
$ModulePath = ".\modules\invoke_generated_family_autonomous_conveyor.ps1"
$ReportPath = ".\reports\generated_family_autonomous_conveyor\GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_FAILURE_RECOVERY_V1_REPORT.json"
$ProofPath = ".\proofs\GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_FAILURE_RECOVERY_V1.json"
$GeneratedFailureProofPath = ".\proofs\GENERATED_CONVEYOR_FAILURE_TRIAL_FAMILY_V1_FAILURE_PACK_V1.json"
$GeneratedFailureReportPath = ".\reports\generated_family_autonomous_conveyor\GENERATED_CONVEYOR_FAILURE_TRIAL_FAMILY_V1_FAILURE_PACK_V1_REPORT.json"
$NextRequiredCapability = "external_agent_production_program_test_v1"
$Conclusion = "The conveyor detected a controlled generated-pack failure, did not fake PASS, preserved failure evidence, and returned the Builder queue to NONE."

Assert-RequiredPath -Path $Phase65ProofPath -Label "PHASE65 proof"
Assert-RequiredPath -Path $ModulePath -Label "Generated-family autonomous conveyor module"
Assert-PathMissing -Path $ProofPath -Label "PHASE66 proof"
Assert-PathMissing -Path $ReportPath -Label "PHASE66 report"
Assert-PathMissing -Path $GeneratedFailureProofPath -Label "Generated failure trial proof"
Assert-PathMissing -Path $GeneratedFailureReportPath -Label "Generated failure trial report"
Assert-JsonParse $Phase65ProofPath

$Phase65Proof = Read-JsonFile $Phase65ProofPath
if ([string]$Phase65Proof.status -ne "PASS") { throw "PHASE65 proof status must be PASS." }
if ([bool]$Phase65Proof.dry_run) { throw "PHASE65 proof dry_run must be false." }
if (-not [bool]$Phase65Proof.generated_pack_execution_attempted) { throw "PHASE65 proof must show generated pack execution attempted." }
if ([int]$Phase65Proof.packs_executed -ne 1) { throw "PHASE65 proof packs_executed must be 1." }

$State = Read-JsonFile ".\GENESIS_STATE.json"
$Roadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
$Queue = Read-JsonFile ".\TASK_QUEUE.json"

if ([string]$Queue.active_task_id -ne $ParentTaskId) {
    throw "PHASE66 validator requires TASK_QUEUE active_task_id=$ParentTaskId before failure recovery staging."
}
if ([string]$State.current_phase -ne "PHASE_66") { throw "State current_phase must be PHASE_66 before PHASE66 runtime." }
if ([string]$State.current_capability -ne $ParentCapabilityId) {
    throw "State current_capability must be $ParentCapabilityId before PHASE66 runtime."
}

$ParentCapability = Get-SingleByProperty -Items @($Roadmap.capabilities) -PropertyName "id" -ExpectedValue $ParentCapabilityId -Label "PHASE66 capability"
$ParentTask = Get-SingleByProperty -Items @($Queue.tasks) -PropertyName "task_id" -ExpectedValue $ParentTaskId -Label "PHASE66 task"
$GeneratedCapability = Get-SingleByProperty -Items @($Roadmap.capabilities) -PropertyName "id" -ExpectedValue $GeneratedCapabilityId -Label "Generated failure trial capability"
$GeneratedTask = Get-SingleByProperty -Items @($Queue.tasks) -PropertyName "task_id" -ExpectedValue $GeneratedTaskId -Label "Generated failure trial task"

if ([string]$ParentCapability.status -ne "ACTIVE") { throw "PHASE66 capability must be ACTIVE before runtime." }
if ([string]$ParentTask.status -ne "ACTIVE") { throw "PHASE66 task must be ACTIVE before runtime." }
if ([string]$GeneratedCapability.status -ne "QUEUED") { throw "Generated failure trial capability must be QUEUED before runtime." }
if ([string]$GeneratedTask.status -ne "QUEUED") { throw "Generated failure trial task must be QUEUED before runtime." }

$ParentTask.status = "IN_PROGRESS"
$GeneratedCapability.status = "ACTIVE"
$GeneratedTask.status = "ACTIVE"
$Queue.active_task_id = $GeneratedTaskId
$State.current_phase = $GeneratedPhase
$State.current_capability = $GeneratedCapabilityId
$State.last_run_status = "IN_PROGRESS"

Write-JsonFile -Path ".\CAPABILITY_ROADMAP.json" -Value $Roadmap
Write-JsonFile -Path ".\TASK_QUEUE.json" -Value $Queue
Write-JsonFile -Path ".\GENESIS_STATE.json" -Value $State

. $ModulePath

$null = Invoke-GeneratedFamilyAutonomousConveyor `
    -RepoRoot $RepoRoot `
    -RunId $RunId `
    -MaxPacks 1 `
    -ReportPath $ReportPath `
    -ProofPath $ProofPath `
    -DryRun $false `
    -ExcludedTaskIds @($ParentTaskId)

Assert-RequiredPath -Path $ProofPath -Label "PHASE66 conveyor proof"
Assert-RequiredPath -Path $ReportPath -Label "PHASE66 conveyor report"
Assert-RequiredPath -Path $GeneratedFailureProofPath -Label "Generated failure trial proof"
Assert-RequiredPath -Path $GeneratedFailureReportPath -Label "Generated failure trial report"
Assert-JsonParse $ProofPath
Assert-JsonParse $ReportPath
Assert-JsonParse $GeneratedFailureProofPath
Assert-JsonParse $GeneratedFailureReportPath

$Proof = Read-JsonFile $ProofPath
if ([string]$Proof.status -ne "FAIL") { throw "PHASE66 raw conveyor proof status must be FAIL." }
if ([bool]$Proof.dry_run) { throw "PHASE66 conveyor proof dry_run must be false." }
if (-not [bool]$Proof.generated_pack_execution_attempted) { throw "PHASE66 conveyor proof must show generated pack execution attempted." }
if ([int]$Proof.packs_executed -ne 1) { throw "PHASE66 conveyor proof packs_executed must be 1." }
if ([string]$Proof.active_task_id_observed -ne $GeneratedTaskId) { throw "PHASE66 active_task_id_observed mismatch." }
if ([string]$Proof.effective_conveyor_task_id -ne $GeneratedTaskId) { throw "PHASE66 effective_conveyor_task_id mismatch." }
if ([string]$Proof.conveyor_status -ne "HALTED_ON_PACK_FAILURE") { throw "PHASE66 conveyor_status must be HALTED_ON_PACK_FAILURE." }

$PerPackResults = @($Proof.per_pack_results)
if ($PerPackResults.Count -ne 1) { throw "PHASE66 conveyor proof must contain exactly one per-pack result." }
$PackResult = $PerPackResults[0]
if ([string]$PackResult.status -ne "FAIL") { throw "PHASE66 per_pack_results[0].status must be FAIL." }
if ([string]$PackResult.error -notlike "*$ControlledErrorCode*") {
    throw "PHASE66 per_pack_results[0].error must contain $ControlledErrorCode."
}
if ([string]$PackResult.pack_id -ne $GeneratedPackId) { throw "PHASE66 failed pack_id mismatch." }
if ([string]$PackResult.task_id -ne $GeneratedTaskId) { throw "PHASE66 failed task_id mismatch." }

$GeneratedProof = Read-JsonFile $GeneratedFailureProofPath
if ([string]$GeneratedProof.status -ne "FAIL_EXPECTED") { throw "Generated failure trial proof status must be FAIL_EXPECTED." }
if (-not [bool]$GeneratedProof.controlled_failure) { throw "Generated failure trial proof controlled_failure must be true." }
if ([string]$GeneratedProof.error_code -ne $ControlledErrorCode) { throw "Generated failure trial proof error_code mismatch." }
if ([string]$GeneratedProof.active_task_after -ne "NONE") { throw "Generated failure trial proof active_task_after must be NONE." }

$GeneratedReport = Read-JsonFile $GeneratedFailureReportPath
if ([string]$GeneratedReport.status -ne "FAIL_EXPECTED") { throw "Generated failure trial report status must be FAIL_EXPECTED." }

$FinalState = Read-JsonFile ".\GENESIS_STATE.json"
$FinalRoadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
$FinalQueue = Read-JsonFile ".\TASK_QUEUE.json"
if ([string]$FinalQueue.active_task_id -ne "NONE") { throw "Final TASK_QUEUE active_task_id must be NONE." }

$ParentCapabilityAfter = Get-SingleByProperty -Items @($FinalRoadmap.capabilities) -PropertyName "id" -ExpectedValue $ParentCapabilityId -Label "PHASE66 capability after failure recovery"
$ParentTaskAfter = Get-SingleByProperty -Items @($FinalQueue.tasks) -PropertyName "task_id" -ExpectedValue $ParentTaskId -Label "PHASE66 task after failure recovery"
$GeneratedCapabilityAfter = Get-SingleByProperty -Items @($FinalRoadmap.capabilities) -PropertyName "id" -ExpectedValue $GeneratedCapabilityId -Label "Generated failure trial capability after failure recovery"
$GeneratedTaskAfter = Get-SingleByProperty -Items @($FinalQueue.tasks) -PropertyName "task_id" -ExpectedValue $GeneratedTaskId -Label "Generated failure trial task after failure recovery"

if ([string]$GeneratedCapabilityAfter.status -ne "FAILED") { throw "Generated failure trial capability must be FAILED after controlled failure." }
if ([string]$GeneratedTaskAfter.status -ne "FAILED") { throw "Generated failure trial task must be FAILED after controlled failure." }

$ParentCapabilityAfter.status = "COMPLETED"
$ParentTaskAfter.status = "COMPLETED"
$GeneratedCapabilityAfter.status = "FAILED"
$GeneratedTaskAfter.status = "FAILED"
Add-CompletedCapability -State $FinalState -CompletedCapabilityId $ParentCapabilityId
$FinalState.current_phase = "PHASE_66"
$FinalState.current_capability = $ParentCapabilityId
$FinalState.last_run_status = "PASS"

Write-JsonFile -Path ".\CAPABILITY_ROADMAP.json" -Value $FinalRoadmap
Write-JsonFile -Path ".\TASK_QUEUE.json" -Value $FinalQueue
Write-JsonFile -Path ".\GENESIS_STATE.json" -Value $FinalState

$Report = Read-JsonFile $ReportPath
$Proof | Add-Member -NotePropertyName "proof_id" -NotePropertyValue "GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_FAILURE_RECOVERY_V1" -Force
$Proof | Add-Member -NotePropertyName "status" -NotePropertyValue "PASS" -Force
$Proof | Add-Member -NotePropertyName "raw_conveyor_status" -NotePropertyValue "FAIL" -Force
$Proof | Add-Member -NotePropertyName "expected_failure_observed" -NotePropertyValue $true -Force
$Proof | Add-Member -NotePropertyName "recovered_queue_state" -NotePropertyValue "NONE" -Force
$Proof | Add-Member -NotePropertyName "family_id" -NotePropertyValue $GeneratedFamilyId -Force
$Proof | Add-Member -NotePropertyName "failed_generated_task_id" -NotePropertyValue $GeneratedTaskId -Force
$Proof | Add-Member -NotePropertyName "failed_generated_capability_id" -NotePropertyValue $GeneratedCapabilityId -Force
$Proof | Add-Member -NotePropertyName "failed_generated_proof_path" -NotePropertyValue $GeneratedFailureProofPath -Force
$Proof | Add-Member -NotePropertyName "failed_generated_report_path" -NotePropertyValue $GeneratedFailureReportPath -Force
$Proof | Add-Member -NotePropertyName "next_required_capability" -NotePropertyValue $NextRequiredCapability -Force
$Proof | Add-Member -NotePropertyName "conclusion" -NotePropertyValue $Conclusion -Force
$Proof | Add-Member -NotePropertyName "report_path" -NotePropertyValue $ReportPath -Force
$Report | Add-Member -NotePropertyName "report_id" -NotePropertyValue "GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_FAILURE_RECOVERY_V1_REPORT" -Force
$Report | Add-Member -NotePropertyName "status" -NotePropertyValue "PASS" -Force
$Report | Add-Member -NotePropertyName "proof_path" -NotePropertyValue $ProofPath -Force
$Report | Add-Member -NotePropertyName "expected_failure_observed" -NotePropertyValue $true -Force
$Report | Add-Member -NotePropertyName "recovered_queue_state" -NotePropertyValue "NONE" -Force
$Report | Add-Member -NotePropertyName "family_id" -NotePropertyValue $GeneratedFamilyId -Force
$Report | Add-Member -NotePropertyName "failed_generated_task_id" -NotePropertyValue $GeneratedTaskId -Force
$Report | Add-Member -NotePropertyName "failed_generated_capability_id" -NotePropertyValue $GeneratedCapabilityId -Force
$Report | Add-Member -NotePropertyName "failed_generated_proof_path" -NotePropertyValue $GeneratedFailureProofPath -Force
$Report | Add-Member -NotePropertyName "failed_generated_report_path" -NotePropertyValue $GeneratedFailureReportPath -Force
$Report | Add-Member -NotePropertyName "next_required_capability" -NotePropertyValue $NextRequiredCapability -Force
$Report | Add-Member -NotePropertyName "conclusion" -NotePropertyValue $Conclusion -Force

Write-JsonFile -Path $ProofPath -Value $Proof
Write-JsonFile -Path $ReportPath -Value $Report

Assert-JsonParse ".\CAPABILITY_ROADMAP.json"
Assert-JsonParse ".\GENESIS_STATE.json"
Assert-JsonParse ".\TASK_QUEUE.json"
Assert-JsonParse ".\packs\registry.json"
Assert-JsonParse $ProofPath
Assert-JsonParse $ReportPath
Assert-JsonParse $GeneratedFailureProofPath
Assert-JsonParse $GeneratedFailureReportPath

Write-Host "GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_FAILURE_RECOVERY_STATUS=PASS"
Write-Host "GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_EXPECTED_FAILURE_OBSERVED=true"
Write-Host "GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_FAILURE_RECOVERY_ACTIVE_TASK_AFTER=NONE"
Write-Host "GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_FAILURE_RECOVERY_NEXT_REQUIRED_CAPABILITY=$NextRequiredCapability"
