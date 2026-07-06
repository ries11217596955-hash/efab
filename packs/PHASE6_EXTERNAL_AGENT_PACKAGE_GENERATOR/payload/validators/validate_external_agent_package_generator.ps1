param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\new_external_agent_package.ps1"

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json
$Spec = Get-Content ".\specs\external_agent_spec_template\SPEC_TEMPLATE.json" -Raw | ConvertFrom-Json

$ProofRoot = ".\runs\$RunId\PACKAGE_GENERATOR_PROOF"
New-Item -ItemType Directory -Force -Path $ProofRoot | Out-Null

$Manifest = New-ExternalAgentPackage -Spec $Spec -OutputRoot $ProofRoot

if (-not (Test-Path (Join-Path $Manifest.package_root "README.md"))) {
    throw "Generated README missing."
}

if (-not (Test-Path (Join-Path $Manifest.package_root "AGENT_MISSION.md"))) {
    throw "Generated mission file missing."
}

$Phase6Cap = $Roadmap.capabilities | Where-Object { $_.id -eq "external_agent_package_generator" } | Select-Object -First 1
$Phase7Cap = $Roadmap.capabilities | Where-Object { $_.id -eq "first_proven_external_agent" } | Select-Object -First 1
$Phase6Task = $Queue.tasks | Where-Object { $_.task_id -eq "TASK_EXTERNAL_AGENT_PACKAGE_GENERATOR_001" } | Select-Object -First 1

if ($State.current_phase -ne "PHASE_6") { throw "Expected PHASE_6." }
if ($State.current_capability -ne "external_agent_package_generator") { throw "Expected external_agent_package_generator." }
if ($Queue.active_task_id -ne "TASK_EXTERNAL_AGENT_PACKAGE_GENERATOR_001") { throw "Unexpected active task." }
if ($Phase6Cap.status -ne "ACTIVE") { throw "Phase 6 capability must be ACTIVE." }
if ($Phase6Task.status -ne "ACTIVE") { throw "Phase 6 task must be ACTIVE." }

if ($FinalizePhase) {
    $Phase6Cap.status = "COMPLETED"
    $Phase7Cap.status = "ACTIVE"

    $State.current_phase = "PHASE_7"
    $State.current_capability = "first_proven_external_agent"
    $State.external_agent_build_ready = $true
    $State.completed_capabilities += "external_agent_package_generator"
    $State.last_run_status = "PASS"

    $Phase6Task.status = "COMPLETED"
    $Queue.active_task_id = "TASK_FIRST_PROVEN_EXTERNAL_AGENT_001"
    $Queue.tasks += [ordered]@{
        task_id = "TASK_FIRST_PROVEN_EXTERNAL_AGENT_001"
        capability_id = "first_proven_external_agent"
        status = "ACTIVE"
        objective = "Prove the factory by building the first real external agent package."
        expected_gate = "FIRST_EXTERNAL_AGENT_PROOF"
        build_task_path = "tasks/TASK_FIRST_PROVEN_EXTERNAL_AGENT_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 | Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8
    $State | ConvertTo-Json -Depth 100 | Set-Content ".\GENESIS_STATE.json" -Encoding UTF8
    $Queue | ConvertTo-Json -Depth 100 | Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: external_agent_package_generator checks passed. run_id=$RunId"
