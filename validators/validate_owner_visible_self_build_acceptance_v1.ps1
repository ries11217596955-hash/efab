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

$SelectedPack = "PHASE54_OWNER_VISIBLE_SELF_BUILD_ACCEPTANCE_V1"
$CapabilityId = "owner_visible_self_build_acceptance_v1"
$TaskId = "TASK_OWNER_VISIBLE_SELF_BUILD_ACCEPTANCE_V1_001"

$RequiredFiles = @(
    ".\.github\workflows\agent-builder-self-build.yml",
    ".\.github\workflows\agent-builder-build-from-raw-idea.yml",
    ".\specs\factory_acceptance\raw_ideas\OWNER_VISIBLE_EXTERNAL_AGENT_IDEA.json",
    ".\docs\OWNER_VISIBLE_FACTORY_ACCEPTANCE_LOOP_V1.md",
    ".\tasks\TASK_OWNER_VISIBLE_SELF_BUILD_ACCEPTANCE_V1_001.json"
)

foreach ($Path in $RequiredFiles) {
    if (-not (Test-Path $Path)) {
        throw "Owner-visible acceptance required file missing: $Path"
    }
}

$SelfBuildWorkflow = Get-Content ".\.github\workflows\agent-builder-self-build.yml" -Raw
foreach ($Marker in @("workflow_dispatch:", "orchestrator\run.ps1", "-Mode SELF_BUILD", "actions/upload-artifact@v7")) {
    if ($SelfBuildWorkflow -notmatch [regex]::Escape($Marker)) {
        throw "Self-build workflow missing marker: $Marker"
    }
}

$RawIdeaWorkflow = Get-Content ".\.github\workflows\agent-builder-build-from-raw-idea.yml" -Raw
foreach ($Marker in @("workflow_dispatch:", "BUILD_FROM_RAW_IDEA", "raw_idea_path:", "output_root:", "actions/upload-artifact@v7")) {
    if ($RawIdeaWorkflow -notmatch [regex]::Escape($Marker)) {
        throw "Raw-idea workflow missing marker: $Marker"
    }
}

Assert-JsonParse ".\specs\factory_acceptance\raw_ideas\OWNER_VISIBLE_EXTERNAL_AGENT_IDEA.json"
Assert-JsonParse ".\TASK_QUEUE.json"
Assert-JsonParse ".\CAPABILITY_ROADMAP.json"
Assert-JsonParse ".\GENESIS_STATE.json"

$RawIdea = Get-Content ".\specs\factory_acceptance\raw_ideas\OWNER_VISIBLE_EXTERNAL_AGENT_IDEA.json" -Raw | ConvertFrom-Json
foreach ($Field in @("problem", "target_user", "operator_goal", "expected_outputs", "constraints", "non_goals")) {
    if (-not $RawIdea.payload.PSObject.Properties.Name.Contains($Field)) {
        throw "Raw idea payload missing field: $Field"
    }
}

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq $CapabilityId } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq $TaskId } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_54") { throw "Expected PHASE_54." }
if ($State.current_capability -ne $CapabilityId) { throw "Expected $CapabilityId." }
if ($Queue.active_task_id -ne $TaskId) { throw "Unexpected active task." }
if ($null -eq $ThisCap) { throw "PHASE54 capability missing from roadmap." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE54 capability must be ACTIVE before runtime." }
if ($null -eq $ThisTask) { throw "PHASE54 task missing from queue." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE54 task must be ACTIVE before runtime." }
if (-not $State.github_action_execution_surface_ready) { throw "GitHub Action execution surface must already be ready." }
if (-not $State.self_build_ready) { throw "Self-build readiness must already be true." }
if (-not $State.external_agent_build_ready) { throw "External-agent build readiness must already be true." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    if (@($State.completed_capabilities) -notcontains $CapabilityId) {
        $State.completed_capabilities += $CapabilityId
    }

    $State.current_phase = "PHASE_54"
    $State.current_capability = $CapabilityId
    $State.last_run_status = "PASS"

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Assert-JsonParse ".\TASK_QUEUE.json"
Assert-JsonParse ".\CAPABILITY_ROADMAP.json"
Assert-JsonParse ".\GENESIS_STATE.json"

$Proof = [ordered]@{
    proof_id = "OWNER_VISIBLE_SELF_BUILD_ACCEPTANCE_V1"
    run_id = $RunId
    selected_pack = $SelectedPack
    execution_mode = "SELF_BUILD"
    source_surface = "GITHUB_ACTION_COMPATIBLE"
    status = "PASS"
    statement = "Agent Builder consumed a repo-defined PHASE54 self-build pack through the GitHub Action compatible self-build path and advanced its own roadmap, state, and task queue truth from ACTIVE to completed with queue NONE."
    owner_visible_surfaces = [ordered]@{
        self_build_workflow = ".github/workflows/agent-builder-self-build.yml"
        raw_idea_workflow = ".github/workflows/agent-builder-build-from-raw-idea.yml"
        raw_idea_fixture = "specs/factory_acceptance/raw_ideas/OWNER_VISIBLE_EXTERNAL_AGENT_IDEA.json"
        playbook = "docs/OWNER_VISIBLE_FACTORY_ACCEPTANCE_LOOP_V1.md"
    }
    final_state = [ordered]@{
        capability_status = $ThisCap.status
        active_task_id = $Queue.active_task_id
        last_run_status = $State.last_run_status
    }
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\OWNER_VISIBLE_SELF_BUILD_ACCEPTANCE_V1.json" -Encoding UTF8

Write-Host "OWNER_VISIBLE_SELF_BUILD_ACCEPTANCE_STATUS=PASS"
Write-Host "OWNER_VISIBLE_SELF_BUILD_SELECTED_PACK=$SelectedPack"
Write-Host "OWNER_VISIBLE_SELF_BUILD_ACTIVE_TASK_AFTER=$($Queue.active_task_id)"
Write-Host "PASS :: owner_visible_self_build_acceptance_v1 checks passed. run_id=$RunId"
