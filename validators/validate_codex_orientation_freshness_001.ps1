param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-GitValue {
    param(
        [string]$Root,
        [string[]]$Arguments,
        [switch]$Optional
    )

    $output = @(& git -C $Root @Arguments 2>$null)
    if ($LASTEXITCODE -ne 0) {
        if ($Optional) {
            return $null
        }
        throw "git $($Arguments -join ' ') failed."
    }
    return (($output -join "`n").Trim())
}

function Get-ObjectPropertyValue {
    param(
        [object]$InputObject,
        [string]$Name
    )

    if ($null -eq $InputObject -or $InputObject.PSObject.Properties.Name -notcontains $Name) {
        return $null
    }
    return $InputObject.$Name
}

function Test-OrientationFreshness {
    param(
        [string]$GeneratedFromHead,
        [string]$CurrentHead,
        [string]$CurrentHeadParent,
        [string]$LatestCommitMessage,
        [bool]$SelfCommitTolerance
    )

    $preCommitState = -not [string]::IsNullOrWhiteSpace($GeneratedFromHead) -and
        $GeneratedFromHead -eq $CurrentHead
    $acceptedOrientationCommit = $LatestCommitMessage -match
        "(?i)^(?=.*codex)(?=.*orientation)(?=.*(?:refresh|repair))(?=.*(?:accept|accepted|acceptance)).+$"
    $selfCommitParentState = $SelfCommitTolerance -and
        -not [string]::IsNullOrWhiteSpace($GeneratedFromHead) -and
        -not [string]::IsNullOrWhiteSpace($CurrentHeadParent) -and
        $GeneratedFromHead -eq $CurrentHeadParent -and
        $acceptedOrientationCommit

    return [pscustomobject][ordered]@{
        valid = [bool]($preCommitState -or $selfCommitParentState)
        pre_commit_state = [bool]$preCommitState
        self_commit_parent_state = [bool]$selfCommitParentState
        accepted_orientation_commit_message = [bool]$acceptedOrientationCommit
    }
}

function Write-Utf8File {
    param(
        [string]$Path,
        [string]$Content
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
}

$root = (Resolve-Path $RepoRoot).Path
$errors = [System.Collections.Generic.List[string]]::new()

function Assert-Condition {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        $script:errors.Add($Message)
    }
}

$requiredIdentityFiles = @(
    "CAPABILITY_ROADMAP.json",
    "GENESIS_STATE.json",
    "TASK_QUEUE.json",
    "packs/registry.json",
    "orchestrator/run.ps1"
)
$missingIdentityFiles = @(
    $requiredIdentityFiles |
        Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_)) }
)
if ($missingIdentityFiles.Count -gt 0) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing: $($missingIdentityFiles -join ', ')"
}

$generatedFiles = @(
    "docs/codex/CODEX_REPO_MAP.md",
    "docs/codex/CODEX_EVIDENCE_INDEX.md",
    "docs/codex/CODEX_CURRENT_STATE_THIN.json"
)
$repoMapPath = Join-Path $root $generatedFiles[0]
$evidenceIndexPath = Join-Path $root $generatedFiles[1]
$currentStatePath = Join-Path $root $generatedFiles[2]
$agentsPath = Join-Path $root "AGENTS.md"
$activeRouteLock = "route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2.md"

foreach ($relativePath in $generatedFiles) {
    Assert-Condition `
        -Condition (Test-Path -LiteralPath (Join-Path $root $relativePath)) `
        -Message "Missing generated file: $relativePath"
}

$branch = Get-GitValue -Root $root -Arguments @("branch", "--show-current")
$head = Get-GitValue -Root $root -Arguments @("rev-parse", "HEAD")
$headParent = Get-GitValue -Root $root -Arguments @("rev-parse", "$head~1") -Optional
$latestCommitMessage = Get-GitValue -Root $root -Arguments @("log", "-1", "--format=%s")
$origin = Get-GitValue -Root $root -Arguments @(
    "rev-parse",
    "--verify",
    "origin/phase110-idempotent-autonomy-trial-runtime"
) -Optional
$headEqualsOrigin = (-not [string]::IsNullOrWhiteSpace($origin)) -and ($head -eq $origin)

