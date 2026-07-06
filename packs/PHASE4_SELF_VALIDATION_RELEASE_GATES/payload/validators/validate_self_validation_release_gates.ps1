param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\validate_truth_alignment.ps1"
. ".\modules\emit_failure_diagnostic.ps1"

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$Alignment = Test-TruthAlignment -GenesisState $State -Roadmap $Roadmap -TaskQueue $Queue

if ($Alignment -ne "PASS") { throw "Truth alignment failed." }

$ReleaseCap = $Roadmap.capabilities | Where-Object { $_.id -eq "self_validation_release_gates" } | Select-Object -First 1
$SpecCap = $Roadmap.capabilities | Where-Object { $_.id -eq "external_agent_spec_intake" } | Select-Object -First 1
$ReleaseTask = $Queue.tasks | Where-Object { $_.task_id -eq "TASK_SELF_VALIDATION_RELEASE_GATES_001" } | Select-Object -First 1

if ($State.current_phase -ne "PHASE_4") { throw "Expected PHASE_4." }
if ($State.current_capability -ne "self_validation_release_gates") { throw "Expected self_validation_release_gates." }
if ($ReleaseCap.status -ne "ACTIVE") { throw "Release capability not ACTIVE." }
if ($ReleaseTask.status -ne "ACTIVE") { throw "Release task not ACTIVE." }

if ($FinalizePhase) {
    $ReleaseCap.status = "COMPLETED"
    $SpecCap.status = "ACTIVE"

    $State.current_phase = "PHASE_5"
    $State.current_capability = "external_agent_spec_intake"
    $State.self_build_ready = $true
    $State.completed_capabilities += "self_validation_release_gates"
    $State.last_run_status = "PASS"

    $ReleaseTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_EXTERNAL_AGENT_SPEC_INTAKE_001"
    $Queue.tasks += [ordered]@{
        task_id = "TASK_EXTERNAL_AGENT_SPEC_INTAKE_001"
        capability_id = "external_agent_spec_intake"
        status = "ACTIVE"
        objective = "Implement formal intake for external agent specifications."
        expected_gate = "EXTERNAL_AGENT_SPEC_INTAKE_READY"
        build_task_path = "tasks/TASK_EXTERNAL_AGENT_SPEC_INTAKE_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 | Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8
    $State | ConvertTo-Json -Depth 100 | Set-Content ".\GENESIS_STATE.json" -Encoding UTF8
    $Queue | ConvertTo-Json -Depth 100 | Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: self_validation_release_gates checks passed. run_id=$RunId"
