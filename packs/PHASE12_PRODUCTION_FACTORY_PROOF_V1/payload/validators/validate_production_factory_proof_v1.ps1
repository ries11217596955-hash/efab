param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$OutputRoot = ".\generated_agents"
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$ProofSpec = ".\specs\production_factory_proof\PRODUCTION_FACTORY_PROOF_SPEC.json"

& ".\orchestrator\run.ps1" `
    -Mode BUILD_EXTERNAL_AGENT `
    -RunId $RunId `
    -SpecPath $ProofSpec `
    -OutputRoot $OutputRoot |
    Out-Host

$GeneratedRoot = ".\generated_agents\production_factory_proof_agent"

$Required = @(
    "README.md",
    "AGENTS.md",
    "AGENT_MISSION.md",
    "contracts\input_contract.json",
    "contracts\output_contract.json",
    "orchestrator\run.ps1",
    "validators\validate_package.ps1"
)

foreach ($Rel in $Required) {
    $Path = Join-Path $GeneratedRoot $Rel
    if (-not (Test-Path $Path)) {
        throw "Production proof package missing: $Rel"
    }
}

$Proof = [ordered]@{
    proof_id = "PRODUCTION_FACTORY_PROOF_V1"
    run_id = $RunId
    status = "PASS"
    generated_agent_id = "production_factory_proof_agent"
    generated_package_root = $GeneratedRoot
    checked_files = $Required
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\PRODUCTION_FACTORY_PROOF_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities | Where-Object { $_.id -eq "production_factory_proof_v1" } | Select-Object -First 1
$ThisTask = $Queue.tasks | Where-Object { $_.task_id -eq "TASK_PRODUCTION_FACTORY_PROOF_V1_001" } | Select-Object -First 1

if ($State.current_phase -ne "PHASE_12") { throw "Expected PHASE_12." }
if ($State.current_capability -ne "production_factory_proof_v1") { throw "Expected production_factory_proof_v1." }
if ($Queue.active_task_id -ne "TASK_PRODUCTION_FACTORY_PROOF_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 12 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 12 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"

    $State.production_factory_ready = $true
    $State.current_phase = "PHASE_12"
    $State.current_capability = "production_factory_proof_v1"
    $State.completed_capabilities += "production_factory_proof_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    $Roadmap | ConvertTo-Json -Depth 100 | Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8
    $State | ConvertTo-Json -Depth 100 | Set-Content ".\GENESIS_STATE.json" -Encoding UTF8
    $Queue | ConvertTo-Json -Depth 100 | Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: production_factory_proof_v1 checks passed. run_id=$RunId"
