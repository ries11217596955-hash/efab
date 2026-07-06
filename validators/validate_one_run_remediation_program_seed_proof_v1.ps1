param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$RawIdeaPath = ".\specs\monitoring_gap_proof\RAW_IDEA_MONITORING_GAP_PROOF.json"

& ".\orchestrator\run.ps1" `
    -Mode BUILD_FROM_RAW_IDEA_SPECIALIZED `
    -RunId $RunId `
    -RawIdeaPath $RawIdeaPath `
    -OutputRoot ".\generated_agents" |
    Out-Host

$ReportPath = ".\runs\$RunId\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1\BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"

if (-not (Test-Path $ReportPath)) {
    throw "One-run program-seed report missing."
}

$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json

if ($Report.status -ne "SPECIALIZATION_GAP") {
    throw "One-run program-seed proof must return SPECIALIZATION_GAP."
}

if (-not (Test-Path $Report.remediation_program_seed.seed_path)) {
    throw "One-run program seed artifact missing."
}

$Seed = Get-Content $Report.remediation_program_seed.seed_path -Raw | ConvertFrom-Json

if ($Seed.candidate_profile_id -ne "monitoring_agent_v1") {
    throw "One-run seed profile id mismatch."
}

if ($Seed.candidate_agent_kind -ne "monitoring_agent") {
    throw "One-run seed kind mismatch."
}

if ($Seed.required_operator_move -ne "AUTHOR_OR_SELECT_REPO_DEFINED_PACKS_FOR_PROGRAM") {
    throw "One-run seed operator move mismatch."
}

New-Item -ItemType Directory -Force -Path ".\remediation_programs" | Out-Null
$CanonicalSeedPath = ".\remediation_programs\MONITORING_AGENT_REMEDIATION_PROGRAM_SEED_V1.json"
Copy-Item $Report.remediation_program_seed.seed_path $CanonicalSeedPath -Force

Write-Host "ONE_RUN_PROGRAM_SEED_PROFILE_ID=$($Seed.candidate_profile_id)"
Write-Host "ONE_RUN_PROGRAM_SEED_KIND=$($Seed.candidate_agent_kind)"
Write-Host "ONE_RUN_PROGRAM_SEED_PATH=$CanonicalSeedPath"

$Proof = [ordered]@{
    proof_id = "ONE_RUN_REMEDIATION_PROGRAM_SEED_PROOF_V1"
    run_id = $RunId
    status = "PASS"
    raw_idea_path = $RawIdeaPath
    specialized_report_path = $ReportPath
    runtime_seed_path = $Report.remediation_program_seed.seed_path
    canonical_seed_path = $CanonicalSeedPath
    candidate_profile_id = $Seed.candidate_profile_id
    candidate_agent_kind = $Seed.candidate_agent_kind
    program_kind = $Seed.recommended_program.program_kind
    required_operator_move = $Seed.required_operator_move
    conclusion = "Unknown specialization families now return a complete remediation packet plus a serial self-build remediation program seed in one specialized run."
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\ONE_RUN_REMEDIATION_PROGRAM_SEED_PROOF_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "one_run_remediation_program_seed_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_ONE_RUN_REMEDIATION_PROGRAM_SEED_PROOF_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_44") { throw "Expected PHASE_44." }
if ($State.current_capability -ne "one_run_remediation_program_seed_proof_v1") { throw "Expected one_run_remediation_program_seed_proof_v1." }
if ($Queue.active_task_id -ne "TASK_ONE_RUN_REMEDIATION_PROGRAM_SEED_PROOF_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 44 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 44 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"

    $State.current_phase = "PHASE_44"
    $State.current_capability = "one_run_remediation_program_seed_proof_v1"
    $State.completed_capabilities += "one_run_remediation_program_seed_proof_v1"
    $State.last_run_status = "PASS"
    $State.one_run_remediation_program_seed_ready = $true

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: one_run_remediation_program_seed_proof_v1 checks passed. run_id=$RunId"
