param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$ProgramSeedPath = ".\remediation_programs\MONITORING_AGENT_REMEDIATION_PROGRAM_SEED_V1.json"
$ProfileProofPath = ".\proofs\SEED_DRIVEN_MONITORING_PROFILE_V1.json"
$ClosureProofPath = ".\proofs\MONITORING_GAP_CLOSURE_SPECIALIZED_PROOF_V1.json"

if (-not (Test-Path $ProgramSeedPath)) {
    throw "Canonical remediation program seed missing."
}

if (-not (Test-Path $ProfileProofPath)) {
    throw "Seed-driven monitoring profile proof missing."
}

if (-not (Test-Path $ClosureProofPath)) {
    throw "Monitoring gap closure proof missing."
}

$Seed = Get-Content $ProgramSeedPath -Raw | ConvertFrom-Json
$ProfileProof = Get-Content $ProfileProofPath -Raw | ConvertFrom-Json
$ClosureProof = Get-Content $ClosureProofPath -Raw | ConvertFrom-Json

if ($Seed.candidate_profile_id -ne "monitoring_agent_v1") {
    throw "Seed profile id mismatch."
}

if ($Seed.candidate_agent_kind -ne "monitoring_agent") {
    throw "Seed agent kind mismatch."
}

if ($Seed.recommended_program.profile_capability_id -ne "monitoring_agent_specialization_profile_v1") {
    throw "Seed profile capability id mismatch."
}

if ($Seed.recommended_program.closure_capability_id -ne "monitoring_agent_gap_closure_proof_v1") {
    throw "Seed closure capability id mismatch."
}

if ($ProfileProof.status -ne "PASS") {
    throw "Profile proof must be PASS."
}

if ($ProfileProof.selected_profile_id -ne $Seed.candidate_profile_id) {
    throw "Profile proof does not consume the seed candidate profile id."
}

if ($ClosureProof.status -ne "PASS") {
    throw "Closure proof must be PASS."
}

if ($ClosureProof.selected_profile_id -ne $Seed.candidate_profile_id) {
    throw "Closure proof does not close through the seed candidate profile id."
}

if ($ClosureProof.specialized_operation -ne "monitoring_alert_triage_queue") {
    throw "Closure specialized operation mismatch."
}

Write-Host "SEED_CONSUMPTION_PROFILE_ID=$($Seed.candidate_profile_id)"
Write-Host "SEED_CONSUMPTION_PROFILE_PROOF=$($ProfileProof.status)"
Write-Host "SEED_CONSUMPTION_CLOSURE_PROOF=$($ClosureProof.status)"
Write-Host "SEED_CONSUMPTION_OPERATION=$($ClosureProof.specialized_operation)"

$Proof = [ordered]@{
    proof_id = "REMEDIATION_PROGRAM_SEED_CONSUMPTION_CLOSURE_PROOF_V1"
    run_id = $RunId
    status = "PASS"
    program_seed_path = $ProgramSeedPath
    seed_profile_id = $Seed.candidate_profile_id
    seed_agent_kind = $Seed.candidate_agent_kind
    seed_program_kind = $Seed.recommended_program.program_kind
    profile_proof_path = $ProfileProofPath
    profile_selected_id = $ProfileProof.selected_profile_id
    closure_proof_path = $ClosureProofPath
    closure_selected_profile_id = $ClosureProof.selected_profile_id
    closure_specialized_operation = $ClosureProof.specialized_operation
    conclusion = "The canonical remediation program seed produced by SP-N11 was consumed into a real serial self-build closure: monitoring_agent_v1 was built, registered, and the prior monitoring specialization gap now closes to PASS."
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\REMEDIATION_PROGRAM_SEED_CONSUMPTION_CLOSURE_PROOF_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "remediation_program_seed_consumption_closure_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_REMEDIATION_PROGRAM_SEED_CONSUMPTION_CLOSURE_PROOF_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_47") { throw "Expected PHASE_47." }
if ($State.current_capability -ne "remediation_program_seed_consumption_closure_proof_v1") { throw "Expected remediation_program_seed_consumption_closure_proof_v1." }
if ($Queue.active_task_id -ne "TASK_REMEDIATION_PROGRAM_SEED_CONSUMPTION_CLOSURE_PROOF_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 47 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 47 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"

    $State.current_phase = "PHASE_47"
    $State.current_capability = "remediation_program_seed_consumption_closure_proof_v1"
    $State.completed_capabilities += "remediation_program_seed_consumption_closure_proof_v1"
    $State.last_run_status = "PASS"
    $State.remediation_program_seed_consumption_closure_ready = $true

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: remediation_program_seed_consumption_closure_proof_v1 checks passed. run_id=$RunId"
