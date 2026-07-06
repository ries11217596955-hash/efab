function Render-GeneratedSelfBuildPackApplyFromRecipe {
    param(
        [string]$RecipePath
    )

    if ([string]::IsNullOrWhiteSpace($RecipePath)) {
        throw "RecipePath is required."
    }
    if (-not (Test-Path $RecipePath)) {
        throw "Execution recipe missing: $RecipePath"
    }

    $ResolvedRecipePath = (Resolve-Path $RecipePath).Path
    $Recipe = Get-Content $ResolvedRecipePath -Raw | ConvertFrom-Json

    Assert-GeneratedSelfBuildExecutionRecipe -Recipe $Recipe -RecipePath $ResolvedRecipePath

    $RecipeJson = $Recipe | ConvertTo-Json -Depth 100
    if ($RecipeJson -match "(?m)^'@") {
        throw "Recipe JSON cannot be embedded in generated APPLY.ps1 here-string because it contains a here-string terminator."
    }

    $Template = @'
param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Recipe = __RECIPE_HERE_START__
__RECIPE_JSON__
__RECIPE_HERE_END__

$PackId = [string]$Recipe.pack_id
$TaskId = [string]$Recipe.task_id
$CapabilityId = [string]$Recipe.capability_id
$ExpectedGate = [string]$Recipe.expected_gate
$SemanticRole = [string]$Recipe.semantic_role
$RecipeKind = [string]$Recipe.recipe_kind
$NextCapabilityId = [string]$Recipe.next_transition.next_capability_id
$NextTaskId = [string]$Recipe.next_transition.next_task_id
$QueueAction = [string]$Recipe.next_transition.queue_action

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

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "$Label path is required."
    }
    if (-not (Test-Path $Path)) {
        throw "$Label missing: $Path"
    }
}

function Assert-RequiredValue {
    param(
        [object]$Value,
        [string]$Label
    )

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        throw "$Label is required by execution recipe."
    }

    return [string]$Value
}

function Get-OptionalValue {
    param(
        [object]$Object,
        [string]$PropertyName
    )

    if ($null -eq $Object) {
        return ""
    }
    if (-not $Object.PSObject.Properties.Name.Contains($PropertyName)) {
        return ""
    }
    if ($null -eq $Object.$PropertyName) {
        return ""
    }
    return [string]$Object.$PropertyName
}

function Get-RequiredRecipeValue {
    param(
        [object]$Object,
        [string]$PropertyName,
        [string]$Label
    )

    $Value = Get-OptionalValue -Object $Object -PropertyName $PropertyName
    return Assert-RequiredValue -Value $Value -Label $Label
}

