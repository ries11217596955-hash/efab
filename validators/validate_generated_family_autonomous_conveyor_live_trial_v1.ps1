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
        throw "$Label must not exist before PHASE65 runtime: $Path"
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
    throw "PHASE65 live trial validator requires -FinalizePhase."
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Get-Location).Path
}
$RepoRoot = (Resolve-Path $RepoRoot).Path
Set-Location $RepoRoot

$ParentCapabilityId = "generated_family_autonomous_conveyor_live_trial_v1"
$ParentTaskId = "TASK_GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_LIVE_TRIAL_V1_001"
$GeneratedFamilyId = "conveyor_trial_family_v1"
$GeneratedCapabilityId = "generated_conveyor_trial_family_v1_live_pack_v1"
$GeneratedTaskId = "TASK_GENERATED_CONVEYOR_TRIAL_FAMILY_V1_LIVE_PACK_V1_001"
$GeneratedPhase = "GENERATED_CONVEYOR_TRIAL_FAMILY_V1_PHASE_1"
$Phase64ProofPath = ".\proofs\GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_CONTRACT_V1.json"
$ModulePath = ".\modules\invoke_generated_family_autonomous_conveyor.ps1"
$ReportPath = ".\reports\generated_family_autonomous_conveyor\GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_LIVE_TRIAL_V1_REPORT.json"
$ProofPath = ".\proofs\GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_LIVE_TRIAL_V1.json"
$GeneratedTrialProofPath = ".\proofs\GENERATED_CONVEYOR_TRIAL_FAMILY_V1_LIVE_PACK_V1.json"
$GeneratedTrialReportPath = ".\reports\generated_family_autonomous_conveyor\GENERATED_CONVEYOR_TRIAL_FAMILY_V1_LIVE_PACK_V1_REPORT.json"
$NextRequiredCapability = "generated_family_autonomous_conveyor_failure_recovery_v1"
$Conclusion = "The generated-family autonomous conveyor executed one active generated-family trial pack through the live path and returned the Builder queue to NONE."

Assert-RequiredPath -Path $Phase64ProofPath -Label "PHASE64 proof"
Assert-RequiredPath -Path $ModulePath -Label "Generated-family autonomous conveyor module"
Assert-PathMissing -Path $ProofPath -Label "PHASE65 proof"
Assert-PathMissing -Path $ReportPath -Label "PHASE65 report"
Assert-PathMissing -Path $GeneratedTrialProofPath -Label "Generated trial proof"
Assert-PathMissing -Path $GeneratedTrialReportPath -Label "Generated trial report"
Assert-JsonParse $Phase64ProofPath

$Phase64Proof = Read-JsonFile $Phase64ProofPath
if ([string]$Phase64Proof.status -ne "PASS") { throw "PHASE64 proof status must be PASS." }
if ([string]$Phase64Proof.conveyor_status -ne "READY_NO_ACTIVE_GENERATED_FAMILY_TASK") {
    throw "PHASE64 proof conveyor_status must be READY_NO_ACTIVE_GENERATED_FAMILY_TASK."
}

$State = Read-JsonFile ".\GENESIS_STATE.json"
$Roadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
$Queue = Read-JsonFile ".\TASK_QUEUE.json"

if ([string]$Queue.active_task_id -ne $ParentTaskId) {
    throw "PHASE65 validator requires TASK_QUEUE active_task_id=$ParentTaskId before live trial staging."
}
if ([string]$State.current_phase -ne "PHASE_65") { throw "State current_phase must be PHASE_65 before PHASE65 runtime." }
if ([string]$State.current_capability -ne $ParentCapabilityId) {
    throw "State current_capability must be $ParentCapabilityId before PHASE65 runtime."
}

