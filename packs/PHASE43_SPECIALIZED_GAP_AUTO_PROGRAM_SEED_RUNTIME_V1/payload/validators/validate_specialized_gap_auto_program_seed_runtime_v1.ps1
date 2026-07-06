param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$Tokens = $null
$Errors = $null

[System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path ".\orchestrator\run.ps1"),
    [ref]$Tokens,
    [ref]$Errors
) | Out-Null

if ($Errors.Count -ne 0) {
    throw "Orchestrator parser check failed."
}

$RawIdeaPath = ".\specs\monitoring_gap_proof\RAW_IDEA_MONITORING_GAP_PROOF.json"

& ".\orchestrator\run.ps1" `
    -Mode BUILD_FROM_RAW_IDEA_SPECIALIZED `
    -RunId $RunId `
    -RawIdeaPath $RawIdeaPath `
    -OutputRoot ".\generated_agents" |
    Out-Host

$ReportPath = ".\runs\$RunId\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1\BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"

if (-not (Test-Path $ReportPath)) {
    throw "Specialized auto-program-seed report missing."
}

$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json

if ($Report.status -ne "SPECIALIZATION_GAP") {
    throw "Specialized auto-program-seed run must return SPECIALIZATION_GAP."
}

if ($Report.remediation_program_seed.status -ne "PASS") {
    throw "Program seed runtime status mismatch."
}

if (-not (Test-Path $Report.remediation_program_seed.seed_path)) {
    throw "Program seed artifact missing."
}

$Seed = Get-Content $Report.remediation_program_seed.seed_path -Raw | ConvertFrom-Json

if ($Seed.status -ne "PROGRAM_SEED_READY") {
    throw "Program seed file status mismatch."
}

if ($Seed.candidate_profile_id -ne "monitoring_agent_v1") {
    throw "Program seed file profile id mismatch."
}

if ($Seed.candidate_agent_kind -ne "monitoring_agent") {
    throw "Program seed file kind mismatch."
}

if ($Seed.recommended_program.program_kind -ne "SPECIALIZATION_PROFILE_CLOSURE_SERIAL_SELF_BUILD") {
    throw "Program seed file program kind mismatch."
}

Write-Host "AUTO_PROGRAM_SEED_STATUS=$($Seed.status)"
Write-Host "AUTO_PROGRAM_SEED_PROFILE_ID=$($Seed.candidate_profile_id)"
Write-Host "AUTO_PROGRAM_SEED_PROGRAM_KIND=$($Seed.recommended_program.program_kind)"
Write-Host "AUTO_PROGRAM_SEED_PATH=$($Report.remediation_program_seed.seed_path)"

$Proof = [ordered]@{
    proof_id = "SPECIALIZED_GAP_AUTO_PROGRAM_SEED_RUNTIME_V1"
    run_id = $RunId
    status = "PASS"
    raw_idea_path = $RawIdeaPath
    specialized_report_path = $ReportPath
    program_seed_path = $Report.remediation_program_seed.seed_path
    candidate_profile_id = $Seed.candidate_profile_id
    candidate_agent_kind = $Seed.candidate_agent_kind
    program_kind = $Seed.recommended_program.program_kind
    required_operator_move = $Seed.required_operator_move
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\SPECIALIZED_GAP_AUTO_PROGRAM_SEED_RUNTIME_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "specialized_gap_auto_program_seed_runtime_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "one_run_remediation_program_seed_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_SPECIALIZED_GAP_AUTO_PROGRAM_SEED_RUNTIME_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_43") { throw "Expected PHASE_43." }
if ($State.current_capability -ne "specialized_gap_auto_program_seed_runtime_v1") { throw "Expected specialized_gap_auto_program_seed_runtime_v1." }
if ($Queue.active_task_id -ne "TASK_SPECIALIZED_GAP_AUTO_PROGRAM_SEED_RUNTIME_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 43 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 43 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_44"
    $State.current_capability = "one_run_remediation_program_seed_proof_v1"
    $State.completed_capabilities += "specialized_gap_auto_program_seed_runtime_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_ONE_RUN_REMEDIATION_PROGRAM_SEED_PROOF_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_ONE_RUN_REMEDIATION_PROGRAM_SEED_PROOF_V1_001"
        capability_id = "one_run_remediation_program_seed_proof_v1"
        status = "ACTIVE"
        objective = "Prove a real monitoring raw idea emits gap, candidate, intake, and serial remediation program seed in one specialized run."
        expected_gate = "ONE_RUN_REMEDIATION_PROGRAM_SEED_PROOF_V1"
        build_task_path = "tasks/TASK_ONE_RUN_REMEDIATION_PROGRAM_SEED_PROOF_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: specialized_gap_auto_program_seed_runtime_v1 checks passed. run_id=$RunId"
