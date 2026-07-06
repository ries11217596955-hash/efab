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

$SpecPath = ".\packs\PHASE7_FIRST_PROVEN_EXTERNAL_AGENT\payload\specs\SPEC_TO_TEMPLATE_AGENT.json"
if (-not (Test-Path $SpecPath)) {
    throw "Proof agent spec missing."
}

$Spec = Get-Content $SpecPath -Raw | ConvertFrom-Json

$OutputRoot = ".\generated_agents"
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$Manifest = New-ExternalAgentPackage -Spec $Spec -OutputRoot $OutputRoot

$ExpectedFiles = @(
    (Join-Path $Manifest.package_root "README.md"),
    (Join-Path $Manifest.package_root "AGENT_MISSION.md")
)

$ExpectedDirs = @(
    (Join-Path $Manifest.package_root "contracts"),
    (Join-Path $Manifest.package_root "modules"),
    (Join-Path $Manifest.package_root "validators")
)

foreach ($Path in $ExpectedFiles) {
    if (-not (Test-Path $Path)) {
        throw "Generated proof file missing: $Path"
    }
}

foreach ($Path in $ExpectedDirs) {
    if (-not (Test-Path $Path)) {
        throw "Generated proof directory missing: $Path"
    }
}

$Phase7Cap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "first_proven_external_agent" } |
    Select-Object -First 1

$Phase7Task = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_FIRST_PROVEN_EXTERNAL_AGENT_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_7") { throw "Expected PHASE_7." }
if ($State.current_capability -ne "first_proven_external_agent") { throw "Expected first_proven_external_agent." }
if ($Queue.active_task_id -ne "TASK_FIRST_PROVEN_EXTERNAL_AGENT_001") { throw "Unexpected active task." }
if ($Phase7Cap.status -ne "ACTIVE") { throw "PHASE 7 capability must be ACTIVE." }
if ($Phase7Task.status -ne "ACTIVE") { throw "PHASE 7 task must be ACTIVE." }

$Proof = [ordered]@{
    proof_id = "FIRST_EXTERNAL_AGENT_PROOF_001"
    run_id = $RunId
    status = "PASS"
    proof_agent_id = $Spec.agent_id
    generated_package_root = $Manifest.package_root
    created_files = $Manifest.created_files
    checked_files = $ExpectedFiles
    checked_directories = $ExpectedDirs
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\FIRST_EXTERNAL_AGENT_PROOF_001.json" -Encoding UTF8

if ($FinalizePhase) {
    $Phase7Cap.status = "COMPLETED"

    $State.first_external_agent_proof = $true
    $State.last_run_status = "PASS"

    $Phase7Task.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    $Roadmap | ConvertTo-Json -Depth 100 | Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8
    $State | ConvertTo-Json -Depth 100 | Set-Content ".\GENESIS_STATE.json" -Encoding UTF8
    $Queue | ConvertTo-Json -Depth 100 | Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: first_proven_external_agent checks passed. run_id=$RunId"