$ParentCapability = Get-SingleByProperty -Items @($Roadmap.capabilities) -PropertyName "id" -ExpectedValue $ParentCapabilityId -Label "PHASE65 capability"
$ParentTask = Get-SingleByProperty -Items @($Queue.tasks) -PropertyName "task_id" -ExpectedValue $ParentTaskId -Label "PHASE65 task"
$GeneratedCapability = Get-SingleByProperty -Items @($Roadmap.capabilities) -PropertyName "id" -ExpectedValue $GeneratedCapabilityId -Label "Generated trial capability"
$GeneratedTask = Get-SingleByProperty -Items @($Queue.tasks) -PropertyName "task_id" -ExpectedValue $GeneratedTaskId -Label "Generated trial task"

if ([string]$ParentCapability.status -ne "ACTIVE") { throw "PHASE65 capability must be ACTIVE before runtime." }
if ([string]$ParentTask.status -ne "ACTIVE") { throw "PHASE65 task must be ACTIVE before runtime." }
if ([string]$GeneratedCapability.status -ne "QUEUED") { throw "Generated trial capability must be QUEUED before runtime." }
if ([string]$GeneratedTask.status -ne "QUEUED") { throw "Generated trial task must be QUEUED before runtime." }

$ParentTask.status = "IN_PROGRESS"
$GeneratedCapability.status = "ACTIVE"
$GeneratedTask.status = "ACTIVE"
$Queue.active_task_id = $GeneratedTaskId
$State.current_phase = $GeneratedPhase
$State.current_capability = $GeneratedCapabilityId

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

Assert-RequiredPath -Path $ProofPath -Label "PHASE65 conveyor proof"
Assert-RequiredPath -Path $ReportPath -Label "PHASE65 conveyor report"
Assert-RequiredPath -Path $GeneratedTrialProofPath -Label "Generated trial proof"
Assert-RequiredPath -Path $GeneratedTrialReportPath -Label "Generated trial report"
Assert-JsonParse $ProofPath
Assert-JsonParse $ReportPath
Assert-JsonParse $GeneratedTrialProofPath
Assert-JsonParse $GeneratedTrialReportPath

$Proof = Read-JsonFile $ProofPath
if ([string]$Proof.status -ne "PASS") { throw "PHASE65 conveyor proof status must be PASS." }
if ([bool]$Proof.dry_run) { throw "PHASE65 conveyor proof dry_run must be false." }
if (-not [bool]$Proof.generated_pack_execution_attempted) { throw "PHASE65 conveyor proof must show generated pack execution attempted." }
if ([int]$Proof.packs_executed -ne 1) { throw "PHASE65 conveyor proof packs_executed must be 1." }
if ([string]$Proof.active_task_id_observed -ne $GeneratedTaskId) { throw "PHASE65 active_task_id_observed mismatch." }
if ([string]$Proof.effective_conveyor_task_id -ne $GeneratedTaskId) { throw "PHASE65 effective_conveyor_task_id mismatch." }
if ([string]$Proof.conveyor_status -ne "EXECUTION_COMPLETE") { throw "PHASE65 conveyor_status must be EXECUTION_COMPLETE." }

$GeneratedProof = Read-JsonFile $GeneratedTrialProofPath
if ([string]$GeneratedProof.status -ne "PASS") { throw "Generated trial proof status must be PASS." }
if ([string]$GeneratedProof.semantic_role -ne "CONVEYOR_LIVE_TRIAL_PROOF") { throw "Generated trial semantic_role mismatch." }
if ([string]$GeneratedProof.active_task_after -ne "NONE") { throw "Generated trial proof active_task_after must be NONE." }

$FinalState = Read-JsonFile ".\GENESIS_STATE.json"
$FinalRoadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
$FinalQueue = Read-JsonFile ".\TASK_QUEUE.json"
if ([string]$FinalQueue.active_task_id -ne "NONE") { throw "Final TASK_QUEUE active_task_id must be NONE." }

