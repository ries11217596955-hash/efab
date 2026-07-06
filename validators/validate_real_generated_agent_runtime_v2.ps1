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
$ProofRoot = ".\runs\$RunId\PHASE14_RUNTIME_V2_PROOF"
New-Item -ItemType Directory -Force -Path $ProofRoot | Out-Null

$Manifest = New-ExternalAgentPackage -Spec $Spec -OutputRoot $ProofRoot

$RequiredFiles = @(
    "AGENT_PROFILE.json",
    "contracts\request.schema.json",
    "contracts\result.schema.json",
    "modules\invoke_agent_operation.ps1",
    "orchestrator\run.ps1",
    "validators\validate_package.ps1",
    "examples\SAMPLE_REQUEST.json"
)

foreach ($Rel in $RequiredFiles) {
    if (-not (Test-Path (Join-Path $Manifest.package_root $Rel))) {
        throw "Runtime v2 package missing file: $Rel"
    }
}

& (Join-Path $Manifest.package_root "validators\validate_package.ps1") | Out-Host

$OutputPath = Join-Path $Manifest.package_root "examples\SAMPLE_RESULT.json"

& (Join-Path $Manifest.package_root "orchestrator\run.ps1") `
    -Mode RUN `
    -InputPath (Join-Path $Manifest.package_root "examples\SAMPLE_REQUEST.json") `
    -OutputPath $OutputPath |
    Out-Host

$Result = Get-Content $OutputPath -Raw | ConvertFrom-Json

if ($Result.status -ne "PASS") { throw "Generated RUN result status must be PASS." }
if ($Result.request_id -ne "sample_request_001") { throw "Generated RUN request_id mismatch." }
if ($Result.agent_id -ne $Spec.agent_id) { throw "Generated RUN agent_id mismatch." }

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "real_generated_agent_runtime_v2" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "operational_validation_harness_v2" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_REAL_GENERATED_AGENT_RUNTIME_V2_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_14") { throw "Expected PHASE_14." }
if ($State.current_capability -ne "real_generated_agent_runtime_v2") { throw "Expected real_generated_agent_runtime_v2." }
if ($Queue.active_task_id -ne "TASK_REAL_GENERATED_AGENT_RUNTIME_V2_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 14 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 14 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_15"
    $State.current_capability = "operational_validation_harness_v2"
    $State.completed_capabilities += "real_generated_agent_runtime_v2"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_OPERATIONAL_VALIDATION_HARNESS_V2_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_OPERATIONAL_VALIDATION_HARNESS_V2_001"
        capability_id = "operational_validation_harness_v2"
        status = "ACTIVE"
        objective = "Add a reusable operational validation harness for generated agent packages."
        expected_gate = "OPERATIONAL_VALIDATION_HARNESS_V2_READY"
        build_task_path = "tasks/TASK_OPERATIONAL_VALIDATION_HARNESS_V2_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: real_generated_agent_runtime_v2 checks passed. run_id=$RunId"
