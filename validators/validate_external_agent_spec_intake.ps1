param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\validate_external_agent_spec_template.ps1"

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$TemplatePath = ".\specs\external_agent_spec_template\SPEC_TEMPLATE.json"
$TemplateProof = Test-ExternalAgentSpecTemplate -TemplatePath $TemplatePath

if ($TemplateProof -ne "PASS") {
    throw "Template validation failed."
}

$Phase5Cap = $Roadmap.capabilities | Where-Object { $_.id -eq "external_agent_spec_intake" } | Select-Object -First 1
$Phase6Cap = $Roadmap.capabilities | Where-Object { $_.id -eq "external_agent_package_generator" } | Select-Object -First 1
$Phase5Task = $Queue.tasks | Where-Object { $_.task_id -eq "TASK_EXTERNAL_AGENT_SPEC_INTAKE_001" } | Select-Object -First 1

if ($State.current_phase -ne "PHASE_5") { throw "Expected PHASE_5." }
if ($State.current_capability -ne "external_agent_spec_intake") { throw "Expected external_agent_spec_intake." }
if ($Queue.active_task_id -ne "TASK_EXTERNAL_AGENT_SPEC_INTAKE_001") { throw "Unexpected active task." }
if ($Phase5Cap.status -ne "ACTIVE") { throw "Phase 5 capability must be ACTIVE." }
if ($Phase5Task.status -ne "ACTIVE") { throw "Phase 5 task must be ACTIVE." }

if ($FinalizePhase) {
    $Phase5Cap.status = "COMPLETED"
    $Phase6Cap.status = "ACTIVE"

    $State.current_phase = "PHASE_6"
    $State.current_capability = "external_agent_package_generator"
    $State.completed_capabilities += "external_agent_spec_intake"
    $State.last_run_status = "PASS"

    $Phase5Task.status = "COMPLETED"
    $Queue.active_task_id = "TASK_EXTERNAL_AGENT_PACKAGE_GENERATOR_001"
    $Queue.tasks += [ordered]@{
        task_id = "TASK_EXTERNAL_AGENT_PACKAGE_GENERATOR_001"
        capability_id = "external_agent_package_generator"
        status = "ACTIVE"
        objective = "Implement external agent package generator."
        expected_gate = "EXTERNAL_AGENT_PACKAGE_GENERATOR_READY"
        build_task_path = "tasks/TASK_EXTERNAL_AGENT_PACKAGE_GENERATOR_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 | Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8
    $State | ConvertTo-Json -Depth 100 | Set-Content ".\GENESIS_STATE.json" -Encoding UTF8
    $Queue | ConvertTo-Json -Depth 100 | Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: external_agent_spec_intake checks passed. run_id=$RunId"