function Expand-RecipeTemplate {
    param(
        [string]$TemplateValue,
        [string]$RunId,
        [string]$PackId
    )

    return $TemplateValue.Replace("{run_id}", $RunId).Replace("{pack_id}", $PackId)
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
        [string]$FollowingTaskId,
        [string]$QueueAction
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

    if ($QueueAction -eq "ACTIVATE_NEXT_GENERATED_TASK") {
        if ([string]::IsNullOrWhiteSpace($FollowingCapabilityId) -or [string]::IsNullOrWhiteSpace($FollowingTaskId)) {
            throw "Recipe next_transition must provide next capability and next task for ACTIVATE_NEXT_GENERATED_TASK."
        }

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
    elseif ($QueueAction -eq "COMPLETE_GENERATED_PROGRAM") {
        $Queue.active_task_id = "NONE"
        $State.current_capability = $CompletedCapabilityId
    }
    else {
        throw "Unsupported recipe next_transition.queue_action: $QueueAction"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

function Assert-OperationalResult {
    param(
        [object]$Result,
        [object]$Expected,
        [string]$ProfileId,
        [string]$Context
    )

    if ($Result.result.operation -ne $Expected.operation) {
        throw "$Context specialized operation mismatch."
    }
    if ($Result.diagnostics.specialization_profile -ne $ProfileId) {
        throw "$Context specialization diagnostics mismatch."
    }
    if ($Result.result.next_alert_id -ne $Expected.next_alert_id) {
        throw "$Context next alert mismatch."
    }
    if ($Result.result.escalation_status -ne $Expected.escalation_status) {
        throw "$Context escalation status mismatch."
    }
}

function Invoke-GeneratedProfileMaterializationFromRecipe {
    param([string]$RunId)

    $Artifacts = $Recipe.input_artifacts
    $Invocation = $Recipe.invocation_contract
    $Expected = $Recipe.expected_assertions
    $BuildContract = $Invocation.external_agent_build

    $ProgramSeedPath = Get-RequiredRecipeValue -Object $Artifacts -PropertyName "program_seed_path" -Label "program seed path"
    $SpecPath = Get-RequiredRecipeValue -Object $BuildContract -PropertyName "spec_path" -Label "profile build spec path"
    $ResolverModulePath = Get-RequiredRecipeValue -Object $Artifacts -PropertyName "resolver_module_path" -Label "resolver module path"
    $ExternalBuildModulePath = Get-RequiredRecipeValue -Object $Artifacts -PropertyName "external_build_module_path" -Label "external build module path"

    Assert-PathExists -Path $ProgramSeedPath -Label "Generated program seed"
    Assert-PathExists -Path $SpecPath -Label "Generated profile proof spec"
    Assert-PathExists -Path $ResolverModulePath -Label "Specialization overlay resolver"
    Assert-PathExists -Path $ExternalBuildModulePath -Label "External agent build module"

    . $ResolverModulePath
    . $ExternalBuildModulePath

    $Seed = Get-Content $ProgramSeedPath -Raw | ConvertFrom-Json
    if ($Seed.status -ne $Expected.program_seed_status) { throw "Program seed status mismatch." }
    if ($Seed.candidate_profile_id -ne $Expected.expected_profile_id) { throw "Program seed profile target mismatch." }
    if ($Seed.candidate_agent_kind -ne $Expected.expected_agent_kind) { throw "Program seed kind target mismatch." }

    $ResolverContract = $Invocation.resolve_specialization_overlay
    $Resolution = Resolve-SpecializationOverlay `
        -AgentKind (Get-RequiredRecipeValue -Object $ResolverContract -PropertyName "agent_kind" -Label "resolver agent kind") `
        -PackageProfile (Get-RequiredRecipeValue -Object $ResolverContract -PropertyName "package_profile" -Label "resolver package profile")

    if ($Resolution.status -ne $Expected.resolver_status) { throw "Resolver status mismatch." }
    if ($Resolution.profile_id -ne $Expected.expected_profile_id) { throw "Unexpected specialization profile id." }

    $RunRootTemplate = Get-RequiredRecipeValue -Object $BuildContract -PropertyName "run_root_template" -Label "profile build run root template"
    $RunRoot = Expand-RecipeTemplate -TemplateValue $RunRootTemplate -RunId $RunId -PackId $PackId

    $Build = Invoke-ExternalAgentBuild `
        -SpecPath (Get-RequiredRecipeValue -Object $BuildContract -PropertyName "spec_path" -Label "profile build spec path") `
        -OutputRoot (Get-RequiredRecipeValue -Object $BuildContract -PropertyName "output_root" -Label "profile build output root") `
        -RunRoot $RunRoot `
        -OverlayRoot $Resolution.overlay_root

    if ($Build.status -ne $Recipe.proof_contract.status) { throw "Generated profile build status mismatch." }
    if ($Build.overlay.status -ne $Expected.overlay_status) { throw "Generated profile overlay status mismatch." }

    $ValidationOutput = $Build.validation.output_result_path
    Assert-PathExists -Path $ValidationOutput -Label "Generated profile validation output"

    $Result = Get-Content $ValidationOutput -Raw | ConvertFrom-Json
    Assert-OperationalResult `
        -Result $Result `
        -Expected $Expected.operational_result `
        -ProfileId $Expected.expected_profile_id `
        -Context "Generated profile materialization"

    $Proof = [ordered]@{
        proof_id = [string]$Recipe.proof_contract.proof_id
        run_id = $RunId
        status = [string]$Recipe.proof_contract.status
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
        conclusion = "Generated self-build profile materialization executed from program-owned execution recipe $($Recipe.recipe_id)."
    }

    $ProofPath = ".\proofs\$PackId.json"
    $Proof | ConvertTo-Json -Depth 100 |
        Set-Content $ProofPath -Encoding UTF8

    return $ProofPath
}

function Invoke-GeneratedClosureProofFromRecipe {
    param([string]$RunId)

    $Artifacts = $Recipe.input_artifacts
    $Invocation = $Recipe.invocation_contract
    $Expected = $Recipe.expected_assertions

    $RawIdeaPath = Get-RequiredRecipeValue -Object $Artifacts -PropertyName "raw_idea_path" -Label "raw idea path"
    $OrchestratorPath = Get-RequiredRecipeValue -Object $Artifacts -PropertyName "orchestrator_path" -Label "orchestrator path"
    Assert-PathExists -Path $RawIdeaPath -Label "Generated closure raw idea"
    Assert-PathExists -Path $OrchestratorPath -Label "Builder orchestrator"

    & $OrchestratorPath `
        -Mode (Get-RequiredRecipeValue -Object $Invocation -PropertyName "mode" -Label "orchestrator mode") `
        -RunId $RunId `
        -RawIdeaPath $RawIdeaPath `
        -OutputRoot (Get-RequiredRecipeValue -Object $Invocation -PropertyName "output_root" -Label "orchestrator output root") |
        Out-Host

    $ReportPathTemplate = Get-RequiredRecipeValue -Object $Invocation -PropertyName "report_path_template" -Label "factory report path template"
    $ReportPath = Expand-RecipeTemplate -TemplateValue $ReportPathTemplate -RunId $RunId -PackId $PackId
    Assert-PathExists -Path $ReportPath -Label "Generated closure factory report"

    $Report = Get-Content $ReportPath -Raw | ConvertFrom-Json
    if ($Report.status -ne $Expected.factory_report_status) { throw "Generated closure factory report status mismatch." }
    if ($Report.specialization.profile_id -ne $Expected.expected_specialization_profile_id) { throw "Generated closure specialization profile mismatch." }
    if ($Expected.PSObject.Properties.Name.Contains("gap_report") -and $null -eq $Expected.gap_report -and $null -ne $Report.gap_report) {
        throw "Generated closure path must not retain a gap report."
    }
    if ($Report.target_build.overlay_status -ne $Expected.overlay_status) { throw "Generated closure overlay status mismatch." }

    Assert-PathExists -Path $Report.target_build.validation_output -Label "Generated closure validation output"
    $Result = Get-Content $Report.target_build.validation_output -Raw | ConvertFrom-Json

    Assert-OperationalResult `
        -Result $Result `
        -Expected $Expected.operational_result `
        -ProfileId $Expected.expected_specialization_profile_id `
        -Context "Generated closure proof"

    $Proof = [ordered]@{
        proof_id = [string]$Recipe.proof_contract.proof_id
        run_id = $RunId
        status = [string]$Recipe.proof_contract.status
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
        conclusion = "Generated self-build closure proof executed from program-owned execution recipe $($Recipe.recipe_id)."
    }

    $ProofPath = ".\proofs\$PackId.json"
    $Proof | ConvertTo-Json -Depth 100 |
        Set-Content $ProofPath -Encoding UTF8

    return $ProofPath
}

function Assert-CrossProofRule {
    param(
        [string]$Rule,
        [object]$Seed,
        [object]$ProfileProof,
        [object]$ClosureProof
    )

    switch -Regex ($Rule) {
        "^profile_proof\.status == (.+)$" {
            if ($ProfileProof.status -ne $Matches[1]) { throw "Cross-proof rule failed: $Rule" }
            return
        }
        "^profile_proof\.selected_profile_id == seed\.candidate_profile_id$" {
            if ($ProfileProof.selected_profile_id -ne $Seed.candidate_profile_id) { throw "Cross-proof rule failed: $Rule" }
            return
        }
        "^closure_proof\.status == (.+)$" {
            if ($ClosureProof.status -ne $Matches[1]) { throw "Cross-proof rule failed: $Rule" }
            return
        }
        "^closure_proof\.selected_profile_id == seed\.candidate_profile_id$" {
            if ($ClosureProof.selected_profile_id -ne $Seed.candidate_profile_id) { throw "Cross-proof rule failed: $Rule" }
            return
        }
        "^closure_proof\.specialized_operation == (.+)$" {
            if ($ClosureProof.specialized_operation -ne $Matches[1]) { throw "Cross-proof rule failed: $Rule" }
            return
        }
        default {
            throw "Unsupported generated seed-consumption cross-proof rule: $Rule"
        }
    }
}

function Invoke-GeneratedSeedConsumptionProofFromRecipe {
    param([string]$RunId)

    $Artifacts = $Recipe.input_artifacts
    $Expected = $Recipe.expected_assertions

    $ProgramSeedPath = Get-RequiredRecipeValue -Object $Artifacts -PropertyName "program_seed_path" -Label "program seed path"
    $ProfileProofPath = Get-RequiredRecipeValue -Object $Artifacts -PropertyName "dependent_generated_profile_proof_path" -Label "dependent profile proof path"
    $ClosureProofPath = Get-RequiredRecipeValue -Object $Artifacts -PropertyName "dependent_generated_closure_proof_path" -Label "dependent closure proof path"

    Assert-PathExists -Path $ProgramSeedPath -Label "Generated program seed"
    Assert-PathExists -Path $ProfileProofPath -Label "Generated profile proof"
    Assert-PathExists -Path $ClosureProofPath -Label "Generated closure proof"

    $Seed = Get-Content $ProgramSeedPath -Raw | ConvertFrom-Json
    $ProfileProof = Get-Content $ProfileProofPath -Raw | ConvertFrom-Json
    $ClosureProof = Get-Content $ClosureProofPath -Raw | ConvertFrom-Json

    if ($Seed.candidate_profile_id -ne $Expected.seed_profile_id) { throw "Seed profile id mismatch." }
    if ($Seed.candidate_agent_kind -ne $Expected.seed_agent_kind) { throw "Seed agent kind mismatch." }

    foreach ($Rule in @($Expected.cross_proof_consistency_rules)) {
        Assert-CrossProofRule -Rule $Rule -Seed $Seed -ProfileProof $ProfileProof -ClosureProof $ClosureProof
    }

    if ($ClosureProof.specialized_operation -ne $Expected.expected_specialized_operation) {
        throw "Generated closure specialized operation mismatch."
    }

    $Proof = [ordered]@{
        proof_id = [string]$Recipe.proof_contract.proof_id
        run_id = $RunId
        status = [string]$Recipe.proof_contract.status
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
        conclusion = "Generated self-build seed consumption proof executed from program-owned execution recipe $($Recipe.recipe_id)."
    }

    $ProofPath = ".\proofs\$PackId.json"
    $Proof | ConvertTo-Json -Depth 100 |
        Set-Content $ProofPath -Encoding UTF8

    return $ProofPath
}

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=__PACK_MARKER__"
Write-Host "GENERATED_PACK_ROLE=__ROLE_MARKER__"
Write-Host "GENERATED_PACK_TASK=__TASK_MARKER__"

$ProofPath = switch ($RecipeKind) {
    "PROFILE_MATERIALIZATION_RECIPE_V1" { Invoke-GeneratedProfileMaterializationFromRecipe -RunId $RunId }
    "SPECIALIZED_CLOSURE_PROOF_RECIPE_V1" { Invoke-GeneratedClosureProofFromRecipe -RunId $RunId }
    "SEED_CONSUMPTION_PROOF_RECIPE_V1" { Invoke-GeneratedSeedConsumptionProofFromRecipe -RunId $RunId }
    default { throw "Unsupported generated execution recipe kind: $RecipeKind" }
}

Complete-GeneratedProgramState `
    -CompletedCapabilityId $CapabilityId `
    -CompletedTaskId $TaskId `
    -FollowingCapabilityId $NextCapabilityId `
    -FollowingTaskId $NextTaskId `
    -QueueAction $QueueAction

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
    "Generated self-build pack $SemanticRole from execution recipe"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "GENERATED_PACK_PROOF=$ProofPath"
Write-Host "PACK_COMMIT_PUSH=PASS"
'@

    $Template = $Template.Replace("__RECIPE_HERE_START__", "@'")
    $Template = $Template.Replace("__RECIPE_HERE_END__", "'@ | ConvertFrom-Json")
    $Template = $Template.Replace("__RECIPE_JSON__", $RecipeJson)
    $Template = $Template.Replace("__PACK_MARKER__", [string]$Recipe.pack_id)
    $Template = $Template.Replace("__ROLE_MARKER__", [string]$Recipe.semantic_role)
    $Template = $Template.Replace("__TASK_MARKER__", [string]$Recipe.task_id)

    return $Template
}

function Assert-GeneratedSelfBuildExecutionRecipe {
    param(
        [object]$Recipe,
        [string]$RecipePath
    )

    $RequiredFields = @(
        "recipe_id",
        "program_manifest_path",
        "target_profile_id",
        "target_agent_kind",
        "pack_id",
        "task_id",
        "capability_id",
        "expected_gate",
        "semantic_role",
        "recipe_kind",
        "input_artifacts",
        "invocation_contract",
        "expected_assertions",
        "proof_contract",
        "next_transition"
    )

    foreach ($Field in $RequiredFields) {
        if (-not $Recipe.PSObject.Properties.Name.Contains($Field)) {
            throw "Execution recipe missing required field $Field at $RecipePath"
        }
        if ($null -eq $Recipe.$Field) {
            throw "Execution recipe required field $Field must not be null at $RecipePath"
        }
    }

    foreach ($StringField in @(
        "recipe_id",
        "program_manifest_path",
        "target_profile_id",
        "target_agent_kind",
        "pack_id",
        "task_id",
        "capability_id",
        "expected_gate",
        "semantic_role",
        "recipe_kind"
    )) {
        if ([string]::IsNullOrWhiteSpace([string]$Recipe.$StringField)) {
            throw "Execution recipe field $StringField must not be empty at $RecipePath"
        }
    }

    $SupportedKinds = @(
        "PROFILE_MATERIALIZATION_RECIPE_V1",
        "SPECIALIZED_CLOSURE_PROOF_RECIPE_V1",
        "SEED_CONSUMPTION_PROOF_RECIPE_V1"
    )
    if ($SupportedKinds -notcontains [string]$Recipe.recipe_kind) {
        throw "Unsupported generated execution recipe kind at ${RecipePath}: $($Recipe.recipe_kind)"
    }

    $SupportedRoles = @(
        "PROFILE_MATERIALIZATION",
        "SPECIALIZED_CLOSURE_PROOF",
        "SEED_CONSUMPTION_PROOF"
    )
    if ($SupportedRoles -notcontains [string]$Recipe.semantic_role) {
        throw "Unsupported generated execution recipe semantic_role at ${RecipePath}: $($Recipe.semantic_role)"
    }

    $ExpectedRoleByKind = @{
        PROFILE_MATERIALIZATION_RECIPE_V1 = "PROFILE_MATERIALIZATION"
        SPECIALIZED_CLOSURE_PROOF_RECIPE_V1 = "SPECIALIZED_CLOSURE_PROOF"
        SEED_CONSUMPTION_PROOF_RECIPE_V1 = "SEED_CONSUMPTION_PROOF"
    }
    if ($ExpectedRoleByKind[[string]$Recipe.recipe_kind] -ne [string]$Recipe.semantic_role) {
        throw "Execution recipe kind/semantic_role mismatch at $RecipePath"
    }

    foreach ($TransitionField in @("queue_action")) {
        if (-not $Recipe.next_transition.PSObject.Properties.Name.Contains($TransitionField)) {
            throw "Execution recipe next_transition missing $TransitionField at $RecipePath"
        }
        if ([string]::IsNullOrWhiteSpace([string]$Recipe.next_transition.$TransitionField)) {
            throw "Execution recipe next_transition.$TransitionField must not be empty at $RecipePath"
        }
    }
}