$state = $null
if (Test-Path -LiteralPath $currentStatePath) {
    try {
        $state = Get-Content -LiteralPath $currentStatePath -Raw | ConvertFrom-Json
    }
    catch {
        $errors.Add("CODEX_CURRENT_STATE_THIN.json is not valid JSON: $($_.Exception.Message)")
    }
}

$repoMap = if (Test-Path -LiteralPath $repoMapPath) {
    Get-Content -LiteralPath $repoMapPath -Raw
}
else {
    ""
}
$evidenceIndex = if (Test-Path -LiteralPath $evidenceIndexPath) {
    Get-Content -LiteralPath $evidenceIndexPath -Raw
}
else {
    ""
}
$agents = if (Test-Path -LiteralPath $agentsPath) {
    Get-Content -LiteralPath $agentsPath -Raw
}
else {
    ""
}

$expectedReadFirst = @(
    "AGENTS.md",
    "README.md",
    $activeRouteLock,
    "CAPABILITY_ROADMAP.json",
    "GENESIS_STATE.json",
    "TASK_QUEUE.json",
    "packs/registry.json",
    "orchestrator/run.ps1"
)
$expectedSkipRules = @(
    "reports/**",
    "proofs/**",
    "self_build_programs/**/canonical_trials/**",
    "self_build_programs/**/dry_runs/**",
    "self_build_programs/**/promotions/**",
    "runtime_sessions/**",
    "zz_MUSORKA_DO_NOT_READ_BY_CODEX/**"
)

$routeLockPresent = Test-Path -LiteralPath (Join-Path $root $activeRouteLock)
$currentStateThinPresent = Test-Path -LiteralPath $currentStatePath
$repoMapPresent = Test-Path -LiteralPath $repoMapPath
$evidenceIndexPresent = Test-Path -LiteralPath $evidenceIndexPath
$agentsBudgetBlockPresent = $agents.Contains("<!-- CODEX_CONTEXT_BUDGET_START -->") -and
    $agents.Contains("<!-- CODEX_CONTEXT_BUDGET_END -->")
$exactPathRulePresent = $repoMap.Contains("Exact-Path Evidence Rule") -and
    $repoMap.Contains("exact proof or report path") -and
    $evidenceIndex.Contains("Exact-Path Evidence Rule")

$readFirstPresent = $false
$skipRulesPresent = $false
$freshnessModelRepaired = $false
$selfCommitTolerancePresent = $false
$generatedFromHeadPresent = $false
$actualFreshness = [pscustomobject][ordered]@{
    valid = $false
    pre_commit_state = $false
    self_commit_parent_state = $false
    accepted_orientation_commit_message = $false
}

