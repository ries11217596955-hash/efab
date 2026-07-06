param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-JsonParse {
    param([string]$Path)
    $null = Get-Content $Path -Raw | ConvertFrom-Json
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\test_generated_self_build_program_admission_readiness.ps1"

$CapabilityId = "generated_program_admission_readiness_gate_v1"
$TaskId = "TASK_GENERATED_PROGRAM_ADMISSION_READINESS_GATE_V1_001"
$ProgramManifestPath = ".\self_build_programs\generated\monitoring_agent_v1\SELF_BUILD_PROGRAM_MANIFEST.json"

$Result = Test-GeneratedSelfBuildProgramAdmissionReadiness -ProgramManifestPath $ProgramManifestPath

if ($Result.status -ne "PASS") {
    throw "Admission readiness status must be PASS."
}
if ($Result.admission_decision -ne "ADMISSION_BLOCKED_NON_EXECUTABLE_PACKS") {
    throw "Admission decision must be ADMISSION_BLOCKED_NON_EXECUTABLE_PACKS."
}
if ([int]$Result.blocked_pack_count -le 0) {
    throw "Blocked pack count must be greater than zero."
}
if ($Result.next_required_capability -ne "executable_generated_program_materialization_v1") {
    throw "Unexpected next required capability."
}

$ReportRoot = ".\reports\generated_program_admission_readiness"
New-Item -ItemType Directory -Force -Path $ReportRoot | Out-Null
$ReportPath = Join-Path $ReportRoot "MONITORING_AGENT_V1_ADMISSION_READINESS.json"

$Report = [ordered]@{
    report_id = "MONITORING_AGENT_V1_ADMISSION_READINESS"
    run_id = $RunId
    status = $Result.status
    evaluated_program_manifest = $ProgramManifestPath
    admission_decision = $Result.admission_decision
    executable_pack_count = $Result.executable_pack_count
    blocked_pack_count = $Result.blocked_pack_count
    blocked_packs = $Result.blocked_packs
    manifest_path = $Result.manifest_path
    program_root = $Result.program_root
    next_required_capability = $Result.next_required_capability
}
$Report | ConvertTo-Json -Depth 100 |
    Set-Content $ReportPath -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq $CapabilityId } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq $TaskId } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_55") { throw "Expected PHASE_55." }
if ($State.current_capability -ne $CapabilityId) { throw "Expected $CapabilityId." }
if ($Queue.active_task_id -ne $TaskId) { throw "Unexpected active task." }
if ($null -eq $ThisCap) { throw "PHASE55 capability missing from roadmap." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE55 capability must be ACTIVE before runtime finalization." }
if ($null -eq $ThisTask) { throw "PHASE55 task missing from queue." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE55 task must be ACTIVE before runtime finalization." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    if (@($State.completed_capabilities) -notcontains $CapabilityId) {
        $State.completed_capabilities += $CapabilityId
    }

    $State.current_phase = "PHASE_55"
    $State.current_capability = $CapabilityId
    $State.last_run_status = "PASS"

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Assert-JsonParse ".\CAPABILITY_ROADMAP.json"
Assert-JsonParse ".\GENESIS_STATE.json"
Assert-JsonParse ".\TASK_QUEUE.json"

$Proof = [ordered]@{
    proof_id = "GENERATED_PROGRAM_ADMISSION_READINESS_GATE_V1"
    run_id = $RunId
    status = "PASS"
    evaluated_program_manifest = $ProgramManifestPath
    admission_decision = $Result.admission_decision
    blocked_pack_count = $Result.blocked_pack_count
    next_required_capability = "executable_generated_program_materialization_v1"
    report_path = $ReportPath
    conclusion = "Builder can now distinguish a materialized generated self-build program from one that is safely admissible into live execution."
}
$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\GENERATED_PROGRAM_ADMISSION_READINESS_GATE_V1.json" -Encoding UTF8

Write-Host "GENERATED_PROGRAM_ADMISSION_READINESS_STATUS=PASS"
Write-Host "GENERATED_PROGRAM_ADMISSION_DECISION=$($Result.admission_decision)"
Write-Host "GENERATED_PROGRAM_BLOCKED_PACK_COUNT=$($Result.blocked_pack_count)"
Write-Host "GENERATED_PROGRAM_NEXT_REQUIRED_CAPABILITY=$($Result.next_required_capability)"
Write-Host "PASS :: generated_program_admission_readiness_gate_v1 checks passed. run_id=$RunId"
