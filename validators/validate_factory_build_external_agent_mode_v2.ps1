param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$OutputRoot = ".\runs\$RunId\PHASE16_BUILD_MODE_V2_PROOF"
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

& ".\orchestrator\run.ps1" `
    -Mode BUILD_EXTERNAL_AGENT `
    -RunId $RunId `
    -SpecPath ".\specs\external_agent_spec_template\SPEC_TEMPLATE.json" `
    -OutputRoot $OutputRoot |
    Out-Host

$ReportPath = ".\runs\$RunId\BUILD_EXTERNAL_AGENT_MODE_V2\BUILD_EXTERNAL_AGENT_REPORT.json"
if (-not (Test-Path $ReportPath)) {
    throw "BUILD_EXTERNAL_AGENT v2 report missing."
}

$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json
if ($Report.status -ne "PASS") {
    throw "BUILD_EXTERNAL_AGENT v2 report status must be PASS."
}

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "factory_build_external_agent_mode_v2" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "operational_factory_proof_v2" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V2_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_16") { throw "Expected PHASE_16." }
if ($State.current_capability -ne "factory_build_external_agent_mode_v2") { throw "Expected factory_build_external_agent_mode_v2." }
if ($Queue.active_task_id -ne "TASK_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V2_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 16 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 16 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_17"
    $State.current_capability = "operational_factory_proof_v2"
    $State.completed_capabilities += "factory_build_external_agent_mode_v2"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_OPERATIONAL_FACTORY_PROOF_V2_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_OPERATIONAL_FACTORY_PROOF_V2_001"
        capability_id = "operational_factory_proof_v2"
        status = "ACTIVE"
        objective = "Prove that Agent Builder can produce an operational baseline external agent through BUILD_EXTERNAL_AGENT mode v2."
        expected_gate = "OPERATIONAL_FACTORY_PROOF_V2"
        build_task_path = "tasks/TASK_OPERATIONAL_FACTORY_PROOF_V2_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: factory_build_external_agent_mode_v2 checks passed. run_id=$RunId"
