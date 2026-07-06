param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$GeneratorText = Get-Content ".\modules\new_external_agent_package.ps1" -Raw

$Weaknesses = [ordered]@{
    has_run_not_implemented = $GeneratorText.Contains("RUN_NOT_IMPLEMENTED")
    has_decorative_validator = $GeneratorText.Contains("GENERATED_AGENT_VALIDATOR=PASS")
}

if (-not $Weaknesses.has_run_not_implemented) {
    throw "Expected RUN_NOT_IMPLEMENTED weakness not found."
}

if (-not $Weaknesses.has_decorative_validator) {
    throw "Expected decorative validator weakness not found."
}

$Proof = [ordered]@{
    proof_id = "PRODUCTION_HONESTY_RESET_V2"
    run_id = $RunId
    status = "PASS"
    weaknesses_detected = $Weaknesses
    conclusion = "Production Factory v1 execution proof existed, but operational production readiness was over-claimed."
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\PRODUCTION_HONESTY_RESET_V2.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "production_truth_reset_v2" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "real_generated_agent_runtime_v2" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_PRODUCTION_TRUTH_RESET_V2_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_13") { throw "Expected PHASE_13." }
if ($State.current_capability -ne "production_truth_reset_v2") { throw "Expected production_truth_reset_v2." }
if ($State.production_factory_ready -ne $false) { throw "production_factory_ready must be false during honesty reset." }
if ($Queue.active_task_id -ne "TASK_PRODUCTION_TRUTH_RESET_V2_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 13 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 13 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_14"
    $State.current_capability = "real_generated_agent_runtime_v2"
    $State.completed_capabilities += "production_truth_reset_v2"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_REAL_GENERATED_AGENT_RUNTIME_V2_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_REAL_GENERATED_AGENT_RUNTIME_V2_001"
        capability_id = "real_generated_agent_runtime_v2"
        status = "ACTIVE"
        objective = "Replace generated agent runtime stubs with a real baseline request to result execution path."
        expected_gate = "REAL_GENERATED_AGENT_RUNTIME_V2_READY"
        build_task_path = "tasks/TASK_REAL_GENERATED_AGENT_RUNTIME_V2_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: production_truth_reset_v2 checks passed. run_id=$RunId"
