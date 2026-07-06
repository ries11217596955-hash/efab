function Complete-GeneratedSelfBuildProgramExecutablePacks {
    param(
        [string]$ProgramManifestPath
    )

    if ([string]::IsNullOrWhiteSpace($ProgramManifestPath)) {
        throw "ProgramManifestPath is required."
    }

    if (-not (Test-Path $ProgramManifestPath)) {
        throw "Program manifest missing: $ProgramManifestPath"
    }

    $ManifestPath = (Resolve-Path $ProgramManifestPath).Path
    $ProgramRoot = Split-Path -Parent $ManifestPath
    $Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

    if ($Manifest.status -ne "PROGRAM_PACKAGE_MATERIALIZED") {
        throw "Program manifest status must be PROGRAM_PACKAGE_MATERIALIZED."
    }
    if ($Manifest.admission_status -ne "NOT_ADMITTED_YET") {
        throw "Program manifest admission_status must be NOT_ADMITTED_YET."
    }
    if ($Manifest.target_profile_id -ne "monitoring_agent_v1") {
        throw "PHASE56 executable materialization currently supports monitoring_agent_v1 only."
    }

    $PacksRoot = Join-Path $ProgramRoot "packs"
    $TasksRoot = Join-Path $ProgramRoot "tasks"
    $PatchesRoot = Join-Path $ProgramRoot "patches"

    foreach ($RequiredPath in @($PacksRoot, $TasksRoot, $PatchesRoot)) {
        if (-not (Test-Path $RequiredPath)) {
            throw "Generated program path missing: $RequiredPath"
        }
    }

    $RegistryPatchPath = Join-Path $PatchesRoot "PACK_REGISTRY_PATCH.json"
    $RoadmapPatchPath = Join-Path $PatchesRoot "CAPABILITY_ROADMAP_PATCH.json"
    $QueueSeedPath = Join-Path $PatchesRoot "TASK_QUEUE_SEED.json"

    foreach ($PatchPath in @($RegistryPatchPath, $RoadmapPatchPath, $QueueSeedPath)) {
        if (-not (Test-Path $PatchPath)) {
            throw "Generated program patch missing: $PatchPath"
        }
    }

    $RegistryPatch = Get-Content $RegistryPatchPath -Raw | ConvertFrom-Json
    $RoadmapPatch = Get-Content $RoadmapPatchPath -Raw | ConvertFrom-Json
    $QueueSeed = Get-Content $QueueSeedPath -Raw | ConvertFrom-Json

    foreach ($Patch in @($RegistryPatch, $RoadmapPatch, $QueueSeed)) {
        if ($Patch.status -ne "READY_FOR_ADMISSION") {
            throw "Generated program patch status must be READY_FOR_ADMISSION."
        }
    }

    $GeneratedPacks = @($RegistryPatch.generated_packs | Sort-Object { [int]$_.order })
    $GeneratedCapabilities = @($RoadmapPatch.generated_capabilities | Sort-Object { [int]$_.order })
    $GeneratedTasks = @($QueueSeed.generated_tasks | Sort-Object { [int]$_.order })

    if ($GeneratedPacks.Count -ne 3) {
        throw "Expected exactly three generated packs."
    }
    if ($GeneratedCapabilities.Count -ne 3) {
        throw "Expected exactly three generated capabilities."
    }
    if ($GeneratedTasks.Count -ne 3) {
        throw "Expected exactly three generated tasks."
    }
    if ([int]$Manifest.pack_count -ne $GeneratedPacks.Count) {
        throw "Manifest pack_count does not match generated registry patch."
    }
    if ([int]$Manifest.capability_count -ne $GeneratedCapabilities.Count) {
        throw "Manifest capability_count does not match generated roadmap patch."
    }
    if ([int]$Manifest.task_count -ne $GeneratedTasks.Count) {
        throw "Manifest task_count does not match generated task queue seed."
    }

    $MaterializedPacks = @()

    for ($Index = 0; $Index -lt $GeneratedPacks.Count; $Index++) {
        $PackPatch = $GeneratedPacks[$Index]
        $CapabilityPatch = $GeneratedCapabilities[$Index]
        $TaskSeed = $GeneratedTasks[$Index]

        if ($PackPatch.task_id -ne $TaskSeed.task_id) {
            throw "Generated pack/task order mismatch for pack $($PackPatch.pack_id)."
        }
        if ($CapabilityPatch.capability_id -ne $TaskSeed.capability_id) {
            throw "Generated capability/task order mismatch for task $($TaskSeed.task_id)."
        }

        $Role = Get-GeneratedExecutablePackRole -PackId $PackPatch.pack_id
        if ($Role -ne $CapabilityPatch.semantic_role) {
            throw "Generated pack role $Role does not match roadmap semantic role $($CapabilityPatch.semantic_role)."
        }

        $PackDir = Join-Path $PacksRoot $PackPatch.pack_id
        $PackContractPath = Join-Path $PackDir "PACK.json"
        $TaskContractPath = Join-Path $TasksRoot "$($TaskSeed.task_id).json"

        if (-not (Test-Path $PackContractPath)) {
            throw "Generated pack contract missing: $PackContractPath"
        }
        if (-not (Test-Path $TaskContractPath)) {
            throw "Generated task contract missing: $TaskContractPath"
        }

        $PackContract = Get-Content $PackContractPath -Raw | ConvertFrom-Json
        $TaskContract = Get-Content $TaskContractPath -Raw | ConvertFrom-Json

        if ($PackContract.pack_id -ne $PackPatch.pack_id) {
            throw "Generated pack contract id mismatch at $PackContractPath."
        }
        if ($PackContract.task_id -ne $PackPatch.task_id) {
            throw "Generated pack contract task id mismatch at $PackContractPath."
        }
        if ($PackContract.entry_script -ne "APPLY.ps1") {
            throw "Generated pack entry_script must be APPLY.ps1 at $PackContractPath."
        }
        if ($PackContract.shell -ne "PowerShell") {
            throw "Generated pack shell must be PowerShell at $PackContractPath."
        }
        if ($TaskContract.task_id -ne $TaskSeed.task_id) {
            throw "Generated task contract id mismatch at $TaskContractPath."
        }
        if ($TaskContract.capability_id -ne $TaskSeed.capability_id) {
            throw "Generated task contract capability mismatch at $TaskContractPath."
        }

        $NextCapabilityId = ""
        $NextTaskId = ""
        if ($Index -lt ($GeneratedPacks.Count - 1)) {
            $NextCapabilityId = [string]$GeneratedTasks[$Index + 1].capability_id
            $NextTaskId = [string]$GeneratedTasks[$Index + 1].task_id
        }

        $ApplyScript = New-GeneratedMonitoringAgentApplyScript `
            -PackId ([string]$PackPatch.pack_id) `
            -TaskId ([string]$TaskSeed.task_id) `
            -CapabilityId ([string]$TaskSeed.capability_id) `
            -ExpectedGate ([string]$TaskSeed.expected_gate) `
            -Role $Role `
            -NextCapabilityId $NextCapabilityId `
            -NextTaskId $NextTaskId

        $ApplyPath = Join-Path $PackDir "APPLY.ps1"
        $ApplyScript | Set-Content $ApplyPath -Encoding UTF8

        $MaterializedPacks += [pscustomobject]@{
            order = [int]$PackPatch.order
            pack_id = [string]$PackPatch.pack_id
            task_id = [string]$TaskSeed.task_id
            capability_id = [string]$TaskSeed.capability_id
            semantic_role = $Role
            apply_script_path = (Resolve-Path $ApplyPath).Path
        }
    }

    return [pscustomobject]@{
        status = "PASS"
        manifest_path = $ManifestPath
        program_root = $ProgramRoot
        materialized_apply_script_count = @($MaterializedPacks).Count
        materialized_packs = @($MaterializedPacks)
    }
}

function Get-GeneratedExecutablePackRole {
    param(
        [string]$PackId
    )

    if ($PackId -match "^GENERATED_.+_PROFILE_MATERIALIZATION_V1$") {
        return "PROFILE_MATERIALIZATION"
    }
    if ($PackId -match "^GENERATED_.+_CLOSURE_PROOF_V1$") {
        return "SPECIALIZED_CLOSURE_PROOF"
    }
    if ($PackId -match "^GENERATED_.+_SEED_CONSUMPTION_PROOF_V1$") {
        return "SEED_CONSUMPTION_PROOF"
    }

    throw "Unsupported generated executable pack id: $PackId"
}

function New-GeneratedMonitoringAgentApplyScript {
    param(
        [string]$PackId,
        [string]$TaskId,
        [string]$CapabilityId,
        [string]$ExpectedGate,
        [string]$Role,
        [string]$NextCapabilityId,
        [string]$NextTaskId
    )

    $Template = @'
param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$PackId = "__PACK_ID__"
$TaskId = "__TASK_ID__"
$CapabilityId = "__CAPABILITY_ID__"
$ExpectedGate = "__EXPECTED_GATE__"
$SemanticRole = "__SEMANTIC_ROLE__"
$NextCapabilityId = "__NEXT_CAPABILITY_ID__"
$NextTaskId = "__NEXT_TASK_ID__"

function Invoke-NativeGitCommand {
    param(
        [string]$Label,
        [string[]]$Arguments
    )

    $PreviousPreference = $ErrorActionPreference
    $Output = @()
    $ExitCode = $null

    try {
        $ErrorActionPreference = "Continue"
        $Output = @(& git @Arguments 2>&1)
        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    foreach ($Line in $Output) {
        Write-Host ($Line.ToString())
    }

    if ($ExitCode -ne 0) {
        throw "GIT_${Label}_FAILED_EXIT_CODE=$ExitCode"
    }

    Write-Host "GIT_${Label}=PASS"
}

function Assert-PathExists {
    param(
        [string]$Path,
        [string]$Label
    )

    if (-not (Test-Path $Path)) {
        throw "$Label missing: $Path"
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

function Complete-GeneratedProgramState {
    param(
        [string]$CompletedCapabilityId,
        [string]$CompletedTaskId,
        [string]$FollowingCapabilityId,
        [string]$FollowingTaskId
    )

    $State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
    $Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
    $Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

    $ThisCap = $Roadmap.capabilities |
        Where-Object { $_.id -eq $CompletedCapabilityId } |
        Select-Object -First 1

    $ThisTask = $Queue.tasks |
        Where-Object { $_.task_id -eq $CompletedTaskId } |
        Select-Object -First 1

    if ($null -eq $ThisCap) { throw "Generated capability missing from live roadmap: $CompletedCapabilityId" }
    if ($null -eq $ThisTask) { throw "Generated task missing from live queue: $CompletedTaskId" }
    if ($State.current_capability -ne $CompletedCapabilityId) { throw "Expected current generated capability $CompletedCapabilityId." }
    if ($Queue.active_task_id -ne $CompletedTaskId) { throw "Expected active generated task $CompletedTaskId." }
    if ($ThisCap.status -ne "ACTIVE") { throw "Generated capability must be ACTIVE before execution." }
    if ($ThisTask.status -ne "ACTIVE") { throw "Generated task must be ACTIVE before execution." }

    $ThisCap.status = "COMPLETED"
    $ThisTask.status = "COMPLETED"
    Add-CompletedCapability -State $State -CompletedCapabilityId $CompletedCapabilityId
    $State.last_run_status = "PASS"

    if (-not [string]::IsNullOrWhiteSpace($FollowingCapabilityId)) {
        $NextCap = $Roadmap.capabilities |
            Where-Object { $_.id -eq $FollowingCapabilityId } |
            Select-Object -First 1

        $NextTask = $Queue.tasks |
            Where-Object { $_.task_id -eq $FollowingTaskId } |
            Select-Object -First 1

        if ($null -eq $NextCap) { throw "Next generated capability missing from live roadmap: $FollowingCapabilityId" }
        if ($null -eq $NextTask) { throw "Next generated task missing from live queue: $FollowingTaskId" }

        $NextCap.status = "ACTIVE"
        $NextTask.status = "ACTIVE"
        $Queue.active_task_id = $FollowingTaskId
        $State.current_capability = $FollowingCapabilityId
        if ($NextCap.PSObject.Properties.Name.Contains("phase") -and -not [string]::IsNullOrWhiteSpace([string]$NextCap.phase)) {
            $State.current_phase = [string]$NextCap.phase
        }
    }
    else {
        $Queue.active_task_id = "NONE"
        $State.current_capability = $CompletedCapabilityId
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

function Invoke-GeneratedProfileMaterialization {
    param([string]$RunId)

    $ProgramSeedPath = ".\remediation_programs\MONITORING_AGENT_REMEDIATION_PROGRAM_SEED_V1.json"
    $SpecPath = ".\specs\monitoring_profile_proof\MONITORING_AGENT_PROFILE_PROOF_SPEC.json"

    Assert-PathExists -Path $ProgramSeedPath -Label "Canonical monitoring remediation program seed"
    Assert-PathExists -Path $SpecPath -Label "Monitoring profile proof spec"
    Assert-PathExists -Path ".\modules\resolve_specialization_overlay.ps1" -Label "Specialization overlay resolver"
    Assert-PathExists -Path ".\modules\invoke_external_agent_build.ps1" -Label "External agent build module"

    . ".\modules\resolve_specialization_overlay.ps1"
    . ".\modules\invoke_external_agent_build.ps1"

    $Seed = Get-Content $ProgramSeedPath -Raw | ConvertFrom-Json
    if ($Seed.status -ne "PROGRAM_SEED_READY") { throw "Program seed status mismatch." }
    if ($Seed.candidate_profile_id -ne "monitoring_agent_v1") { throw "Program seed profile target mismatch." }
    if ($Seed.candidate_agent_kind -ne "monitoring_agent") { throw "Program seed kind target mismatch." }

    $Resolution = Resolve-SpecializationOverlay `
        -AgentKind "monitoring_agent" `
        -PackageProfile "operational_specialized"

    if ($Resolution.status -ne "PASS") { throw "Resolver must return PASS for monitoring_agent." }
    if ($Resolution.profile_id -ne "monitoring_agent_v1") { throw "Unexpected monitoring specialization profile id." }

    $Build = Invoke-ExternalAgentBuild `
        -SpecPath $SpecPath `
        -OutputRoot ".\generated_agents" `
        -RunRoot ".\runs\$RunId\$PackId\profile_build" `
        -OverlayRoot $Resolution.overlay_root

    if ($Build.status -ne "PASS") { throw "Monitoring generated profile build must be PASS." }
    if ($Build.overlay.status -ne "PASS") { throw "Monitoring generated overlay apply must be PASS." }

    $ValidationOutput = $Build.validation.output_result_path
    Assert-PathExists -Path $ValidationOutput -Label "Monitoring generated validation output"

    $Result = Get-Content $ValidationOutput -Raw | ConvertFrom-Json
    if ($Result.result.operation -ne "monitoring_alert_triage_queue") { throw "Monitoring specialized operation mismatch." }
    if ($Result.diagnostics.specialization_profile -ne "monitoring_agent_v1") { throw "Monitoring specialization diagnostics mismatch." }
    if ($Result.result.next_alert_id -ne "cpu_spike") { throw "Monitoring next alert mismatch." }
    if ($Result.result.escalation_status -ne "ESCALATE") { throw "Monitoring escalation status mismatch." }

    $Proof = [ordered]@{
        proof_id = $PackId
        run_id = $RunId
        status = "PASS"
        task_id = $TaskId
        capability_id = $CapabilityId
        expected_gate = $ExpectedGate
        semantic_role = $SemanticRole
        program_seed_path = $ProgramSeedPath
        selected_profile_id = $Resolution.profile_id
        build_report_path = $Build.report_path
        validation_output = $ValidationOutput
        specialized_operation = $Result.result.operation
        next_alert_id = $Result.result.next_alert_id
        escalation_status = $Result.result.escalation_status
        conclusion = "Generated monitoring_agent_v1 profile materialization executed through the existing validated monitoring profile contour."
    }

    $ProofPath = ".\proofs\$PackId.json"
    $Proof | ConvertTo-Json -Depth 100 |
        Set-Content $ProofPath -Encoding UTF8

    return $ProofPath
}

function Invoke-GeneratedClosureProof {
    param([string]$RunId)

    $RawIdeaPath = ".\specs\monitoring_gap_proof\RAW_IDEA_MONITORING_GAP_PROOF.json"
    Assert-PathExists -Path $RawIdeaPath -Label "Monitoring gap proof raw idea"

    & ".\orchestrator\run.ps1" `
        -Mode BUILD_FROM_RAW_IDEA_SPECIALIZED `
        -RunId $RunId `
        -RawIdeaPath $RawIdeaPath `
        -OutputRoot ".\generated_agents" |
        Out-Host

    $ReportPath = ".\runs\$RunId\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1\BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"
    Assert-PathExists -Path $ReportPath -Label "Monitoring generated closure factory report"

    $Report = Get-Content $ReportPath -Raw | ConvertFrom-Json
    if ($Report.status -ne "PASS") { throw "Monitoring generated closure factory report must be PASS." }
    if ($Report.specialization.profile_id -ne "monitoring_agent_v1") { throw "Monitoring generated closure did not route to monitoring_agent_v1." }
    if ($null -ne $Report.gap_report) { throw "Monitoring generated closure path must not retain a gap report." }
    if ($Report.target_build.overlay_status -ne "PASS") { throw "Monitoring generated closure overlay status must be PASS." }

    Assert-PathExists -Path $Report.target_build.validation_output -Label "Monitoring generated closure validation output"
    $Result = Get-Content $Report.target_build.validation_output -Raw | ConvertFrom-Json

    if ($Result.result.operation -ne "monitoring_alert_triage_queue") { throw "Monitoring generated closure specialized operation mismatch." }
    if ($Result.diagnostics.specialization_profile -ne "monitoring_agent_v1") { throw "Monitoring generated closure specialization diagnostics mismatch." }
    if ($Result.result.next_alert_id -ne "cpu_spike") { throw "Monitoring generated closure next alert mismatch." }
    if ($Result.result.escalation_status -ne "ESCALATE") { throw "Monitoring generated closure escalation status mismatch." }

    $Proof = [ordered]@{
        proof_id = $PackId
        run_id = $RunId
        status = "PASS"
        task_id = $TaskId
        capability_id = $CapabilityId
        expected_gate = $ExpectedGate
        semantic_role = $SemanticRole
        raw_idea_path = $RawIdeaPath
        factory_report_path = $ReportPath
        selected_profile_id = $Report.specialization.profile_id
        generated_package_root = $Report.target_build.package_root
        validation_output = $Report.target_build.validation_output
        specialized_operation = $Result.result.operation
        next_alert_id = $Result.result.next_alert_id
        escalation_status = $Result.result.escalation_status
        conclusion = "Generated monitoring_agent_v1 closure proof reran the formerly missing monitoring specialization route and closed it to PASS."
    }

    $ProofPath = ".\proofs\$PackId.json"
    $Proof | ConvertTo-Json -Depth 100 |
        Set-Content $ProofPath -Encoding UTF8

    return $ProofPath
}

function Invoke-GeneratedSeedConsumptionProof {
    param([string]$RunId)

    $ProgramSeedPath = ".\remediation_programs\MONITORING_AGENT_REMEDIATION_PROGRAM_SEED_V1.json"
    $ProfileProofPath = ".\proofs\GENERATED_MONITORING_AGENT_V1_PROFILE_MATERIALIZATION_V1.json"
    $ClosureProofPath = ".\proofs\GENERATED_MONITORING_AGENT_V1_CLOSURE_PROOF_V1.json"

    Assert-PathExists -Path $ProgramSeedPath -Label "Canonical remediation program seed"
    Assert-PathExists -Path $ProfileProofPath -Label "Generated monitoring profile proof"
    Assert-PathExists -Path $ClosureProofPath -Label "Generated monitoring closure proof"

    $Seed = Get-Content $ProgramSeedPath -Raw | ConvertFrom-Json
    $ProfileProof = Get-Content $ProfileProofPath -Raw | ConvertFrom-Json
    $ClosureProof = Get-Content $ClosureProofPath -Raw | ConvertFrom-Json

    if ($Seed.candidate_profile_id -ne "monitoring_agent_v1") { throw "Seed profile id mismatch." }
    if ($Seed.candidate_agent_kind -ne "monitoring_agent") { throw "Seed agent kind mismatch." }
    if ($ProfileProof.status -ne "PASS") { throw "Generated profile proof must be PASS." }
    if ($ProfileProof.selected_profile_id -ne $Seed.candidate_profile_id) { throw "Generated profile proof does not consume the seed profile id." }
    if ($ClosureProof.status -ne "PASS") { throw "Generated closure proof must be PASS." }
    if ($ClosureProof.selected_profile_id -ne $Seed.candidate_profile_id) { throw "Generated closure proof does not close through the seed profile id." }
    if ($ClosureProof.specialized_operation -ne "monitoring_alert_triage_queue") { throw "Generated closure specialized operation mismatch." }

    $Proof = [ordered]@{
        proof_id = $PackId
        run_id = $RunId
        status = "PASS"
        task_id = $TaskId
        capability_id = $CapabilityId
        expected_gate = $ExpectedGate
        semantic_role = $SemanticRole
        program_seed_path = $ProgramSeedPath
        seed_profile_id = $Seed.candidate_profile_id
        seed_agent_kind = $Seed.candidate_agent_kind
        profile_proof_path = $ProfileProofPath
        profile_selected_id = $ProfileProof.selected_profile_id
        closure_proof_path = $ClosureProofPath
        closure_selected_profile_id = $ClosureProof.selected_profile_id
        closure_specialized_operation = $ClosureProof.specialized_operation
        conclusion = "Generated monitoring_agent_v1 seed consumption proof confirms the generated profile and closure packs consumed the remediation seed into a serial executable contour."
    }

    $ProofPath = ".\proofs\$PackId.json"
    $Proof | ConvertTo-Json -Depth 100 |
        Set-Content $ProofPath -Encoding UTF8

    return $ProofPath
}

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=$PackId"
Write-Host "GENERATED_PACK_ROLE=$SemanticRole"
Write-Host "GENERATED_PACK_TASK=$TaskId"

$ProofPath = switch ($SemanticRole) {
    "PROFILE_MATERIALIZATION" { Invoke-GeneratedProfileMaterialization -RunId $RunId }
    "SPECIALIZED_CLOSURE_PROOF" { Invoke-GeneratedClosureProof -RunId $RunId }
    "SEED_CONSUMPTION_PROOF" { Invoke-GeneratedSeedConsumptionProof -RunId $RunId }
    default { throw "Unsupported generated semantic role: $SemanticRole" }
}

Complete-GeneratedProgramState `
    -CompletedCapabilityId $CapabilityId `
    -CompletedTaskId $TaskId `
    -FollowingCapabilityId $NextCapabilityId `
    -FollowingTaskId $NextTaskId

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    $ProofPath,
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Generated monitoring_agent_v1 self-build pack $SemanticRole"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "GENERATED_PACK_PROOF=$ProofPath"
Write-Host "PACK_COMMIT_PUSH=PASS"
'@

    $Template = $Template.Replace("__PACK_ID__", $PackId)
    $Template = $Template.Replace("__TASK_ID__", $TaskId)
    $Template = $Template.Replace("__CAPABILITY_ID__", $CapabilityId)
    $Template = $Template.Replace("__EXPECTED_GATE__", $ExpectedGate)
    $Template = $Template.Replace("__SEMANTIC_ROLE__", $Role)
    $Template = $Template.Replace("__NEXT_CAPABILITY_ID__", $NextCapabilityId)
    $Template = $Template.Replace("__NEXT_TASK_ID__", $NextTaskId)

    return $Template
}