$ParentCapabilityAfter = Get-SingleByProperty -Items @($FinalRoadmap.capabilities) -PropertyName "id" -ExpectedValue $ParentCapabilityId -Label "PHASE65 capability after live trial"
$ParentTaskAfter = Get-SingleByProperty -Items @($FinalQueue.tasks) -PropertyName "task_id" -ExpectedValue $ParentTaskId -Label "PHASE65 task after live trial"
$GeneratedCapabilityAfter = Get-SingleByProperty -Items @($FinalRoadmap.capabilities) -PropertyName "id" -ExpectedValue $GeneratedCapabilityId -Label "Generated trial capability after live trial"
$GeneratedTaskAfter = Get-SingleByProperty -Items @($FinalQueue.tasks) -PropertyName "task_id" -ExpectedValue $GeneratedTaskId -Label "Generated trial task after live trial"

if ([string]$GeneratedCapabilityAfter.status -ne "COMPLETED") { throw "Generated trial capability must be COMPLETED after live trial." }
if ([string]$GeneratedTaskAfter.status -ne "COMPLETED") { throw "Generated trial task must be COMPLETED after live trial." }

$ParentCapabilityAfter.status = "COMPLETED"
$ParentTaskAfter.status = "COMPLETED"
Add-CompletedCapability -State $FinalState -CompletedCapabilityId $ParentCapabilityId
$FinalState.current_phase = "PHASE_65"
$FinalState.current_capability = $ParentCapabilityId
$FinalState.last_run_status = "PASS"

Write-JsonFile -Path ".\CAPABILITY_ROADMAP.json" -Value $FinalRoadmap
Write-JsonFile -Path ".\TASK_QUEUE.json" -Value $FinalQueue
Write-JsonFile -Path ".\GENESIS_STATE.json" -Value $FinalState

$Proof = Read-JsonFile $ProofPath
$Report = Read-JsonFile $ReportPath
$Proof | Add-Member -NotePropertyName "proof_id" -NotePropertyValue "GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_LIVE_TRIAL_V1" -Force
$Proof | Add-Member -NotePropertyName "family_id" -NotePropertyValue $GeneratedFamilyId -Force
$Proof | Add-Member -NotePropertyName "generated_trial_task_id" -NotePropertyValue $GeneratedTaskId -Force
$Proof | Add-Member -NotePropertyName "generated_trial_proof_path" -NotePropertyValue $GeneratedTrialProofPath -Force
$Proof | Add-Member -NotePropertyName "generated_trial_report_path" -NotePropertyValue $GeneratedTrialReportPath -Force
$Proof | Add-Member -NotePropertyName "next_required_capability" -NotePropertyValue $NextRequiredCapability -Force
$Proof | Add-Member -NotePropertyName "conclusion" -NotePropertyValue $Conclusion -Force
$Proof | Add-Member -NotePropertyName "report_path" -NotePropertyValue $ReportPath -Force
$Report | Add-Member -NotePropertyName "report_id" -NotePropertyValue "GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_LIVE_TRIAL_V1_REPORT" -Force
$Report | Add-Member -NotePropertyName "family_id" -NotePropertyValue $GeneratedFamilyId -Force
$Report | Add-Member -NotePropertyName "generated_trial_task_id" -NotePropertyValue $GeneratedTaskId -Force
$Report | Add-Member -NotePropertyName "generated_trial_proof_path" -NotePropertyValue $GeneratedTrialProofPath -Force
$Report | Add-Member -NotePropertyName "generated_trial_report_path" -NotePropertyValue $GeneratedTrialReportPath -Force
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
Assert-JsonParse $GeneratedTrialProofPath
Assert-JsonParse $GeneratedTrialReportPath

Write-Host "GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_LIVE_TRIAL_STATUS=PASS"
Write-Host "GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_LIVE_TRIAL_PACKS_EXECUTED=1"
Write-Host "GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_LIVE_TRIAL_ACTIVE_TASK_AFTER=NONE"
Write-Host "GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_LIVE_TRIAL_NEXT_REQUIRED_CAPABILITY=$NextRequiredCapability"
