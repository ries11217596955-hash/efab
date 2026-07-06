param(
    [switch]$FinalizePhase,
    [string]$RunId,
    [string]$RepoRoot = ""
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
if (-not $FinalizePhase) { throw "PHASE64 validator requires -FinalizePhase." }
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Get-Location).Path
}
$RepoRoot = (Resolve-Path $RepoRoot).Path
Set-Location $RepoRoot

$modulePath = ".\modules\invoke_generated_family_autonomous_conveyor.ps1"
$spN15Report = ".\reports\generated_program_live_admission\SP_N15_SECOND_FAMILY_LIVE_CONSUMPTION_ACCEPTANCE_V1.md"
$reportPath = ".\reports\generated_family_autonomous_conveyor\GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_CONTRACT_V1_REPORT.json"
$proofPath = ".\proofs\GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_CONTRACT_V1.json"
$phase64TaskId = "TASK_GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_CONTRACT_V1_001"

$null = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $modulePath), [ref]$null, [ref]$null)
if (-not (Test-Path $spN15Report)) { throw "SP-N15 acceptance report missing: $spN15Report" }

$queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json
if ([string]$queue.active_task_id -ne $phase64TaskId) { throw "PHASE64 validator requires TASK_QUEUE active_task_id=$phase64TaskId before finalization." }

. $modulePath
$result = Invoke-GeneratedFamilyAutonomousConveyor -RepoRoot $RepoRoot -RunId $RunId -MaxPacks 3 -ReportPath $reportPath -ProofPath $proofPath -DryRun $true -ExcludedTaskIds @($phase64TaskId)

$proof = Get-Content $proofPath -Raw | ConvertFrom-Json
if ([string]$proof.status -ne "PASS") { throw "Proof status must be PASS." }
if ([string]$proof.active_task_id_observed -ne $phase64TaskId) { throw "active_task_id_observed must equal PHASE64 task." }
if ([string]$proof.effective_conveyor_task_id -ne "NONE") { throw "effective_conveyor_task_id must be NONE." }
if ([string]$proof.conveyor_status -ne "READY_NO_ACTIVE_GENERATED_FAMILY_TASK") { throw "conveyor_status must be READY_NO_ACTIVE_GENERATED_FAMILY_TASK." }
if ([int]$proof.packs_executed -ne 0) { throw "packs_executed must be 0." }
if ([bool]$proof.generated_pack_execution_attempted) { throw "generated_pack_execution_attempted must be false." }
if ([string]$proof.next_required_capability -ne "generated_family_autonomous_conveyor_live_trial_v1") { throw "next_required_capability mismatch." }

$state = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$taskQueue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json
$capability = @($roadmap.capabilities | Where-Object { $_.id -eq "generated_family_autonomous_conveyor_contract_v1" })[0]
$task = @($taskQueue.tasks | Where-Object { $_.task_id -eq $phase64TaskId })[0]
if ($null -eq $capability -or $null -eq $task) { throw "PHASE64 capability/task not found." }
$capability.status = "COMPLETED"
$task.status = "COMPLETED"
$taskQueue.active_task_id = "NONE"
if (@($state.completed_capabilities) -notcontains "generated_family_autonomous_conveyor_contract_v1") { $state.completed_capabilities += "generated_family_autonomous_conveyor_contract_v1" }
$state.current_phase = "PHASE_64"
$state.current_capability = "generated_family_autonomous_conveyor_contract_v1"
$state.last_run_status = "PASS"

$roadmap | ConvertTo-Json -Depth 100 | Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8
$taskQueue | ConvertTo-Json -Depth 100 | Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
$state | ConvertTo-Json -Depth 100 | Set-Content ".\GENESIS_STATE.json" -Encoding UTF8
