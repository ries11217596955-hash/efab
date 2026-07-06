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

function Assert-RequiredApplyScript {
    param(
        [string]$Path,
        [string]$PackId,
        [string]$TaskId
    )

    if (-not (Test-Path $Path)) {
        throw "Generated APPLY.ps1 missing: $Path"
    }

    $Script = Get-Content $Path -Raw
    foreach ($Marker in @(
        "param(",
        "Set-StrictMode -Version Latest",
        '$ErrorActionPreference = "Stop"',
        'if (-not $InvokedByOrchestrator)',
        "Write-Host `"PACK=`$PackId`"",
        "Invoke-NativeGitCommand",
        "Complete-GeneratedProgramState",
        $PackId,
        $TaskId
    )) {
        if ($Script -notmatch [regex]::Escape($Marker)) {
            throw "Generated APPLY.ps1 for $PackId missing marker: $Marker"
        }
    }
}

function Add-CompletedCapability {
    param(
        [object]$State,
        [string]$CompletedCapabilityId
    )

    if (@($State.completed_capabilities) -notcontains $CompletedCapabilityId) {
        $State.completed_capabilities += $CompletedCapabilityId
    }
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\complete_generated_self_build_program_executable_packs.ps1"
. ".\modules\test_generated_self_build_program_admission_readiness.ps1"

$CapabilityId = "executable_generated_program_materialization_v1"
$TaskId = "TASK_EXECUTABLE_GENERATED_PROGRAM_MATERIALIZATION_V1_001"
$ProgramManifestPath = ".\self_build_programs\generated\monitoring_agent_v1\SELF_BUILD_PROGRAM_MANIFEST.json"

$Completion = Complete-GeneratedSelfBuildProgramExecutablePacks -ProgramManifestPath $ProgramManifestPath

if ($Completion.status -ne "PASS") {
    throw "Executable generated program materialization failed."
}
if ([int]$Completion.materialized_apply_script_count -ne 3) {
    throw "Expected three materialized APPLY.ps1 scripts."
}

$RequiredPacks = @(
    [pscustomobject]@{
        pack_id = "GENERATED_MONITORING_AGENT_V1_PROFILE_MATERIALIZATION_V1"
        task_id = "TASK_GENERATED_MONITORING_AGENT_V1_PROFILE_MATERIALIZATION_V1_001"
        path = ".\self_build_programs\generated\monitoring_agent_v1\packs\GENERATED_MONITORING_AGENT_V1_PROFILE_MATERIALIZATION_V1\APPLY.ps1"
    },
    [pscustomobject]@{
        pack_id = "GENERATED_MONITORING_AGENT_V1_CLOSURE_PROOF_V1"
        task_id = "TASK_GENERATED_MONITORING_AGENT_V1_CLOSURE_PROOF_V1_001"
        path = ".\self_build_programs\generated\monitoring_agent_v1\packs\GENERATED_MONITORING_AGENT_V1_CLOSURE_PROOF_V1\APPLY.ps1"
    },
    [pscustomobject]@{
        pack_id = "GENERATED_MONITORING_AGENT_V1_SEED_CONSUMPTION_PROOF_V1"
        task_id = "TASK_GENERATED_MONITORING_AGENT_V1_SEED_CONSUMPTION_PROOF_V1_001"
        path = ".\self_build_programs\generated\monitoring_agent_v1\packs\GENERATED_MONITORING_AGENT_V1_SEED_CONSUMPTION_PROOF_V1\APPLY.ps1"
    }
)

foreach ($RequiredPack in $RequiredPacks) {
    Assert-RequiredApplyScript `
        -Path $RequiredPack.path `
        -PackId $RequiredPack.pack_id `
        -TaskId $RequiredPack.task_id
}

$Readiness = Test-GeneratedSelfBuildProgramAdmissionReadiness -ProgramManifestPath $ProgramManifestPath

if ($Readiness.status -ne "PASS") {
    throw "Admission readiness status must be PASS."
}
if ($Readiness.admission_decision -ne "ADMISSION_READY") {
    throw "Admission readiness must be ADMISSION_READY after executable materialization."
}
if ([int]$Readiness.executable_pack_count -ne 3) {
    throw "Executable pack count must be 3."
}
if ([int]$Readiness.blocked_pack_count -ne 0) {
    throw "Blocked pack count must be 0."
}

$ReportRoot = ".\reports\executable_generated_program_materialization"
New-Item -ItemType Directory -Force -Path $ReportRoot | Out-Null
$ReportPath = Join-Path $ReportRoot "MONITORING_AGENT_V1_EXECUTABLE_PACKS.json"

$Report = [ordered]@{
    report_id = "MONITORING_AGENT_V1_EXECUTABLE_PACKS"
    run_id = $RunId
    status = "PASS"
    evaluated_program_manifest = $ProgramManifestPath
    materialized_apply_script_count = $Completion.materialized_apply_script_count
    materialized_packs = $Completion.materialized_packs
    admission_decision_after_materialization = $Readiness.admission_decision
    executable_pack_count = $Readiness.executable_pack_count
    blocked_pack_count = $Readiness.blocked_pack_count
    next_required_capability = "generated_program_live_admission_proof_v1"
}

$Report | ConvertTo-Json -Depth 100 |
    Set-Content $ReportPath -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq $CapabilityId } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq $TaskId } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_56") { throw "Expected PHASE_56." }
if ($State.current_capability -ne $CapabilityId) { throw "Expected $CapabilityId." }
if ($Queue.active_task_id -ne $TaskId) { throw "Unexpected active task." }
if ($null -eq $ThisCap) { throw "PHASE56 capability missing from roadmap." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE56 capability must be ACTIVE before runtime finalization." }
if ($null -eq $ThisTask) { throw "PHASE56 task missing from queue." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE56 task must be ACTIVE before runtime finalization." }
if (-not $State.self_build_ready) { throw "Self-build readiness must already be true." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    Add-CompletedCapability -State $State -CompletedCapabilityId $CapabilityId

    $State.current_phase = "PHASE_56"
    $State.current_capability = $CapabilityId
    $State.last_run_status = "PASS"
    $State | Add-Member -NotePropertyName "executable_generated_program_materialization_ready" -NotePropertyValue $true -Force

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Assert-JsonParse ".\CAPABILITY_ROADMAP.json"
Assert-JsonParse ".\GENESIS_STATE.json"
Assert-JsonParse ".\TASK_QUEUE.json"

$Proof = [ordered]@{
    proof_id = "EXECUTABLE_GENERATED_PROGRAM_MATERIALIZATION_V1"
    run_id = $RunId
    status = "PASS"
    evaluated_program_manifest = $ProgramManifestPath
    materialized_apply_script_count = 3
    admission_decision_after_materialization = "ADMISSION_READY"
    next_required_capability = "generated_program_live_admission_proof_v1"
    report_path = $ReportPath
    conclusion = "Builder can now materialize generated self-build programs into an executable admission-ready contour."
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\EXECUTABLE_GENERATED_PROGRAM_MATERIALIZATION_V1.json" -Encoding UTF8

Write-Host "EXECUTABLE_GENERATED_PROGRAM_MATERIALIZATION_STATUS=PASS"
Write-Host "EXECUTABLE_GENERATED_PROGRAM_APPLY_SCRIPT_COUNT=$($Completion.materialized_apply_script_count)"
Write-Host "EXECUTABLE_GENERATED_PROGRAM_ADMISSION_DECISION=$($Readiness.admission_decision)"
Write-Host "EXECUTABLE_GENERATED_PROGRAM_BLOCKED_PACK_COUNT=$($Readiness.blocked_pack_count)"
Write-Host "EXECUTABLE_GENERATED_PROGRAM_NEXT_REQUIRED_CAPABILITY=generated_program_live_admission_proof_v1"
Write-Host "PASS :: executable_generated_program_materialization_v1 checks passed. run_id=$RunId"
