param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\validate_production_external_agent_spec.ps1"

$SpecPath = ".\specs\external_agent_spec_template\SPEC_TEMPLATE.json"
$SpecProof = Test-ProductionExternalAgentSpec -SpecPath $SpecPath
if ($SpecProof -ne "PASS") { throw "Production spec validation failed." }

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities | Where-Object { $_.id -eq "production_spec_contract_v1" } | Select-Object -First 1
$NextCap = $Roadmap.capabilities | Where-Object { $_.id -eq "production_package_blueprint_v1" } | Select-Object -First 1
$ThisTask = $Queue.tasks | Where-Object { $_.task_id -eq "TASK_PRODUCTION_SPEC_CONTRACT_V1_001" } | Select-Object -First 1

if ($State.current_phase -ne "PHASE_8") { throw "Expected PHASE_8." }
if ($State.current_capability -ne "production_spec_contract_v1") { throw "Expected production_spec_contract_v1." }
if ($Queue.active_task_id -ne "TASK_PRODUCTION_SPEC_CONTRACT_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 8 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 8 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_9"
    $State.current_capability = "production_package_blueprint_v1"
    $State.completed_capabilities += "production_spec_contract_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_PRODUCTION_PACKAGE_BLUEPRINT_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_PRODUCTION_PACKAGE_BLUEPRINT_V1_001"
        capability_id = "production_package_blueprint_v1"
        status = "ACTIVE"
        objective = "Upgrade the external agent package generator to a production blueprint v1."
        expected_gate = "PRODUCTION_PACKAGE_BLUEPRINT_V1_READY"
        build_task_path = "tasks/TASK_PRODUCTION_PACKAGE_BLUEPRINT_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 | Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8
    $State | ConvertTo-Json -Depth 100 | Set-Content ".\GENESIS_STATE.json" -Encoding UTF8
    $Queue | ConvertTo-Json -Depth 100 | Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: production_spec_contract_v1 checks passed. run_id=$RunId"
