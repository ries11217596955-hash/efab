param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$ProofOut = ".\runs\$RunId\PHASE11_BUILD_MODE_PROOF"
New-Item -ItemType Directory -Force -Path $ProofOut | Out-Null

& ".\orchestrator\run.ps1" `
    -Mode BUILD_EXTERNAL_AGENT `
    -RunId $RunId `
    -SpecPath ".\specs\external_agent_spec_template\SPEC_TEMPLATE.json" `
    -OutputRoot $ProofOut |
    Out-Host

$ExpectedPackage = Join-Path $ProofOut "production_example_agent"
if (-not (Test-Path (Join-Path $ExpectedPackage "README.md"))) {
    throw "BUILD_EXTERNAL_AGENT proof README missing."
}

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities | Where-Object { $_.id -eq "factory_build_external_agent_mode_v1" } | Select-Object -First 1
$NextCap = $Roadmap.capabilities | Where-Object { $_.id -eq "production_factory_proof_v1" } | Select-Object -First 1
$ThisTask = $Queue.tasks | Where-Object { $_.task_id -eq "TASK_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V1_001" } | Select-Object -First 1

if ($State.current_phase -ne "PHASE_11") { throw "Expected PHASE_11." }
if ($State.current_capability -ne "factory_build_external_agent_mode_v1") { throw "Expected factory_build_external_agent_mode_v1." }
if ($Queue.active_task_id -ne "TASK_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 11 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 11 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_12"
    $State.current_capability = "production_factory_proof_v1"
    $State.completed_capabilities += "factory_build_external_agent_mode_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_PRODUCTION_FACTORY_PROOF_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_PRODUCTION_FACTORY_PROOF_V1_001"
        capability_id = "production_factory_proof_v1"
        status = "ACTIVE"
        objective = "Prove production-grade factory build mode end to end."
        expected_gate = "PRODUCTION_FACTORY_PROOF_V1"
        build_task_path = "tasks/TASK_PRODUCTION_FACTORY_PROOF_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 | Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8
    $State | ConvertTo-Json -Depth 100 | Set-Content ".\GENESIS_STATE.json" -Encoding UTF8
    $Queue | ConvertTo-Json -Depth 100 | Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: factory_build_external_agent_mode_v1 checks passed. run_id=$RunId"
