param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\new_gap_remediation_program_seed.ps1"

$RawIdeaPath = ".\specs\monitoring_gap_proof\RAW_IDEA_MONITORING_GAP_PROOF.json"

& ".\orchestrator\run.ps1" `
    -Mode BUILD_FROM_RAW_IDEA_SPECIALIZED `
    -RunId $RunId `
    -RawIdeaPath $RawIdeaPath `
    -OutputRoot ".\generated_agents" |
    Out-Host

$ReportPath = ".\runs\$RunId\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1\BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"

if (-not (Test-Path $ReportPath)) {
    throw "Inline remediation packet source report missing."
}

$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json

if ($Report.status -ne "SPECIALIZATION_GAP") {
    throw "Monitoring raw idea must remain a specialization gap before program seed runtime integration."
}

if ($Report.remediation_intake.status -ne "PASS") {
    throw "Inline remediation intake must be PASS."
}

$ModeRoot = ".\runs\$RunId\PHASE42_REMEDIATION_PROGRAM_SEED_CONTRACT_V1\program_seed"

$Seed = New-GapRemediationProgramSeed `
    -RunId $RunId `
    -ModeRoot $ModeRoot `
    -GapReportPath $Report.gap_report.report_path `
    -CandidatePath $Report.remediation_intake.candidate_path `
    -IntakeReportPath $Report.remediation_intake.intake_report_path

if ($Seed.status -ne "PASS") {
    throw "Program seed generation must return PASS."
}

if (-not (Test-Path $Seed.seed_path)) {
    throw "Program seed artifact missing."
}

$SeedJson = Get-Content $Seed.seed_path -Raw | ConvertFrom-Json

if ($SeedJson.status -ne "PROGRAM_SEED_READY") {
    throw "Program seed status mismatch."
}

if ($SeedJson.candidate_profile_id -ne "monitoring_agent_v1") {
    throw "Program seed profile id mismatch."
}

if ($SeedJson.candidate_agent_kind -ne "monitoring_agent") {
    throw "Program seed agent kind mismatch."
}

if ($SeedJson.recommended_program.program_kind -ne "SPECIALIZATION_PROFILE_CLOSURE_SERIAL_SELF_BUILD") {
    throw "Program seed program kind mismatch."
}

if ($SeedJson.required_operator_move -ne "AUTHOR_OR_SELECT_REPO_DEFINED_PACKS_FOR_PROGRAM") {
    throw "Program seed operator move mismatch."
}

Write-Host "PROGRAM_SEED_STATUS=$($SeedJson.status)"
Write-Host "PROGRAM_SEED_PROFILE_ID=$($SeedJson.candidate_profile_id)"
Write-Host "PROGRAM_SEED_PROGRAM_KIND=$($SeedJson.recommended_program.program_kind)"
Write-Host "PROGRAM_SEED_PATH=$($Seed.seed_path)"

$Proof = [ordered]@{
    proof_id = "REMEDIATION_PROGRAM_SEED_CONTRACT_V1"
    run_id = $RunId
    status = "PASS"
    source_specialized_report = $ReportPath
    seed_path = $Seed.seed_path
    candidate_profile_id = $SeedJson.candidate_profile_id
    candidate_agent_kind = $SeedJson.candidate_agent_kind
    program_kind = $SeedJson.recommended_program.program_kind
    required_operator_move = $SeedJson.required_operator_move
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\REMEDIATION_PROGRAM_SEED_CONTRACT_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "remediation_program_seed_contract_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "specialized_gap_auto_program_seed_runtime_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_REMEDIATION_PROGRAM_SEED_CONTRACT_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_42") { throw "Expected PHASE_42." }
if ($State.current_capability -ne "remediation_program_seed_contract_v1") { throw "Expected remediation_program_seed_contract_v1." }
if ($Queue.active_task_id -ne "TASK_REMEDIATION_PROGRAM_SEED_CONTRACT_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 42 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 42 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_43"
    $State.current_capability = "specialized_gap_auto_program_seed_runtime_v1"
    $State.completed_capabilities += "remediation_program_seed_contract_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_SPECIALIZED_GAP_AUTO_PROGRAM_SEED_RUNTIME_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_SPECIALIZED_GAP_AUTO_PROGRAM_SEED_RUNTIME_V1_001"
        capability_id = "specialized_gap_auto_program_seed_runtime_v1"
        status = "ACTIVE"
        objective = "Upgrade specialized no-match runtime so one run emits remediation packet plus serial remediation program seed."
        expected_gate = "SPECIALIZED_GAP_AUTO_PROGRAM_SEED_RUNTIME_V1_READY"
        build_task_path = "tasks/TASK_SPECIALIZED_GAP_AUTO_PROGRAM_SEED_RUNTIME_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: remediation_program_seed_contract_v1 checks passed. run_id=$RunId"