if ($null -ne $state) {
    $stateBranch = [string](Get-ObjectPropertyValue -InputObject $state -Name "branch")
    $stateRouteLock = [string](Get-ObjectPropertyValue -InputObject $state -Name "active_route_lock")
    $generatedFromHead = [string](Get-ObjectPropertyValue -InputObject $state -Name "generated_from_head")
    $freshnessModel = [string](Get-ObjectPropertyValue -InputObject $state -Name "orientation_freshness_model")
    $selfCommitTolerance = [bool](Get-ObjectPropertyValue -InputObject $state -Name "orientation_self_commit_tolerance")

    Assert-Condition -Condition ($stateBranch -eq $branch) -Message "Thin state branch does not equal actual git branch."
    Assert-Condition -Condition ($stateRouteLock -eq $activeRouteLock) -Message "Thin state active route lock is incorrect."

    $generatedFromHeadPresent = -not [string]::IsNullOrWhiteSpace($generatedFromHead)
    $selfCommitTolerancePresent = $selfCommitTolerance
    $freshnessModelRepaired = $freshnessModel -eq "generated_from_repo_state_not_self_referential"
    $actualFreshness = Test-OrientationFreshness `
        -GeneratedFromHead $generatedFromHead `
        -CurrentHead $head `
        -CurrentHeadParent $headParent `
        -LatestCommitMessage $latestCommitMessage `
        -SelfCommitTolerance $selfCommitTolerance

    Assert-Condition -Condition $generatedFromHeadPresent -Message "Thin state generated_from_head is missing."
    Assert-Condition -Condition $selfCommitTolerancePresent -Message "Thin state self-commit tolerance is missing."
    Assert-Condition -Condition $freshnessModelRepaired -Message "Thin state freshness model is missing or incorrect."
    Assert-Condition `
        -Condition $actualFreshness.valid `
        -Message "Thin state was not generated from current HEAD or an accepted orientation self-commit parent."

    $actualReadFirst = @(
        (Get-ObjectPropertyValue -InputObject $state -Name "read_first") |
            ForEach-Object { [string]$_ }
    )
    $readFirstPresent = ($actualReadFirst.Count -gt 0) -and (@(
        $expectedReadFirst |
            Where-Object { $actualReadFirst -notcontains $_ }
    ).Count -eq 0)

    $actualSkipRules = @(
        (Get-ObjectPropertyValue -InputObject $state -Name "codex_skip_rules") |
            ForEach-Object { [string]$_ }
    )
    $skipRulesPresent = ($actualSkipRules.Count -gt 0) -and (@(
        $expectedSkipRules |
            Where-Object { $actualSkipRules -notcontains $_ }
    ).Count -eq 0)
}

Assert-Condition -Condition $routeLockPresent -Message "Active route lock is missing."
Assert-Condition -Condition $readFirstPresent -Message "Required read-first list is missing or incomplete."
Assert-Condition -Condition $skipRulesPresent -Message "Required Codex skip rules are missing or incomplete."
Assert-Condition -Condition $exactPathRulePresent -Message "Exact-path evidence rule is missing."
Assert-Condition -Condition $agentsBudgetBlockPresent -Message "AGENTS.md Codex Context Budget block is missing."

$freshnessPreCommitTest = Test-OrientationFreshness `
    -GeneratedFromHead "PRE_COMMIT_HEAD" `
    -CurrentHead "PRE_COMMIT_HEAD" `
    -CurrentHeadParent "OLDER_HEAD" `
    -LatestCommitMessage "Unrelated commit" `
    -SelfCommitTolerance $true
$freshnessSelfCommitParentTest = Test-OrientationFreshness `
    -GeneratedFromHead "ORIENTATION_PARENT" `
    -CurrentHead "ORIENTATION_ACCEPTANCE" `
    -CurrentHeadParent "ORIENTATION_PARENT" `
    -LatestCommitMessage "Accept PHASE165P Codex orientation freshness model repair" `
    -SelfCommitTolerance $true
$freshnessInvalidTest = Test-OrientationFreshness `
    -GeneratedFromHead "STALE_HEAD" `
    -CurrentHead "CURRENT_HEAD" `
    -CurrentHeadParent "PARENT_HEAD" `
    -LatestCommitMessage "Accept PHASE165P Codex orientation freshness model repair" `
    -SelfCommitTolerance $true
$validatorAcceptsPreCommitState = [bool]$freshnessPreCommitTest.valid
$validatorAcceptsSelfCommitParentModel = [bool]$freshnessSelfCommitParentTest.valid
Assert-Condition -Condition $validatorAcceptsPreCommitState -Message "Validator pre-commit freshness model self-test failed."
Assert-Condition `
    -Condition $validatorAcceptsSelfCommitParentModel `
    -Message "Validator self-commit parent freshness model self-test failed."
Assert-Condition -Condition (-not $freshnessInvalidTest.valid) -Message "Validator stale-state rejection self-test failed."

$protectedFiles = [ordered]@{
    task_queue_mutated = "TASK_QUEUE.json"
    genesis_state_mutated = "GENESIS_STATE.json"
    capability_roadmap_mutated = "CAPABILITY_ROADMAP.json"
    registry_mutated = "packs/registry.json"
    route_lock_mutated = $activeRouteLock
    orchestrator_mutated = "orchestrator/run.ps1"
}
$mutationResults = @{}
foreach ($field in $protectedFiles.Keys) {
    $relativePath = $protectedFiles[$field]
    $workingTreeChanged = Get-GitValue -Root $root -Arguments @(
        "diff",
        "--name-only",
        "HEAD",
        "--",
        $relativePath
    )
    $latestCommitChanged = $null
    if ($actualFreshness.self_commit_parent_state) {
        $latestCommitChanged = Get-GitValue -Root $root -Arguments @(
            "diff",
            "--name-only",
            $headParent,
            $head,
            "--",
            $relativePath
        )
    }

    $mutated = -not [string]::IsNullOrWhiteSpace($workingTreeChanged) -or
        -not [string]::IsNullOrWhiteSpace($latestCommitChanged)
    $mutationResults[$field] = $mutated
    Assert-Condition -Condition (-not $mutated) -Message "Protected file was mutated: $relativePath"
}

$validationPassed = $errors.Count -eq 0
$status = if ($validationPassed) { "PASS" } else { "FAIL" }
$nextRequiredAction = if ($validationPassed) {
    "PHASE165P_CODEX_ORIENTATION_FRESHNESS_MODEL_REPAIR_ACCEPTANCE_COMMIT"
}
else {
    "PHASE165P_CODEX_ORIENTATION_FRESHNESS_MODEL_REPAIR_TRIAGE"
}
$actualFreshnessMode = if ($actualFreshness.pre_commit_state) {
    "PRE_COMMIT_CURRENT_HEAD"
}
elseif ($actualFreshness.self_commit_parent_state) {
    "ACCEPTED_SELF_COMMIT_PARENT"
}
else {
    "STALE"
}

$proofPath = Join-Path $root "proofs/self_development/PHASE165P_CODEX_ORIENTATION_FRESHNESS_MODEL_REPAIR_V1.json"
$reportPath = Join-Path $root "reports/self_development/PHASE165P_CODEX_ORIENTATION_FRESHNESS_MODEL_REPAIR_V1.md"
$proofCreatedUtc = [DateTime]::UtcNow.ToString("o")
if (Test-Path -LiteralPath $proofPath) {
    try {
        $existingProof = Get-Content -LiteralPath $proofPath -Raw | ConvertFrom-Json
        if ([string](Get-ObjectPropertyValue -InputObject $existingProof -Name "phase") -eq
                "PHASE165P_CODEX_ORIENTATION_FRESHNESS_MODEL_REPAIR" -and
            -not [string]::IsNullOrWhiteSpace(
                [string](Get-ObjectPropertyValue -InputObject $existingProof -Name "created_utc")
            )) {
            $existingCreatedUtc = Get-ObjectPropertyValue -InputObject $existingProof -Name "created_utc"
            $proofCreatedUtc = if ($existingCreatedUtc -is [DateTime]) {
                $existingCreatedUtc.ToUniversalTime().ToString("o")
            }
            else {
                [string]$existingCreatedUtc
            }
        }
    }
    catch {
        # A malformed prior proof is replaced by the current validation result.
    }
}

$proof = [ordered]@{
    phase = "PHASE165P_CODEX_ORIENTATION_FRESHNESS_MODEL_REPAIR"
    created_utc = $proofCreatedUtc
    status = $status
    validation_passed = [bool]$validationPassed
    errors = @($errors)
    branch = $branch
    head = $head
    head_parent = $headParent
    latest_commit_message = $latestCommitMessage
    origin = $origin
    head_equals_origin = [bool]$headEqualsOrigin
    freshness_model_repaired = [bool]$freshnessModelRepaired
    self_commit_tolerance_present = [bool]$selfCommitTolerancePresent
    generated_from_head_present = [bool]$generatedFromHeadPresent
    actual_freshness_valid = [bool]$actualFreshness.valid
    actual_freshness_mode = $actualFreshnessMode
    validator_accepts_pre_commit_state = [bool]$validatorAcceptsPreCommitState
    validator_accepts_self_commit_parent_model = [bool]$validatorAcceptsSelfCommitParentModel
    current_state_thin_present = [bool]$currentStateThinPresent
    repo_map_present = [bool]$repoMapPresent
    evidence_index_present = [bool]$evidenceIndexPresent
    agents_budget_block_present = [bool]$agentsBudgetBlockPresent
    skip_rules_present = [bool]$skipRulesPresent
    exact_path_rule_present = [bool]$exactPathRulePresent
    task_queue_mutated = [bool]$mutationResults["task_queue_mutated"]
    genesis_state_mutated = [bool]$mutationResults["genesis_state_mutated"]
    capability_roadmap_mutated = [bool]$mutationResults["capability_roadmap_mutated"]
    registry_mutated = [bool]$mutationResults["registry_mutated"]
    route_lock_mutated = [bool]$mutationResults["route_lock_mutated"]
    orchestrator_mutated = [bool]$mutationResults["orchestrator_mutated"]
    orchestrator_run = $false
    external_fetch_or_install = $false
    codex_used = $true
    next_required_action = $nextRequiredAction
}

$reportLines = @(
    "# PHASE165P Codex Orientation Freshness Model Repair",
    "",
    "- Status: **$status**",
    "- Validation passed: ``$($validationPassed.ToString().ToLowerInvariant())``",
    "- Branch: ``$branch``",
    "- HEAD: ``$head``",
    "- Freshness mode: ``$actualFreshnessMode``",
    "- Origin: ``$(if ($origin) { $origin } else { 'UNAVAILABLE' })``",
    "- HEAD equals origin: ``$($headEqualsOrigin.ToString().ToLowerInvariant())``",
    "- Active route lock present: ``$($routeLockPresent.ToString().ToLowerInvariant())``",
    "- Orchestrator run: ``false``",
    "- External fetch or install: ``false``",
    "",
    "## Repaired Loop",
    "",
    "The former validator required the generated HEAD to equal current HEAD. Committing the generated orientation files changed HEAD and made the accepted orientation appear stale immediately. The repaired model records the source repository state and tolerates one latest acceptance commit whose parent is that recorded source.",
    "",
    "## Manual Refresh",
    "",
    "Run the generator before a major Codex task and whenever the active route, protected state, registry/roadmap/self-model, or proof index changes. Then run the validator before acceptance.",
    "",
    "## Automation Boundary",
    "",
    "Auto-after-push is not enabled because this phase does not create a GitHub Action and should not introduce unattended repository mutation. If the Owner later wants automation, the next step is a separately scoped workflow that refreshes, validates, and opens or commits a bounded orientation-only change.",
    "",
    "## Protected File Mutation Checks",
    ""
)
foreach ($field in $protectedFiles.Keys) {
    $reportLines += "- ``$($protectedFiles[$field])`` mutated: ``$($mutationResults[$field].ToString().ToLowerInvariant())``"
}
$reportLines += @(
    "",
    "## Validation Errors",
    ""
)
if ($errors.Count -eq 0) {
    $reportLines += "- None."
}
else {
    $reportLines += $errors | ForEach-Object { "- $_" }
}
$reportLines += @(
    "",
    "## Next Required Action",
    "",
    "``$nextRequiredAction``",
    ""
)

Write-Utf8File -Path $proofPath -Content ($proof | ConvertTo-Json -Depth 20)
Write-Utf8File -Path $reportPath -Content ($reportLines -join "`n")

Write-Host "CODEX_ORIENTATION_VALIDATION=$status"
Write-Host "FRESHNESS_MODE=$actualFreshnessMode"
Write-Host "PROOF_PATH=proofs/self_development/PHASE165P_CODEX_ORIENTATION_FRESHNESS_MODEL_REPAIR_V1.json"
Write-Host "REPORT_PATH=reports/self_development/PHASE165P_CODEX_ORIENTATION_FRESHNESS_MODEL_REPAIR_V1.md"
Write-Host "NEXT_REQUIRED_ACTION=$nextRequiredAction"

if (-not $validationPassed) {
    throw "Codex orientation freshness validation failed: $($errors -join '; ')"
}

[pscustomobject]$proof
