param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\new_external_agent_package.ps1"

$Spec = Get-Content ".\specs\external_agent_spec_template\SPEC_TEMPLATE.json" -Raw | ConvertFrom-Json
$ProofRoot = ".\runs\$RunId\PHASE9_PACKAGE_BLUEPRINT_PROOF"
New-Item -ItemType Directory -Force -Path $ProofRoot | Out-Null

$Manifest = New-ExternalAgentPackage -Spec $Spec -OutputRoot $ProofRoot

$RequiredFiles = @(
    "README.md",
    "AGENTS.md",
    "AGENT_MISSION.md",
    "contracts\input_contract.json",
    "contracts\output_contract.json",
    "modules\README.md",
    "orchestrator\run.ps1",
    "validators\validate_package.ps1",
    "examples\SAMPLE_INPUT.json"
)

foreach ($Rel in $RequiredFiles) {
    $Path = Join-Path $Manifest.package_root $Rel
    if (-not (Test-Path $Path)) {
        throw "Package blueprint missing file: $Rel"
    }
}

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities | Where-Object { $_.id -eq "production_package_blueprint_v1" } | Select-Object -First 1
$NextCap = $Roadmap.capabilities | Where-Object { $_.id -eq "generated_agent_validation_harness_v1" } | Select-Object -First 1
$ThisTask = $Queue.tasks | Where-Object { $_.task_id -eq "TASK_PRODUCTION_PACKAGE_BLUEPRINT_V1_001" } | Select-Object -First 1

if ($State.current_phase -ne "PHASE_9") { throw "Expected PHASE_9." }
if ($State.current_capability -ne "production_package_blueprint_v1") { throw "Expected production_package_blueprint_v1." }
if ($Queue.active_task_id -ne "TASK_PRODUCTION_PACKAGE_BLUEPRINT_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 9 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 9 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_10"
    $State.current_capability = "generated_agent_validation_harness_v1"
    $State.completed_capabilities += "production_package_blueprint_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_GENERATED_AGENT_VALIDATION_HARNESS_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_GENERATED_AGENT_VALIDATION_HARNESS_V1_001"
        capability_id = "generated_agent_validation_harness_v1"
        status = "ACTIVE"
        objective = "Add reusable validation harness for generated agent packages."
        expected_gate = "GENERATED_AGENT_VALIDATION_HARNESS_V1_READY"
        build_task_path = "tasks/TASK_GENERATED_AGENT_VALIDATION_HARNESS_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 | Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8
    $State | ConvertTo-Json -Depth 100 | Set-Content ".\GENESIS_STATE.json" -Encoding UTF8
    $Queue | ConvertTo-Json -Depth 100 | Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: production_package_blueprint_v1 checks passed. run_id=$RunId"
